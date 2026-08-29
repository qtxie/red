#!/bin/bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/.." && pwd)
compiler=${RED_COMPILER:-"$repo/build/self-hosting/red-bootstrap-stage2-darwin-arm64"}
output_dir=${RED_BUNDLE_SIGN_OUTPUT_DIR:-"$repo/build/macos-arm64-bundle-sign-tests"}
source_file="$repo/tests/source/view/macos-arm64-smoke.red"

[ -x "$compiler" ] || {
	printf 'Darwin ARM64 compiler is not executable: %s\n' "$compiler" >&2
	exit 2
}

for tool in file otool plutil codesign; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'Required macOS tool is unavailable: %s\n' "$tool" >&2
		exit 2
	}
done

mkdir -p "$output_dir"

verify_bundle() {
	app=$1
	name=$2
	expected_identifier=$3
	bundle_executable=$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")
	executable="$app/Contents/MacOS/$bundle_executable"
	signature_details=

	[ -x "$executable" ] || {
		printf 'Bundle executable is not executable: %s\n' "$executable" >&2
		exit 1
	}
	[ -f "$app/Contents/_CodeSignature/CodeResources" ] || {
		printf 'Bundle resource envelope is missing: %s\n' "$app" >&2
		exit 1
	}
	file "$executable" | grep -q 'Mach-O 64-bit executable arm64'
	otool -hv "$executable" | grep -q 'ARM64'
	plutil -lint "$app/Contents/Info.plist" >/dev/null
	plutil -lint "$app/Contents/_CodeSignature/CodeResources" >/dev/null
	[ "$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")" = "$expected_identifier" ]
	codesign --verify --deep --strict --verbose=4 "$app"
	signature_details=$(codesign --display --verbose=4 "$app" 2>&1)
	printf '%s\n' "$signature_details" | grep -q "Identifier=$expected_identifier"
	printf '%s\n' "$signature_details" | grep -q 'Hash choices=sha1,sha256'
	printf '%s\n' "$signature_details" | grep -q 'Signature=adhoc'
	printf '%s\n' "$signature_details" | grep -q 'Sealed Resources version=2'

	tampered="$output_dir/$name-tampered.app"
	rm -rf "$tampered"
	cp -R "$app" "$tampered"
	printf 'tampered' >> "$tampered/Contents/Resources/AppIcon.icns"
	if codesign --verify --deep --strict "$tampered" >/dev/null 2>&1; then
		printf 'Tampered bundle unexpectedly verified: %s\n' "$tampered" >&2
		exit 1
	fi
	cp "$app/Contents/Resources/AppIcon.icns" "$tampered/Contents/Resources/AppIcon.icns"
	printf '\n' >> "$tampered/Contents/Info.plist"
	if codesign --verify --deep --strict "$tampered" >/dev/null 2>&1; then
		printf 'Bundle with tampered Info.plist unexpectedly verified: %s\n' "$tampered" >&2
		exit 1
	fi
	cp "$app/Contents/Info.plist" "$tampered/Contents/Info.plist"
	printf '\n' >> "$tampered/Contents/_CodeSignature/CodeResources"
	if codesign --verify --deep --strict "$tampered" >/dev/null 2>&1; then
		printf 'Bundle with tampered CodeResources unexpectedly verified: %s\n' "$tampered" >&2
		exit 1
	fi
	rm -rf "$tampered"
}

release_output="$output_dir/release/gui-console"
development_output="$output_dir/development/gui-console"
special_name=$'GUI & caf\xC3\xA9'
special_output="$output_dir/names/$special_name"
rm -rf "$output_dir/release" "$output_dir/development" "$output_dir/names"
mkdir -p "$output_dir/release" "$output_dir/development" "$output_dir/names"

"$compiler" -r -d -t macOS-ARM64 -o "$release_output" "$source_file"
verify_bundle "$release_output.app" gui-console org.redlang.gui-console

"$compiler" -d -t macOS-ARM64 -o "$development_output" "$source_file"
verify_bundle "$development_output.app" gui-console org.redlang.gui-console
[ -f "$development_output.app/Contents/MacOS/libRedRT.dylib" ]
[ ! -e "$release_output.app/Contents/MacOS/libRedRT.dylib" ]

"$compiler" -r -d -t macOS-ARM64 -o "$special_output" "$source_file"
verify_bundle "$special_output.app" "$special_name" org.redlang.GUI---caf-

printf 'macOS ARM64 Red bundle signing validation passed.\n'
