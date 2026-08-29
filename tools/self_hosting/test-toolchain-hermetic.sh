#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 red-toolchain" >&2
	exit 2
fi

toolchain=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
fixture_dir=$(cd "$(dirname "$0")/fixtures/toolchain" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/red-toolchain-hermetic.XXXXXX")
trap 'rm -rf -- "$work"' EXIT HUP INT TERM

cp "$toolchain" "$work/red-toolchain"
cp "$fixture_dir"/* "$work/"
chmod +x "$work/red-toolchain"
cd "$work"

./red-toolchain --self-check
./red-toolchain -r -t Darwin-ARM64 -o hello-release hello.red
chmod +x hello-release
[ "$(./hello-release)" = "RED-TOOLCHAIN-HERMETIC-OK" ]

./red-toolchain -r -t Darwin-ARM64 -o modules-release modules.red
chmod +x modules-release
[ "$(./modules-release)" = "RED-TOOLCHAIN-MODULES-OK" ]

./red-toolchain -r -t Darwin-ARM64 -o hello-reds hello.reds
chmod +x hello-reds
[ "$(./hello-reds)" = "RED-TOOLCHAIN-REDS-OK" ]

./red-toolchain -t Darwin-ARM64 -o hello-development hello.red
[ -f libRedRT.dylib ]
chmod +x hello-development
[ "$(DYLD_LIBRARY_PATH="$work" ./hello-development)" = "RED-TOOLCHAIN-HERMETIC-OK" ]

./red-toolchain -r -dlib -t Darwin-ARM64 -o libtoolchain-fixture.dylib library.reds
[ -f libtoolchain-fixture.dylib ]

./red-toolchain -r -t macOS-ARM64 -o view-fixture view.red
[ -x view-fixture.app/Contents/MacOS/view-fixture ]
[ ! -e view-fixture.app/Contents/MacOS/libRedRT.dylib ]

echo "RED-TOOLCHAIN-HERMETIC-SUITE-OK"
