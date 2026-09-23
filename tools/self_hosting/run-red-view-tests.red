Red [
	Title: "Red/View native (GUI backend) test runner"
	File:  %run-red-view-tests.red
]

comment {
	Runs the View unit test that needs a real GUI: %tests/source/view/
	base-self-test.red scores itself by rasterizing a face and measuring the
	pixels it rendered, so it needs a backend with an actual renderer. The
	headless `test` backend's draw dialect is a stub -- every snapshot comes
	back blank -- which is why run-red-view-headless-tests.red leaves this
	file out of its list.

	This is the Red port of %tests/run-view-tests.r, which drove the same
	single file from Rebol. Rebol cannot run on ARM64, so a harness that
	`do`es the Rebol Quick-Test driver can never execute there; and unlike
	%tests/run-windows-x64-view-tests.ps1 this one needs no Windows host --
	it runs wherever Red and a display do.

	The source is staged rather than compiled in place. As shipped it has
	`Needs: 'View` commented out, it turns on the interactive display of
	failed images (five seconds each), and its whole body sits behind
	`object? :system/view`, which is only true once the View engine is up.
	The staged copy enables View, switches that display off and opens one
	throwaway window before the gate. Staging at the output directory keeps
	the quick-test.red include working: it is spelled relative to the source
	and the output directory happens to sit at the same depth.

	Usage:     red-console.exe tools/self_hosting/run-red-view-tests.red
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
	"MSDOS-X86-64"
]
qt/set-compiler "RED_COMPILER"
qt/output-dir: %build/self-hosting/red-view-suite/
qt/ensure-output-dir

;; -r forces a standalone link so the View engine is compiled now instead of
;; being glued to a prebuilt libRedRT that may carry a different backend.
qt/compile-flag: rejoin [" -r " qt/target-flag]

source: %tests/source/view/base-self-test.red
staged: qt/out-path %base-self-test.red

text: read qt/abs-file qt/root-dir source

marker: {; Needs:   'View}
unless find text marker [
	print ["** base-self-test.red no longer has:" mold marker]
	quit/return 1
]
replace text marker {Needs:   View}

marker: {bst-user-mode: yes}
unless find text marker [
	print ["** base-self-test.red no longer has:" mold marker]
	quit/return 1
]
replace text marker {bst-user-mode: no}

;; Bring the View engine up before the gate on line 22 tests it. Inserted
;; rather than replaced, so `find` above cannot match the replacement.
marker: {~~~start-file~~~ "base-self-test"}
insert any [
	find/tail text marker
	(print ["** base-self-test.red no longer has:" mold marker] quit/return 1)
] rejoin [newline newline {view/no-wait [base 1x1]} newline]

write staged text

executable: qt/compile staged
unless executable [
	print "** base-self-test.red - compiler error **"
	print qt/comp-output
	quit/return 1
]

qt/run executable
qt/read-summary qt/output source

if find qt/output "Runtime Error" [
	print ["view test error:" source]
	qt/failures: qt/failures + 1
]

qt/report "Red/View native totals:"
