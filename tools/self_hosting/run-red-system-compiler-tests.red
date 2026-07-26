Red [
	Title: "Red-native Red/System compiler tests"
	File:  %run-red-system-compiler-tests.red
]

path-at: func [base [file!] relative [file!]][
	clean-path append copy base relative
]

resolve-file: func [base [file!] value [file! string!] /local file spelling][
	file: to file! value
	spelling: to string! file
	either any [
		all [not empty? spelling spelling/1 = #"/"]
		all [(length? spelling) >= 2 spelling/2 = #":"]
	][file][path-at base file]
]

quoted: func [value][
	rejoin [{"} to-local-file value {"}]
]

root-dir: path-at system/options/path %../../
change-dir root-dir
tests-dir: path-at root-dir %system/tests/
compiler-dir: path-at tests-dir %source/compiler/
output-dir: path-at root-dir %build/self-hosting/compiler-tests/
compiler-script: path-at root-dir %red-system-selfhost-windows.red
red-console: system/options/boot
compiler-executable: get-env "RED_SYSTEM_COMPILER"
compiler-prefix: either compiler-executable [
	quoted to file! compiler-executable
][
	rejoin [quoted red-console " " quoted compiler-script]
]
make-dir output-dir

qt: context [
	compile-ok?: false
	comp-output: make string! 0
	output: make string! 0
	base-dir: root-dir
	library-target: "MSDOS"
]

test-name: "unnamed compiler test"
assertions: failures: compile-index: 0
current-source: current-output: none

record-assertion: func [passed? /local passed][
	assertions: assertions + 1
	passed: to logic! passed?
	unless passed [
		failures: failures + 1
		print ["FAILED:" test-name]
	]
	passed
]

cleanup-current: does [
	foreach file reduce [current-source current-output][
		if all [file? file exists? file][delete file]
	]
	current-source: current-output: none
]

compile-command: func [source [file!] output [file!] output-type [word!] /local command][
	command: rejoin [
		compiler-prefix
		either output-type = 'dll [" -dlib -t MSDOS"][""]
		" -o " quoted output " " quoted source
	]
	command
]

compile-file: func [
	source [file!]
	output-type [word!]
	/local output suffix process-output status
][
	compile-index: compile-index + 1
	suffix: either output-type = 'dll [".dll"][".exe"]
	output: path-at output-dir to file! rejoin ["compiler-test-" compile-index suffix]
	if exists? output [delete output]
	process-output: make string! 4096
	status: call/wait/output (compile-command source output output-type) process-output
	qt/comp-output: process-output
	qt/compile-ok?: all [status = 0 exists? output]
	current-output: output
	either qt/compile-ok? [output][none]
]

compile-source: func [source [string!] /local source-file][
	cleanup-current
	source-file: path-at output-dir to file! rejoin ["compiler-test-" (compile-index + 1) ".reds"]
	write source-file source
	current-source: source-file
	compile-file source-file 'exe
]

run-output: func [executable [file!] /local status output][
	output: make string! 4096
	status: call/wait/output (quoted executable) output
	qt/output: output
	status
]

--compile-this: func [source [string!]][compile-source source]

--compiled?: func [source [string!] /local executable][
	executable: compile-source source
	qt/compile-ok?
]

--compile-and-run: func [source [string! file!] /pgm /local executable source-file][
	qt/output: copy ""
	executable: either pgm [
		source-file: resolve-file tests-dir source
		cleanup-current
		compile-file source-file 'exe
	][
		compile-source source
	]
	if executable [run-output executable]
	executable
]

--compile-and-run-this: func [source [string!]][--compile-and-run source]

--compile-dll: func [source [file!] target /local source-file executable][
	cleanup-current
	source-file: resolve-file root-dir source
	executable: compile-file source-file 'dll
	unless qt/compile-ok? [
		print ["DLL source:" mold source-file]
		print ["DLL compiler output:" mold qt/comp-output]
	]
	executable
]

--clean: does [cleanup-current]

--assert: func [condition][record-assertion condition]

--assert-msg?: func [message [string!]][
	unless record-assertion not none? find qt/comp-output message [
		print ["expected compiler message:" mold message]
		print ["actual compiler output:" mold qt/comp-output]
	]
]

--assert-printed?: func [expected [string!]][
	record-assertion not none? find qt/output expected
]

--test--: func [name][test-name: form name]
~~~start-file~~~: func [name][print ["compiler tests:" name]]
~~~end-file~~~: does [cleanup-current]
===start-group===: func [name][none]
===end-group===: does [none]

REBOL: func [header [block!]][none]
change-dir: func [path][none]
comment: func [value][none]
found?: func [value][not none? value]
reform: func [values][form reduce values]
join: func [value rest][append either series? value [copy value][form value] rest]

compiler-scripts: [
	%alias-test.r %cast-test.r %comp-err-test.r %exit-test.r
	%int-literals-test.r %output-test.r %return-test.r %cond-expr-test.r
	%inference-test.r %callback-test.r %infix-test.r %not-test.r
	%print-test.r %enum-test.r %pointer-test.r %namespace-test.r
	%compiles-ok-test.r %dylib-test.r %regression-test-rsc.r
]

requested: system/options/args
foreach relative compiler-scripts [
	if any [empty? requested find requested to string! relative][
		script-file: path-at compiler-dir relative
		print ["load compiler tests:" script-file]
		set/any 'result try [do transcode read/binary script-file]
		if error? :result [
			failures: failures + 1
			print ["compiler test harness error:" relative]
			print mold :result
		]
		cleanup-current
	]
]

if empty? requested [
	test-name: "define-test.reds"
	define-executable: compile-file path-at compiler-dir %define-test.reds 'exe
	record-assertion qt/compile-ok?
	if define-executable [
		run-output define-executable
		record-assertion not none? find qt/output "Number of Assertions Failed:    0"
	]
]

cleanup-current
print [
	"Red/System compiler-test totals:"
	"assertions" assertions
	"failed" failures
]
quit/return either zero? failures [0][1]
