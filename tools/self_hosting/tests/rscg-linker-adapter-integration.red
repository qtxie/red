Red [
	Title: "Fresh-process RSCG to PE linker integration"
]

#include %../../../system/compiler-windows-bootstrap.red
#include %../../../compiler/wire-container.red
#include %../../../compiler/wire-string-table.red
#include %../../../compiler/wire-file-source.red
#include %../../../compiler/wire-data-layout.red
#include %../../../compiler/wire-module-lifecycle.red
#include %../../../compiler/wire-rscg-object.red
#include %../../../compiler/wire-rscg-relocation.red
#include %../../../compiler/wire-rscg-metadata.red
#include %../../../compiler/rscg-linker-adapter.red

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
fixture-file: clean-path to file! rejoin [
	root %tools/self_hosting/tests/codegen-bridge-integration.red
]
unless exists? fixture-file [fail ["cannot locate generated RSCG fixtures: " fixture-file]]
fixture-values: load/all read fixture-file
artifact: select fixture-values to set-word! 'expected-late-name-glue-rscg
unless binary? artifact [fail "generated late-name glue RSCG fixture is missing"]

output: either all [
	block? system/options/args
	not empty? system/options/args
][
	clean-path to-red-file to file! system/options/args/1
][
	clean-path to file! rejoin [root %build/self-hosting/rscg-adapter-glue.exe]
]
set [output-dir output-name] split-path output

base-job: compiler-system-job/new 'Windows-X86-64
unless object? base-job [fail "could not create the Windows x64 linker job"]
job: system-dialect/make-job base-job %rscg-adapter-glue.reds
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

unless compiler-rscg-linker-adapter/adapt artifact job [
	fail compiler-rscg-linker-adapter/last-error/message
]
linked: linker/build job
unless all [file? linked exists? linked][fail ["linker did not write output: " mold linked]]
unless linked = output [fail ["linker wrote an unexpected path: " linked]]
unless all [
	find job/sections 'import
	find job/sections 'idata
	not empty? job/sections/import/2
	not empty? job/sections/idata/2
][fail "RSCG ExitProcess import did not produce PE import and IAT sections"]
if find job/sections 'reloc [
	fail "relocation-free RSCG image retained an empty PE base-relocation section"
]

process-output: make string! 0
status: call/wait/output to-local-file linked process-output
unless zero? status [fail ["linked RSCG executable returned " status]]
unless empty? process-output [fail ["linked RSCG executable wrote output: " mold process-output]]

print ["PASS: fresh-process RSCG PE link and launch" linked]
