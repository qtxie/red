Red [
	Title: "PE empty import and relocation section regression"
]

#include %../../../system/compiler-windows-bootstrap.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

root: clean-path to file! rejoin [system/options/path %../../../]
system/options/path: root
output: clean-path to file! rejoin [root %build/self-hosting/pe-empty-sections.exe]
set [output-dir output-name] split-path output

base-job: compiler-system-job/new 'Windows-X86-64
unless object? base-job [fail "could not create the Windows x64 linker job"]
job: system-dialect/make-job base-job %pe-empty-sections.reds
compiler-system-job/job-set job 'link? true
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'PIC? false
compiler-system-job/job-set job 'PIE? false
compiler-system-job/job-set job 'static-link? false
compiler-system-job/job-set job 'red-pass? false
compiler-system-job/job-set job 'libRed? false
compiler-system-job/job-set job 'libRedRT? false
compiler-system-job/job-set job 'libRedRT-update? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename output-name
compiler-system-job/job-set job 'build-suffix none
compiler-system-job/job-set job 'verbosity 0

code: #{554889E56A006A0068000000006A00C9C3}
data: make binary! 16
append/dup data 0 16
imports: make block! 0
job/sections: reduce [
	'code reduce ['- code]
	'data reduce ['- data]
	'import reduce ['- '- imports]
]
job/symbols: make hash! [entry [native 1 []]]
job/debug-info: none

linked: linker/build job
unless all [file? linked linked = output exists? linked][
	fail ["linker did not write the empty-section probe: " mold linked]
]
foreach section [import idata reloc][
	if find job/sections section [
		fail ["empty PE section survived layout normalization: " section]
	]
]
unless job/sections/1 = 'code [fail "PE code section order changed"]
unless job/sections/3 = 'data [fail "PE data section order changed"]
unless (length? job/sections) = 4 [fail "PE emitted an unexpected section"]

delete linked
print "PASS: PE omits empty import, IAT, and base-relocation sections"
