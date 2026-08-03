Red [
	Title: "Focused ARM Red/System cross-compiler driver"
	File:  %compile-arm-red-system.red
	Config: [show: 'ARM-ELF-only]
]

#include %../../system/compiler.red
#include %../../compiler/bootstrap-options.red

; compiler-core shares these hooks with the Red frontend. Red/System jobs do
; not call them, but native compilation still resolves the words.
red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

recycle/on

fail-command: func [message][
	print ["*** ARM compiler error:" message]
	quit/return 1
]

args: any [system/options/args copy []]
unless block? args [args: copy []]
unless (length? args) = 3 [
	print "Usage: compile-arm-red-system Linux-ARM64|RPi source.reds output"
	quit/return 2
]

target: to string! args/1
unless find ["Linux-ARM64" "RPi"] target [
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

system/options/path: root-dir
options: compiler-options/make-options
compiler-options/option-set options 'target target
compiler-options/option-set options 'source to string! source
compiler-options/option-set options 'output to string! output
compiler-options/option-set options 'release? true
compiler-options/option-set options 'debug? true
compiler-options/option-set options 'verbose 3
if (suffix? output) = %.so [compiler-options/option-set options 'dll? true]

job: compiler-options/to-job options
if error? :job [fail-command mold job]
compiler-system-job/job-set job 'link? true

print ["Compiling" source "for" target]
set/any 'result try [system-dialect/compile/options source job]
if error? :result [fail-command mold result]

result: system-dialect/last-result
unless block? result [fail-command "Red/System backend did not produce a result"]
print ["output:" result/4 "bytes:" result/3]
quit/return 0
