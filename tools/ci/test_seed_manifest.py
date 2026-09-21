#!/usr/bin/env python3
"""Tests for seed-manifest.py.

Every CI job finds its compiler through the manifest, so a wrong manifest
breaks all of them at once. These run on the push path; see the "Audit CI
tooling" step of build-hybrid-toolchain.yml.
"""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

# seed-manifest.py has a hyphen, so it cannot be imported by name.
spec = importlib.util.spec_from_file_location(
    "seed_manifest", Path(__file__).with_name("seed-manifest.py")
)
manifest_module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = manifest_module
spec.loader.exec_module(manifest_module)

PLATFORMS = manifest_module.PLATFORMS


def seed_tree(root, gui_platforms=()):
    """One artifact directory per platform, as a seed build leaves behind."""
    for platform in PLATFORMS:
        directory = root / f"seed-{platform}"
        directory.mkdir(parents=True)
        (directory / f"red-toolchain-{platform}.tar.gz").write_bytes(b"toolchain")
        (directory / f"red-cli-console-{platform}").write_bytes(b"console")
        (directory / "SHA256SUMS").write_text("sums\n")
        if platform in gui_platforms:
            (directory / f"red-gui-console-{platform}.tar.gz").write_bytes(b"gui")
    return root


class ManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.seeds = seed_tree(self.root / "seeds", gui_platforms=("darwin-arm64",))
        self.stage = self.root / "assets"
        self.out = self.root / "MANIFEST.json"

    def tearDown(self):
        self.tmp.cleanup()

    def build(self):
        return manifest_module.build(self.seeds, self.stage, "seed-1", "abc123")

    def argv(self):
        return [
            "--seeds", str(self.seeds),
            "--stage", str(self.stage),
            "--generation", "seed-1",
            "--commit", "abc123",
            "--out", str(self.out),
        ]

    def test_every_platform_has_a_toolchain_and_console(self):
        manifest = self.build()
        for platform in PLATFORMS:
            entry = manifest["assets"][platform]
            self.assertIn("toolchain", entry)
            self.assertIn("console", entry)

    def test_gui_only_where_a_bundle_was_built(self):
        manifest = self.build()
        self.assertIn("gui", manifest["assets"]["darwin-arm64"])
        self.assertNotIn("gui", manifest["assets"]["windows-x64"])

    def test_manifest_records_the_generation(self):
        manifest = self.build()
        self.assertEqual(manifest["generation"], "seed-1")
        self.assertEqual(manifest["commit"], "abc123")

    def test_staged_content_matches_its_hash(self):
        manifest = self.build()
        for platform in PLATFORMS:
            for component, item in manifest["assets"][platform].items():
                staged = self.stage / item["name"]
                self.assertTrue(staged.is_file(), item["name"])
                self.assertEqual(manifest_module.sha256(staged), item["sha256"])

    def test_checksums_are_renamed_per_platform(self):
        manifest = self.build()
        for platform in PLATFORMS:
            name = manifest["assets"][platform]["checksums"]["name"]
            self.assertEqual(name, f"SHA256SUMS-{platform}")

    def test_cli_writes_parseable_json(self):
        manifest_module.main(self.argv())
        written = json.loads(self.out.read_text())
        self.assertEqual(written["generation"], "seed-1")
        self.assertEqual(written["assets"], self.build()["assets"])

    def test_missing_required_component_fails(self):
        (self.seeds / "seed-linux-x64" / "red-toolchain-linux-x64.tar.gz").unlink()
        with self.assertRaises(SystemExit):
            self.build()

    def test_duplicate_asset_fails(self):
        (self.seeds / "seed-linux-x64" / "red-toolchain-linux-x64.zip").write_bytes(b"x")
        with self.assertRaises(SystemExit):
            self.build()


if __name__ == "__main__":
    unittest.main()
