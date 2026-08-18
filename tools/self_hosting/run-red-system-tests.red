Red [
	Title: "Windows Red/System compiler tests"
	File:  %run-red-system-tests.red
]

; Compiles and runs the non-static Windows IA-32 Red/System unit suite through
; RED_SYSTEM_COMPILER must name the self-hosted red-bootstrap executable.

join-file: func [base [file!] relative [file!]][
	append copy base relative
]

abs-file: func [base [file!] relative [file!]][
	clean-path join-file base relative
]

; red-console sets options/path to the script directory (tools/self_hosting/).
root-dir: abs-file system/options/path %../../
change-dir root-dir
source-dir: %system/tests/source/units/
output-dir: %build/self-hosting/system-suite/
make-dir output-dir
compiler-script: %red-system-selfhost-windows.red
red-console: system/options/boot
compiler-executable: get-env "RED_SYSTEM_COMPILER"
compiler-arguments: any [get-env "RED_SYSTEM_COMPILER_ARGUMENTS" ""]
structlib-file: any [get-env "RED_SYSTEM_STRUCTLIB" join-file source-dir %libs/structlib.dll]
x64?: not none? find compiler-arguments "X86-64"
arguments: any [system/options/args copy []]
run-only?: not none? find arguments "--run-only"
use-existing-dlls?: not none? find arguments "--use-existing-dlls"
compile-failures: 0

quoted: func [value][
	; Prefer root-relative local paths for Stage1 path joining.
	rejoin [{"} to-local-file value {"}]
]

compiler-prefix: either compiler-executable [
	quoted to file! compiler-executable
][
	rejoin [quoted red-console " " quoted compiler-script]
]

output-name: func [source [file!] output-type [word!] /local name suffix][
	name: to string! last split-path source
	clear find/last name ".reds"
	suffix: either output-type = 'dll [".dll"][".exe"]
	to file! rejoin [name suffix]
]

compile-source: func [
	source [file!]
	output-type [word!]
	/local output target command status log-file
][
	output: output-name source output-type
	target: join-file output-dir output
	command: rejoin [
		compiler-prefix
		either empty? compiler-arguments [""][rejoin [" " compiler-arguments]]
		either output-type = 'dll [" -dlib"][""]
		" -o " quoted target " " quoted source
	]
	print ["compile" source "->" target]
	log-file: append copy target %.compile.log
	if exists? target [delete target]
	if exists? log-file [delete log-file]
	status: call/shell/wait rejoin [
		command " > " quoted log-file " 2>&1"
	]
	unless all [status = 0 exists? target][
		if exists? log-file [print read log-file]
		print ["compiler failed for" source "status:" status]
		compile-failures: compile-failures + 1
		return none
	]
	target
]

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
if x64? [
	change find unit-sources %struct-test.reds %struct-x64-test.reds
	change find unit-sources %size-test.reds %size-x64-test.reds
]

compiled: make block! (length? unit-sources) * 2
either run-only? [
	foreach relative unit-sources [
		executable: join-file output-dir output-name relative 'exe
		unless exists? executable [
			print ["missing compiled test:" executable]
			quit/return 1
		]
		append/only compiled relative
		append/only compiled executable
	]
][
	unless use-existing-dlls? [
		compile-source join-file source-dir %libtest-dll1.reds 'dll
		compile-source join-file source-dir %libtest-dll2.reds 'dll
	]
	if use-existing-dlls? [
		foreach dependency [%libtest-dll1.dll %libtest-dll2.dll][
			unless exists? join-file output-dir dependency [
				print ["missing existing test dependency:" dependency]
				compile-failures: compile-failures + 1
			]
		]
	]
	write/binary join-file output-dir %structlib.dll read/binary to file! structlib-file

	foreach relative unit-sources [
		executable: compile-source join-file source-dir relative 'exe
		if file? executable [
			append/only compiled relative
			append/only compiled executable
		]
	]
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
	"Red/System suite totals:"
	"tests" total-tests
	"assertions" total-asserts
	"passed" total-passes
	"failed" total-failures
	"compile-failures" compile-failures
]
quit/return either zero? (total-failures + compile-failures) [0][1]
