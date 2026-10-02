Red [
	Title: "Red batch driver test runner"
	File:  %run-red-run-all-tests.red
]

comment {
	Compiles and runs the three Quick-Test batch drivers through RED_COMPILER.

	%make-run-all.red splits the unit list over run-all-comp1 and run-all-comp2
	and inlines the interpreted half into run-all-interp, so a run here pays three
	compiles for the units the per-unit runner pays one apiece. The drivers and the
	stripped copies they #include land in %tests/source/units/auto-tests/, which is
	generated and never checked in -- hence the generation step below.

	Usage:     red-console.exe tools/self_hosting/run-red-run-all-tests.red
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
qt/source-dir: %tests/source/units/
qt/output-dir: %build/self-hosting/red-run-all-suite/
qt/ensure-output-dir
qt/set-compiler "RED_COMPILER"

; The compiler links against a runtime it finds in the output directory instead
; of building one. Drop the whole triple here so every run uses current sources.
qt/clear-runtime

;-- Generated sources are only current if this run made them. `do` of a file
;-- evaluates it from that file's own directory, which is where make-run-all.red
;-- reads %all-tests.txt and writes %auto-tests/ from.
do qt/abs-file qt/root-dir %tests/source/units/make-run-all.red

driver-sources: [
	%auto-tests/run-all-comp1.red
	%auto-tests/run-all-comp2.red
	%auto-tests/run-all-interp.red
]

foreach relative driver-sources [
	qt/run-unit qt/join-file qt/source-dir relative
]

;-- %all-tests.txt never listed this one -- the Rebol harness ran it from its
;-- "extra" phase, outside the units directory -- so the drivers cannot carry it.
qt/run-unit %tests/source/runtime/unicode-test.red

qt/report "Red run-all suite totals:"
