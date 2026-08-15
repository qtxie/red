Red [
	Title: "Standalone saved-frontend hybrid backend"
	File:  %red-bootstrap-windows-hybrid-backend.red
	Config: [show: 'X86-64-Hybrid-only]
]

compiler-root: system/options/path
unless value? 'event! [event!: make datatype! #get-definition TYPE_EVENT]

#include %system/compiler-windows-hybrid-bootstrap.red
#include %compiler/version.red
#include %compiler/bootstrap-options.red
#include %compiler/saved-frontend.red

recycle/on

backend-version: "0.1.0"

fail-command: func [message][
	print ["*** Hybrid backend error:" message]
	quit/return 1
]

print-usage: does [
	print "Usage: hybrid-backend [-r] [-d] [-n] [-O0|-O1] -t Windows-X86-64 --loaded-red generated.reds -o output.exe original.red"
]

strip-quotes: func [text [string!]][
	if all [
		(length? text) >= 2
		any [text/1 = #"^"" text/1 = #"'"]
		text/1 = last text
	][text: copy/part next text (length? text) - 2]
	text
]

resolve-source-path: func [raw [string! file!] /local text candidate][
	text: strip-quotes to string! raw
	candidate: clean-path to-red-file to file! text
	if exists? candidate [return candidate]
	clean-path append copy compiler-root to-red-file to file! text
]

read-source-marker: func [source [file!] /local value][
	set/any 'value try [transcode/one read/binary source]
	if error? :value [fail-command rejoin ["cannot read source header: " source]]
	:value
]

compile-saved: func [options [object!] /local source saved job frontend-result result prefix][
	unless compiler-options/option-get options 'source [fail-command "missing original Red source"]
	unless saved: compiler-options/option-get options 'loaded-red [
		fail-command "standalone backend requires --loaded-red"
	]
	if compiler-options/option-get options 'red-only? [
		fail-command "standalone backend cannot produce --red-only output"
	]
	unless compiler-options/option-get options 'output [fail-command "missing -o output"]

	source: resolve-source-path compiler-options/option-get options 'source
	unless exists? source [fail-command rejoin ["cannot access source file: " source]]
	unless (read-source-marker source) = 'Red [
		fail-command "standalone backend requires an original Red source file"
	]
	saved: resolve-source-path saved

	job: compiler-options/to-job options
	if error? :job [fail-command mold job]
	compiler-system-job/job-set job 'backend-mode 'rsir
	compiler-system-job/job-set job 'link? true
	compiler-system-job/job-set job 'unicode? true
	compiler-system-job/job-set job 'red-pass? true
	compiler-system-job/job-set job 'compiler-version compiler-version
	compiler-system-job/job-set job 'compiler-build-date compiler-build-date
	compiler-system-job/job-set job 'compiler-git none
	prefix: compiler-system-job/job-get job 'build-prefix
	unless empty? prefix [make-dir/deep prefix]

	frontend-result: compiler-saved-frontend/load-artifacts
		saved source compiler-system-job/job-get job 'config-name
	unless block? frontend-result [fail-command compiler-saved-frontend/last-error/message]
	print ["Compiling saved frontend" saved "..."]
	phase-timer/begin 'backend-total
	system-dialect/compile/options/loaded source job frontend-result
	phase-timer/finish 'backend-total
	result: system-dialect/last-result
	unless all [block? result file? result/4 exists? result/4][
		fail-command "hybrid backend did not produce an output"
	]
	print [
		"...native time      :" result/1
		"...link time        :" result/2
		"...output file      :" result/4
		"...output bytes     :" result/3
	]
]

args: any [system/options/args copy []]
unless block? args [args: copy []]
phase-timer/reset
options: compiler-options/parse-args args
if error? :options [fail-command mold options]
if compiler-options/option-get options 'help? [print-usage quit/return 0]
if compiler-options/option-get options 'version? [print backend-version quit/return 0]
compile-saved options
quit/return 0
