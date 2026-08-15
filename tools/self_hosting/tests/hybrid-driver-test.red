Red [
	Title: "Strict hybrid compiler driver tests"
]

#include %../../../system/compiler-windows-bootstrap.red
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

root: clean-path to file! rejoin [system/options/path %../../../]
system/options/path: root
fixture-file: clean-path to file! rejoin [
	root %tools/self_hosting/tests/codegen-bridge-integration.red
]
unless exists? fixture-file [fail ["cannot locate codegen fixtures: " fixture-file]]
fixture-values: load/all read fixture-file
expected-ir: select fixture-values to set-word! 'late-name-glue-rsir
expected-artifact: select fixture-values to set-word! 'expected-late-name-glue-rscg
user-artifact: select fixture-values to set-word! 'expected-function-rscg
failure-diagnostics: select fixture-values to set-word! 'expected-invalid-verify
unless all [
	binary? expected-ir
	binary? expected-artifact
	binary? user-artifact
	binary? failure-diagnostics
][fail "generated hybrid driver fixtures are missing"]

driver: compiler-hybrid-driver
schema: compiler-wire-schema
codegen-calls: 0
adapter-calls: 0

make-supported-job: does [
	base: compiler-system-job/new 'Windows-X86-64
	unless object? base [fail "could not create Windows x64 compiler job"]
	job: system-dialect/make-job base %hybrid-driver.reds
	compiler-system-job/job-set job 'link? true
	compiler-system-job/job-set job 'runtime? false
	compiler-system-job/job-set job 'debug? false
	compiler-system-job/job-set job 'opt-level 1
	compiler-system-job/job-set job 'PIC? false
	compiler-system-job/job-set job 'PIE? false
	compiler-system-job/job-set job 'static-link? false
	compiler-system-job/job-set job 'red-pass? false
	compiler-system-job/job-set job 'libRed? false
	compiler-system-job/job-set job 'libRedRT? false
	compiler-system-job/job-set job 'libRedRT-update? false
	job
]

install-adapter: does [
	set in driver 'invoke-adapter func [artifact job][
		adapter-calls: adapter-calls + 1
		compiler-rscg-linker-adapter/adapt artifact job
	]
	set in driver 'adapter-message does [
		either compiler-rscg-linker-adapter/last-error [
			compiler-rscg-linker-adapter/last-error/message
		]["RSCG adapter failed without a diagnostic"]
	]
]

install-success-codegen: does [
	set in driver 'invoke-codegen func [ir config artifact diagnostics][
		codegen-calls: codegen-calls + 1
		check ir = expected-ir "driver changed RSIR before codegen"
		check all [
			not same? ir config
			not same? ir artifact
			not same? ir diagnostics
			not same? config artifact
			not same? config diagnostics
			not same? artifact diagnostics
		]["driver passed aliased series to codegen"]
		verified-config: compiler-wire-rscf/verify config
		check verified-config/valid? "driver passed invalid RSCF to codegen"
		append artifact expected-artifact
		schema/WIRE_STATUS_SUCCESS
	]
]

install-adapter
install-success-codegen
driver/installed?: true
job: make-supported-job
job-before: mold/all job
artifact: driver/generate copy expected-ir job
check artifact = expected-artifact "driver did not publish the codegen artifact"
check driver/last-artifact = expected-artifact "driver lost its last RSCG artifact"
check empty? driver/last-diagnostics "successful codegen retained diagnostics"
check driver/last-status = schema/WIRE_STATUS_SUCCESS
	"successful codegen retained the wrong status"
check codegen-calls = 1 "driver did not invoke codegen exactly once"
check (mold/all job) = job-before "codegen phase mutated the linker job"
check driver/adapt artifact job "driver rejected the supported RSCG artifact"
check adapter-calls = 1 "driver did not invoke the adapter exactly once"
check to logic! all [find job/sections 'code find job/sections 'import]
	"driver adapter did not commit linker sections"

driver/installed?: false
job: make-supported-job
job-before: mold/all job
before-calls: codegen-calls
check none? driver/generate copy expected-ir job
	"uninstalled driver generated an artifact"
check driver/last-error/code = driver/ERROR-NOT-INSTALLED
	"uninstalled driver reported the wrong error"
check codegen-calls = before-calls "uninstalled driver called codegen"
check (mold/all job) = job-before "uninstalled driver mutated the linker job"
driver/installed?: true

job: make-supported-job
compiler-system-job/job-set job 'opt-level 2
job-before: mold/all job
before-calls: codegen-calls
check none? driver/generate copy expected-ir job
	"driver accepted unsupported O2 configuration"
check driver/last-error/code = driver/ERROR-CONFIGURATION
	"unsupported O2 reported the wrong driver error"
check codegen-calls = before-calls "configuration failure called codegen"
check (mold/all job) = job-before "configuration failure mutated the linker job"

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	append diagnostics failure-diagnostics
	schema/WIRE_STATUS_INVALID_RSIR
]
job: make-supported-job
check none? driver/generate copy expected-ir job
	"codegen failure produced an artifact"
check all [
	driver/last-error/code = driver/ERROR-CODEGEN
	driver/last-error/status = schema/WIRE_STATUS_INVALID_RSIR
	not empty? driver/last-error/message
	driver/last-diagnostics = failure-diagnostics
]["valid native diagnostics were not preserved"]

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	append diagnostics #{00}
	schema/WIRE_STATUS_CODEGEN_FAILURE
]
job: make-supported-job
check none? driver/generate copy expected-ir job
	"invalid RSDG failure produced an artifact"
check driver/last-error/code = driver/ERROR-DIAGNOSTIC
	"invalid RSDG reported the wrong driver error"

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	append artifact expected-artifact
	schema/WIRE_STATUS_CODEGEN_FAILURE
]
job: make-supported-job
check none? driver/generate copy expected-ir job
	"failure with a committed artifact was accepted"
check driver/last-error/code = driver/ERROR-CONTRACT
	"failure artifact reported the wrong driver error"

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	append artifact expected-artifact
	append diagnostics failure-diagnostics
	schema/WIRE_STATUS_SUCCESS
]
job: make-supported-job
check none? driver/generate copy expected-ir job
	"success with diagnostics was accepted"
check driver/last-error/code = driver/ERROR-DIAGNOSTIC
	"success diagnostics reported the wrong driver error"

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	schema/WIRE_STATUS_SUCCESS
]
job: make-supported-job
check none? driver/generate copy expected-ir job
	"success without an artifact was accepted"
check driver/last-error/code = driver/ERROR-CONTRACT
	"empty success reported the wrong driver error"

set in driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-calls: codegen-calls + 1
	append artifact user-artifact
	schema/WIRE_STATUS_SUCCESS
]
job: make-supported-job
job-before: mold/all job
artifact: driver/generate copy expected-ir job
check binary? artifact "driver did not retain the adapter-negative artifact"
before-adapters: adapter-calls
check not driver/adapt artifact job "adapter accepted a USER lifecycle object"
check driver/last-error/code = driver/ERROR-ADAPTER
	"adapter rejection reported the wrong driver error"
check adapter-calls = (before-adapters + 1) "adapter rejection was not called once"
check (mold/all job) = job-before "adapter rejection mutated the linker job"

print "PASS: strict hybrid compiler driver"
