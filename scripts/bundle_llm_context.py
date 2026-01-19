#!/usr/bin/env python3
"""
Bundle dotfiles repo context into a single Markdown file for LLMs.

Intelligent defaults:
- Prefers `git ls-files` (tracked files only) when available.
- Excludes secrets and build artifacts (e.g., local.properties, build/, .gradle/).
- Orders important config/docs first, then source.
- Limits per-file and total output size to keep prompts usable.

Usage:
  ./bundle_llm_context.py
  ./bundle_llm_context.py --out LLM_CONTEXT.md
  ./bundle_llm_context.py --max-files 200 --max-bytes 1200000
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple


REPO_ROOT = Path(__file__).resolve().parent.parent


DEFAULT_OUT = "LLM_CONTEXT.md"

# Hard excludes (security + noise).
EXCLUDE_DIRS = {
    ".git",
    "tmux/.config/tmux/plugins",
}

EXCLUDE_GLOBS = [
    "LLM_CONTEXT.md",
    "local.properties",
    "*.keystore",
    "*.jks",
    "*.apk",
    "*.aab",
    "*.dex",
    "*.class",
    "*.jar",
    "*.zip",
    "*.png",
    "*.jpg",
    "*.jpeg",
    "*.gif",
    "*.webp",
    "*.mp4",
    "*.mov",
    "*.DS_Store",
    "Thumbs.db",
]


PREFERRED_ORDER = [
    "AGENTS.md",
    "README.md",
    ".gitignore",
    "scripts/dotfiles-doctor",
    "scripts/profile-zsh-startup",
    "scripts/profile-nvim-startup",
    "shell/.config/shell/env.sh",
    "zsh/.zshrc",
    "nvim/.config/nvim/init.lua",
    "tmux/.config/tmux/tmux.conf",
]

PREFERRED_PREFIXES = [
    "shell/",
    "zsh/",
    "nvim/",
    "tmux/",
    "git/",
    "bash/",
    "scripts/",
]


def run_git_ls_files(cwd: Path) -> Optional[List[str]]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=str(cwd),
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return None
    raw = result.stdout
    if not raw:
        return []
    return [p for p in raw.decode("utf-8", errors="replace").split("\x00") if p]


def is_excluded_path(rel: str) -> bool:
    norm = rel.replace("\\", "/").lstrip("./")
    for d in EXCLUDE_DIRS:
        dnorm = d.replace("\\", "/").strip("/")
        if norm == dnorm or norm.startswith(dnorm + "/"):
            return True
    for pat in EXCLUDE_GLOBS:
        if fnmatch.fnmatch(norm, pat) or fnmatch.fnmatch(Path(norm).name, pat):
            return True
    return False


def discover_files(repo_root: Path, include_untracked: bool) -> List[Path]:
    if not include_untracked:
        tracked = run_git_ls_files(repo_root)
        if tracked is not None:
            paths = [repo_root / p for p in tracked]
            return [p for p in paths if p.is_file() and not is_excluded_path(p.relative_to(repo_root).as_posix())]

    paths: List[Path] = []
    for p in repo_root.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(repo_root).as_posix()
        if is_excluded_path(rel):
            continue
        if any(part.startswith(".") and part not in {".", ".."} for part in p.parts):
            if rel != ".gitignore":
                continue
        paths.append(p)
    return paths


def sort_files(paths: Sequence[Path], repo_root: Path) -> List[Path]:
    rels = [p.relative_to(repo_root).as_posix() for p in paths]
    rel_to_path = {r: p for r, p in zip(rels, paths)}

    def rank(rel: str) -> Tuple[int, int, str]:
        if rel in PREFERRED_ORDER:
            return (0, PREFERRED_ORDER.index(rel), rel)
        for i, prefix in enumerate(PREFERRED_PREFIXES):
            if rel.startswith(prefix):
                return (1, i, rel)
        return (2, 0, rel)

    sorted_rels = sorted(rels, key=rank)
    return [rel_to_path[r] for r in sorted_rels]


def guess_code_fence_language(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in {".kt"}:
        return "kotlin"
    if ext in {".kts"}:
        return "kotlin"
    if ext in {".xml"}:
        return "xml"
    if ext in {".md"}:
        return "markdown"
    if ext in {".properties"}:
        return "properties"
    if ext in {".gradle"}:
        return "groovy"
    if ext in {".json"}:
        return "json"
    if ext in {".js"}:
        return "javascript"
    if ext in {".html"}:
        return "html"
    if ext in {".css"}:
        return "css"
    if ext in {".yml", ".yaml"}:
        return "yaml"
    return ""


@dataclass(frozen=True)
class BundleLimits:
    max_files: int
    max_bytes: int
    max_bytes_per_file: int


def read_text_limited(path: Path, limit: int) -> Tuple[str, bool]:
    data = path.read_bytes()
    truncated = False
    if len(data) > limit:
        data = data[:limit]
        truncated = True
    return data.decode("utf-8", errors="replace"), truncated


def render_tree(paths: Sequence[Path], repo_root: Path, max_entries: int = 400) -> str:
    rels = [p.relative_to(repo_root).as_posix() for p in paths]
    shown = rels[:max_entries]
    lines = ["```text"] + shown
    if len(rels) > max_entries:
        lines.append(f"... ({len(rels) - max_entries} more)")
    lines.append("```")
    return "\n".join(lines)


def build_bundle(
    repo_root: Path,
    out_path: Path,
    include_untracked: bool,
    limits: BundleLimits,
) -> Tuple[int, List[str]]:
    files = sort_files(discover_files(repo_root, include_untracked), repo_root)

    warnings: List[str] = []
    total_written = 0
    included = 0

    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%SZ")
    header = [
        "# Dotfiles — LLM Context Bundle",
        "",
        f"- Generated: `{now}`",
        f"- Repo root: `{repo_root}`",
        f"- Included files: tracked={not include_untracked}, excludes=on, limits={{max_files={limits.max_files}, max_bytes={limits.max_bytes}, max_bytes_per_file={limits.max_bytes_per_file}}}",
        "",
        "## File List",
        render_tree(files, repo_root),
        "",
        "## Contents",
        "",
    ]
    out_path.write_text("\n".join(header), encoding="utf-8")
    total_written = out_path.stat().st_size

    for path in files:
        if included >= limits.max_files:
            warnings.append(f"Reached max_files={limits.max_files}; stopping early.")
            break
        rel = path.relative_to(repo_root).as_posix()
        try:
            content, truncated = read_text_limited(path, limits.max_bytes_per_file)
        except Exception as e:
            warnings.append(f"Failed to read {rel}: {e}")
            continue

        lang = guess_code_fence_language(path)
        block = []
        block.append(f"### `{rel}`")
        block.append("")
        block.append(f"```{lang}".rstrip())
        block.append(content.rstrip("\n"))
        if truncated:
            block.append("")
            block.append(f"[TRUNCATED: file exceeded {limits.max_bytes_per_file} bytes]")
        block.append("```")
        block.append("")
        block_text = "\n".join(block)

        next_size = len(block_text.encode("utf-8"))
        if total_written + next_size > limits.max_bytes:
            warnings.append(f"Reached max_bytes={limits.max_bytes}; stopping early at {rel}.")
            break

        with out_path.open("a", encoding="utf-8") as f:
            f.write(block_text)

        total_written += next_size
        included += 1

    if warnings:
        with out_path.open("a", encoding="utf-8") as f:
            f.write("\n## Warnings\n")
            for w in warnings:
                f.write(f"- {w}\n")

    return included, warnings


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Bundle repo context into a single Markdown file for LLMs.")
    p.add_argument("--out", default=DEFAULT_OUT, help=f"Output file path (default: {DEFAULT_OUT})")
    p.add_argument(
        "--include-untracked",
        action="store_true",
        help="Include untracked files (fallback is tracked files only).",
    )
    p.add_argument("--max-files", type=int, default=160, help="Maximum files to include.")
    p.add_argument("--max-bytes", type=int, default=1_200_000, help="Maximum total output bytes.")
    p.add_argument("--max-bytes-per-file", type=int, default=120_000, help="Maximum bytes per file before truncation.")
    return p.parse_args(argv)


def main() -> int:
    args = parse_args()
    out_path = (REPO_ROOT / args.out).resolve()
    limits = BundleLimits(
        max_files=max(1, int(args.max_files)),
        max_bytes=max(10_000, int(args.max_bytes)),
        max_bytes_per_file=max(2_000, int(args.max_bytes_per_file)),
    )

    included, warnings = build_bundle(
        repo_root=REPO_ROOT,
        out_path=out_path,
        include_untracked=bool(args.include_untracked),
        limits=limits,
    )

    print(f"Wrote {included} files into: {out_path}")
    if warnings:
        print("Warnings:")
        for w in warnings:
            print(f"- {w}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
