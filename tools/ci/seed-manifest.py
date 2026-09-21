#!/usr/bin/env python3
"""Assemble a CI seed manifest from the artifacts of one seed build.

A seed build uploads one artifact per platform, each holding a toolchain
archive, a CLI console binary and a SHA256SUMS. This script stages those files
under unique release asset names and writes the manifest that every later CI
run reads to find them:

    {
      "generation": "seed-123456",
      "commit": "...",
      "created": "...",
      "assets": {
        "windows-x64": {
          "toolchain": {"name": "red-toolchain-windows-x64.zip", "sha256": "..."},
          "console":   {"name": "red-cli-console-windows-x64.exe", "sha256": "..."}
        }
      }
    }

The manifest is the whole pointer. Promoting a generation means publishing its
binaries to an immutable release and then rewriting MANIFEST.json, so no
asset is ever overwritten in place and no URL or checksum is configured
anywhere in the repository.
"""

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

PLATFORMS = ("windows-x64", "linux-x64", "linux-arm64", "darwin-arm64")


def fail(message):
    sys.exit(f"seed-manifest: {message}")


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def asset(root, prefix, platform):
    """The single file named <prefix>-<platform>[.ext] under root."""
    matches = sorted(
        path for path in root.rglob(f"{prefix}-{platform}*") if path.is_file()
    )
    if len(matches) != 1:
        found = ", ".join(str(path) for path in matches) or "none"
        fail(f"expected one {prefix}-{platform}* under {root}, found: {found}")
    return matches[0]


def stage(destination, path, name):
    """Copy an asset under a release-unique name and describe it."""
    target = destination / name
    target.write_bytes(path.read_bytes())
    return {"name": name, "sha256": sha256(path)}


def build(seeds, stage_dir, generation, commit):
    if not seeds.is_dir():
        fail(f"{seeds} is not a directory")
    stage_dir.mkdir(parents=True, exist_ok=True)

    assets = {}
    for platform in PLATFORMS:
        toolchain = asset(seeds, "red-toolchain", platform)
        console = asset(seeds, "red-cli-console", platform)
        assets[platform] = {
            "toolchain": stage(stage_dir, toolchain, toolchain.name),
            "console": stage(stage_dir, console, console.name),
        }
        # Every platform ships a SHA256SUMS; the name has to change for it to be
        # a distinct release asset.
        for sums in sorted(seeds.rglob("SHA256SUMS")):
            if platform in str(sums.parent):
                assets[platform]["checksums"] = stage(
                    stage_dir, sums, f"SHA256SUMS-{platform}"
                )
                break

    return {
        "generation": generation,
        "commit": commit,
        "created": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "assets": assets,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", required=True, type=Path,
                        help="directory holding one seed-<platform> artifact each")
    parser.add_argument("--stage", required=True, type=Path,
                        help="directory to copy release assets into")
    parser.add_argument("--generation", required=True,
                        help="release tag that will hold this generation")
    parser.add_argument("--commit", required=True, help="commit the seed was built from")
    parser.add_argument("--out", required=True, type=Path, help="manifest to write")
    args = parser.parse_args()

    manifest = build(args.seeds, args.stage, args.generation, args.commit)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n")

    for platform, entry in manifest["assets"].items():
        print(f"{platform}: {entry['toolchain']['name']}, {entry['console']['name']}")
    print(f"manifest: {args.out}")


if __name__ == "__main__":
    main()
