Red [
	Title:   "Standalone hybrid Red toolchain hermetic test"
	File:    %test-red-toolchain-hermetic.red
	Purpose: {
		Copies a standalone hybrid toolchain into a scratch directory and drives
		it there, with nothing but the fixtures in fixtures/toolchain: release
		and -O2 Red builds, embedded modules, Red/System, a development build
		linked against libRedRT, a Red/System shared library whose export is
		called back through a loader the toolchain itself compiles, and a native
		View program. Every image is checked by reading it, no compilation may
		mention the repository, and the toolchain must never need anything
		outside the scratch directory.

		Replaces test-windows-hybrid-toolchain.ps1: no PowerShell, no dumpbin,
		and no C# P/Invoke loader.
	}
	Usage: {
		console tools/self_hosting/test-red-toolchain-hermetic.red [options]

		--toolchain <exe>   standalone toolchain to test (required)
		--root <dir>        repository root (default: two levels above this file)
		--target <name>     target the fixtures are compiled for (default: host)
		--keep              keep the scratch directory when the test fails
		--no-view           skip the native View fixture
		-h --help           print this text
	}
	Notes: {
		The scratch directory becomes the working directory as soon as it is
		created, so every path handed to the toolchain is relative. That is what
		makes "the repository path never appears in the output" a real check
		instead of a tautology.

		The suite is shaped by the Windows standalone toolchain: libRedRT.dll,
		the -DLL target and the View backend. It refuses any other target rather
		than half-running.
	}
]

;-- ------------------------------------------------- shared toolchain helpers --

#include %toolchain-common.red
error-prefix: "Toolchain test error"

;-- ---------------------------------------------------------------- options --

options: context [
	toolchain: none
	root: none
	target: none
	keep: no
	no-view: no
	help: no
]

