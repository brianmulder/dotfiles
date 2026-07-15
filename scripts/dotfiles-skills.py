#!/usr/bin/env python3
"""Compose private skill profiles into runtime-specific agent skill trees."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # Python 3.10 and earlier
    try:
        import tomli as tomllib
    except ModuleNotFoundError as exc:
        raise SystemExit("dotfiles-skills requires Python 3.11+ or the tomli package") from exc


TARGET_DEFAULTS = {
    "codex": "{home}/.codex/skills",
    "claude-code": "{home}/.claude/skills",
    "openclaw": "{home}/.agents/skills",
}

CODEX_FRONTMATTER = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}

ADAPTER_VERSIONS = {
    "codex": 1,
    "claude-code": 1,
    "openclaw": 1,
}


class EstateError(RuntimeError):
    pass


@dataclass(frozen=True)
class Roots:
    home: Path
    config: Path
    data: Path
    state: Path


def read_toml(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except FileNotFoundError as exc:
        raise EstateError(f"missing file: {path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise EstateError(f"invalid TOML in {path}: {exc}") from exc


def expand_path(value: str, *, roots: Roots, source: Path) -> Path:
    replacements = {
        "{home}": str(roots.home),
        "{source}": str(source),
    }
    for key, replacement in replacements.items():
        value = value.replace(key, replacement)
    path = Path(os.path.expandvars(os.path.expanduser(value)))
    return path if path.is_absolute() else source / path


def package_hash(directory: Path) -> str:
    digest = hashlib.sha256()
    files = sorted(
        ((path.relative_to(directory).as_posix(), path) for path in directory.rglob("*") if path.is_file()),
        key=lambda item: item[0],
    )
    for relative, path in files:
        if any(part in {".git", "__pycache__"} for part in path.parts):
            continue
        if relative == ".dotfiles-skills-managed.json":
            continue
        digest.update(relative.encode())
        digest.update(b"\0")
        content = path.read_bytes()
        if b"\0" not in content:
            content = content.replace(b"\r\n", b"\n")
        digest.update(content)
        digest.update(b"\0")
    return digest.hexdigest()


def target_paths(profile: dict[str, Any], target: str, roots: Roots) -> list[Path]:
    configured = profile.get("target_paths", {}).get(target)
    if configured is None and target not in TARGET_DEFAULTS:
        raise EstateError(f"custom target {target!r} requires target_paths")
    values = configured if configured is not None else [TARGET_DEFAULTS[target]]
    if isinstance(values, str):
        values = [values]
    return [expand_path(value, roots=roots, source=roots.home) for value in values]


def target_adapter(profile: dict[str, Any], target: str) -> str:
    configured = profile.get("target_adapters", {}).get(target)
    if configured:
        return str(configured)
    for adapter in ("codex", "claude-code", "openclaw"):
        if target == adapter or target.startswith(adapter + "-"):
            return adapter
    raise EstateError(f"custom target {target!r} requires target_adapters")


def load_desired(roots: Roots) -> list[dict[str, Any]]:
    descriptor_root = roots.config / "sources.d"
    descriptors = sorted(descriptor_root.glob("*.toml")) if descriptor_root.exists() else []
    if not descriptors:
        raise EstateError(f"no source descriptors under {descriptor_root}")

    desired: list[dict[str, Any]] = []
    seen: set[str] = set()
    for descriptor_path in descriptors:
        descriptor = read_toml(descriptor_path)
        if descriptor.get("version") != 1:
            raise EstateError(f"unsupported descriptor version in {descriptor_path}")
        source = expand_path(str(descriptor["path"]), roots=roots, source=descriptor_path.parent)
        profile_name = str(descriptor["profile"])
        manifest_path = source / str(descriptor.get("manifest", "estate.toml"))
        manifest = read_toml(manifest_path)
        if manifest.get("version") != 1:
            raise EstateError(f"unsupported estate version in {manifest_path}")
        try:
            profile = manifest["profiles"][profile_name]
        except KeyError as exc:
            raise EstateError(f"profile {profile_name!r} missing from {manifest_path}") from exc
        subscriptions = profile.get("subscriptions")
        enabled_targets = set(subscriptions.keys()) if subscriptions else set(profile.get("targets", []))
        frozen = bool(descriptor.get("frozen", False))
        lock: dict[str, Any] | None = None
        if frozen:
            lock_path = source / str(descriptor.get("lock", "skills.lock.json"))
            if not lock_path.is_file():
                raise EstateError(f"missing frozen lock: {lock_path}")
            try:
                lock = json.loads(lock_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise EstateError(f"invalid frozen lock {lock_path}: {exc}") from exc
            if lock.get("version") != 1:
                raise EstateError(f"unsupported frozen lock version in {lock_path}")
        for target in enabled_targets:
            target_adapter(profile, target)
            target_paths(profile, target, roots)
        selected_names = (
            sorted({name for names in subscriptions.values() for name in names})
            if subscriptions
            else profile.get("skills", [])
        )
        for skill_name in selected_names:
            try:
                skill = manifest["skills"][skill_name]
            except KeyError as exc:
                raise EstateError(f"skill {skill_name!r} missing from {manifest_path}") from exc
            source_path = expand_path(str(skill["path"]), roots=roots, source=source)
            skill_file = source_path / "SKILL.md"
            if not skill_file.is_file():
                raise EstateError(f"skill {skill_name!r} has no SKILL.md at {source_path}")
            source_hash = package_hash(source_path)
            if frozen:
                locked = lock.get("skills", {}).get(skill_name, {}) if lock else {}
                if locked.get("hash") != source_hash:
                    raise EstateError(f"skill {skill_name!r} does not match frozen lock")
            if subscriptions:
                selected_targets = sorted(
                    target
                    for target, names in subscriptions.items()
                    if skill_name in names and target in skill.get("targets", enabled_targets)
                )
            else:
                selected_targets = sorted(enabled_targets.intersection(skill.get("targets", enabled_targets)))
            for target in selected_targets:
                for destination_root in target_paths(profile, target, roots):
                    destination = destination_root / skill_name
                    identity = str(destination)
                    if identity in seen:
                        raise EstateError(f"duplicate desired destination: {destination}")
                    seen.add(identity)
                    desired.append(
                        {
                            "skill": skill_name,
                            "target": target,
                            "adapter": target_adapter(profile, target),
                            "source": source_path,
                            "source_hash": source_hash,
                            "destination": destination,
                            "mode": str(skill.get("mode", "auto")),
                            "descriptor": descriptor_path,
                            "profile": profile_name,
                        }
                    )
    return sorted(desired, key=lambda item: (item["skill"], item["target"], str(item["destination"])))


def descriptor_paths(roots: Roots) -> list[Path]:
    descriptor_root = roots.config / "sources.d"
    return sorted(descriptor_root.glob("*.toml")) if descriptor_root.exists() else []


def lock_sources(roots: Roots) -> list[Path]:
    descriptors = descriptor_paths(roots)
    if not descriptors:
        raise EstateError(f"no source descriptors under {roots.config / 'sources.d'}")
    written: list[Path] = []
    for descriptor_path in descriptors:
        descriptor = read_toml(descriptor_path)
        source = expand_path(str(descriptor["path"]), roots=roots, source=descriptor_path.parent)
        manifest_path = source / str(descriptor.get("manifest", "estate.toml"))
        manifest = read_toml(manifest_path)
        skills: dict[str, Any] = {}
        for name, skill in sorted(manifest.get("skills", {}).items()):
            source_path = expand_path(str(skill["path"]), roots=roots, source=source)
            if not (source_path / "SKILL.md").is_file():
                raise EstateError(f"skill {name!r} has no SKILL.md at {source_path}")
            skills[name] = {"hash": package_hash(source_path), "path": str(skill["path"])}
        lock_path = source / str(descriptor.get("lock", "skills.lock.json"))
        payload = {"version": 1, "skills": skills}
        lock_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        written.append(lock_path)
    return written


def add_source(roots: Roots, name: str, path: Path, profile: str, frozen: bool, force: bool) -> Path:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
        raise EstateError("source name must contain only letters, numbers, dots, underscores, or hyphens")
    path = path.expanduser().resolve()
    if not (path / "estate.toml").is_file():
        raise EstateError(f"source has no estate.toml: {path}")
    descriptor_root = roots.config / "sources.d"
    descriptor_root.mkdir(parents=True, exist_ok=True)
    destination = descriptor_root / f"{name}.toml"
    if destination.exists() and not force:
        raise EstateError(f"source descriptor already exists: {destination}")
    content = (
        "version = 1\n"
        f"path = {json.dumps(path.as_posix())}\n"
        f"profile = {json.dumps(profile)}\n"
        f"frozen = {'true' if frozen else 'false'}\n"
    )
    destination.write_text(content, encoding="utf-8")
    return destination


def load_receipts(roots: Roots) -> dict[str, Any]:
    path = roots.state / "deployments.json"
    if not path.exists():
        return {"version": 1, "deployments": {}}
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("version") != 1:
        raise EstateError(f"unsupported deployment receipt version in {path}")
    return value


def is_managed(destination: Path, roots: Roots, receipts: dict[str, Any]) -> bool:
    if destination.is_symlink():
        try:
            destination.resolve().relative_to((roots.data / "build").resolve())
            return True
        except (OSError, ValueError):
            return False
    marker = destination / ".dotfiles-skills-managed.json"
    if not marker.is_file():
        return False
    try:
        metadata = json.loads(marker.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return False
    return metadata.get("version") == 1


def deployed_matches(destination: Path, desired: dict[str, Any], receipt: dict[str, Any] | None) -> bool:
    if not receipt or not (destination.exists() or destination.is_symlink()):
        return False
    if (
        receipt.get("source_hash") != desired["source_hash"]
        or receipt.get("target") != desired["target"]
        or receipt.get("adapter") != desired["adapter"]
        or receipt.get("adapter_version") != ADAPTER_VERSIONS[desired["adapter"]]
    ):
        return False
    build = Path(receipt.get("build", ""))
    if not build.is_dir() or package_hash(build) != receipt.get("build_hash"):
        return False
    if destination.is_symlink():
        return destination.resolve() == build.resolve()
    marker = destination / ".dotfiles-skills-managed.json"
    if not marker.is_file():
        return False
    try:
        metadata = json.loads(marker.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return False
    return (
        metadata.get("source_hash") == desired["source_hash"]
        and metadata.get("target") == desired["target"]
        and metadata.get("adapter") == desired["adapter"]
        and metadata.get("adapter_version") == ADAPTER_VERSIONS[desired["adapter"]]
        and package_hash(destination) == receipt.get("build_hash")
    )


def build_plan(roots: Roots) -> dict[str, Any]:
    desired = load_desired(roots)
    receipts = load_receipts(roots)
    actions: list[dict[str, Any]] = []
    desired_paths: set[str] = set()
    for item in desired:
        destination = item["destination"]
        desired_paths.add(str(destination))
        if destination.exists() or destination.is_symlink():
            receipt = receipts.get("deployments", {}).get(str(destination))
            if deployed_matches(destination, item, receipt):
                action = "unchanged"
            else:
                action = "replace-managed" if is_managed(destination, roots, receipts) else "collision"
        else:
            action = "create"
        actions.append(
            {
                "skill": item["skill"],
                "target": item["target"],
                "adapter": item["adapter"],
                "action": action,
                "source": str(item["source"]),
                "source_hash": item["source_hash"],
                "destination": str(destination),
                "mode": item["mode"],
                "profile": item["profile"],
            }
        )
    for destination, receipt in sorted(receipts.get("deployments", {}).items()):
        if destination not in desired_paths:
            destination_path = Path(destination)
            action = (
                "remove-managed"
                if not (destination_path.exists() or destination_path.is_symlink())
                or is_managed(destination_path, roots, receipts)
                else "orphaned-unmanaged"
            )
            actions.append(
                {
                    "skill": receipt["skill"],
                    "target": receipt["target"],
                    "adapter": receipt.get("adapter", receipt["target"]),
                    "action": action,
                    "source": receipt.get("source", ""),
                    "source_hash": receipt.get("source_hash", ""),
                    "destination": destination,
                    "mode": receipt.get("mode", ""),
                    "profile": receipt.get("profile", ""),
                }
            )
    actions.sort(key=lambda item: (item["skill"], item["target"], item["destination"]))
    return {"version": 1, "actions": actions}


def filter_frontmatter(text: str, adapter: str) -> str:
    text = text.replace("\r\n", "\n")
    if adapter != "codex" or not text.startswith("---\n"):
        return text
    end = text.find("\n---\n", 4)
    if end < 0:
        raise EstateError("SKILL.md has an unterminated frontmatter block")
    lines = text[4:end].splitlines()
    kept: list[str] = []
    keep_block = True
    for line in lines:
        match = re.match(r"^([A-Za-z0-9_-]+):", line)
        if match:
            keep_block = match.group(1) in CODEX_FRONTMATTER
        if keep_block:
            kept.append(line)
    return "---\n" + "\n".join(kept) + text[end:]


def materialize_build(item: dict[str, Any], roots: Roots) -> Path:
    adapter_version = ADAPTER_VERSIONS[item["adapter"]]
    build = (
        roots.data
        / "build"
        / item["profile"]
        / item["target"]
        / f"{item['skill']}-{item['source_hash'][:16]}-{item['adapter']}-v{adapter_version}"
    )
    if build.exists():
        return build
    build.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{item['skill']}-", dir=build.parent))
    try:
        shutil.copytree(item["source"], temporary / item["skill"], dirs_exist_ok=True)
        staged = temporary / item["skill"]
        skill_file = staged / "SKILL.md"
        skill_file.write_text(filter_frontmatter(skill_file.read_text(encoding="utf-8"), item["adapter"]), encoding="utf-8")
        os.replace(staged, build)
    finally:
        shutil.rmtree(temporary, ignore_errors=True)
    return build


def remove_managed(destination: Path) -> None:
    if destination.is_symlink() or destination.is_file():
        destination.unlink()
    elif destination.exists():
        shutil.rmtree(destination)


def deploy(item: dict[str, Any], build: Path, roots: Roots) -> str:
    destination = item["destination"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    requested = item["mode"]
    use_link = requested == "link" or (requested == "auto" and os.name != "nt" and item["adapter"] != "openclaw")
    if destination.exists() or destination.is_symlink():
        remove_managed(destination)
    if use_link:
        destination.symlink_to(build, target_is_directory=True)
        return "link"

    temporary = Path(tempfile.mkdtemp(prefix=f".{item['skill']}-", dir=destination.parent))
    staged = temporary / item["skill"]
    try:
        shutil.copytree(build, staged)
        marker = management_metadata(item)
        (staged / ".dotfiles-skills-managed.json").write_text(json.dumps(marker, indent=2) + "\n", encoding="utf-8")
        os.replace(staged, destination)
    finally:
        shutil.rmtree(temporary, ignore_errors=True)
    return "copy"


def write_receipts(roots: Roots, receipts: dict[str, Any]) -> None:
    roots.state.mkdir(parents=True, exist_ok=True)
    destination = roots.state / "deployments.json"
    handle, name = tempfile.mkstemp(prefix=".deployments-", suffix=".json", dir=roots.state)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as output:
            json.dump(receipts, output, indent=2, sort_keys=True)
            output.write("\n")
        os.replace(name, destination)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def management_metadata(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "version": 1,
        "skill": item["skill"],
        "target": item["target"],
        "adapter": item["adapter"],
        "adapter_version": ADAPTER_VERSIONS[item["adapter"]],
        "source_hash": item["source_hash"],
    }


def adopt_collisions(roots: Roots) -> dict[str, Any]:
    desired = {str(item["destination"]): item for item in load_desired(roots)}
    plan = build_plan(roots)
    collisions = [item for item in plan["actions"] if item["action"] == "collision"]
    mismatches = [
        item
        for item in collisions
        if Path(item["destination"]).is_symlink()
        or package_hash(Path(item["destination"])) != item["source_hash"]
    ]
    if mismatches:
        names = ", ".join(f"{item['skill']} -> {item['destination']}" for item in mismatches)
        raise EstateError(f"refusing mismatched collisions: {names}")

    receipts = load_receipts(roots)
    deployments = receipts.setdefault("deployments", {})
    for action in collisions:
        item = desired[action["destination"]]
        build = materialize_build(item, roots)
        marker = Path(action["destination"]) / ".dotfiles-skills-managed.json"
        marker.write_text(json.dumps(management_metadata(item), indent=2) + "\n", encoding="utf-8")
        deployments[action["destination"]] = {
            "skill": item["skill"],
            "target": item["target"],
            "adapter": item["adapter"],
            "adapter_version": ADAPTER_VERSIONS[item["adapter"]],
            "profile": item["profile"],
            "source": str(item["source"]),
            "source_hash": item["source_hash"],
            "build": str(build),
            "build_hash": package_hash(build),
            "mode": "adopted",
        }
    if collisions:
        write_receipts(roots, receipts)
    return build_plan(roots)


def apply_plan(roots: Roots) -> dict[str, Any]:
    desired = {str(item["destination"]): item for item in load_desired(roots)}
    plan = build_plan(roots)
    collisions = [item for item in plan["actions"] if item["action"] in {"collision", "orphaned-unmanaged"}]
    if collisions:
        names = ", ".join(f"{item['skill']} -> {item['destination']}" for item in collisions)
        raise EstateError(f"refusing unmanaged collisions: {names}")
    receipts = load_receipts(roots)
    deployments = receipts.setdefault("deployments", {})
    for action in plan["actions"]:
        destination = Path(action["destination"])
        if action["action"] == "unchanged":
            continue
        if action["action"] == "remove-managed":
            remove_managed(destination)
            deployments.pop(str(destination), None)
            continue
        item = desired[str(destination)]
        build = materialize_build(item, roots)
        mode = deploy(item, build, roots)
        deployments[str(destination)] = {
            "skill": item["skill"],
            "target": item["target"],
            "adapter": item["adapter"],
            "adapter_version": ADAPTER_VERSIONS[item["adapter"]],
            "profile": item["profile"],
            "source": str(item["source"]),
            "source_hash": item["source_hash"],
            "build": str(build),
            "build_hash": package_hash(build),
            "mode": mode,
        }
    write_receipts(roots, receipts)
    return build_plan(roots)


def doctor(roots: Roots) -> dict[str, Any]:
    desired = {str(item["destination"]): item for item in load_desired(roots)}
    receipts = load_receipts(roots).get("deployments", {})
    deployments: list[dict[str, str]] = []
    for destination_text, item in sorted(desired.items(), key=lambda pair: (pair[1]["skill"], pair[1]["target"], pair[0])):
        destination = Path(destination_text)
        receipt = receipts.get(destination_text)
        if not receipt:
            status = "unmanaged" if destination.exists() or destination.is_symlink() else "missing"
        elif receipt.get("source_hash") != item["source_hash"]:
            status = "source-drift"
        elif (
            receipt.get("target") != item["target"]
            or receipt.get("adapter") != item["adapter"]
            or receipt.get("adapter_version") != ADAPTER_VERSIONS[item["adapter"]]
        ):
            status = "projection-drift"
        elif not destination.exists() and not destination.is_symlink():
            status = "missing"
        elif not is_managed(destination, roots, {"deployments": receipts}):
            status = "ownership-drift"
        else:
            build = Path(receipt.get("build", ""))
            if not build.is_dir() or package_hash(build) != receipt.get("build_hash"):
                status = "build-drift"
            elif destination.is_symlink():
                status = "ok" if destination.resolve() == build.resolve() else "content-drift"
            else:
                status = "ok" if package_hash(destination) == receipt.get("build_hash") else "content-drift"
        deployments.append(
            {
                "skill": item["skill"],
                "target": item["target"],
                "destination": destination_text,
                "status": status,
            }
        )
    for destination_text, receipt in sorted(receipts.items()):
        if destination_text in desired:
            continue
        destination = Path(destination_text)
        if destination.exists() or destination.is_symlink():
            status = (
                "stale-managed"
                if is_managed(destination, roots, {"deployments": receipts})
                else "orphaned-unmanaged"
            )
        else:
            status = "stale-receipt"
        deployments.append(
            {
                "skill": receipt.get("skill", ""),
                "target": receipt.get("target", ""),
                "destination": destination_text,
                "status": status,
            }
        )
    deployments.sort(key=lambda item: (item["skill"], item["target"], item["destination"]))
    overall = "ok" if all(item["status"] == "ok" for item in deployments) else "drift"
    return {"version": 1, "status": overall, "deployments": deployments}


def print_plan(plan: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(plan, indent=2, sort_keys=True))
        return
    for item in plan["actions"]:
        print(f"{item['action']:16} {item['skill']:32} {item['target']:12} {item['destination']}")


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(prog="dotfiles-skills")
    default_home = Path.home()
    value.add_argument("--home", type=Path, default=default_home)
    value.add_argument(
        "--config-root",
        type=Path,
        default=Path(os.environ.get("XDG_CONFIG_HOME", default_home / ".config")) / "dotfiles-skills",
    )
    value.add_argument(
        "--data-root",
        type=Path,
        default=Path(os.environ.get("XDG_DATA_HOME", default_home / ".local" / "share")) / "dotfiles-skills",
    )
    value.add_argument(
        "--state-root",
        type=Path,
        default=Path(os.environ.get("XDG_STATE_HOME", default_home / ".local" / "state")) / "dotfiles-skills",
    )
    commands = value.add_subparsers(dest="command", required=True)
    plan = commands.add_parser("plan")
    plan.add_argument("--json", action="store_true")
    apply = commands.add_parser("apply")
    apply.add_argument("--json", action="store_true")
    adopt = commands.add_parser("adopt")
    adopt.add_argument("--json", action="store_true")
    doctor_parser = commands.add_parser("doctor")
    doctor_parser.add_argument("--json", action="store_true")
    commands.add_parser("lock")
    source_parser = commands.add_parser("source")
    source_commands = source_parser.add_subparsers(dest="source_command", required=True)
    source_add = source_commands.add_parser("add")
    source_add.add_argument("name")
    source_add.add_argument("--path", type=Path, required=True)
    source_add.add_argument("--profile", required=True)
    source_add.add_argument("--frozen", action="store_true")
    source_add.add_argument("--force", action="store_true")
    source_commands.add_parser("list")
    path_parser = commands.add_parser("path")
    path_parser.add_argument("skill")
    path_parser.add_argument("--target")
    return value


def main() -> int:
    args = parser().parse_args()
    roots = Roots(args.home.resolve(), args.config_root.resolve(), args.data_root.resolve(), args.state_root.resolve())
    try:
        if args.command == "plan":
            print_plan(build_plan(roots), args.json)
            return 0
        if args.command == "apply":
            print_plan(apply_plan(roots), args.json)
            return 0
        if args.command == "adopt":
            print_plan(adopt_collisions(roots), args.json)
            return 0
        if args.command == "doctor":
            report = doctor(roots)
            if args.json:
                print(json.dumps(report, indent=2, sort_keys=True))
            else:
                for item in report["deployments"]:
                    print(f"{item['status']:16} {item['skill']:32} {item['target']:12} {item['destination']}")
            return 0 if report["status"] == "ok" else 1
        if args.command == "lock":
            for path in lock_sources(roots):
                print(path)
            return 0
        if args.command == "source" and args.source_command == "add":
            print(add_source(roots, args.name, args.path, args.profile, args.frozen, args.force))
            return 0
        if args.command == "source" and args.source_command == "list":
            for path in descriptor_paths(roots):
                descriptor = read_toml(path)
                print(f"{path.stem}\t{descriptor.get('profile', '')}\t{descriptor.get('path', '')}")
            return 0
        if args.command == "path":
            matches = [
                item
                for item in load_desired(roots)
                if item["skill"] == args.skill and (not args.target or item["target"] == args.target)
            ]
            sources = sorted({str(item["source"]) for item in matches})
            if not sources:
                raise EstateError(f"skill {args.skill!r} is not subscribed in this profile")
            if len(sources) != 1:
                raise EstateError(f"skill {args.skill!r} resolves to multiple sources")
            print(sources[0])
            return 0
        raise EstateError(f"unsupported command: {args.command}")
    except EstateError as exc:
        print(f"dotfiles-skills: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
