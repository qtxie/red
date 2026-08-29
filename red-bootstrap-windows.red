Red [
	Title: "Self-hosted Red compiler bootstrap"
	File:  %red-bootstrap-windows.red
	Config: [show: 'X86-64-only]
]

compiler-root: system/options/path
#include %compiler/resource-store.red

if value? 'toolchain-resource-index [
	compiler-resource-store/install
		toolchain-resource-index
		toolchain-resource-data
		toolchain-resource-manifest-sha256
]
; The core compiler does not load View, but it needs the datatype token to compile View targets.
unless value? 'event! [event!: make datatype! #get-definition TYPE_EVENT]

; Keep the canonical Windows compiler small, while allowing focused bootstrap
; wrappers to select another self-hosted backend.
#either config/show = 'X86-64-only [
	#include %system/compiler-windows-bootstrap.red
][
	#include %system/compiler.red
]

#include %compiler/modules.red
#include %compiler/version.red
#include %compiler/preprocessor.red
#include %compiler/extractor.red
#include %compiler/redbin.red
#include %compiler/crush.red
#include %compiler/frontend.red
#include %compiler/bootstrap-options.red
#if config/show = 'ARM64-Darwin-only [
	#include %system/formats/Mach-APP-sign.red
	#include %system/formats/Mach-APP.red
]

; Interpreted bootstrap follows Stage0's deep binding operation. The AOT source
; materializes this field through frontend.red's nested include instead.
if none? red/redbin [do bind load %compiler/redbin-emitter.red red]

; Keep collection enabled while the compiler builds its large intermediate graphs.
recycle/on
set-compiler-series-frame-max: routine [bytes [integer!]][memory/s-max: bytes]
set-compiler-series-frame-max 16777216

bootstrap-version: "0.6.6-selfhost.2"
red-system-marker: first [Red/System]

print-usage: does [
	print "Usage: red-bootstrap [-r] [-u] [-d] [-O0|-O1|-O2] [--dump-o2-ir file] [-n|--no-runtime] [--show-func-map] [-dlib] [-t target] [--red-only] [-o output] source.red|source.reds"
	print "       red-bootstrap --toolchain-info|--list-targets|--resource-manifest|--self-check"
]

fail-command: func [message][
	print ["*** Red command-line error:" message]
	quit/return 1
]

focused-target: #either config/show = 'X86-64-only ["Windows-X86-64"]["Darwin-ARM64"]

resource-count: does [
	either compiler-resource-store/installed? [
		divide length? compiler-resource-store/index 2
	][0]
]

print-toolchain-info: does [
	print ["name: red-toolchain"]
	print ["version:" bootstrap-version]
	print ["host:" focused-target]
	print ["targets:" focused-target]
	print ["standalone:" compiler-resource-store/installed?]
	print ["resources:" resource-count]
	print ["resource-manifest:" any [compiler-resource-store/manifest-sha256 "none"]]
]

join-file: func [base [file!] relative [file!]][append copy base relative]

