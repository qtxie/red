Red [
	Title: "Self-hosted Red compiler bootstrap"
	File:  %red-bootstrap-windows.red
	Config: [show: 'X86-64-only]
]

compiler-root: system/options/path
; The core compiler does not load View, but it needs the datatype token to compile View targets.
unless value? 'event! [event!: make datatype! #get-definition TYPE_EVENT]

; Select exactly one backend closure at preprocess time. The hybrid entry must
; not include the legacy emitter or machine IR even as unreachable source.
#either config/show = 'X86-64-Hybrid-only [
	#include %system/compiler-windows-hybrid-bootstrap.red
][
	; Keep the normal Windows bootstrap on its small PE-only closure. The focused
	; Linux x64 wrapper selects the ELF compiler and static linker instead.
	#either config/show = 'X86-64-ELF-only [
		#include %system/compiler.red
	][
		#include %system/compiler-windows-bootstrap.red
	]
]

#include %compiler/modules.red
#include %compiler/version.red
#include %compiler/preprocessor.red
#include %compiler/extractor.red
#include %compiler/redbin.red
#include %compiler/crush.red
#include %compiler/frontend.red
#include %compiler/bootstrap-options.red
#include %compiler/saved-frontend.red

; Interpreted bootstrap follows Stage0's deep binding operation. The AOT source
; materializes this field through frontend.red's nested include instead.
if none? red/redbin [do bind load %compiler/redbin-emitter.red red]

; Keep collection enabled while the compiler builds its large intermediate graphs.
recycle/on

bootstrap-version: "0.6.6-selfhost.2"
red-system-marker: first [Red/System]

print-usage: does [
	#either config/show = 'X86-64-Hybrid-only [
		print "Usage: red-bootstrap [-r] [-u] [-d] [-n] [-O0|-O2] [-dlib] [-t Windows-X86-64] [--red-only|--loaded-red output.reds] [-o output] source.red|source.reds"
	][
		print "Usage: red-bootstrap [-r] [-u] [-d] [-n] [-O0|-O1|-O2] [--dump-o2-ir file] [-dlib] [-t target] [--red-only|--loaded-red output.reds] [-o output] source.red|source.reds"
	]
]

fail-command: func [message][
	print ["*** Red command-line error:" message]
	quit/return 1
]

configure-backend-mode: func [job [object!]][
	#either config/show = 'X86-64-Hybrid-only [
		compiler-system-job/job-set job 'backend-mode 'rsir
	][none]
]

join-file: func [base [file!] relative [file!]][append copy base relative]

