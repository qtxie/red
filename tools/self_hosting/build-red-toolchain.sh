#!/bin/sh
set -eu

# Builds the standalone Red toolchain for one hybrid target with a pinned
# bootstrap compiler. The target is explicit because the same script now serves
# every platform the matrix builds for, not just Darwin-ARM64.

target=Darwin-ARM64

usage() {
	echo "Usage: $0 [-t hybrid-target] focused-bootstrap [output]" >&2
	exit 2
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		-t)
			[ "$#" -ge 2 ] || usage
			target=$2
			shift 2
			;;
		-t?*)
			target=${1#-t}
			shift
			;;
		-h|--help) usage ;;
		--) shift; break ;;
		-*) usage ;;
		*) break ;;
	esac
done

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage
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
"$bootstrap" -r -t "$target" \
	-o "$generator" \
	tools/self_hosting/generate-toolchain-resources.red
chmod +x "$generator"
"$generator" "$repo_root" "$resources"

"$bootstrap" -r -t "$target" -o "$output" red-toolchain.red
chmod +x "$output"
"$output" --self-check
"$output" --toolchain-info

echo "Built $output for $target"
