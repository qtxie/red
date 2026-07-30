Red [
	Title: "Self-hosted Windows Red compiler bootstrap"
	File:  %red-bootstrap-windows.red
]

compiler-root: system/options/path
; The core compiler does not load View, but it needs the datatype token to compile View targets.
unless value? 'event! [event!: make datatype! #get-definition TYPE_EVENT]


; The bootstrap backend contains dynamic Windows PE support for IA-32 and
; x86-64. Static linking and the other targets enter after the compiler can
; rebuild this executable without Rebol.
#include %system/compiler-windows-bootstrap.red

#include %compiler/modules.red
#include %compiler/version.red
#include %compiler/preprocessor.red
#include %compiler/extractor.red
#include %compiler/redbin.red
#include %compiler/crush.red
#include %compiler/frontend.red
#include %compiler/bootstrap-options.red

; Interpreted bootstrap follows Stage0's deep binding operation. The AOT source
; materializes this field through frontend.red's nested include instead.
if none? red/redbin [do bind load %compiler/redbin-emitter.red red]

; Keep collection enabled while the compiler builds its large intermediate graphs.
recycle/on

bootstrap-version: "0.6.6-selfhost.1-windows"
red-system-marker: first [Red/System]

print-usage: does [
	print "Usage: red-bootstrap-windows [-r] [-u] [-d] [-dlib] [-t target] [--red-only] [-o output.exe] source.red|source.reds"
]

fail-command: func [message][
	print ["*** Red command-line error:" message]
	quit/return 1
]

strip-quotes: func [text [string!]][
	if all [
		(length? text) >= 2
		any [text/1 = #"^"" text/1 = #"'"]
		text/1 = last text
	][
		text: copy/part next text (length? text) - 2
	]
	text
]

resolve-source-path: func [
	raw [string! file!]
	/local text candidate
][
	text: strip-quotes to string! raw
	; clean-path resolves against the process current directory first.
	candidate: clean-path to-red-file to file! text
	if exists? candidate [return candidate]
	; Fall back to the process options path (boot cwd) for relative inputs.
	clean-path append copy system/options/path to-red-file to file! text
]

read-source-marker: func [
	source [file!]
	/local bin header
][
	; Only parse the first value. Full-file Red TRANSCODE rejects Red/System
	; sources that contain 64-bit hex integer literals (valid in R/S, not in Red).
	bin: read/binary source
	set/any 'header try [transcode/one bin]
	if error? :header [
		fail-command rejoin ["cannot transcode source header: " source " " mold header]
	]
	:header
]

compile-source: func [
	options [object!]
	/local source marker job frontend-result backend-result saved-verbosity build-prefix
][
	unless compiler-options/option-get options 'source [fail-command "missing source file"]
	source: resolve-source-path compiler-options/option-get options 'source
	unless exists? source [fail-command rejoin ["cannot access source file: " source]]

	marker: read-source-marker source
	unless any [marker = 'Red marker = red-system-marker][
		fail-command "source must start with a Red or Red/System header"
	]

	job: compiler-options/to-job options
	if error? :job [fail-command mold job]
	unless all [
		(compiler-system-job/job-get job 'OS) = 'Windows
		(compiler-system-job/job-get job 'format) = 'PE
		find [IA-32 X86-64] compiler-system-job/job-get job 'target
	][
		fail-command "bootstrap supports only Windows IA-32 or x86-64 PE targets"
	]
	if compiler-system-job/job-get job 'static-link? [fail-command "static linking is unavailable in the bootstrap compiler"]
	; Full runtime until Stage1 libRedRT defs path is verified.
	if none? compiler-system-job/job-get job 'dev-mode? [
		compiler-system-job/job-set job 'dev-mode? false
	]
	compiler-system-job/job-set job 'link? true
	; unicode? enables red/platform print hooks used by the Red runtime only.
	; Pure Red/System programs must keep the libc prin path (unicode? = no).
	compiler-system-job/job-set job 'unicode? (marker = 'Red)
	compiler-system-job/job-set job 'red-pass? (marker = 'Red)
	if compiler-options/option-get options 'dll? [compiler-system-job/job-set job 'type 'dll]
	compiler-system-job/job-set job 'compiler-version compiler-version
	compiler-system-job/job-set job 'compiler-build-date compiler-build-date
	compiler-system-job/job-set job 'compiler-git none
	build-prefix: compiler-system-job/job-get job 'build-prefix
	unless empty? build-prefix [make-dir/deep build-prefix]

	print ["Compiling" source "..."]
	either marker = red-system-marker [
		system-dialect/compile/options source job
	][
		frontend-result: compiler-frontend/compile source job
		print ["...frontend time    :" frontend-result/2]
		if compiler-system-job/job-get job 'red-only? [
			unless compiler-options/option-get options 'output [
				fail-command "--red-only requires -o output.reds"
			]
			write to file! compiler-options/option-get options 'output mold/only frontend-result/1
			write/binary to file! rejoin [
				compiler-options/option-get options 'output ".redbin"
			] frontend-result/3
			return none
		]
		saved-verbosity: compiler-system-job/job-get job 'verbosity
		compiler-system-job/job-set job 'verbosity (max 0 saved-verbosity - 3)
		system-dialect/compile/options/loaded source job frontend-result
		compiler-system-job/job-set job 'verbosity saved-verbosity
	]

	backend-result: system-dialect/last-result
	unless block? backend-result [fail-command "Red/System backend did not produce a result"]
	print [
		"...native time      :" backend-result/1
		"...link time        :" backend-result/2
		"...output file      :" backend-result/4
		"...output bytes     :" backend-result/3
	]
]

args: any [system/options/args []]
unless block? args [args: copy []]
options: compiler-options/parse-args args
if error? :options [fail-command mold options]
if compiler-options/option-get options 'help? [print-usage quit/return 0]
if compiler-options/option-get options 'version? [print bootstrap-version quit/return 0]
compile-source options
quit/return 0
