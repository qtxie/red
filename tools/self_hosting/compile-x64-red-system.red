Red [
	Title: "Focused x64 Red/System source compiler driver"
	File:  %compile-x64-red-system.red
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

recycle/on

fail-command: func [message][
	print ["*** x64 compiler error:" message]
	quit/return 1
]

args: any [system/options/args copy []]
unless find [3 4 5] length? args [
	print "Usage: compile-x64-red-system Windows-X86-64|Linux-X86-64 source.reds output [ir-dump|O0|O1|O2] [O0|O1|O2]"
	quit/return 2
]

target: to string! args/1
unless find ["Windows-X86-64" "Linux-X86-64"] target [
	fail-command rejoin ["unsupported target: " target]
]

root-dir: clean-path system/options/path
unless exists? join root-dir %system/compiler.red [
	root-dir: clean-path join system/options/path %../../
]
unless exists? join root-dir %system/compiler.red [
	fail-command rejoin ["cannot locate repository root from: " system/options/path]
]
source: clean-path join root-dir to-red-file to file! args/2
output: clean-path join root-dir to-red-file to file! args/3
unless exists? source [fail-command rejoin ["cannot access source file: " source]]

optimization: "O2"
dump-path: none
if (length? args) >= 4 [
	value: uppercase form args/4
	either find ["O0" "O1" "O2"] value [
		optimization: value
	][
		dump-path: to string! to-red-file to file! args/4
	]
]
if (length? args) = 5 [optimization: uppercase form args/5]
unless find ["O0" "O1" "O2"] optimization [
	fail-command rejoin ["unsupported optimization level: " optimization]
]
optimization-level: select [
	"O0" 0
	"O1" 1
	"O2" 2
] optimization
unless integer? optimization-level [
	fail-command rejoin ["cannot map optimization level: " optimization]
]

system/options/path: root-dir
options: compiler-options/make-options
compiler-options/option-set options 'target target
compiler-options/option-set options 'source to string! source
compiler-options/option-set options 'output to string! output
compiler-options/option-set options 'opt-level optimization-level
compiler-options/option-set options 'release? false
compiler-options/option-set options 'debug? false
compiler-options/option-set options 'verbose 0
if dump-path [compiler-options/option-set options 'o2-ir-dump dump-path]

job: compiler-options/to-job options
if error? :job [fail-command mold job]
compiler-system-job/job-set job 'link? true

print ["Compiling" source "for" target optimization "(development mode)"]
set/any 'result try [system-dialect/compile/options source job]
if error? :result [fail-command mold result]

result: system-dialect/last-result
unless all [block? result file? result/4 exists? result/4][
	fail-command rejoin ["no output produced: " mold result]
]
print ["output:" result/4 "bytes:" result/3]
quit/return 0