parse-options: func [args [block!] /local arg value][
	while [not tail? args][
		arg: first args
		args: next args
		case [
			find ["-h" "--help"] arg [options/help: yes  args: tail args]
			true [
				require all [#"-" = pick arg 1  #"-" = pick arg 2] ["unexpected argument:" arg]
				value: to word! skip arg 2
				case [
					find [toolchain root target] value [
						require not tail? args [arg "needs a value"]
						set in options value first args
						args: next args
					]
					find [keep no-view] value [set in options value yes]
					true [fail ["unknown option:" arg]]
				]
			]
		]
	]
]

print-usage: has [spec header][
	print "Test a standalone hybrid Red toolchain in a scratch directory."
	spec: attempt [load/header script-file]
	header: either all [block? spec  block? spec/2] [spec/2][[]]
	print any [
		attempt [select header to-set-word 'usage]
		"(the Usage: field of this script's header)"
	]
]

;-- ------------------------------------------------------------------- paths --

script-file: does [
	rejoin [
		script-dir
		any [
			attempt [second split-path system/options/script]
			%test-red-toolchain-hermetic.red
		]
	]
]

;-- ----------------------------------------------------------------- scratch --

temp-root: does [
	dirize to-red-file to file! any [
		get-env "RED_TEST_TMPDIR"
		if system/platform = 'Windows [any [get-env "TEMP"  get-env "TMP"]]
		get-env "TMPDIR"
		either system/platform = 'Windows [to file! "C:/Windows/Temp"][%/tmp]
	]
]

work: none
toolchain: none
target: none
root-text: none
root-local: none

;-- `random` is deterministic without a seed, so an unseeded name would be the
;-- same on every run and two runs would share a scratch directory.
scratch-name: has [text][
	random/seed now/precise
	text: form now/precise
	foreach separator [":" "/" " " "+"][replace/all text separator ""]
	rejoin ["red-toolchain-hermetic-" text "-" random FFFFFFh]
]

;-- Red has no recursive delete: `delete` only takes files and empty folders.
delete-tree: func [dir [file!] /local entry][
	foreach entry read dir [
		entry: dir/:entry
		either dir? entry [delete-tree dirize entry][delete entry]
	]
	delete dir
]

discard: does [
	unless work [exit]
	;-- the scratch directory is the working directory, and Windows will not
	;-- delete the directory a process is sitting in.
	change-dir root
	delete-tree work
	work: none
]

prepare-scratch: has [fixtures copied][
	work: dirize rejoin [temp-root scratch-name]
	require not exists? work ["scratch directory already exists:" work]
	make-dir/deep work
	fixtures: dirize rejoin [root "tools/self_hosting/fixtures/toolchain"]
	require exists? fixtures ["fixtures not found:" fixtures]
	copied: rejoin [work "red-toolchain" executable-suffix target]
	write/binary copied read/binary toolchain
	foreach file read fixtures [write/binary work/:file read/binary fixtures/:file]
	toolchain: copied
	log-dir: dirize rejoin [work "logs/"]
	make-dir/deep log-dir
	change-dir work					;-- from here on, every path is relative
]

;-- ------------------------------------------------------------------ checks --

assert-marker: func [output [string!] marker [string!] name [string!] /local lines count][
	lines: copy []
	foreach line split output "^/" [unless empty? line: trim-eol line [append lines line]]
	count: 0
	foreach line lines [if line = marker [count: count + 1]]
	require all [count = 1  (last lines) = marker] [			;-- `=` binds tighter than `last`
		name "produced unexpected output^/--- output ---^/" output
	]
]

compile-fixture: func [name [string!] args [block!] /local result output][
	result: run-checked rejoin [name "-compile"] toolchain args
	output: rejoin [result/2 result/3]
	require all [not find output root-text  not find output root-local] [
		name "compilation exposed the repository path^/--- output ---^/" output
	]
	output
]

run-fixture: func [name [string!] exe [file!] /local result][
	result: run-checked rejoin [name "-run"] exe []
	rejoin [result/2 result/3]
]

check-fixture: func [name [string!] args [block!] image [file!] marker [string!]][
	compile-fixture name args
	check-image image target
	assert-marker (run-fixture name image) marker rejoin [name " fixture"]
]

;-- -------------------------------------------------------------------- test --

hermetic: func [/local result resources exports marker][
	parse-options any [system/options/args copy []]
	if options/help [print-usage  quit/return 0]
	on-fail: [
		either options/keep [
			print ["preserved failing test directory:" work]
		][discard]
	]

	root: any [
		if options/root [dirize resolve-in script-dir options/root]
		resolve-root
	]
	require exists? root/compiler/bootstrap-boot.red ["not a Red repository root:" root]

	toolchain: attempt [resolve-in root options/toolchain]
	require toolchain "--toolchain is required"
	require exists? toolchain ["toolchain not found:" toolchain]

	target: any [options/target  host-target]
	require find target "Windows" [
		"this suite is shaped by the Windows standalone toolchain, not" target
	]
	root-text: form root
	root-local: to-local-file root

	prepare-scratch
	print ["toolchain:" toolchain]
	print ["scratch:" work]

	result: run-checked "self-check" toolchain ["--self-check"]
	resources: resource-count result/2
	result: run-checked "toolchain-info" toolchain ["--toolchain-info"]
	require-match result/2 "backend: hybrid-rsir" "the toolchain is not hybrid"
	require-match result/2 "standalone: true" "the toolchain is not standalone"

	check-fixture "hello-release" reduce [
		"-r" "-t" target "-o" "hello-release.exe" "hello.red"
	] %hello-release.exe "RED-TOOLCHAIN-HERMETIC-OK"

	check-fixture "hello-o2" reduce [
		"-r" "-O2" "-t" target "-o" "hello-o2.exe" "hello.red"
	] %hello-o2.exe "RED-TOOLCHAIN-HERMETIC-OK"

	check-fixture "modules" reduce [
		"-r" "-t" target "-o" "modules.exe" "modules.red"
	] %modules.exe "RED-TOOLCHAIN-MODULES-OK"

	check-fixture "hello-red-system" reduce [
		"-r" "-t" target "-o" "hello-red-system.exe" "hello.reds"
	] %hello-red-system.exe "RED-TOOLCHAIN-REDS-OK"

	;-- a development build keeps the Red runtime in libRedRT.dll
	compile-fixture "hello-development" reduce [
		"-t" target "-o" "hello-development.exe" "hello.red"
	]
	foreach file reduce [
		%hello-development.exe %libRedRT.dll %libRedRT-include.red %libRedRT-defs.red
	][
		require exists? file ["development compilation did not produce" file]
	]
	check-image/runtime %hello-development.exe target
	check-image/runtime %libRedRT.dll target
	require find pe-imports read/binary %hello-development.exe "LIBREDRT.DLL" [
		"development Red executable does not import libRedRT.dll"
	]
	assert-marker (
		run-fixture "hello-development" %hello-development.exe
	) "RED-TOOLCHAIN-HERMETIC-OK" "development Red fixture"

	;-- a Red/System shared library, called back through its own export
	compile-fixture "toolchain-library" reduce [
		"-r" "-dlib" "-t" rejoin [target "-DLL"] "-o" "toolchain-library.dll" "library.reds"
	]
	check-image %toolchain-library.dll target
	exports: pe-exports read/binary %toolchain-library.dll
	require find exports "TOOLCHAIN-ANSWER" [
		"Red/System DLL does not export toolchain-answer^/exports:"
		form exports
	]
	check-fixture "library-loader" reduce [
		"-r" "-t" target "-o" "library-loader.exe" "library-loader.reds"
	] %library-loader.exe "42"

	unless options/no-view [
		compile-fixture "view" reduce ["-r" "-t" target "-o" "view.exe" "view.red"]
		check-image %view.exe target
		result: run-fixture "view" %view.exe
		marker: %red-toolchain-view.ok
		require all [exists? marker  "RED-TOOLCHAIN-VIEW-OK" = trim-eol read marker] [
			"View fixture did not write" marker
		]
		require find result "RED-TOOLCHAIN-VIEW-OK" [
			"View fixture produced unexpected output^/--- output ---^/" result
		]
	]

	print ["Hermetic test passed:" resources "resources," target]
	discard
	quit/return 0
]

;-- An uncaught script error leaves the console exit status at 0, which would
;-- pass CI, so report it and fail.
either error? result: try [hermetic][
	print ["*** Toolchain test error:" form result]
	if on-fail [do on-fail]
	quit/return 1
][]
