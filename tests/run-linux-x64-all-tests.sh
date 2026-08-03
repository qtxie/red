#!/bin/sh
set -eu

phase=${1:-all}
compile_timeout=${COMPILE_TIMEOUT_SECONDS:-300}
run_timeout=${RUN_TIMEOUT_SECONDS:-30}
smoke_runs=${X64_SMOKE_RUNS:-3}

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
root=$(CDPATH='' cd "$script_dir/.." && pwd)
compiler=${2:-${RED_COMPILER:-$root/build/self-hosting/red-bootstrap-stage1-linux-x64.exe}}
artifact_dir="$root/build/linux-x64-all-tests"
dependency_dir="$artifact_dir/dependencies"
source_dir="$root/system/tests/source/units"
runtime_source_dir="$root/tests/source/runtime"

case "$phase" in
	prepare|native|system|all) ;;
	*)
		echo "Usage: $0 [prepare|native|system|all] [stage1-compiler]" >&2
		exit 2
		;;
esac

require_tool() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Required tool not found: $1" >&2
		exit 1
	fi
}

safe_remove_artifacts() {
	case "$artifact_dir" in
		"$root/build/linux-x64-all-tests") rm -rf -- "$artifact_dir" ;;
		*)
			echo "Refusing to remove unexpected artifact directory: $artifact_dir" >&2
			exit 1
			;;
	esac
}

run_logged() {
	label=$1
	shift
	log="$artifact_dir/$label.log"
	if "$@" >"$log" 2>&1; then
		return 0
	else
		status=$?
	fi
	echo "$label failed with exit code $status" >&2
	cat "$log" >&2
	return "$status"
}

assert_no_runtime_error() {
	log=$1
	if grep -E '\*\*\* (Runtime|Internal) Error' "$log" >/dev/null 2>&1; then
		echo "Runtime error reported in $log" >&2
		cat "$log" >&2
		return 1
	fi
}

assert_elf64_pie() {
	binary=$1
	label=$2
	header_log="$artifact_dir/$label-elf-header.log"
	file_log="$artifact_dir/$label-file.log"

	file "$binary" >"$file_log"
	if ! grep -F 'ELF 64-bit' "$file_log" >/dev/null; then
		echo "$label is not an ELF64 binary" >&2
		cat "$file_log" >&2
		return 1
	fi

	readelf -hW "$binary" >"$header_log"
	if ! grep -E 'Class:[[:space:]]+ELF64' "$header_log" >/dev/null; then
		echo "$label has the wrong ELF class" >&2
		return 1
	fi
	if ! grep -E 'Type:[[:space:]]+DYN' "$header_log" >/dev/null; then
		echo "$label is not ET_DYN/PIE" >&2
		return 1
	fi
}

compile_program() {
	name=$1
	source=$2
	output=$3
	if [ "${RESUME_TESTS:-0}" = 1 ] && [ -f "$output" ]; then
		echo "Reusing $output"
		chmod +x "$output"
		return 0
	fi
	case "$compiler" in
		*.exe)
			run_logged "$name-compile" timeout "${compile_timeout}s" \
				"$compiler" -r -d -t Linux-X86-64 \
				-o "$(wslpath -w "$output")" "$(wslpath -w "$source")"
			;;
		*)
			run_logged "$name-compile" timeout "${compile_timeout}s" \
				"$compiler" -r -d -t Linux-X86-64 -o "$output" "$source"
			;;
	esac
	chmod +x "$output"
}

compile_library() {
	name=$1
	source=$2
	output=$3
	if [ "${RESUME_TESTS:-0}" = 1 ] && [ -f "$output" ]; then
		echo "Reusing $output"
		return 0
	fi
	case "$compiler" in
		*.exe)
			run_logged "$name-compile" timeout "${compile_timeout}s" \
				"$compiler" -r -dlib -d -t Linux-X86-64-SO \
				-o "$(wslpath -w "$output")" "$(wslpath -w "$source")"
			;;
		*)
			run_logged "$name-compile" timeout "${compile_timeout}s" \
				"$compiler" -r -dlib -d -t Linux-X86-64-SO -o "$output" "$source"
			;;
	esac
}

run_program() {
	name=$1
	binary=$2
	log="$artifact_dir/$name-run.log"
	if env LD_LIBRARY_PATH="$artifact_dir:$dependency_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
		timeout "${run_timeout}s" "$binary" >"$log" 2>&1; then
		assert_no_runtime_error "$log"
		return 0
	else
		status=$?
	fi
	echo "$name failed with exit code $status" >&2
	cat "$log" >&2
	return "$status"
}

