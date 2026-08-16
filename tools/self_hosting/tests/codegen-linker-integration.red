Red [
	Title: "Direct native codegen image to PE linker integration"
]

#include %../../../system/compiler-windows-common.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

emit: func [output [binary!] values [block!] /local value][
	foreach value values [append output int-to-bin/to-bin32 value]
]

system-dialect: context [
	compiler: context [
		quit-on-error: does [quit/return 1]
	]
]

; Independently constructed image for main -> identity 42.
artifact: make binary! 252
emit artifact [252 3 2 2 1 1 35 176 60 16]
emit artifact [0 8 41 19 32 0 16 0 0]
emit artifact [8 4 0 41 32 0 16 0 0]
emit artifact [12 12 24 11 1 1]
emit artifact [33]
append artifact to binary! "identitymainkernel32.dllExitProcess"
append/dup artifact 0 (176 - length? artifact)
append artifact #{554889E56A006A0068000000006A00B92A000000E81000000089C14883EC20FF150000000031C0C9C3}
append artifact #{554889E56A006A0068000000006A0089C8C9C3}
append/dup artifact 0 (252 - length? artifact)
unless (length? artifact) = 252 [fail "independent native image has the wrong size"]

root: clean-path to file! rejoin [system/options/path %../../../]
system/options/path: root
output: either all [block? system/options/args not empty? system/options/args][
	clean-path to-red-file to file! system/options/args/1
][
	clean-path to file! rejoin [root %build/self-hosting/compact-linker-parameter-i32.exe]
]
set [output-dir output-name] split-path output

base-job: compiler-system-job/new 'Windows-X86-64
unless object? base-job [fail "could not create the Windows x64 linker job"]
job-data: copy/deep body-of base-job
forall job-data [if lit-word? job-data/1 [job-data/1: to word! job-data/1]]
job: construct/with job-data linker/job-class
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

unless linker/load-codegen job artifact [fail linker/codegen-error]
linked: linker/build job
unless all [file? linked exists? linked][fail ["linker did not write output: " mold linked]]
unless linked = output [fail ["linker wrote an unexpected path: " linked]]
unless all [
	find job/sections 'import
	find job/sections 'idata
	not empty? job/sections/import/2
	not empty? job/sections/idata/2
][fail "ExitProcess reference did not produce PE import and IAT sections"]
if find job/sections 'reloc [
	fail "relocation-free image retained an empty PE base-relocation section"
]

status: call/wait to-local-file linked
unless status = 42 [fail ["linked executable returned " status " instead of 42"]]

print ["PASS: compact parameter image -> direct PE linker -> exit 42" linked]
