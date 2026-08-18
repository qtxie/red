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

; Independently constructed image for main -> answer and answer: 42.
artifact: make binary! 316
emit artifact [316 3 2 2 1 2 41 240 54 20 1 0 0]
emit artifact [0 8 35 19 32 0 16 0 0]
emit artifact [8 4 0 35 32 0 16 0 0]
emit artifact [12 6 16 4 1 1 0]
emit artifact [18 12 30 11 2 1]
emit artifact [17 27]
append artifact to binary! "identitymainanswerkernel32.dllExitProcess"
append/dup artifact 0 (240 - length? artifact)
append artifact #{554889E56A006A0068000000006A008B0D000000004883EC20FF150000000031C0C9C3}
append artifact #{554889E56A006A0068000000006A0089C8C9C3}
append/dup artifact 0 (296 - length? artifact)
append/dup artifact 0 16
append artifact #{2A000000}
unless (length? artifact) = 316 [fail "independent native image has the wrong size"]

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

bad-global: copy artifact
change/part at bad-global 133 int-to-bin/to-bin32 0 4
if linker/load-codegen job bad-global [fail "linker accepted a global inside the bitmap"]

bad-global: copy artifact
change/part at bad-global 125 int-to-bin/to-bin32 0 4
change/part at bad-global 129 int-to-bin/to-bin32 8 4
if linker/load-codegen job bad-global [fail "linker accepted a duplicate global symbol"]

bad-global: copy artifact
change/part at bad-global 149 int-to-bin/to-bin32 1 4
if linker/load-codegen job bad-global [fail "linker accepted an invalid global section flag"]

unless linker/load-codegen job artifact [fail linker/codegen-error]
answer: select job/symbols 'answer
unless all [block? answer answer/1 = 'global answer/2 = 16 answer/3 = [18]][
	fail "native global did not become a direct linker symbol"
]
data-section: select job/sections 'data
unless all [block? data-section data-section/2 = #{000000000000000000000000000000002A000000}][
	fail "native global initializer changed in the linker data section"
]

protected-artifact: copy/part artifact 296
append protected-artifact #{2A000000}
append/dup protected-artifact 0 16
change/part at protected-artifact 37 int-to-bin/to-bin32 16 4
change/part at protected-artifact 45 int-to-bin/to-bin32 4 4
change/part at protected-artifact 133 int-to-bin/to-bin32 0 4
change/part at protected-artifact 149 int-to-bin/to-bin32 2 4
unless linker/load-codegen job protected-artifact [fail linker/codegen-error]
answer: select job/symbols 'answer
unless all [block? answer answer/1 = 'constant answer/2 = 0 answer/3 = [18]][
	fail "native constant did not become a direct read-only linker symbol"
]
rodata-section: select job/sections 'rodata
data-section: select job/sections 'data
unless all [
	block? rodata-section rodata-section/2 = #{2A000000}
	block? data-section data-section/2 = #{00000000000000000000000000000000}
][fail "native read-only and writable data were not split directly"]
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

; The same code reference now derives the constant address and writes one byte.
; The PE page, rather than a compiler-side qualifier, must reject the write.
fault-artifact: copy protected-artifact
change/part at fault-artifact 177 int-to-bin/to-bin32 18 4
change/part at fault-artifact 256 #{488D0D00000000C60100} 10
unless linker/load-codegen job fault-artifact [fail linker/codegen-error]
fault-output: clean-path to file! rejoin [root %build/self-hosting/compact-linker-protect-fault.exe]
set [output-dir output-name] split-path fault-output
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename output-name
fault-linked: linker/build job
unless all [file? fault-linked fault-linked = fault-output exists? fault-linked][
	fail "linker did not write the protected-write fault probe"
]
status: call/wait to-local-file fault-linked
unless status = -1073741819 [
	fail ["write to read-only data returned " status " instead of an access violation"]
]

; Independently construct a DLL image with one exported entry function.
dll-artifact: make binary! 136
emit dll-artifact [136 4 0 1 0 0 24 128 6 0 0 0 1]
emit dll-artifact [0 19 0 6 0 0 0 0 0]
emit dll-artifact [1 19 5]
append dll-artifact to binary! "***-dll-entry-pointprobe"
append/dup dll-artifact 0 (128 - length? dll-artifact)
append dll-artifact #{B801000000C3}
append/dup dll-artifact 0 (136 - length? dll-artifact)
unless (length? dll-artifact) = 136 [fail "independent DLL image has the wrong size"]

compiler-system-job/job-set job 'type 'dll
bad-export: copy dll-artifact
change/part at bad-export 93 int-to-bin/to-bin32 -1 4
if linker/load-codegen job bad-export [fail "linker accepted a negative export name offset"]

unless linker/load-codegen job dll-artifact [fail linker/codegen-error]
export-section: select job/sections 'export
unless all [
	block? export-section
	export-section/3 = [***-dll-entry-point "probe"]
][fail "native export did not become a direct linker export"]

dll-output: clean-path to file! rejoin [root %build/self-hosting/compact-linker-export.dll]
set [output-dir output-name] split-path dll-output
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename output-name
dll-linked: linker/build job
unless all [file? dll-linked dll-linked = dll-output exists? dll-linked][
	fail "linker did not write the exported DLL"
]
dll-bytes: read/binary dll-linked
unless find dll-bytes (to binary! "compact-linker-export.dll") [
	fail "PE export directory omitted the DLL name"
]
if find dll-bytes (to binary! "compact-linker-export.dll.dll") [
	fail "PE export directory duplicated the DLL suffix"
]

print ["PASS: compact writable/read-only image -> direct PE linker -> exit 42" linked]
