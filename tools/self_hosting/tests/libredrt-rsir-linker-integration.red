Red [
	Title: "Direct libRedRT native image linker integration"
]

#include %../../../system/compiler-windows-common.red

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

system-dialect: context [
	compiler: context [
		quit-on-error: does [quit/return 1]
	]
]

root: clean-path to file! rejoin [system/options/path %../../../]
system/options/path: root
input: %build/self-hosting/libredrt-rsir/libRedRT.image
output: %build/self-hosting/libredrt-rsir/libRedRT.dll
unless exists? input [fail ["missing native image: " mold input]]

base-job: compiler-system-job/new 'Windows-X86-64-DLL
unless object? base-job [fail compiler-system-job/last-error/message]
job-data: copy/deep body-of base-job
forall job-data [if lit-word? job-data/1 [job-data/1: to word! job-data/1]]
job: construct/with job-data linker/job-class

set [output-dir output-name] split-path output
compiler-system-job/job-set job 'type 'dll
compiler-system-job/job-set job 'link? true
compiler-system-job/job-set job 'runtime? true
compiler-system-job/job-set job 'dev-mode? true
compiler-system-job/job-set job 'red-pass? true
compiler-system-job/job-set job 'libRed? false
compiler-system-job/job-set job 'libRedRT? true
compiler-system-job/job-set job 'libRedRT-update? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'PIC? false
compiler-system-job/job-set job 'PIE? false
compiler-system-job/job-set job 'static-link? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename output-name
compiler-system-job/job-set job 'build-suffix none
compiler-system-job/job-set job 'verbosity 0

image: read/binary input
unless linker/load-codegen job image [fail linker/codegen-error]
exports: select job/sections 'export
unless all [
	block? exports
	(select exports/3 to word! "red>boot") = "red/boot"
	(select exports/3 to word! "red>root") = "red/root"
][fail "native image lost required libRedRT exports"]

linked: linker/build job
unless all [file? linked linked = output exists? linked][
	fail ["linker did not write libRedRT.dll: " mold linked]
]

print [
	"PASS: direct libRedRT native image -> PE DLL"
	length? read/binary linked "bytes"
]
