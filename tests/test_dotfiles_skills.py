import json
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "scripts" / "dotfiles-skills.py"


class DotfilesSkillsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.config = self.root / "config"
        self.data = self.root / "data"
        self.state = self.root / "state"
        self.private = self.root / "private"
        for directory in (self.home, self.config, self.data, self.state, self.private):
            directory.mkdir(parents=True)

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args, check=True):
        command = [
            sys.executable,
            str(CLI),
            "--home",
            str(self.home),
            "--config-root",
            str(self.config),
            "--data-root",
            str(self.data),
            "--state-root",
            str(self.state),
            *args,
        ]
        return subprocess.run(command, text=True, capture_output=True, check=check)

    def write_private_estate(self, *, descriptor=True, frozen=False):
        skill = self.private / "skills" / "example-skill"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            "---\nname: example-skill\ndescription: Shape the next turn.\ndisable-model-invocation: true\nargument-hint: '[goal]'\n---\n\nDo the useful next thing.\n",
            encoding="utf-8",
        )
        (self.private / "estate.toml").write_text(
            """
version = 1

[profiles.test]
targets = ["codex", "claude-code"]
skills = ["example-skill"]

[skills.example-skill]
path = "skills/example-skill"
targets = ["codex", "claude-code"]
""".lstrip(),
            encoding="utf-8",
        )
        if descriptor:
            sources = self.config / "sources.d"
            sources.mkdir(parents=True)
            (sources / "private.toml").write_text(
                f'version = 1\npath = "{self.private.as_posix()}"\nprofile = "test"\nfrozen = {str(frozen).lower()}\n',
                encoding="utf-8",
            )

    def test_plan_resolves_private_profile_without_mutating_targets(self):
        self.write_private_estate()

        result = self.run_cli("plan", "--json")

        plan = json.loads(result.stdout)
        self.assertEqual(
            [(item["skill"], item["target"], item["action"]) for item in plan["actions"]],
            [
                ("example-skill", "claude-code", "create"),
                ("example-skill", "codex", "create"),
            ],
        )
        self.assertFalse((self.home / ".claude" / "skills" / "example-skill").exists())
        self.assertFalse((self.home / ".codex" / "skills" / "example-skill").exists())

    def test_apply_projects_runtime_specific_consumers_and_records_ownership(self):
        self.write_private_estate()

        self.run_cli("apply")

        codex_skill = self.home / ".codex" / "skills" / "example-skill" / "SKILL.md"
        claude_skill = self.home / ".claude" / "skills" / "example-skill" / "SKILL.md"
        self.assertTrue(codex_skill.is_file())
        self.assertTrue(claude_skill.is_file())
        self.assertNotIn("disable-model-invocation", codex_skill.read_text(encoding="utf-8"))
        self.assertNotIn("argument-hint", codex_skill.read_text(encoding="utf-8"))
        self.assertIn("disable-model-invocation: true", claude_skill.read_text(encoding="utf-8"))
        self.assertIn("argument-hint: '[goal]'", claude_skill.read_text(encoding="utf-8"))
        receipts = json.loads((self.state / "deployments.json").read_text(encoding="utf-8"))
        self.assertEqual(len(receipts["deployments"]), 2)

        plan = json.loads(self.run_cli("plan", "--json").stdout)
        self.assertEqual({item["action"] for item in plan["actions"]}, {"unchanged"})

    def test_apply_refuses_unmanaged_collisions_without_touching_them(self):
        self.write_private_estate()
        destination = self.home / ".codex" / "skills" / "example-skill"
        destination.mkdir(parents=True)
        sentinel = destination / "owner.txt"
        sentinel.write_text("leave me alone\n", encoding="utf-8")

        result = self.run_cli("apply", check=False)

        self.assertEqual(result.returncode, 2)
        self.assertIn("refusing unmanaged collisions", result.stderr)
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "leave me alone\n")
        self.assertFalse((self.home / ".claude" / "skills" / "example-skill").exists())

    def test_doctor_reports_consumer_drift(self):
        self.write_private_estate()
        self.run_cli("apply")
        consumer = self.home / ".codex" / "skills" / "example-skill" / "SKILL.md"
        consumer.write_text(consumer.read_text(encoding="utf-8") + "\nlocal mutation\n", encoding="utf-8")

        result = self.run_cli("doctor", "--json", check=False)

        self.assertEqual(result.returncode, 1)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "drift")
        self.assertEqual(
            [(item["skill"], item["target"], item["status"]) for item in report["deployments"]],
            [
                ("example-skill", "claude-code", "ok"),
                ("example-skill", "codex", "content-drift" if os.name == "nt" else "build-drift"),
            ],
        )

    def test_stale_receipt_does_not_authorize_replacing_new_unmanaged_content(self):
        self.write_private_estate()
        self.run_cli("apply")
        destination = self.home / ".codex" / "skills" / "example-skill"
        if destination.is_symlink():
            destination.unlink()
        else:
            shutil.rmtree(destination)
        destination.mkdir()
        sentinel = destination / "owner.txt"
        sentinel.write_text("new owner\n", encoding="utf-8")

        report = json.loads(self.run_cli("doctor", "--json", check=False).stdout)
        codex = next(item for item in report["deployments"] if item["target"] == "codex")
        self.assertEqual(codex["status"], "ownership-drift")

        result = self.run_cli("apply", check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("refusing unmanaged collisions", result.stderr)
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "new owner\n")

    def test_stale_receipt_does_not_authorize_removing_new_unmanaged_content(self):
        self.write_private_estate()
        self.run_cli("apply")
        codex = self.home / ".codex" / "skills" / "example-skill"
        if codex.is_symlink():
            codex.unlink()
        else:
            shutil.rmtree(codex)
        codex.mkdir()
        sentinel = codex / "owner.txt"
        sentinel.write_text("new owner\n", encoding="utf-8")
        (self.private / "estate.toml").write_text(
            "version = 1\n\n[profiles.test]\ntargets = []\nskills = []\n",
            encoding="utf-8",
        )

        report = json.loads(self.run_cli("doctor", "--json", check=False).stdout)
        self.assertEqual(report["status"], "drift")
        self.assertEqual(
            {item["status"] for item in report["deployments"]},
            {"orphaned-unmanaged", "stale-managed"},
        )

        result = self.run_cli("apply", check=False)

        self.assertEqual(result.returncode, 2)
        self.assertIn("refusing unmanaged collisions", result.stderr)
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "new owner\n")

    def test_adapter_change_rebuilds_and_redeploys_unchanged_source(self):
        self.write_private_estate(descriptor=False)
        (self.private / "estate.toml").write_text(
            """
version = 1
[profiles.test.subscriptions]
custom = ["example-skill"]
[profiles.test.target_paths]
custom = ["{home}/.custom/skills"]
[profiles.test.target_adapters]
custom = "claude-code"
[skills.example-skill]
path = "skills/example-skill"
""".lstrip(),
            encoding="utf-8",
        )
        self.run_cli("source", "add", "private", "--path", str(self.private), "--profile", "test")
        self.run_cli("apply")
        destination = self.home / ".custom" / "skills" / "example-skill" / "SKILL.md"
        self.assertIn("disable-model-invocation", destination.read_text(encoding="utf-8"))
        manifest = self.private / "estate.toml"
        manifest.write_text(
            manifest.read_text(encoding="utf-8").replace('custom = "claude-code"', 'custom = "codex"'),
            encoding="utf-8",
        )

        plan = json.loads(self.run_cli("plan", "--json").stdout)
        self.assertEqual(plan["actions"][0]["action"], "replace-managed")
        before = json.loads(self.run_cli("doctor", "--json", check=False).stdout)
        self.assertEqual(before["deployments"][0]["status"], "projection-drift")
        self.run_cli("apply")
        self.assertNotIn("disable-model-invocation", destination.read_text(encoding="utf-8"))

    def test_source_add_keeps_private_subscription_outside_public_source(self):
        self.write_private_estate(descriptor=False)

        self.run_cli(
            "source",
            "add",
            "private",
            "--path",
            str(self.private),
            "--profile",
            "test",
        )

        descriptor = self.config / "sources.d" / "private.toml"
        self.assertTrue(descriptor.is_file())
        self.assertIn(self.private.as_posix(), descriptor.read_text(encoding="utf-8").replace("\\", "/"))
        plan = json.loads(self.run_cli("plan", "--json").stdout)
        self.assertEqual(len(plan["actions"]), 2)

    def test_frozen_source_requires_lock_and_rejects_changed_content(self):
        self.write_private_estate(frozen=True)

        missing = self.run_cli("apply", check=False)
        self.assertEqual(missing.returncode, 2)
        self.assertIn("missing frozen lock", missing.stderr)

        self.run_cli("lock")
        self.run_cli("apply")
        skill_file = self.private / "skills" / "example-skill" / "SKILL.md"
        skill_file.write_text(skill_file.read_text(encoding="utf-8") + "\nchanged\n", encoding="utf-8")

        changed = self.run_cli("plan", check=False)
        self.assertEqual(changed.returncode, 2)
        self.assertIn("does not match frozen lock", changed.stderr)

        lock = json.loads((self.private / "skills.lock.json").read_text(encoding="utf-8"))
        self.assertEqual(lock["skills"]["example-skill"]["path"], "skills/example-skill")

    def test_lock_hash_uses_platform_independent_relative_path_order(self):
        self.write_private_estate()
        skill = self.private / "skills" / "example-skill"
        (skill / "a.txt").write_bytes(b"a\r\n")
        (skill / "Z.txt").write_bytes(b"z\n")

        self.run_cli("lock")

        digest = hashlib.sha256()
        files = {
            "SKILL.md": (skill / "SKILL.md").read_bytes().replace(b"\r\n", b"\n"),
            "Z.txt": b"z\n",
            "a.txt": b"a\n",
        }
        for relative in sorted(files):
            digest.update(relative.encode())
            digest.update(b"\0")
            digest.update(files[relative])
            digest.update(b"\0")
        lock = json.loads((self.private / "skills.lock.json").read_text(encoding="utf-8"))
        self.assertEqual(lock["skills"]["example-skill"]["hash"], digest.hexdigest())

    def test_adopt_takes_ownership_only_when_existing_content_matches_source(self):
        self.write_private_estate()
        source = self.private / "skills" / "example-skill"
        codex_destination = self.home / ".codex" / "skills" / "example-skill"
        claude_destination = self.home / ".claude" / "skills" / "example-skill"
        codex_destination.parent.mkdir(parents=True)
        claude_destination.parent.mkdir(parents=True)
        shutil.copytree(source, codex_destination)
        shutil.copytree(source, claude_destination)
        for destination in (codex_destination, claude_destination):
            skill_file = destination / "SKILL.md"
            content = skill_file.read_bytes().replace(b"\r\n", b"\n")
            skill_file.write_bytes(content.replace(b"\n", b"\r\n"))

        adopted = json.loads(self.run_cli("adopt", "--json").stdout)
        self.assertEqual(
            {item["action"] for item in adopted["actions"]},
            {"replace-managed", "unchanged"},
        )

        self.run_cli("apply")
        report = json.loads(self.run_cli("doctor", "--json").stdout)
        self.assertEqual(report["status"], "ok")
        self.assertNotIn(
            "disable-model-invocation",
            (codex_destination / "SKILL.md").read_text(encoding="utf-8"),
        )

    def test_adopt_refuses_mismatched_existing_content_without_partial_receipts(self):
        self.write_private_estate()
        codex_destination = self.home / ".codex" / "skills" / "example-skill"
        claude_destination = self.home / ".claude" / "skills" / "example-skill"
        codex_destination.mkdir(parents=True)
        claude_destination.mkdir(parents=True)
        (codex_destination / "SKILL.md").write_text("different\n", encoding="utf-8")
        (claude_destination / "SKILL.md").write_text("different\n", encoding="utf-8")

        result = self.run_cli("adopt", check=False)

        self.assertEqual(result.returncode, 2)
        self.assertIn("refusing mismatched collisions", result.stderr)
        self.assertFalse((self.state / "deployments.json").exists())

    def test_profile_subscriptions_can_select_different_skills_per_runtime(self):
        self.write_private_estate(descriptor=False)
        (self.private / "estate.toml").write_text(
            """
version = 1

[profiles.test.subscriptions]
codex = ["example-skill"]
openclaw-agent = ["example-skill"]

[profiles.test.target_paths]
openclaw-agent = ["{home}/.openclaw/workspace-agent/skills"]

[profiles.test.target_adapters]
openclaw-agent = "openclaw"

[skills.example-skill]
path = "skills/example-skill"
""".lstrip(),
            encoding="utf-8",
        )
        self.run_cli("source", "add", "private", "--path", str(self.private), "--profile", "test")

        plan = json.loads(self.run_cli("plan", "--json").stdout)

        self.assertEqual(
            [(item["target"], Path(item["destination"]).as_posix()) for item in plan["actions"]],
            [
                ("codex", (self.home / ".codex" / "skills" / "example-skill").as_posix()),
                (
                    "openclaw-agent",
                    (self.home / ".openclaw" / "workspace-agent" / "skills" / "example-skill").as_posix(),
                ),
            ],
        )

    def test_two_target_aliases_cannot_resolve_to_the_same_destination(self):
        self.write_private_estate(descriptor=False)
        (self.private / "estate.toml").write_text(
            """
version = 1
[profiles.test.subscriptions]
alias-one = ["example-skill"]
alias-two = ["example-skill"]
[profiles.test.target_paths]
alias-one = ["{home}/.same/skills"]
alias-two = ["{home}/.same/skills"]
[profiles.test.target_adapters]
alias-one = "codex"
alias-two = "codex"
[skills.example-skill]
path = "skills/example-skill"
""".lstrip(),
            encoding="utf-8",
        )
        self.run_cli("source", "add", "private", "--path", str(self.private), "--profile", "test")

        result = self.run_cli("plan", check=False)

        self.assertEqual(result.returncode, 2)
        self.assertIn("duplicate desired destination", result.stderr)

    @unittest.skipUnless(shutil.which("pwsh") or shutil.which("powershell"), "PowerShell is unavailable")
    def test_windows_wrapper_finds_installed_libexec_layout(self):
        local = self.home / ".local"
        bin_dir = local / "bin"
        libexec = local / "libexec"
        bin_dir.mkdir(parents=True)
        libexec.mkdir(parents=True)
        shutil.copy2(ROOT / "scripts" / "dotfiles-skills.ps1", bin_dir / "dotfiles-skills.ps1")
        shutil.copy2(CLI, libexec / "dotfiles-skills.py")
        shell = shutil.which("pwsh") or shutil.which("powershell")

        result = subprocess.run(
            [shell, "-NoProfile", "-File", str(bin_dir / "dotfiles-skills.ps1"), "--help"],
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("dotfiles-skills", result.stdout)


if __name__ == "__main__":
    unittest.main()
