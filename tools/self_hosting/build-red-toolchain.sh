#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "Usage: $0 focused-darwin-arm64-bootstrap [output]" >&2
	exit 2
fi

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
bootstrap=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
output=${2:-"$repo_root/build/red-toolchain/red-toolchain"}
case "$output" in
	/*) ;;
	*) output="$repo_root/$output" ;;
esac
output_dir=$(dirname "$output")
generator="$repo_root/build/red-toolchain/generate-toolchain-resources"
resources="$repo_root/build/generated/red-toolchain-resources.generated.red"

mkdir -p "$repo_root/build/red-toolchain" "$repo_root/build/generated" "$output_dir"
chmod +x "$bootstrap"

cd "$repo_root"
"$bootstrap" -r -t Darwin-ARM64 \
	-o "$generator" \
	tools/self_hosting/generate-toolchain-resources.red
chmod +x "$generator"
"$generator" "$repo_root" "$resources"

"$bootstrap" -r -t Darwin-ARM64 -o "$output" red-toolchain.red
chmod +x "$output"
"$output" --self-check
"$output" --toolchain-info

echo "Built $output"
