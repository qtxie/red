Red [
	Title: "Red/View headless (test backend) test runner"
	File:  %run-red-view-headless-tests.red
]

comment {
	Runs the View/VID unit tests that target the headless `test` GUI backend
	(Config: [GUI-engine: 'test]). No display is required, so the suite runs on
	any platform and any CI runner without a windowing system.

	The tests are *interpreted*: %view-headless-interpreter.red is compiled once
	per run, so it always picks up the current sources, and every test file is
	then fed to that one binary -- one compile instead of sixteen.

	This is the Red port of %tests/run-view-headless-tests.r. Rebol cannot run
	on ARM64, so a harness that `do`es the Rebol Quick-Test driver can never
	execute there; this one runs wherever Red runs.

	Usage:     red-console.exe tools/self_hosting/run-red-view-headless-tests.red
	           (optionally followed by the test file names to run a subset)
	Configure: RED_COMPILER, RED_COMPILER_ARGUMENTS, RED_TARGET.
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
	"Windows-X86-64"
]
qt/set-compiler "RED_COMPILER"
qt/output-dir: %build/self-hosting/red-view-headless-suite/
qt/ensure-output-dir

;; Force a full standalone compile. The encapped compiler otherwise links a
;; prebuilt libRedRT that is built with the *native* GUI backend, which is
;; incompatible with `Config: [GUI-engine: 'test]` (undefined `do-event`,
;; duplicate draw-ctx! definitions). -r is what forces the standalone link.
;; The target is only injected when the caller named none: two -t conflict.
qt/compile-flag: rejoin [" -r " qt/target-flag]

interpreter: qt/compile %tests/view-headless-interpreter.red
unless interpreter [
	print "** view-headless-interpreter.red - compiler error **"
	print qt/comp-output
	quit/return 1
]

view-dir: qt/abs-file qt/root-dir %tests/source/view/

view-sources: [
	%vid-positioning-test.red %vid-styles-test.red %vid-facets-test.red
	%vid-containers-test.red %vid-actors-test.red %vid-errors-test.red
	%vid-window-test.red
	%face-facets-test.red %face-types-test.red %show-sync-test.red
	%make-face-test.red %face-tree-test.red
	%events-actors-test.red %input-test.red %reactivity-test.red
	%draw-parse-test.red
	;; Needs: 'View is commented out in this one and it carries no Config: of
	;; its own, because it is meant to run under whatever backend hosts it --
	;; here the interpreter, which is built with GUI-engine: 'test. It used to
	;; be driven only by %tests/run-view-tests.r, through a Rebol interpreter
	;; that happened to have a real GUI.
	%base-self-test.red
]

requested: any [system/options/args copy []]

foreach relative view-sources [
	if any [empty? requested find requested to string! relative][
		source: qt/join-file view-dir relative
		;; The interpreter scores itself: its totals come back in the Quick-Test
		;; summary block, and a script that dies before ~~~end-file~~~ emits
		;; none, which read-summary counts as a failure.
		qt/run/with interpreter source
		qt/read-summary qt/output source
		if any [
			find qt/output "Runtime Error"			;; Red/System runtime error
			find qt/output "Error:"					;; interpreter error report
		][
			qt/failures: qt/failures + 1
			print ["view test error:" relative]
		]
	]
]

qt/report "Red/View headless totals:"
