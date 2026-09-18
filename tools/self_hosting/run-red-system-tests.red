Red [
	Title: "Red/System unit suite runner"
	File:  %run-red-system-tests.red
]

comment {
	Compiles and runs the Red/System unit suite through RED_SYSTEM_COMPILER.

	All compile/run/score logic lives in qt-runner.red; this file only names the
	sources and handles the x64 source swaps. Rebol cannot run on ARM64, so the
	harness runs on Red.
}

#include %qt-runner.red

qt/compiler-arguments: any [get-env "RED_SYSTEM_COMPILER_ARGUMENTS" ""]
qt/target: any [
	get-env "RED_SYSTEM_TARGET"
	if all [
		not empty? qt/compiler-arguments
		pos: find split qt/compiler-arguments " " "-t"
		1 < length? pos
	][pos/2]
	"Windows-X86-64"
]
;; The shared-object target follows the executable one. Windows spells the
;; suffix -DLL; every other target the toolchain reports is -SO.
qt/library-target: any [
	get-env "RED_SYSTEM_LIBRARY_TARGET"
	rejoin [qt/target either find qt/target "Windows" ["-DLL"]["-SO"]]
]
qt/source-dir: %system/tests/source/units/
qt/output-dir: %build/self-hosting/system-suite/
qt/ensure-output-dir
qt/set-compiler "RED_SYSTEM_COMPILER"

structlib-file: any [
	get-env "RED_SYSTEM_STRUCTLIB"
	qt/join-file qt/source-dir %libs/structlib.dll
]
arguments: any [system/options/args copy []]
run-only?: not none? find arguments "--run-only"
use-existing-dlls?: not none? find arguments "--use-existing-dlls"

unit-sources: [
	%array-test.reds %logic-test.reds %byte-test.reds %c-string-test.reds
	%struct-test.reds %union-test.reds %pointer-test.reds %cast-test.reds
	%alias-test.reds %length-test.reds %null-test.reds %enum-test.reds
	%protect-test.reds %float-test.reds %float32-test.reds %lib-test.reds
	%get-pointer-test.reds %float-pointer-test.reds %namespace-test.reds
	%not-test.reds %size-test.reds %integer-test.reds %fixed-int-test.reds
	%int64-test.reds %function-test.reds %case-test.reds %switch-test.reds
	%subroutine-test.reds %use-test.reds %exit-test.reds %return-test.reds
	%exceptions-test.reds %modulo-test.reds %math-mixed-test.reds
	%overflow-test.reds %vararg-test.reds %infix-test.reds %conditional-test.reds
	%system-test.reds %atomic-test.reds %queue-test.reds %push-pop-test.reds
	%auto-tests/dylib-auto-test.reds
]
if not none? find qt/target "X86-64" [
	change find unit-sources %struct-test.reds %struct-x64-test.reds
	change find unit-sources %size-test.reds %size-x64-test.reds
]

;-- %auto-tests/dylib-auto-test.reds is assembled from four templates, the same
;-- substitution the Rebol harness spread over %make-dylib-auto-test.r and
;-- %create-dylib-auto-test.r. The #import block names the DLLs by absolute
;-- path: a compiled test runs from the repo root, not from the output
;-- directory the DLLs were emitted into.
generate-dylib-auto-test: func [
	/local units-dir out header libs make-length script
][
	units-dir: qt/abs-file qt/root-dir %system/tests/source/units/
	make-dir/deep qt/join-file units-dir %auto-tests/

	header: read qt/join-file units-dir %dylib-test-script-header.txt
	libs:   read qt/join-file units-dir %dylib-libs.txt

	;; The header credits its generator by byte length. This runner regenerates
	;; on every run, so the marker only has to stay stable.
	make-length: 0
	if file? script: system/options/script [
		script: qt/absolute script
		if exists? script [make-length: length? read/binary script]
	]
	replace header "###make-length###" make-length
	replace header "###target###" any [qt/library-target qt/target]

	replace libs "***test-dll1***" form to-local-file qt/out-path to file! rejoin ["libtest-dll1" qt/library-suffix]
	replace libs "***test-dll2***" form to-local-file qt/out-path to file! rejoin ["libtest-dll2" qt/library-suffix]

	out: qt/join-file units-dir %auto-tests/dylib-auto-test.reds
	write out rejoin [
		header
		libs
		read qt/join-file units-dir %dylib-tests.txt
		read qt/join-file units-dir %dylib-test-script-footer.txt
	]
	out
]

generate-dylib-auto-test

either run-only? [
	foreach relative unit-sources [
		executable: qt/out-path qt/output-name relative 'exe
		unless exists? executable [
			print ["missing compiled test:" executable]
			quit/return 1
		]
		qt/run executable
		qt/read-summary qt/output relative
	]
][
	unless use-existing-dlls? [
		qt/compile-library qt/join-file qt/source-dir %libtest-dll1.reds
		qt/compile-library qt/join-file qt/source-dir %libtest-dll2.reds
	]
	if use-existing-dlls? [
		foreach dependency [%libtest-dll1.dll %libtest-dll2.dll][
			unless exists? qt/out-path dependency [
				print ["missing existing test dependency:" dependency]
				qt/compile-failures: qt/compile-failures + 1
			]
		]
	]
	write/binary qt/out-path %structlib.dll read/binary qt/local-path structlib-file

	foreach relative unit-sources [
		qt/run-unit qt/join-file qt/source-dir relative
	]
	;; From the Rebol harness's "extra" phase; it lives outside the units
	;; directory, so it is not part of unit-sources.
	qt/run-unit %tests/source/runtime/tools-test.reds
]

qt/report "Red/System suite totals:"