prepare_suite() {
	for tool in "$compiler" gcc file readelf timeout gawk grep; do
		case "$tool" in
			*/*)
				if [ ! -x "$tool" ]; then
					echo "Compiler is not executable: $tool" >&2
					exit 1
				fi
				;;
			*) require_tool "$tool" ;;
		esac
	done

	safe_remove_artifacts
	mkdir -p "$dependency_dir"

	run_logged bootstrap-version "$compiler" -v
	run_logged structlib-build gcc -shared -fPIC -O2 \
		-o "$dependency_dir/libstructlib.so" \
		"$source_dir/libs/structlib.c"

	canary="$artifact_dir/linux-x64-runner-canary"
	compile_program linux-x64-runner-canary \
		"$source_dir/x64-argument-count-smoke.reds" "$canary"
	assert_elf64_pie "$canary" linux-x64-runner-canary
	run_program linux-x64-runner-canary "$canary"

	echo "Linux x86-64 test preparation passed."
}

build_probe_libraries() {
	compile_library libx64test-dll1 \
		"$source_dir/libtest-dll1.reds" "$artifact_dir/libx64test-dll1.so"
	compile_library libx64import-extra \
		"$source_dir/libx64-import-var-extra.reds" "$artifact_dir/libx64import-extra.so"
}

run_abi_probes() {
	probes='x64-atomic-direct
x64-branch-smoke
x64-catch-cleanup
x64-catch-global
x64-catch-runtime
x64-cpu-register-smoke
x64-dylib-import-smoke
x64-fixed-int-op-smoke
x64-fixed-int-path-smoke
x64-fixed-int-smoke
x64-float-arg-smoke
x64-float-comparison-smoke
x64-float-smoke
x64-float-stack-arg-smoke
x64-float32-comparison-smoke
x64-function-arg-smoke
x64-function-nested-path-smoke
x64-function-pointer-smoke
x64-function-smoke
x64-function-variable-smoke
x64-hidden-return-smoke
x64-image-info-smoke
x64-import-smoke
x64-import-var-logic-smoke
x64-import-var-smoke
x64-int64-smoke
x64-local-smoke
x64-log-b-call-state-smoke
x64-mixed-arg-smoke
x64-nested-struct-smoke
x64-not-smoke
x64-overflow-smoke
x64-plt-import-smoke
x64-pointer-smoke
x64-register-arg-smoke
x64-secondary-call-smoke
x64-secondary-operand-smoke
x64-size-smoke
x64-stack-arg-smoke
x64-stack-smoke
x64-struct-by-value-smoke
x64-struct-pointer-index-smoke
x64-struct-smoke
x64-subroutine-smoke
x64-syscall-smoke
x64-tagged-union-smoke
x64-typed-print-smoke
x64-typed-variadic-smoke
x64-union-by-value-smoke
x64-variadic-smoke
x64-wide-stack-arg-smoke
x64-write'

	# x64-mixed-overflow-smoke and x64-pointer-parity-smoke remain
	# non-blocking diagnostics until their backend edge cases are implemented.
	count=0
	for name in $probes; do
		source="$source_dir/$name.reds"
		binary="$artifact_dir/$name"
		if [ ! -f "$source" ]; then
			echo "Probe source is missing: $source" >&2
			return 1
		fi
		compile_program "$name" "$source" "$binary"
		run_program "$name" "$binary"
		count=$((count + 1))
	done
	echo "Linux x86-64 ABI probes passed ($count tests)."
}

assert_no_executable_relocations() {
	binary=$1
	sections="$artifact_dir/release-sections.log"
	relocations="$artifact_dir/release-relocations.log"
	readelf -SW "$binary" >"$sections"
	readelf -rW "$binary" >"$relocations"

	gawk '
		function hex(value) { return strtonum("0x" value) }
		NR == FNR {
			if (match($0, /^[[:space:]]*\[[[:space:]]*[0-9]+\][[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+([0-9A-Fa-f]+)[[:space:]]+[0-9A-Fa-f]+[[:space:]]+([0-9A-Fa-f]+)[[:space:]]+[^[:space:]]+[[:space:]]+([A-Z]+)/, match_data)) {
				if (match_data[3] ~ /X/) {
					start[++ranges] = hex(match_data[1])
					finish[ranges] = start[ranges] + hex(match_data[2])
				}
			}
			next
		}
		$1 ~ /^[0-9A-Fa-f]{8,16}$/ {
			offset = hex($1)
			for (range_index = 1; range_index <= ranges; range_index++) {
				if ((offset >= start[range_index]) && (offset < finish[range_index])) {
					printf "Dynamic relocation targets executable section at 0x%X\n", offset > "/dev/stderr"
					exit 1
				}
			}
		}
	' "$sections" "$relocations"
}

run_release_smoke() {
	binary="$artifact_dir/x64-red-smoke"
	compile_program release-smoke "$runtime_source_dir/x64-red-smoke.red" "$binary"
	assert_elf64_pie "$binary" release-smoke

	readelf -dW "$binary" >"$artifact_dir/release-dynamic.log"
	if grep -F 'TEXTREL' "$artifact_dir/release-dynamic.log" >/dev/null; then
		echo "Linux x86-64 release smoke contains TEXTREL" >&2
		return 1
	fi
	assert_no_executable_relocations "$binary"

	aslr=$(cat /proc/sys/kernel/randomize_va_space)
	if [ "$aslr" = 0 ]; then
		echo "ASLR is disabled" >&2
		return 1
	fi

	run=1
	while [ "$run" -le "$smoke_runs" ]; do
		log="$artifact_dir/release-run-$run.log"
		if timeout "${run_timeout}s" "$binary" >"$log" 2>&1; then
			:
		else
			status=$?
			echo "Release smoke run $run failed with exit code $status" >&2
			cat "$log" >&2
			return "$status"
		fi
		assert_no_runtime_error "$log"
		last_line=$(gawk 'NF { last = $0 } END { print last }' "$log")
		markers=$(grep -c '^X64-RED-OK$' "$log" || true)
		if [ "$last_line" != X64-RED-OK ] || [ "$markers" -ne 1 ]; then
			echo "Unexpected release smoke output on run $run" >&2
			cat "$log" >&2
			return 1
		fi
		run=$((run + 1))
	done

	echo "Linux x86-64 release smoke passed ($smoke_runs runs, ASLR=$aslr)."
}

run_native_suite() {
	if [ ! -d "$dependency_dir" ]; then
		echo "Linux x86-64 dependencies are missing; run the prepare phase first" >&2
		return 1
	fi
	build_probe_libraries
	run_abi_probes
	run_release_smoke
	echo "Linux x86-64 native tests passed."
}

run_system_suite() {
	if [ ! -d "$dependency_dir" ]; then
		echo "Linux x86-64 dependencies are missing; run the prepare phase first" >&2
		return 1
	fi

	compile_library system-libtest-dll1 \
		"$source_dir/libtest-dll1.reds" "$artifact_dir/libtest-dll1.so"
	compile_library system-libtest-dll2 \
		"$source_dir/libtest-dll2.reds" "$artifact_dir/libtest-dll2.so"

	unit_sources='array-test
logic-test
byte-test
c-string-test
struct-x64-test
union-test
pointer-test
cast-test
alias-test
length-test
null-test
enum-test
protect-test
float-test
float32-test
lib-test
get-pointer-test
float-pointer-test
namespace-test
not-test
size-x64-test
integer-test
fixed-int-test
int64-test
function-test
case-test
switch-test
subroutine-test
use-test
exit-test
return-test
exceptions-test
modulo-test
math-mixed-test
overflow-test
vararg-test
infix-test
conditional-test
system-test
atomic-test
queue-test
push-pop-test'

	count=0
	for suite in $unit_sources; do
		binary="$artifact_dir/system-$suite"
		compile_program "system-$suite" "$source_dir/$suite.reds" "$binary"
		run_program "system-$suite" "$binary"
		log="$artifact_dir/system-$suite-run.log"
		if ! grep -E 'Number of Assertions Failed:[[:space:]]+0' "$log" >/dev/null; then
			echo "$suite did not report a zero-failure Quick-Test summary" >&2
			cat "$log" >&2
			return 1
		fi
		count=$((count + 1))
	done

	dylib_source="$artifact_dir/dylib-auto-test-linux.reds"
	quick_test_reds=$(wslpath -w "$root/quick-test/quick-test.reds" | \
		tr '\\' '/' | sed 's|^\([A-Za-z]\):|/\1|')
	sed \
		-e "s|#include .*quick-test/quick-test.reds|#include %$quick_test_reds|" \
		-e 's|libtest-dll1\.dll|libtest-dll1.so|g' \
		-e 's|libtest-dll2\.dll|libtest-dll2.so|g' \
		"$source_dir/auto-tests/dylib-auto-test.reds" >"$dylib_source"
	dylib_binary="$artifact_dir/system-dylib-auto-test"
	compile_program system-dylib-auto-test "$dylib_source" "$dylib_binary"
	run_program system-dylib-auto-test "$dylib_binary"
	dylib_log="$artifact_dir/system-dylib-auto-test-run.log"
	if ! grep -E 'Number of Assertions Failed:[[:space:]]+0' "$dylib_log" >/dev/null; then
		echo "dylib-auto-test did not report a zero-failure Quick-Test summary" >&2
		cat "$dylib_log" >&2
		return 1
	fi
	count=$((count + 1))

	echo "Linux x86-64 Red/System unit suites passed ($count tests)."
}

case "$phase" in
	prepare) prepare_suite ;;
	native) run_native_suite ;;
	system) run_system_suite ;;
	all)
		prepare_suite
		run_native_suite
		run_system_suite
		;;
esac

if [ "$phase" != prepare ] && [ "${KEEP_ARTIFACTS:-0}" != 1 ]; then
	safe_remove_artifacts
fi
