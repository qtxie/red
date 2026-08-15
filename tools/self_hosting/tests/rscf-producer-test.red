Red [
	Title: "Hybrid compiler Red-side RSCF producer tests"
]

do %../../../compiler/target-registry.red
do %../../../compiler/system-job.red
do %../../../compiler/wire-rscf.red
do %../../../compiler/rscf-producer.red

schema: compiler-wire-schema
producer: compiler-rscf-producer
verifier: compiler-wire-rscf

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

job: compiler-system-job/new 'Windows-X86-64
assert object? job "could not create a Windows x64 compiler job"
compiler-system-job/job-set job 'opt-level 1
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'PIC? false
job-before: mold/all job

config: producer/build job
assert binary? config "producer rejected its supported compiler job"
assert none? producer/last-error "producer retained an error after success"
assert (length? config) = schema/WIRE_RSCF_MINIMUM_SIZE
	"producer emitted a noncanonical RSCF size"
assert config = producer/build job "producer output is not deterministic"
assert (mold/all job) = job-before "producer mutated its compiler job"

verified: verifier/verify config
assert verified/valid? ["producer emitted invalid RSCF: " verified/error]
fields: verified/config
assert all [
	(select fields 'optimization-level) = schema/WIRE_OPTIMIZATION_LEVEL_O1
	(select fields 'flags) = schema/WIRE_CONFIG_FLAG_DETERMINISTIC
	(select fields 'code-model) = schema/WIRE_CODE_MODEL_SMALL
	(select fields 'relocation-model) = schema/WIRE_RELOCATION_MODEL_STATIC
	(select fields 'debug-format) = schema/WIRE_DEBUG_FORMAT_NONE
	(select fields 'cpu-baseline) = schema/WIRE_CPU_BASELINE_X86_64_BASE
	(select fields 'cpu-features-low) = 0
	(select fields 'cpu-features-high) = 0
	(select fields 'max-output-bytes) = producer/DEFAULT-MAX-OUTPUT-BYTES
	(select fields 'max-diagnostic-bytes) = producer/DEFAULT-MAX-DIAGNOSTIC-BYTES
	(select fields 'worker-count) = 1
	(select fields 'deterministic-seed) = 0
	(select fields 'reserved-0) = 0
	(select fields 'reserved-1) = 0
	(select fields 'reserved-2) = 0
	(select fields 'reserved-3) = 0
]["producer mapped one or more compiler job fields incorrectly"]

compiler-system-job/job-set job 'opt-level 0
minimum: producer/build/limits job schema/WIRE_RSCG_MINIMUM_SIZE 0
assert binary? minimum "producer rejected protocol-minimum arena limits"
verified: verifier/verify minimum
assert all [
	verified/valid?
	(select verified/config 'optimization-level) = schema/WIRE_OPTIMIZATION_LEVEL_O0
	(select verified/config 'max-output-bytes) = schema/WIRE_RSCG_MINIMUM_SIZE
	(select verified/config 'max-diagnostic-bytes) = 0
]["producer did not preserve O0 or minimum arena limits"]

assert-failure: func [
	name [string!]
	job [object!]
	expected [integer!]
	/local before output
][
	before: mold/all job
	output: producer/build job
	assert none? output [name " unexpectedly produced RSCF"]
	assert producer/last-error/code = expected [
		name " expected error " expected " but got " producer/last-error/code
	]
	assert (mold/all job) = before [name " failure mutated its compiler job"]
]

incomplete: make object! [OS: 'Windows]
assert-failure "incomplete job" incomplete producer/ERROR-ARGUMENTS

bad: make job []
bad/target: 'ARM64
assert-failure "wrong target" bad producer/ERROR-TARGET

bad: make job []
bad/opt-level: 2
assert-failure "unsupported O2" bad producer/ERROR-OPTIMIZATION

bad: make job []
bad/debug?: true
assert-failure "unsupported debug" bad producer/ERROR-UNSUPPORTED

bad: make job []
bad/PIC?: true
assert-failure "unsupported PIC" bad producer/ERROR-UNSUPPORTED

bad: make job []
bad/opt-level: 'O1
assert-failure "noninteger optimization" bad producer/ERROR-OPTIMIZATION

output: producer/build/limits job (schema/WIRE_RSCG_MINIMUM_SIZE - 1) 0
assert none? output "producer accepted an undersized artifact arena"
assert producer/last-error/code = producer/ERROR-LIMIT
	"producer reported the wrong artifact-limit error"

output: producer/build/limits job schema/WIRE_RSCG_MINIMUM_SIZE
	(schema/WIRE_RSDG_MINIMUM_SIZE - 1)
assert none? output "producer accepted an undersized diagnostic arena"
assert producer/last-error/code = producer/ERROR-LIMIT
	"producer reported the wrong diagnostic-limit error"

print "PASS: Red-side RSCF producer"
