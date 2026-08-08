#!/bin/bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/.." && pwd)
compiler=${RED_COMPILER:-"$repo/build/self-hosting/red-bootstrap-stage2-darwin-arm64"}
output_dir=${RED_VIEW_TEST_OUTPUT_DIR:-"$repo/build/macos-arm64-view-tests-release"}
timeout_seconds=${RED_VIEW_TEST_TIMEOUT:-60}

usage() {
	cat <<EOF
Usage: $0 [--compiler path] [--output-dir path]

Builds and runs the macOS ARM64 View smoke test in release mode.
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--compiler)
			[ "$#" -ge 2 ] || { usage >&2; exit 2; }
			compiler=$2
			shift 2
			;;
		--output-dir)
			[ "$#" -ge 2 ] || { usage >&2; exit 2; }
			output_dir=$2
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown argument: %s\n' "$1" >&2
			usage >&2
			exit 2
			;;
	esac
done

case "$timeout_seconds" in
	''|*[!0-9]*)
		printf 'RED_VIEW_TEST_TIMEOUT must be a positive integer.\n' >&2
		exit 2
		;;
esac
[ "$timeout_seconds" -gt 0 ] || {
	printf 'RED_VIEW_TEST_TIMEOUT must be greater than zero.\n' >&2
	exit 2
}

[ -x "$compiler" ] || {
	printf 'Darwin ARM64 compiler is not executable: %s\n' "$compiler" >&2
	exit 2
}

for tool in file otool dyld_info plutil codesign; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'Required macOS tool is unavailable: %s\n' "$tool" >&2
		exit 2
	}
done

name=macos-arm64-view-smoke
source_file="$repo/tests/source/view/macos-arm64-smoke.red"
app="$output_dir/$name.app"
executable="$app/Contents/MacOS/$name"
plist="$app/Contents/Info.plist"
runtime="$app/Contents/MacOS/libRedRT.dylib"
compile_log="$output_dir/compile.log"
stdout_log="$output_dir/$name.stdout.log"
stderr_log="$output_dir/$name.stderr.log"
marker="$output_dir/$name.ok"
error_file="$output_dir/$name.error"
tampered_app="$output_dir/$name-tampered.app"
signature_details=

mkdir -p "$output_dir"
rm -rf "$app"
rm -f "$compile_log" "$stdout_log" "$stderr_log" "$marker" "$error_file"
rm -rf "$tampered_app"

cd "$repo"
if ! "$compiler" -r -d --show-func-map -t macOS-ARM64 -o "$output_dir/$name" "$source_file" \
	>"$compile_log" 2>&1; then
	cat "$compile_log" >&2
	printf 'macOS ARM64 release View compilation failed.\n' >&2
	exit 1
fi

[ -f "$executable" ] || {
	printf 'Bundle executable is missing: %s\n' "$executable" >&2
	exit 1
}
[ -f "$plist" ] || {
	printf 'Bundle Info.plist is missing: %s\n' "$plist" >&2
	exit 1
}
[ -f "$app/Contents/_CodeSignature/CodeResources" ] || {
	printf 'Bundle CodeResources is missing: %s\n' "$app/Contents/_CodeSignature/CodeResources" >&2
	exit 1
}
[ ! -e "$runtime" ] || {
	printf 'Release bundle unexpectedly contains libRedRT.dylib.\n' >&2
	exit 1
}

[ -x "$executable" ] || {
	printf 'Bundle executable is not executable: %s\n' "$executable" >&2
	exit 1
}
file "$executable" | grep -q 'Mach-O 64-bit executable arm64'
otool -hv "$executable" | grep -q 'ARM64'
otool -L "$executable" | grep -q 'AppKit.framework'
if otool -L "$executable" | grep -q 'libRedRT.dylib'; then
	printf 'Release executable unexpectedly imports libRedRT.dylib.\n' >&2
	exit 1
fi
dyld_info -validate_only "$executable"
plutil -lint "$plist" >/dev/null
plutil -lint "$app/Contents/_CodeSignature/CodeResources" >/dev/null
[ "$(plutil -extract CFBundleExecutable raw -o - "$plist")" = "$name" ]
codesign --verify --deep --strict --verbose=4 "$app"
signature_details=$(codesign --display --verbose=4 "$app" 2>&1)
printf '%s\n' "$signature_details" | grep -q "Identifier=org.redlang.$name"
printf '%s\n' "$signature_details" | grep -q 'Hash choices=sha1,sha256'
printf '%s\n' "$signature_details" | grep -q 'Signature=adhoc'
printf '%s\n' "$signature_details" | grep -q 'Sealed Resources version=2'

cp -R "$app" "$tampered_app"
printf 'tampered' >> "$tampered_app/Contents/Resources/AppIcon.icns"
if codesign --verify --deep --strict "$tampered_app" >/dev/null 2>&1; then
	printf 'Tampered bundle unexpectedly passed code-signature verification.\n' >&2
	exit 1
fi
rm -rf "$tampered_app"

console_user=$(stat -f %Su /dev/console)
current_user=$(id -un)
if [ "$console_user" != "$current_user" ]; then
	printf 'The GUI smoke must run as the console user (%s), current user is %s.\n' \
		"$console_user" "$current_user" >&2
	exit 1
fi

RED_VIEW_TEST_OUTPUT_DIR="$output_dir" \
	"$executable" >"$stdout_log" 2>"$stderr_log" &
app_pid=$!
deadline=$(($(date +%s) + timeout_seconds))
timed_out=no

while kill -0 "$app_pid" 2>/dev/null; do
	if [ "$(date +%s)" -ge "$deadline" ]; then
		timed_out=yes
		kill "$app_pid" 2>/dev/null || true
		sleep 1
		kill -9 "$app_pid" 2>/dev/null || true
		break
	fi
	sleep 1
done

set +e
wait "$app_pid"
status=$?
set -e

if [ "$timed_out" = yes ]; then
	printf 'macOS ARM64 View smoke timed out after %s seconds.\n' "$timeout_seconds" >&2
	status=124
fi
if [ "$status" -ne 0 ]; then
	[ ! -s "$stderr_log" ] || cat "$stderr_log" >&2
	printf 'macOS ARM64 View smoke exited with status %s.\n' "$status" >&2
	exit "$status"
fi

if [ -f "$error_file" ]; then
	cat "$error_file" >&2
	printf 'macOS ARM64 View smoke reported a test failure.\n' >&2
	exit 1
fi

[ -f "$marker" ] || {
	printf 'macOS ARM64 View smoke did not create its success marker.\n' >&2
	exit 1
}
[ "$(cat "$marker")" = 'MACOS-ARM64-VIEW-OK' ] || {
	printf 'macOS ARM64 View smoke marker has unexpected content.\n' >&2
	exit 1
}

printf 'macOS ARM64 release View validation passed.\n'
