Red [
	Title: "RSIR-core exclusive hybrid driver integration"
]

#include %../../../system/compiler-windows-common.red
#include %../../../system/compiler-rsir-core.red
#include %../../../compiler/wire-rscf.red
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

check: func [condition [logic!] message [string! block!]][
	unless condition [fail message]
]

; Interpreted scripts start relative to this test directory, while an AOT test
; launched from the repository starts at the repository root.
root: clean-path system/options/path
unless exists? append copy root %system/compiler-rsir-core.red [
	root: clean-path to file! rejoin [system/options/path %../../../]
]
system/options/path: root

source: clean-path to file! rejoin [
	root %tools/self_hosting/fixtures/backend/rsir-empty-void.reds
]
fixture-file: clean-path to file! rejoin [
	root %tools/self_hosting/tests/codegen-bridge-integration.red
]
unless exists? source [fail ["cannot locate RSIR source fixture: " source]]
unless exists? fixture-file [fail ["cannot locate codegen fixtures: " fixture-file]]
fixture-values: load/all read fixture-file
expected-rsir: select fixture-values to set-word! 'glue-function-rsir
expected-rscg: select fixture-values to set-word! 'expected-glue-rscg
unless all [binary? expected-rsir binary? expected-rscg][
	fail "generated hybrid integration fixtures are missing"
]

output: clean-path to file! rejoin [
	root %build/self-hosting/compiler-core-hybrid-driver-integration.exe
]
if exists? output [delete output]
set [output-dir output-name] split-path output

check not value? 'emitter "hybrid core installed the legacy emitter"
check not value? 'rs-o2-ir "hybrid core installed the legacy machine IR"

driver: compiler-hybrid-driver
schema: compiler-wire-schema
codegen-calls: 0
adapter-calls: 0
linker-calls: 0

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	check ir = expected-rsir "compiler-core passed unexpected RSIR to codegen"
	check all [
		not same? ir config
		not same? ir artifact
		not same? ir diagnostics
		not same? config artifact
		not same? config diagnostics
		not same? artifact diagnostics
	]["compiler-core passed aliased series to codegen"]
	verified-config: compiler-wire-rscf/verify config
	check verified-config/valid? "compiler-core passed invalid RSCF to codegen"
	check all [
		(select verified-config/config 'optimization-level)
			= schema/WIRE_OPTIMIZATION_LEVEL_O1
		(select verified-config/config 'flags)
			= schema/WIRE_CONFIG_FLAG_DETERMINISTIC
	]["compiler-core passed the wrong native configuration"]
	append artifact expected-rscg
	schema/WIRE_STATUS_SUCCESS
]
set in driver 'invoke-adapter func [artifact job][
	adapter-calls: adapter-calls + 1
	compiler-rscg-linker-adapter/adapt artifact job
]
set in driver 'adapter-message does [
	either compiler-rscg-linker-adapter/last-error [
		compiler-rscg-linker-adapter/last-error/message
	]["RSCG adapter failed without a diagnostic"]
]
driver/installed?: true

original-linker-build: get in linker 'build
set in linker 'build func [job][
	linker-calls: linker-calls + 1
	original-linker-build job
]

base-job: compiler-system-job/new 'Windows-X86-64
unless object? base-job [fail "could not create Windows x64 compiler job"]
compiler-system-job/job-set base-job 'backend-mode 'rsir
compiler-system-job/job-set base-job 'link? true
compiler-system-job/job-set base-job 'runtime? false
compiler-system-job/job-set base-job 'debug? false
compiler-system-job/job-set base-job 'opt-level 1
compiler-system-job/job-set base-job 'o2-ir-dump none
compiler-system-job/job-set base-job 'dev-mode? false
compiler-system-job/job-set base-job 'PIC? false
compiler-system-job/job-set base-job 'PIE? false
compiler-system-job/job-set base-job 'static-link? false
compiler-system-job/job-set base-job 'red-pass? false
compiler-system-job/job-set base-job 'libRed? false
compiler-system-job/job-set base-job 'libRedRT? false
compiler-system-job/job-set base-job 'libRedRT-update? false
compiler-system-job/job-set base-job 'build-prefix output-dir
compiler-system-job/job-set base-job 'build-basename output-name
compiler-system-job/job-set base-job 'build-suffix none

system-dialect/compile/options source base-job
result: system-dialect/last-result

check system-dialect/last-rsir = expected-rsir
	"compiler-core did not publish the expected RSIR"
check system-dialect/last-rscg = expected-rscg
	"compiler-core did not publish the expected RSCG"
check empty? system-dialect/last-diagnostics
	"successful compiler-core path retained diagnostics"
check codegen-calls = 1 "compiler-core did not call codegen exactly once"
check adapter-calls = 1 "compiler-core did not call the adapter exactly once"
check linker-calls = 1 "compiler-core did not call the linker exactly once"
check all [
	block? result
	file? result/4
	result/4 = output
	exists? output
	result/3 > 0
]["compiler-core did not publish a linked result"]
check not value? 'emitter "hybrid compile installed the legacy emitter"
check not value? 'rs-o2-ir "hybrid compile installed the legacy machine IR"

process-output: make string! 0
status: call/wait/output to-local-file output process-output
check zero? status ["linked hybrid output returned " status]
check empty? process-output ["linked hybrid output wrote: " mold process-output]
delete output

print "PASS: RSIR-core exclusive hybrid driver link"
