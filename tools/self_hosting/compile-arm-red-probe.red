Red [
	Title: "Single-source ARM64 cross-compile probe (debugging AV)"
	File:  %compile-arm-red-probe.red
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

recycle/on

join-file: func [base [file! string!] relative [file! string!]][append copy base relative]

args: any [system/options/args copy []]
unless block? args [args: copy []]
if (length? args) < 3 [
	print "Usage: compile-arm-red-probe Linux-ARM64 source.reds output"
	quit/return 2
]
target: to string! args/1
source: to file! args/2
output: to file! args/3
root-dir: system/options/path
unless exists? join-file root-dir %system/compiler.red [
	root-dir: clean-path join-file system/options/path %../../
]
system/options/path: root-dir
source: clean-path join-file root-dir source
output: clean-path join-file root-dir output

options: compiler-options/make-options
compiler-options/option-set options 'target target
compiler-options/option-set options 'source to string! source
compiler-options/option-set options 'output to string! output
compiler-options/option-set options 'release? true
compiler-options/option-set options 'verbose 0
if (suffix? output) = %.so [compiler-options/option-set options 'dll? true]
job: compiler-options/to-job options
if error? :job [
	print ["job setup failed:" mold job]
	quit/return 1
]
compiler-system-job/job-set job 'link? true
print ["Compiling" source "for" target "->" output]
set/any 'result try [system-dialect/compile/options source job]
if error? :result [
	print ["compile failed:" mold result]
	quit/return 1
]
result: system-dialect/last-result
unless all [block? result file? result/4 exists? result/4][
	print ["no output produced:" mold result]
	quit/return 1
]
print ["output:" result/4 "bytes:" result/3]
quit/return 0
