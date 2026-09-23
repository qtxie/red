#!/usr/bin/env bash
#
# Build every platform's seed package locally, in the layout
# tools/ci/seed-manifest.py expects, and assemble the manifest.
#
# This is the cold start that avoids hosting pinned bootstrap URLs: the four
# packages it leaves in build/seed/stage can be uploaded as one generation and
# the chain takes over from there. It cross-compiles, so the remote toolchains
# cannot be executed here -- CI is still what validates those.
#
#   BOOTSTRAP=... CONSOLE=... tools/ci/build-seed-local.sh [platform ...]
#
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

BOOTSTRAP=${BOOTSTRAP:-build/self-hosting/merge-red64/hybrid-compiler203.exe}
CONSOLE=${CONSOLE:-build/console-203/console.exe}
STAGE=build/seed/stage
mkdir -p build/seed

target_for() {
  case "$1" in
    windows-x64)  echo Windows-X86-64 ;;
    linux-x64)    echo Linux-X86-64 ;;
    linux-arm64)  echo Linux-ARM64 ;;
    darwin-arm64) echo Darwin-ARM64 ;;
    *) echo "unknown platform: $1" >&2; return 1 ;;
  esac
}

# A toolchain built for another OS cannot be run here, so its post-build
# self-check has to be skipped.
verify_flag() {
  [[ $1 == windows-x64 ]] || echo --no-verify
}

# The compiler appends .exe on Windows, and build-red-toolchain.red checks that
# the exact path it was given exists, so the name has to match what is written.
toolchain_name() {
  [[ $1 == windows-x64 ]] && echo red-toolchain.exe || echo red-toolchain
}

console_name() {
  [[ $1 == windows-x64 ]] && echo "red-cli-console-$1.exe" || echo "red-cli-console-$1"
}

# Git Bash on Windows has no shasum.
checksums() {
  python - "$1" <<'PY'
import hashlib, sys
from pathlib import Path

directory = Path(sys.argv[1])
lines = []
for path in sorted(directory.iterdir()):
    if not path.is_file() or path.name == "SHA256SUMS":
        continue
    lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
(directory / "SHA256SUMS").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY
}

archive() {
  # archive <format> <source-dir> <member> <destination>
  local format=$1 srcdir=$2 member=$3 dest=$4
  python - "$format" "$srcdir" "$member" "$dest" <<'PY'
import sys, tarfile, zipfile
from pathlib import Path

fmt, srcdir, member, dest = sys.argv[1:5]
source = Path(srcdir) / member
if fmt == "zip":
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(source, source.name)
else:
    # Cross builds run on filesystems without an exec bit (a bundle built on
    # Windows cannot chmod its executable), so every tar member is archived
    # 0755 and unpacks runnable.
    def runnable(member):
        member.mode = 0o755
        return member
    with tarfile.open(dest, "w:gz") as archive:
        archive.add(source, source.name, filter=runnable)
PY
}

package_platform() {
  local platform=$1 target=$2
  local dir="$STAGE/seed-$platform"
  local work="build/seed/work-$platform"
  local toolchain_path="$work/$(toolchain_name "$platform")"
  local console_path="$work/$(console_name "$platform")"
  # Rebuilt from scratch so a run that failed early leaves nothing behind.
  rm -rf "$dir"
  mkdir -p "$dir" "$work"

  # Resumable: a build that fails late should not redo the expensive parts.
  if [[ -f $toolchain_path ]]; then
    echo "=== $platform: toolchain already built ==="
  else
    echo "=== $platform: toolchain ($target) ==="
    "$CONSOLE" tools/self_hosting/build-red-toolchain.red \
      --bootstrap "$BOOTSTRAP" \
      --target "$target" \
      --output "$toolchain_path" \
      $(verify_flag "$platform")
  fi

  if [[ -f $console_path ]]; then
    echo "=== $platform: CLI console already built ==="
  else
    echo "=== $platform: CLI console ==="
    "$BOOTSTRAP" -r -t "$target" \
      -o "$work/red-cli-console-$platform" \
      environment/console/CLI/console.red
  fi

  if [[ $platform == darwin-arm64 ]]; then
    if [[ -d "$work/gui-console.app" || -f "$work/gui-console" ]]; then
      echo "=== $platform: GUI console already built ==="
    else
      echo "=== $platform: GUI console ==="
      "$BOOTSTRAP" -r -t macOS-ARM64 \
        -o "$work/gui-console" \
        environment/console/GUI/gui-console.red
    fi
    # The packager wraps the executable wherever the toolchain runs, so a
    # cross build packages the bundle too; the bare executable is gone after.
    local gui_member=gui-console
    [[ -d "$work/gui-console.app" ]] && gui_member=gui-console.app
    chmod 755 "$work/$gui_member" 2>/dev/null || true
    archive tgz "$work" "$gui_member" "$dir/red-gui-console-$platform.tar.gz"
  fi

  echo "=== $platform: package ==="
  # The toolchain binary may or may not carry .exe, depending on the target.
  local binary
  binary=$(ls "$work"/red-toolchain* | grep -v '\.log$' | head -1)
  if [[ $platform == windows-x64 ]]; then
    archive zip "$work" "$(basename "$binary")" "$dir/red-toolchain-$platform.zip"
  else
    archive tgz "$work" "$(basename "$binary")" "$dir/red-toolchain-$platform.tar.gz"
  fi
  cp "$console_path" "$dir/"
  if [[ $platform != windows-x64 ]]; then
    chmod 755 "$dir/$(console_name "$platform")"
  fi

  echo "--- $platform ---"
  checksums "$dir"
}

platforms=("$@")
if [[ ${#platforms[@]} -eq 0 ]]; then
  platforms=(windows-x64 linux-x64 linux-arm64 darwin-arm64)
fi

for platform in "${platforms[@]}"; do
  package_platform "$platform" "$(target_for "$platform")"
done

echo "=== manifest ==="
python tools/ci/seed-manifest.py \
  --seeds "$STAGE" \
  --stage build/seed/assets \
  --generation "seed-local-$(git rev-parse --short HEAD)" \
  --commit "$(git rev-parse HEAD)" \
  --out build/seed/MANIFEST.json
echo "seed packages: $STAGE"
echo "manifest: build/seed/MANIFEST.json"
