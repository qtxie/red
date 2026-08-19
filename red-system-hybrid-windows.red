Red [
	Title: "Windows x64 hybrid Red/System compiler"
	File:  %red-system-hybrid-windows.red
]

#include %system/compiler-windows-hybrid-bootstrap.red
#include %compiler/bootstrap-options.red

recycle/on

compiler-version: "0.1.0"

print-usage: does [
	print "Usage: red-system-hybrid-windows [-n] [-O0|-O2] [-dlib] -t Windows-X86-64 [-o output] source.reds"
]

fail-command: func [message][
	print ["*** Hybrid compiler error:" message]
	quit/return 1
]

compile-source: func [options [object!] /local source job prefix result][
	unless source: compiler-options/option-get options 'source [
		fail-command "missing Red/System source"
	]
	source: clean-path to-red-file to file! source
	compiler-options/option-set options 'source to string! source
	job: compiler-options/to-job options
	if error? :job [fail-command mold job]
	compiler-system-job/job-set job 'backend-mode 'rsir
	compiler-system-job/job-set job 'link? true

	prefix: compiler-system-job/job-get job 'build-prefix
	unless empty? prefix [make-dir/deep prefix]

	system-dialect/compile/options source job
	result: system-dialect/last-result
	unless all [
		block? result
		(length? result) = 4
		file? result/4
		exists? result/4
	][
		fail-command "compiler did not produce an output file"
	]
	print [
		"...output file      :" result/4
		"...output file size :" result/3 "bytes"
	]
]

args: any [system/options/args copy []]
unless block? args [args: copy []]
options: compiler-options/parse-args/hybrid args
if error? :options [fail-command mold options]
if compiler-options/option-get options 'help? [print-usage quit/return 0]
if compiler-options/option-get options 'version? [print compiler-version quit/return 0]
compile-source options
quit/return 0
