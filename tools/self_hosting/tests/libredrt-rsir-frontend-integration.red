Red [
	Title: "Direct libRedRT RSIR frontend integration"
]

system/options/path: clean-path %../../../
compiler-root: system/options/path
unless value? 'event! [event!: make datatype! #get-definition TYPE_EVENT]

#include %system/compiler-windows-common.red
#include %system/utils/libRedRT.red
#include %compiler/rsir-frontend.red
#include %system/compiler-rsir-core.red
#include %compiler/modules.red
#include %compiler/version.red
#include %compiler/preprocessor.red
#include %compiler/extractor.red
#include %compiler/redbin.red
#include %compiler/crush.red
#include %compiler/frontend.red

if none? red/redbin [do bind load %compiler/redbin-emitter.red red]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

job: compiler-system-job/new 'Windows-X86-64-DLL
unless object? job [fail compiler-system-job/last-error/message]
output-dir: %build/self-hosting/libredrt-rsir/
make-dir/deep output-dir
compiler-system-job/job-set job 'backend-mode 'rsir
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename libRedRT/lib-file
compiler-system-job/job-set job 'type 'dll
compiler-system-job/job-set job 'dev-mode? true
compiler-system-job/job-set job 'libRedRT? true
compiler-system-job/job-set job 'link? false
compiler-system-job/job-set job 'unicode? true
compiler-system-job/job-set job 'red-pass? true
compiler-system-job/job-set job 'sub-system 'Console
compiler-system-job/job-set job 'GUI-engine none
compiler-system-job/job-set job 'draw-engine none
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'opt-level 1
compiler-system-job/job-set job 'redbin-compress? true
compiler-system-job/job-set job 'compiler-version compiler-version
compiler-system-job/job-set job 'compiler-build-date compiler-build-date
compiler-system-job/job-set job 'compiler-git none
compiler-system-job/normalize job
compiler-system-job/job-set job 'red-store-bodies? true

frontend-result: compiler-frontend/compile [[]] job
unless all [block? frontend-result binary? frontend-result/3][
	fail "libRedRT Red frontend did not return source and boot data"
]
system-dialect/compile/options/loaded libRedRT/lib-file job frontend-result
unless binary? system-dialect/last-rsir [fail "libRedRT did not lower to RSIR"]
write/binary join output-dir %libRedRT.rsir system-dialect/last-rsir

libRedRT/root-dir: clean-path output-dir
libRedRT/save-files
	job
	compiler-rsir-frontend/runtime-functions
	compiler-rsir-frontend/runtime-specs
unless block? libRedRT/get-include-file job [
	fail "generated libRedRT include file could not be loaded"
]
unless block? libRedRT/get-definitions [
	fail "generated libRedRT definitions could not be loaded"
]

print [
	"PASS: direct libRedRT frontend -> RSIR + interface files"
	length? system-dialect/last-rsir "bytes"
]
