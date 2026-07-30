Red [
	Title: "Windows Stage1 Red unit suite runner"
	File:  %run-red-unit-tests.red
]

; Compiles and runs non-View Red unit tests through RED_COMPILER (Stage1).
; Uses the same Quick-Test summary format as the Red/System suite runner.

join-file: func [base [file!] relative [file!]][append copy base relative]
abs-file: func [base [file!] relative [file!]][clean-path join-file base relative]

root-dir: abs-file system/options/path %../../
change-dir root-dir
source-dir: %tests/source/units/
output-dir: %build/self-hosting/red-unit-suite/
make-dir output-dir
compiler-executable: get-env "RED_COMPILER"
unless compiler-executable [
	print "RED_COMPILER env var required (path to Stage1 red-bootstrap exe)"
	quit/return 1
]
compiler-arguments: any [get-env "RED_COMPILER_ARGUMENTS" ""]

quoted: func [value][rejoin [{"} to-local-file value {"}]]
compiler-prefix: quoted to file! compiler-executable

output-name: func [source [file!] /local name][
	name: to string! last split-path source
	clear find/last name ".red"
	to file! rejoin [name ".exe"]
]

compile-source: func [
	source [file!]
	/local output target command compiler-output status attempt log-file full-cmd
][
	output: output-name source
	target: join-file output-dir output
	command: rejoin [
		compiler-prefix
		either empty? compiler-arguments [""][rejoin [" " compiler-arguments]]
		" -o " quoted target " " quoted source
	]
	print ["compile" source "->" target]
	; Avoid call/wait/output: capturing Stage1 stdout via pipes can AV during
	; high-warning compiles (e.g. fixed-int-test). Redirect to a log file instead.
	; Retry because Stage1 still has occasional native-gen AVs.
	attempt: 0
	log-file: append copy target %.compile.log
	until [
		attempt: attempt + 1
		if exists? target [delete target]
		if exists? log-file [delete log-file]
		; The compiler uses the Windows GUI subsystem, so CMD otherwise returns
		; before the process exits. START /WAIT keeps the status and output file
		; checks synchronized with the actual compiler process.
		full-cmd: rejoin [{start "" /wait } command " > " quoted log-file " 2>&1"]
		status: call/shell/wait full-cmd
		any [
			all [status = 0 exists? target]
			attempt >= 5
		]
	]
	unless all [status = 0 exists? target][
		if exists? log-file [print read log-file]
		print ["compiler failed for" source "status:" status "attempts:" attempt]
		quit/return 1
	]
	if attempt > 1 [print ["compiled after" attempt "attempts:" source]]
	target
]

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
	%file-test.red %url-test.red %csv-test.red %json-test.red
	%system-test.red %recycle-test.red %case-folding-test.red
	%points-test.red %preprocessor-test.red %serialization-test.red
	%redbin-codec-test.red
]

compiled: make block! (length? unit-sources) * 2
foreach relative unit-sources [
	append/only compiled relative
	append/only compiled compile-source join-file source-dir relative
]

digits: charset "0123456789"
whitespace: charset " ^-^/^M"
total-tests: total-asserts: total-passes: total-failures: 0

read-summary: func [output [string!] name [file!] /local tests asserts passes failures][
	if parse output [
		thru "Number of Tests Performed:" some whitespace copy tests some digits
		thru "Number of Assertions Performed:" some whitespace copy asserts some digits
		thru "Number of Assertions Passed:" some whitespace copy passes some digits
		thru "Number of Assertions Failed:" some whitespace copy failures some digits to end
	][
		total-tests: total-tests + to integer! tests
		total-asserts: total-asserts + to integer! asserts
		total-passes: total-passes + to integer! passes
		total-failures: total-failures + to integer! failures
		print ["run" name "tests:" tests "assertions:" asserts "failed:" failures]
		return none
	]
	print ["missing Quick-Test summary:" name]
	print output
	total-failures: total-failures + 1
]

foreach [relative executable] compiled [
	output: make string! 8192
	status: call/wait/output to-local-file executable output
	if status <> 0 [
		print ["process failed:" relative "status:" status]
		total-failures: total-failures + 1
	]
	read-summary output relative
]

print [
	"Red unit suite totals:"
	"tests" total-tests
	"assertions" total-asserts
	"passed" total-passes
	"failed" total-failures
]
quit/return either zero? total-failures [0][1]
