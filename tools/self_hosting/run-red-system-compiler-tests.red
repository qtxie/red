Red [
	Title: "Red-native Red/System compiler tests"
	File:  %run-red-system-compiler-tests.red
]

comment {
	Drives the ported Red/System compiler test scripts.

	Rebol cannot run on ARM64, so the harness runs on Red. The scripts
	themselves are ported to Red and pulled in with `do`, which evaluates them
	in the global context where the driver has installed the test DSL. Nothing
	is loaded through `transcode` any more, and there is no Rebol-compatibility
	shim: a shim made the scripts *load* without making them *correct* (it
	defined `change-dir` as a no-op, so every script that opened with
	`change-dir %../` ran in whatever directory it inherited).
}

#include %qt-runner.red

qt/compiler-arguments: any [get-env "RED_SYSTEM_COMPILER_ARGUMENTS" ""]

; The executable and library suffixes follow the target, so recover it from the
; -t argument when the caller did not name it outright.
qt/target: any [
	get-env "RED_SYSTEM_TARGET"
	if all [
		not empty? qt/compiler-arguments
		pos: find split qt/compiler-arguments " " "-t"
		1 < length? pos
	][pos/2]
	"MSDOS-X86-64"
]
;; The shared-object target follows the executable one. Windows spells the
;; suffix -DLL; every other target the toolchain reports is -SO. It used to
;; default to Windows-X86-64-DLL outright, which made every non-Windows target
;; ask for a Windows DLL and emit <name>.so.dll -- a file the runner then
;; could not find, so both libtest-dll sources counted as compile failures.
qt/library-target: any [
	get-env "RED_SYSTEM_LIBRARY_TARGET"
	rejoin [qt/target either qt/windows-target? ["-DLL"]["-SO"]]
]

qt/set-compiler "RED_SYSTEM_COMPILER"
qt/output-dir: %build/self-hosting/compiler-tests/
qt/ensure-output-dir

; `do` of a file resolves relative paths against system/options/path (the
; runner's own directory), not the working directory, so hand it absolute ones.
compiler-dir: qt/abs-file qt/root-dir %system/tests/source/compiler/

compiler-scripts: [
	%alias-test.red %cast-test.red %comp-err-test.red %exit-test.red
	%int-literals-test.red %output-test.red %return-test.red %cond-expr-test.red
	%inference-test.red %callback-test.red %infix-test.red %not-test.red
	%print-test.red %enum-test.red %pointer-test.red %namespace-test.red
	%compiles-ok-test.red %dylib-test.red %regression-test-rsc.red
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

if empty? requested [
	qt/test-name: "define-test.reds"
	define-executable: qt/compile-file qt/join-file compiler-dir %define-test.reds 'exe
	qt/record-assertion qt/compile-ok?
	if define-executable [
		qt/run define-executable
		qt/record-assertion not none? find qt/output "Number of Assertions Failed:    0"
	]
]

qt/cleanup-current
qt/report "Red/System compiler-test totals:"
