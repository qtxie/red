Red [
	Title: "Red unit suite runner"
	File:  %run-red-unit-tests.red
]

comment {
	Compiles and runs the non-View Red unit tests through RED_COMPILER.

	All compile/run/score logic lives in qt-runner.red; this file only names the
	sources. Rebol cannot run on ARM64, so the harness runs on Red.
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
qt/source-dir: %tests/source/units/
qt/output-dir: %build/self-hosting/red-unit-suite/
qt/ensure-output-dir
qt/set-compiler "RED_COMPILER"

; The compiler reuses an existing libRedRT in the output directory. Drop a stale
; runtime here so every run links against one built from current sources.
libRedRT-file: qt/join-file qt/output-dir to file! rejoin ["libRedRT" qt/library-suffix]
if exists? libRedRT-file [delete libRedRT-file]

; Core console language units only (no View/GUI/clipboard/draw/image).
unit-sources: [
	%logic-test.red %conditional-test.red %case-test.red %switch-test.red
	%integer-test.red %float-test.red %char-test.red %tuple-test.red
	%pair-test.red %money-test.red %time-test.red %date-test.red
	%bitset-test.red %vector-test.red %map-test.red %object-test.red
	%function-test.red %loop-test.red %series-test.red %find-test.red
	%select-test.red %append-test.red %insert-test.red %change-test.red
	%move-test.red %replace-test.red %path-test.red %parse-test.red
	%make-test.red %convert-test.red %comparison-test.red %same-test.red
	%strict-equal-test.red %mold-test.red %load-test.red %lexer-test.red
	%evaluation-test.red %binding-test.red %throw-test.red %try-test.red
	%unset-test.red %type-test.red %words-of-test.red %power-test.red
	%checksum-test.red %enbase-test.red %debase-test.red %decompress-test.red
	%file-test.red %url-test.red
	%system-test.red %recycle-test.red %case-folding-test.red
	%points-test.red %preprocessor-test.red %serialization-test.red
	%redbin-codec-test.red
]

foreach relative unit-sources [
	qt/run-unit qt/join-file qt/source-dir relative
]

;; The Rebol harness ran this one from its "extra" phase, outside the units
;; directory. It is folded in here so retiring that harness loses nothing.
qt/run-unit %tests/source/runtime/unicode-test.red

qt/report "Red unit suite totals:"
