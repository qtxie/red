Red [
	Title: "Shared Quick-Test driver for the Red-native test runners"
	File:  %qt-runner.red
]

comment {
	Shared Quick-Test driver for the Red-native test runners.

	Rebol cannot run on ARM64, so the harness that drives the test suites has to
	run on Red. This file is the port of the Quick-Test driver layer; it is
	#included by the suite runners, which then declare their own source list.

	It deliberately carries no Red header: it is #included, never do'ne.

	State lives in the `qt` context because the test scripts reference
	qt/comp-output and qt/output directly. The test DSL (--assert, --compiled?,
	--test--, the group and file markers) is global so a script pulled in with
	`do %file.red` sees it: `do` of a file evaluates in the global context.
}

qt: context [
	root-dir: none
	source-dir: none
	output-dir: none
	compiler: none						;-- quoted command prefix
	compiler-arguments: ""
	compile-flag: ""					;-- extra flags a test script may set
	source-file?: true					;-- set by scripts; this driver ignores it
	target: none
	library-target: none

	comp-output: make string! 8192		;-- captured compiler output
	output: make string! 8192			;-- captured program output
	compile-ok?: false
	compile-failures: 0

	tests: asserts: passes: failures: 0

	current-source: current-output: none

	digits: charset "0123456789"
	whitespace: charset " ^-^/^M"

	join-file: func [base [file!] relative [file!]][append copy base relative]

	abs-file: func [base [file!] relative [file!]][clean-path join-file base relative]

	; Everything the driver touches is resolved against the repo root. `do` of a
	; test script change-dir's into that script's directory, so a relative path
	; built before the call is not the same path inside it.
	absolute: func [path [file!] /local text][
		text: to string! path
		; Absolute means a leading slash (Red spelling) or a drive letter
		; (a path that came from an environment variable).
		either any [
			all [not empty? text text/1 = #"/"]
			all [2 <= length? text text/2 = #":"]
		][
			path
		][
			clean-path join-file root-dir path
		]
	]

	; Red file operations resolve relative paths against system/options/path
	; (this runner's own directory), not the working directory, so every path
	; the driver hands to Red has to be absolute.
	out-path: func [name [file!]][absolute join-file output-dir name]

	local-path: func [value [file! string!]][
		absolute to file! replace/all copy to string! value #"\" "/"
	]

	quote: func [value][rejoin [{"} to-local-file value {"}]]

	;-- Windows executables carry .exe, the ELF and Mach-O targets carry none.
	;-- The suite runners hard-coded %.exe, which only ever worked on Windows.
	executable-suffix: does [
		either all [target find target "Windows"] [%".exe"][%""]
	]

	library-suffix: does [
		case [
			all [target find target "Windows"]	[%".dll"]
			all [target find target "Darwin"]	[%".dylib"]
			true								[%".so"]
		]
	]

	;-- `-t` may only appear once: when the caller's arguments already name a
	;-- target, a runner must not add a second one. When they name none the
	;-- runner's own target is injected, which is also what pins a compile to
	;-- the host instead of to whatever default the compiler picked.
	target-flag: does [
		either all [
			not empty? compiler-arguments
			find split compiler-arguments " " "-t"
		][""][rejoin ["-t " target]]
	]

	output-name: func [
		source [file!]
		output-type [word!]
		/local name
	][
		name: to string! last split-path source
		if find/last name "." [clear find/last name "."]
		to file! rejoin [
			name
			either output-type = 'dll [library-suffix][executable-suffix]
		]
	]

	; make-dir silently returns its argument without creating anything when
	; given a relative path in this Red build, so always hand it an absolute one.
	ensure-output-dir: does [
		make-dir/deep absolute output-dir
		; The Rebol harness published these globally and the test scripts use
		; them to stage files the compiler then reads.
		set 'qt-tmp-file out-path %testfile.txt
		set 'qt-temp-file qt-tmp-file
		set 'qt-tmp-dir absolute output-dir
		set 'qt-temp-dir qt-tmp-dir
		output-dir
	]

	set-compiler: func [
		env-var [string!]
		/local value
	][
		value: get-env env-var
		unless value [
			print ["*** Quick-Test:" env-var "env var required (path to the hybrid compiler)"]
			quit/return 1
		]
		compiler: quote to file! value
		compiler
	]

	;-- Compile one source. Returns the emitted file, or none on failure.
	;-- Success is the exit code *and* the emitted file: a compiler that exits 0
	;-- without producing anything is a failure, and a failure keeps its
	;-- diagnostics in comp-output so --assert-msg? can inspect them.
	compile-file: func [
		source [file!]
		output-type [word!]
		/local output command status out err
	][
		output: out-path output-name source output-type
		source: absolute source
		command: rejoin [
			compiler
			either empty? compiler-arguments [""][rejoin [" " compiler-arguments]]
			either empty? compile-flag [""][rejoin [" " compile-flag]]
			case [
				output-type <> 'dll					[""]
				none? library-target				[" -dlib"]
				true								[rejoin [" -dlib -t " library-target]]
			]
			" -o " quote output " " quote source
		]
		print ["compile" source "->" output]
		if exists? output [delete output]
		out: make string! 8192
		err: make string! 8192
		status: call/wait/output/error command out err
		comp-output: rejoin [out err]
		compile-ok?: all [status = 0 exists? output]
		current-output: output
		either compile-ok? [
			output
		][
			compile-failures: compile-failures + 1
			print ["compiler failed for" source "status:" status]
			unless empty? comp-output [print comp-output]
			none
		]
	]

	compile: func [source [file!]][compile-file source 'exe]

	compile-library: func [source [file!]][compile-file source 'dll]

	;-- Run a compiled program, leaving its output in qt/output.
	run: func [
		executable [file!]
		/with argument [file! string!]	;-- pass the program an argument
		/local command status out err
	][
		command: either with [
			rejoin [quote executable " " quote argument]
		][
			quote executable
		]
		out: make string! 8192
		err: make string! 8192
		status: call/wait/output/error command out err
		output: rejoin [out err]
		status
	]

	;-- Parse the summary block quick-test.red emits and fold it into the totals.
	read-summary: func [
		text [string!]
		name [file! string!]
		/local tests asserts passes failures
	][
		either parse text [
			thru "Number of Tests Performed:" some whitespace copy tests some digits
			thru "Number of Assertions Performed:" some whitespace copy asserts some digits
			thru "Number of Assertions Passed:" some whitespace copy passes some digits
			thru "Number of Assertions Failed:" some whitespace copy failures some digits to end
		][
			self/tests: self/tests + to integer! tests
			self/asserts: self/asserts + to integer! asserts
			self/passes: self/passes + to integer! passes
			self/failures: self/failures + to integer! failures
			print ["run" name "tests:" tests "assertions:" asserts "failed:" failures]
			true
		][
			print ["missing Quick-Test summary:" name]
			unless empty? text [print text]
			self/failures: self/failures + 1
			false
		]
	]

	;-- Compile, run and score one unit source.
	run-unit: func [
		source [file!]
		/local executable status
	][
		executable: compile source
		unless executable [return false]
		status: run executable
		if status <> 0 [
			print ["process failed:" source "status:" status]
			failures: failures + 1
		]
		read-summary output source
	]

	; `none` is a legitimate result here: --assert --compile-and-run ... passes
	; none when the compile failed. Coerce it rather than type-checking it away.
	record-assertion: func [passed? /local passed][
		asserts: asserts + 1
		passed: either none? passed? [false][to logic! passed?]
		either passed [
			passes: passes + 1
			true
		][
			failures: failures + 1
			print ["FAILED:" test-name]
			false
		]
	]

	test-name: "unnamed test"

	cleanup-current: does [
		foreach file reduce [current-source current-output][
			if all [file? file exists? file][delete file]
		]
		current-source: current-output: none
	]

	;-- A source supplied as a string often omits its header, so insert the
	;-- default one: the compiler decides Red vs Red/System from it.
	has-script-header?: func [source [string!]][
		any [
			find source "Red/System ["
			find source "Red ["
			find source "Red/System[]"
			find source "Red[]"
		]
	]

	compile-string: func [
		source [string!]
		/red							;-- Red rather than Red/System source
		/local source-file body
	][
		cleanup-current
		source-file: out-path either red [%qt-runner-source.red][%qt-runner-source.reds]
		body: copy source
		unless has-script-header? body [
			insert body rejoin [either red ["Red []"]["Red/System []"] newline]
		]
		write source-file body
		current-source: source-file
		compile-file source-file 'exe
	]

	compile-source: func [source [string!]][compile-string source]

	compile-and-run-string: func [
		source [string!]
		/red
		/error							;-- a runtime error is expected
		/local executable
	][
		output: copy ""
		executable: either red [compile-string/red source][compile-string source]
		if executable [run executable]
		executable
	]

	report: func [label [string!]][
		print [
			label
			"tests" tests
			"assertions" asserts
			"passed" passes
			"failed" failures
			"compile-failures" compile-failures
		]
		quit/return either zero? (failures + compile-failures) [0][1]
	]
]

;-- Resolve the repo root. red-console sets options/path to the script
;-- directory (tools/self_hosting/), and relative file resolution follows it,
;-- so change-dir before touching any relative path.
qt/root-dir: qt/abs-file system/options/path %../../
change-dir qt/root-dir

system/options/quiet: true

;---------------------------------------------------------------------------
; Test DSL. Global, so scripts pulled in with `do %file.red` see it.
;---------------------------------------------------------------------------

--test--: func [name][qt/test-name: form name]

--assert: func [condition][qt/record-assertion condition]

--assert-msg?: func [message [string!]][
	unless qt/record-assertion not none? find qt/comp-output message [
		print ["expected compiler message:" mold message]
		print ["actual compiler output:" mold qt/comp-output]
	]
]

--assert-printed?: func [expected [string!]][
	qt/record-assertion not none? find qt/output expected
]

--assert-red-printed?: func [expected [string!]][--assert-printed? expected]

;-- Log-file switch from the Rebol harness; the Red runners write no log files.
--separate-log-file: does [none]
--seperate-log-file: does [none]

~~~start-file~~~: func [name][print ["tests:" name]]

~~~end-file~~~: does [qt/cleanup-current]

===start-group===: func [name][none]

===end-group===: does [none]

--compile-this: func [source [string!]][qt/compile-string source]

--compile-this-red: func [source [string!]][qt/compile-string/red source]

--compiled?: func [source [string!]][
	qt/compile-string source
	qt/compile-ok?
]

; /error marks a program expected to raise a runtime error. The driver never
; counts a runtime error as a test failure -- only the assertions do -- so the
; refinement is accepted and has nothing to change.
--compile-and-run: func [
	source [string! file!]
	/pgm
	/error
	/local executable
][
	qt/output: copy ""
	executable: either pgm [
		qt/cleanup-current
		qt/compile-file source 'exe
	][
		qt/compile-string source
	]
	if executable [qt/run executable]
	executable
]

--compile-and-run-this: func [source [string!] /error][
	either error [qt/compile-and-run-string/error source][qt/compile-and-run-string source]
]

--compile-and-run-this-red: func [source [string!] /error][
	either error [
		qt/compile-and-run-string/error/red source
	][
		qt/compile-and-run-string/red source
	]
]

--compile-dll: func [source [file!]][qt/compile-library source]

--clean: does [qt/cleanup-current]

--run-test-file-quiet: func [source [file!]][qt/run-unit source]
