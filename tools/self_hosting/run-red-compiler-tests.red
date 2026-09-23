Red [
	Title: "Red compiler regression tests"
	File:  %run-red-compiler-tests.red
]

comment {
	Drives the ported Red compiler regression scripts.

	These are the counterparts of the Red/System compiler tests: they exercise
	the Red frontend through --compile-this-red and
	--compile-and-run-this-red rather than the Red/System ones. Rebol cannot run
	on ARM64, so the harness runs on Red and the scripts are real Red scripts
	pulled in with `do` -- no transcode, no compatibility shim.

	%preprocessor-test.red is here rather than beside the Rebol-only
	%lexer-test.r: it drives the Red preprocessor, not a Rebol one.
}

#include %qt-runner.red

qt/compiler-arguments: any [get-env "RED_COMPILER_ARGUMENTS" ""]
qt/target: any [
	get-env "RED_TARGET"
	if all [
		not empty? qt/compiler-arguments
		pos: find split qt/compiler-arguments " " "-t"
		1 < length? pos
	][pos/2]
	"MSDOS-X86-64"
]
qt/set-compiler "RED_COMPILER"
qt/output-dir: %build/self-hosting/red-compiler-tests/
qt/ensure-output-dir

compiler-dir: qt/abs-file qt/root-dir %tests/source/compiler/

compiler-scripts: [
	%regression-test-redc-1.red %regression-test-redc-2.red
	%regression-test-redc-3.red %regression-test-redc-4.red
	%regression-test-redc-5.red
	%compile-error-test.red %run-time-error-test.red %print-test.red
	%preprocessor-test.red
]

requested: any [system/options/args copy []]
foreach relative compiler-scripts [
	if any [empty? requested find requested to string! relative][
		script-file: qt/join-file compiler-dir relative
		print ["load compiler tests:" script-file]
		; `do` of a file change-dir's into that file's directory, and every
		; later compile resolves its paths against the working directory.
		save-dir: what-dir
		; The trailing word guarantees a value even when the script ends unset,
		; so `error?` always has something to look at.
		set/any 'result try [do script-file 'loaded]
		change-dir save-dir
		if error? :result [
			qt/failures: qt/failures + 1
			print ["compiler test harness error:" relative]
			print mold :result
		]
		qt/cleanup-current
	]
]

qt/report "Red compiler-test totals:"
