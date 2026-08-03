Red [
	Title: "Darwin ARM64 Red cross-suite builder"
	File:  %build-darwin-arm64-red-tests.red
	Config: [show: 'ARM64-Darwin-only]
]

compiler-root: clean-path append copy system/options/path %../../
system/options/path: compiler-root
unless value? 'event! [event!: make datatype! #get-definition TYPE_EVENT]

#include %system/compiler.red
#include %compiler/modules.red
#include %compiler/version.red
#include %compiler/preprocessor.red
#include %compiler/extractor.red
#include %compiler/redbin.red
#include %compiler/crush.red
#include %compiler/frontend.red
#include %compiler/bootstrap-options.red

if none? red/redbin [do bind load %compiler/redbin-emitter.red red]

; The installed interpreter's collector faults during large compiler jobs.
; The generated macOS runtimes retain their normal GC configuration.
recycle/off

darwin-red-suite-builder: context [
	root-dir: source-dir: output-dir: none
	compiled: 0
	resume?: false

	join-file: func [base [file!] relative [file!]][append copy base relative]

	fail: func [message][
		print ["*** Darwin Red suite builder error:" message]
		quit/return 1
	]

	clean-output: func [dir [file!] /local entry path][
		make-dir/deep dir
		foreach entry read dir [
			path: join-file dir entry
			if dir? path [fail rejoin ["unexpected directory in suite output: " path]]
			delete path
		]
	]

	compile-source: func [
		source [file!]
		output [file!]
		/local options job frontend-result backend-result saved-verbosity result
	][
		if all [resume? exists? output][
			print ["reuse" output]
			return output
		]
		print ["compile" source "->" output]
		options: compiler-options/make-options
		compiler-options/option-set options 'target "Darwin-ARM64"
		compiler-options/option-set options 'source to string! source
		compiler-options/option-set options 'output to string! output
		compiler-options/option-set options 'release? true
		compiler-options/option-set options 'verbose 0
		job: compiler-options/to-job options
		if error? :job [fail rejoin ["job setup failed: " mold job]]
		compiler-system-job/job-set job 'dev-mode? false
		compiler-system-job/job-set job 'link? true
		compiler-system-job/job-set job 'unicode? true
		compiler-system-job/job-set job 'red-pass? true
		compiler-system-job/job-set job 'compiler-version compiler-version
		compiler-system-job/job-set job 'compiler-build-date compiler-build-date
		compiler-system-job/job-set job 'compiler-git none

		set/any 'result try [compiler-frontend/compile source job]
		if error? :result [fail rejoin ["frontend failed for " source ": " mold result]]
		frontend-result: result
		saved-verbosity: compiler-system-job/job-get job 'verbosity
		compiler-system-job/job-set job 'verbosity (max 0 saved-verbosity - 3)
		set/any 'result try [
			system-dialect/compile/options/loaded source job frontend-result
		]
		compiler-system-job/job-set job 'verbosity saved-verbosity
		if error? :result [fail rejoin ["backend failed for " source ": " mold result]]
		backend-result: system-dialect/last-result
		unless all [
			block? backend-result file? backend-result/4 exists? backend-result/4
		][
			fail rejoin ["compiler produced no output for " source]
		]
		compiled: compiled + 1
		backend-result/4
	]

	run: func [args [block! none!] /local sources relative source name output][
		unless all [block? args find [1 2] (length? args)][
			print "Usage: build-darwin-arm64-red-tests output-directory [--resume]"
			quit/return 2
		]
		resume?: all [(length? args) = 2 args/2 = "--resume"]
		if all [(length? args) = 2 not resume?][fail "second argument must be --resume"]

		root-dir: clean-path system/options/path
		unless exists? join-file root-dir %system/compiler.red [
			root-dir: clean-path join-file system/options/path %../../
		]
		unless exists? join-file root-dir %system/compiler.red [
			fail rejoin ["cannot locate repository root from: " system/options/path]
		]
		system/options/path: root-dir
		source-dir: join-file root-dir %tests/source/units/auto-tests/
		output-dir: clean-path join-file root-dir to-red-file to file! args/1
		unless (last output-dir) = #"/" [append output-dir #"/"]
		either resume? [make-dir/deep output-dir][clean-output output-dir]

		sources: [%run-all-comp1.red %run-all-comp2.red %run-all-interp.red]
		foreach relative sources [
			source: join-file source-dir relative
			name: to string! relative
			clear find/last name ".red"
			output: join-file output-dir to file! name
			compile-source source output
		]

		print [
			"Darwin ARM64 Red suite build: compiled:" compiled
			"output:" output-dir
		]
		quit/return 0
	]
]

darwin-red-suite-builder/run system/options/args