libRedRT-target: func [job [object!]][
	case [
		all [
			(compiler-system-job/job-get job 'OS) = 'Windows
			(compiler-system-job/job-get job 'target) = 'X86-64
		]['Windows-X86-64-DLL]
		all [
			(compiler-system-job/job-get job 'OS) = 'Linux
			(compiler-system-job/job-get job 'target) = 'X86-64
		]['Linux-X86-64-SO]
		true [none]
	]
]

libRedRT-extension: func [job [object!]][
	switch/default compiler-system-job/job-get job 'format [
		PE [%.dll]
		ELF [%.so]
		Mach-O [%.dylib]
	][%.dll]
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
	extension: libRedRT-extension job
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
	configure-backend-mode job
	compiler-system-job/job-set job 'build-prefix dir
	compiler-system-job/job-set job 'build-basename libRedRT/lib-file
	compiler-system-job/job-set job 'type 'dll
	compiler-system-job/job-set job 'dev-mode? true
	compiler-system-job/job-set job 'libRedRT? true
	compiler-system-job/job-set job 'link? true
	compiler-system-job/job-set job 'unicode? true
	compiler-system-job/job-set job 'red-pass? true
	compiler-system-job/job-set job 'sub-system 'Console
	compiler-system-job/job-set job 'GUI-engine none
	compiler-system-job/job-set job 'draw-engine none
	compiler-system-job/job-set job 'debug? compiler-system-job/job-get app-job 'debug?
	compiler-system-job/job-set job 'opt-level compiler-system-job/job-get app-job 'opt-level
	compiler-system-job/job-set job 'redbin-compress? compiler-system-job/job-get app-job 'redbin-compress?
	compiler-system-job/job-set job 'compiler-version compiler-version
	compiler-system-job/job-set job 'compiler-build-date compiler-build-date
	compiler-system-job/job-set job 'compiler-git none
	compiler-system-job/normalize job
	; Development applications import environment functions from this runtime.
	; Keep their bodies so reflection has the same semantics as release builds.
	compiler-system-job/job-set job 'red-store-bodies? true

	; The x64 bootstrap compiler uses a headless core runtime. Optional modules
	; belong to applications, not to the compiler's development runtime.
	source: [[]]

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
	][fail-command "libRedRT build produced no shared library"]
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
	/local source marker job frontend-result backend-result saved-verbosity build-prefix
		loaded-red loaded-path saved-output
][
	unless compiler-options/option-get options 'source [fail-command "missing source file"]
	source: resolve-source-path compiler-options/option-get options 'source
	unless exists? source [fail-command rejoin ["cannot access source file: " source]]

	marker: read-source-marker source
	unless any [marker = 'Red marker = red-system-marker][
		fail-command "source must start with a Red or Red/System header"
	]
	loaded-red: compiler-options/option-get options 'loaded-red
	if all [loaded-red compiler-options/option-get options 'red-only?][
		fail-command "--loaded-red and --red-only are mutually exclusive"
	]
	if all [loaded-red marker <> 'Red][
		fail-command "--loaded-red requires an original Red source file"
	]

	job: compiler-options/to-job options
	if error? :job [fail-command mold job]
	configure-backend-mode job
	#either config/show = 'X86-64-ELF-only [
		unless all [
			(compiler-system-job/job-get job 'OS) = 'Linux
			(compiler-system-job/job-get job 'target) = 'X86-64
			(compiler-system-job/job-get job 'format) = 'ELF
		][fail-command "this compiler supports only Linux-X86-64 ELF targets"]
	][
		unless all [
			(compiler-system-job/job-get job 'OS) = 'Windows
			(compiler-system-job/job-get job 'target) = 'X86-64
			(compiler-system-job/job-get job 'format) = 'PE
		][fail-command "this compiler supports only Windows-X86-64 PE targets"]
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
	compiler-system-job/job-set job 'compiler-build-date compiler-build-date
	compiler-system-job/job-set job 'compiler-git none
	build-prefix: compiler-system-job/job-get job 'build-prefix
	unless empty? build-prefix [make-dir/deep build-prefix]
	if all [
		marker = 'Red
		compiler-system-job/job-get job 'dev-mode?
		not compiler-system-job/job-get job 'libRedRT?
		not libRedRT-ready? job
	][build-libRedRT job]

	print ["Compiling" source "..."]
	either marker = red-system-marker [
		if loaded-red [fail-command "--loaded-red cannot compile Red/System input"]
		phase-timer/begin 'red-system-total
		system-dialect/compile/options source job
		phase-timer/finish 'red-system-total
	][
		either loaded-red [
			loaded-path: resolve-source-path loaded-red
			frontend-result: compiler-saved-frontend/load-artifacts
				loaded-path source compiler-system-job/job-get job 'config-name
			unless block? frontend-result [
				fail-command compiler-saved-frontend/last-error/message
			]
			print ["...frontend cache   :" loaded-path]
		][
			phase-timer/begin 'frontend
			frontend-result: compiler-frontend/compile source job
			phase-timer/finish 'frontend
			print ["...frontend time    :" frontend-result/2]
			if compiler-system-job/job-get job 'red-only? [
				unless compiler-options/option-get options 'output [
					fail-command "--red-only requires -o output.reds"
				]
				saved-output: to file! compiler-options/option-get options 'output
				unless compiler-saved-frontend/write-artifacts
					saved-output source frontend-result/1 frontend-result/3
					frontend-result/4 compiler-system-job/job-get job 'config-name
				[
					fail-command compiler-saved-frontend/last-error/message
				]
				return none
			]
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
#either config/show = 'X86-64-Hybrid-only [
	options: compiler-options/parse-args/hybrid args
][
	options: compiler-options/parse-args args
]
if error? :options [fail-command mold options]
if compiler-options/option-get options 'help? [print-usage quit/return 0]
if compiler-options/option-get options 'version? [print bootstrap-version quit/return 0]
compile-source options
phase-timer/finish 'compiler-total
if phase-timer/active? [
	phase-timer/report
	print [
		"...profile gc      : cycles:" system/state/GC/series-cycles
		"nodes:" system/state/GC/nodes-cycles
		"last-pinned-frames:" system/state/GC/pinned-frames
		"last-pinned-bytes:" system/state/GC/pinned-bytes
		"memory:" stats
	]
	write to file! compiler-profile-path mold/only phase-timer/snapshot
]
quit/return 0