libRedRT-target: func [job [object!] /local os cpu][
	os: compiler-system-job/job-get job 'OS
	cpu: compiler-system-job/job-get job 'target
	#either config/show = 'X86-64-only [
		either all [os = 'Windows cpu = 'X86-64]['Windows-X86-64-DLL][none]
	][
		either all [os = 'macOS cpu = 'ARM64]['Darwin-ARM64-SO][none]
	]
]

libRedRT-output-dir: func [job [object!] /local dir][
	dir: compiler-system-job/job-get job 'build-prefix
	dir: either empty? dir [system/options/path][clean-path dir]
	unless (last dir) = #"/" [append dir #"/"]
	dir
]

configure-libRedRT-path: func [dir [file!]][
	libRedRT/root-dir: dir
]

libRedRT-ready?: func [job [object!] /local dir extension][
	dir: libRedRT-output-dir job
	configure-libRedRT-path dir
	extension: #either config/show = 'X86-64-only [%.dll][%.dylib]
	all [
		exists? join-file dir to file! rejoin [form libRedRT/lib-file extension]
		exists? join-file dir libRedRT/include-file
		exists? join-file dir libRedRT/defs-file
	]
]

build-libRedRT: func [
	app-job [object!]
	/local target dir job source frontend-result backend-result saved-verbosity result
][
	target: libRedRT-target app-job
	unless target [
		fail-command rejoin [
			"no libRedRT target for "
			compiler-system-job/job-get app-job 'OS
			" " compiler-system-job/job-get app-job 'target
		]
	]
	dir: libRedRT-output-dir app-job
	make-dir/deep dir
	configure-libRedRT-path dir

	job: compiler-system-job/new target
	unless job [fail-command compiler-system-job/last-error/message]
	compiler-system-job/job-set job 'build-prefix dir
	compiler-system-job/job-set job 'build-basename libRedRT/lib-file
	compiler-system-job/job-set job 'type 'dll
	compiler-system-job/job-set job 'dev-mode? true
	compiler-system-job/job-set job 'libRedRT? true
	compiler-system-job/job-set job 'link? true
	compiler-system-job/job-set job 'unicode? true
	compiler-system-job/job-set job 'red-pass? true
	compiler-system-job/job-set job 'GUI-engine compiler-system-job/job-get app-job 'GUI-engine
	compiler-system-job/job-set job 'draw-engine compiler-system-job/job-get app-job 'draw-engine
	compiler-system-job/job-set job 'debug? compiler-system-job/job-get app-job 'debug?
	compiler-system-job/job-set job 'opt-level compiler-system-job/job-get app-job 'opt-level
	compiler-system-job/job-set job 'redbin-compress? compiler-system-job/job-get app-job 'redbin-compress?
	compiler-system-job/job-set job 'compiler-version compiler-version
	compiler-system-job/job-set job 'compiler-build-date now/utc
	compiler-system-job/job-set job 'compiler-git none
	compiler-system-job/normalize job

	; Keep the runtime module set identical to Stage0's libRedRT build.
	source: either compiler-system-job/job-get job 'GUI-engine [
		[[Needs: [View CSV JSON]]]
	][[[Needs: [CSV JSON]]]]

	print ["Compiling" join-file dir %libRedRT "..."]
	set/any 'result try [compiler-frontend/compile source job]
	if error? :result [fail-command rejoin ["libRedRT frontend failed: " mold result]]
	frontend-result: result
	saved-verbosity: compiler-system-job/job-get job 'verbosity
	compiler-system-job/job-set job 'verbosity (max 0 saved-verbosity - 3)
	set/any 'result try [
		system-dialect/compile/options/loaded libRedRT/lib-file job frontend-result
	]
	compiler-system-job/job-set job 'verbosity saved-verbosity
	if error? :result [fail-command rejoin ["libRedRT backend failed: " mold result]]
	backend-result: system-dialect/last-result
	unless all [
		block? backend-result
		file? backend-result/4
		exists? backend-result/4
	][fail-command #either config/show = 'X86-64-only [
		"libRedRT build produced no DLL"
	]["libRedRT build produced no dylib"]]
	configure-libRedRT-path dir
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
	/local source marker job frontend-result backend-result saved-verbosity build-prefix packager-name
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
	#either config/show = 'X86-64-only [
		unless all [
			(compiler-system-job/job-get job 'OS) = 'Windows
			(compiler-system-job/job-get job 'target) = 'X86-64
			(compiler-system-job/job-get job 'format) = 'PE
		][fail-command "this compiler supports only Windows-X86-64 PE targets"]
	][
		unless all [
			(compiler-system-job/job-get job 'OS) = 'macOS
			(compiler-system-job/job-get job 'target) = 'ARM64
			(compiler-system-job/job-get job 'format) = 'Mach-O
		][fail-command "this compiler supports only Darwin ARM64 Mach-O targets"]
	]
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
	compiler-system-job/job-set job 'compiler-build-date now/utc
	compiler-system-job/job-set job 'compiler-git none
	build-prefix: compiler-system-job/job-get job 'build-prefix
	unless empty? build-prefix [make-dir/deep build-prefix]
	if all [
		marker = 'Red
		compiler-system-job/job-get job 'dev-mode?
		not compiler-system-job/job-get job 'libRedRT?
		not libRedRT-ready? job
	][build-libRedRT job]
	#if config/show = 'ARM64-Darwin-only [
		if packager-name: compiler-system-job/job-get job 'packager [
			switch/default packager-name [
				Mach-APP [mach-app-packager/prepare job source]
			][fail-command rejoin ["unsupported packager: " packager-name]]
		]
	]

	print ["Compiling" source "..."]
	either marker = red-system-marker [
		phase-timer/begin 'red-system-total
		system-dialect/compile/options source job
		phase-timer/finish 'red-system-total
	][
		phase-timer/begin 'frontend
		frontend-result: compiler-frontend/compile source job
		phase-timer/finish 'frontend
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
		phase-timer/begin 'backend-total
		system-dialect/compile/options/loaded source job frontend-result
		phase-timer/finish 'backend-total
		compiler-system-job/job-set job 'verbosity saved-verbosity
	]

	backend-result: system-dialect/last-result
	unless block? backend-result [fail-command "Red/System backend did not produce a result"]
	#if config/show = 'ARM64-Darwin-only [
		if packager-name: compiler-system-job/job-get job 'packager [
			switch/default packager-name [
				Mach-APP [
					poke backend-result 4 mach-app-packager/process job source backend-result/4
				]
			][fail-command rejoin ["unsupported packager: " packager-name]]
		]
	]
	print [
		"...native time      :" backend-result/1
		"...link time        :" backend-result/2
		"...output file      :" backend-result/4
		"...output bytes     :" backend-result/3
	]
]

args: any [system/options/args []]
unless block? args [args: copy []]
compiler-profile-path: get-env "RED_COMPILER_PROFILE"
phase-timer/reset
phase-timer/active?: string? compiler-profile-path
phase-timer/begin 'compiler-total
options: compiler-options/parse-args args
if error? :options [fail-command mold options]
if compiler-options/option-get options 'help? [print-usage quit/return 0]
if compiler-options/option-get options 'version? [print bootstrap-version quit/return 0]
if compiler-options/option-get options 'toolchain-info? [print-toolchain-info quit/return 0]
if compiler-options/option-get options 'list-targets? [print focused-target quit/return 0]
if compiler-options/option-get options 'resource-manifest? [
	print any [compiler-resource-store/manifest-sha256 "none"]
	quit/return either compiler-resource-store/installed? [0][1]
]
if compiler-options/option-get options 'self-check? [
	unless compiler-resource-store/installed? [fail-command "resource archive is not installed"]
	print ["resource-self-check: ok resources:" compiler-resource-store/self-check]
	quit/return 0
]
compile-source options
phase-timer/finish 'compiler-total
if phase-timer/active? [
	phase-timer/report
	print [
		"...profile gc      : cycles:" system/state/GC/series-cycles
		"nodes:" system/state/GC/nodes-cycles
		"memory:" stats
	]
	write to file! compiler-profile-path mold/only phase-timer/snapshot
]
quit/return 0
