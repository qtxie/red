Red [
	Title: "Generate hybrid codegen routine bridge integration fixtures"
]

generating-wire-container-fixtures?: true
do %tests/wire-container-test.red
do %../../compiler/wire-rscf.red
do %../../compiler/wire-target-intrinsic.red
do %../../compiler/wire-atomic.red
do %../../compiler/wire-memory-aggregate.red
do %../../compiler/wire-rscg-metadata.red
do %../../compiler/wire-diagnostics.red
do %../../compiler/rsir-producer.red

index-flags:
	schema/WIRE_SECTION_FLAG_SORTED
	+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

set-rsir-flags: func [sections [block!] /local kind][
	foreach kind reduce [
		schema/WIRE_RSIR_SECTION_STRINGS
		schema/WIRE_RSIR_SECTION_FILES
		schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		schema/WIRE_RSIR_SECTION_SYMBOLS
		schema/WIRE_RSIR_SECTION_IMPORTS
		schema/WIRE_RSIR_SECTION_EXPORTS
		schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
	][fixture-writer/set-section-flags sections kind index-flags]
	sections
]

build-rsir: func [
	payloads [map!]
	/module module-values [block!]
	/local sections
][
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words any [module-values [0 2 1 0 0 0 0 0]]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	sections: set-rsir-flags
		fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/build
		schema/WIRE_MAGIC_RSIR
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

make-canonical-strings: func [
	values [block!]
	/local ordered records data ids offset id bytes
][
	ordered: sort/case copy values
	records: make block! ((length? ordered) * 2)
	data: make binary! 64
	ids: make map! ((length? ordered) * 2)
	offset: 0
	id: 1
	foreach value ordered [
		bytes: to binary! value
		repend records [offset length? bytes]
		append data bytes
		put ids value id
		offset: offset + length? bytes
		id: id + 1
	]
	reduce [fixture-writer/words records data ids]
]

empty-rsir: build-rsir make map! 16

one-empty-string: make-canonical-strings [""]
string-rsir-payloads: make map! 16
put string-rsir-payloads schema/WIRE_RSIR_SECTION_STRINGS one-empty-string/1
put string-rsir-payloads schema/WIRE_RSIR_SECTION_STRING_DATA one-empty-string/2
string-rsir: build-rsir string-rsir-payloads

function-strings: make-canonical-strings ["" "fn"]
function-name: select function-strings/3 "fn"
nonempty-rsir-payloads: make map! 48
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_STRINGS function-strings/1
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_STRING_DATA function-strings/2
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_TYPES fixture-writer/words [
	; void
	1 0 0 0 0 0 0 0 0 0
]
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_SIGNATURES fixture-writer/words [
	; Red/System void(), no parameters.
	1 0 1 0 0 0 0 0
]
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_SYMBOLS
	fixture-writer/words reduce [
		function-name schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN
		1 0 0 0
	]
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_FUNCTIONS fixture-writer/words [
	1 1 0 1 1 1 0 0 0 0
]
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_BLOCKS fixture-writer/words [
	1 0 1 1 0 0 0 0
]
put nonempty-rsir-payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS
	fixture-writer/words reduce [
		1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	]
minimal-function-rsir: build-rsir nonempty-rsir-payloads
glue-function-rsir: build-rsir/module copy nonempty-rsir-payloads [
	0 4 1 0 0 1 0 0
]
late-function-strings: make-canonical-strings ["" "zz-entry"]
late-name-rsir-payloads: copy nonempty-rsir-payloads
put late-name-rsir-payloads schema/WIRE_RSIR_SECTION_STRINGS late-function-strings/1
put late-name-rsir-payloads schema/WIRE_RSIR_SECTION_STRING_DATA late-function-strings/2
late-name-glue-rsir: build-rsir/module late-name-rsir-payloads [
	0 4 1 0 0 1 0 0
]
produced-minimal-function-rsir: compiler-rsir-producer/build-empty-void-module
	none "fn"
	schema/WIRE_MODULE_KIND_USER
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? produced-minimal-function-rsir
	"minimal RSIR producer rejected its supported fixture"
assert produced-minimal-function-rsir = minimal-function-rsir
	"minimal RSIR producer bytes differ from the independent fixture"
produced-glue-function-rsir: compiler-rsir-producer/build-empty-void-module
	none "fn"
	schema/WIRE_MODULE_KIND_GLUE
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? produced-glue-function-rsir
	"minimal RSIR producer rejected its glue fixture"
assert produced-glue-function-rsir = glue-function-rsir
	"minimal RSIR glue producer bytes differ from the independent fixture"
produced-late-name-glue-rsir: compiler-rsir-producer/build-empty-void-module
	none "zz-entry"
	schema/WIRE_MODULE_KIND_GLUE
	schema/WIRE_IMAGE_KIND_EXECUTABLE
assert binary? produced-late-name-glue-rsir
	"minimal RSIR producer rejected its late-name glue fixture"
assert produced-late-name-glue-rsir = late-name-glue-rsir
	"minimal RSIR late-name glue producer bytes differ from the independent fixture"

verify-rsir: func [name [string!] data [binary!] /local result][
	result: compiler-wire-target-intrinsic/verify data
	assert result/valid? [name " target verifier rejected fixture: " result/error]
	result: compiler-wire-atomic/verify data
	assert result/valid? [name " atomic verifier rejected fixture: " result/error]
	result: compiler-wire-memory-aggregate/verify data
	assert result/valid? [name " memory verifier rejected fixture: " result/error]
]

verify-rsir "empty" empty-rsir
verify-rsir "empty-string" string-rsir
verify-rsir "minimal-function" minimal-function-rsir
verify-rsir "glue-function" glue-function-rsir
verify-rsir "late-name-glue" late-name-glue-rsir

empty-container-result: verifier/verify/expect empty-rsir schema/WIRE_MAGIC_RSIR
empty-module-section: verifier/find-section
	empty-container-result schema/WIRE_RSIR_SECTION_MODULE
invalid-semantic-rsir: copy empty-rsir
fixture-mutations/put-u32 invalid-semantic-rsir
	((select empty-module-section 'payload-offset) + schema/WIRE_RSIR_MODULE_KIND_OFFSET)
	99

invalid-container-rsir: copy/part empty-rsir (schema/WIRE_HEADER_SIZE - 1)

mismatched-rsir: copy empty-rsir
fixture-mutations/put-u32 mismatched-rsir schema/WIRE_HEADER_TARGET_OFFSET
	schema/WIRE_TARGET_ARM64
fixture-mutations/put-u32 mismatched-rsir schema/WIRE_HEADER_ABI_OFFSET
	schema/WIRE_ABI_AAPCS64

base-config: copy rscf
config-container-result: verifier/verify/expect base-config schema/WIRE_MAGIC_RSCF
config-section: verifier/find-section
	config-container-result schema/WIRE_RSCF_SECTION_CONFIG
config-offset: select config-section 'payload-offset

no-diagnostic-config: copy base-config
fixture-mutations/put-u32 no-diagnostic-config
	(config-offset + schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET) 0

minimum-output-config: copy base-config
fixture-mutations/put-u32 minimum-output-config
	(config-offset + schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET)
	schema/WIRE_RSCG_MINIMUM_SIZE

unsupported-config: copy base-config
fixture-mutations/put-u32 unsupported-config schema/WIRE_HEADER_TARGET_OFFSET
	schema/WIRE_TARGET_ARM64
fixture-mutations/put-u32 unsupported-config schema/WIRE_HEADER_ABI_OFFSET
	schema/WIRE_ABI_AAPCS64

foreach [name config-data expected-valid?] reduce [
	"base" base-config true
	"diagnostics-disabled" no-diagnostic-config true
	"minimum-output" minimum-output-config true
	"unsupported-target" unsupported-config false
][
	result: compiler-wire-rscf/verify config-data
	assert result/valid? = expected-valid? [name " RSCF validity changed"]
]

build-rscg: func [
	string-records string-data [binary!]
	payloads [map!]
	/module module-values [block!]
	/local sections kind
][
	put payloads schema/WIRE_RSCG_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSCG_SECTION_STRINGS string-records
	put payloads schema/WIRE_RSCG_SECTION_STRING_DATA string-data
	put payloads schema/WIRE_RSCG_SECTION_MODULES
		fixture-writer/words any [module-values [0 2 1 0 0 0 0 0]]
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSCG payloads
	foreach kind reduce [
		schema/WIRE_RSCG_SECTION_STRINGS
		schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
		schema/WIRE_RSCG_SECTION_RELOCATIONS
		schema/WIRE_RSCG_SECTION_IMPORTS
		schema/WIRE_RSCG_SECTION_EXPORTS
		schema/WIRE_RSCG_SECTION_FUNCTIONS
		schema/WIRE_RSCG_SECTION_FILES
		schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS
		schema/WIRE_RSCG_SECTION_GC_FRAMES
	][fixture-writer/set-section-flags sections kind index-flags]
	fixture-writer/set-section-flags sections schema/WIRE_RSCG_SECTION_SYMBOLS
		schema/WIRE_SECTION_FLAG_SORTED
	fixture-writer/set-section-flags sections schema/WIRE_RSCG_SECTION_DEBUG_LINES
		schema/WIRE_SECTION_FLAG_SORTED
	fixture-writer/build
		schema/WIRE_MAGIC_RSCG
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

expected-empty-rscg: build-rscg #{} #{} make map! 8
result: compiler-wire-rscg-metadata/verify expected-empty-rscg
assert result/valid? ["expected empty RSCG rejected: " result/error]
assert (length? expected-empty-rscg) = schema/WIRE_RSCG_MINIMUM_SIZE
	"empty RSCG size changed"

function-rscg-strings: make-canonical-strings ["" ".data" ".text" "fn"]
data-section-name: select function-rscg-strings/3 ".data"
code-section-name: select function-rscg-strings/3 ".text"
output-function-name: select function-rscg-strings/3 "fn"
empty-void-code: #{554889E56A006A0068000000006A00C9C3}
empty-void-bitmap: make binary! 16
append/dup empty-void-bitmap 0 16
empty-void-output: copy empty-void-code
append empty-void-output empty-void-bitmap
function-rscg-payloads: make map! 24
put function-rscg-payloads schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
	fixture-writer/words reduce [
		code-section-name schema/WIRE_OUTPUT_SECTION_CLASS_CODE 0 16
		0 17 17 0
		data-section-name schema/WIRE_OUTPUT_SECTION_CLASS_DATA 0 4
		17 16 16 0
	]
put function-rscg-payloads schema/WIRE_RSCG_SECTION_OUTPUT_DATA empty-void-output
put function-rscg-payloads schema/WIRE_RSCG_SECTION_SYMBOLS
	fixture-writer/words reduce [
		output-function-name schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_SYMBOL_BINDING_LOCAL schema/WIRE_VISIBILITY_HIDDEN
		1 0 17 16 0 1
	]
put function-rscg-payloads schema/WIRE_RSCG_SECTION_FUNCTIONS
	fixture-writer/words [1 1 0 17 32 0 0 0 0 0]
put function-rscg-payloads schema/WIRE_RSCG_SECTION_GC_FRAMES
	fixture-writer/words [1 2 0 16 0 9]
expected-function-rscg: build-rscg function-rscg-strings/1
	function-rscg-strings/2 function-rscg-payloads
result: compiler-wire-rscg-metadata/verify expected-function-rscg
assert result/valid? ["expected function RSCG rejected: " result/error]

glue-rscg-strings: make-canonical-strings [
	"" ".data" ".text" "ExitProcess" "fn" "kernel32.dll" "system-exit-process"
]
glue-data-section-name: select glue-rscg-strings/3 ".data"
glue-code-section-name: select glue-rscg-strings/3 ".text"
glue-function-name: select glue-rscg-strings/3 "fn"
glue-exit-symbol-name: select glue-rscg-strings/3 "system-exit-process"
glue-exit-library-name: select glue-rscg-strings/3 "kernel32.dll"
glue-exit-external-name: select glue-rscg-strings/3 "ExitProcess"
empty-void-entry-code: #{554889E56A006A0068000000006A0031C94883EC20FF150000000031C0C9C3}
empty-void-entry-output: copy empty-void-entry-code
append empty-void-entry-output empty-void-bitmap
glue-rscg-payloads: make map! 24
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
	fixture-writer/words reduce [
		glue-code-section-name schema/WIRE_OUTPUT_SECTION_CLASS_CODE 0 16
		0 31 31 0
		glue-data-section-name schema/WIRE_OUTPUT_SECTION_CLASS_DATA 0 4
		31 16 16 0
	]
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_OUTPUT_DATA empty-void-entry-output
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_SYMBOLS
	fixture-writer/words reduce [
		glue-function-name schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_SYMBOL_BINDING_LOCAL schema/WIRE_VISIBILITY_HIDDEN
		1 0 31 16 0 1
		glue-exit-symbol-name schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_SYMBOL_BINDING_GLOBAL schema/WIRE_VISIBILITY_DEFAULT
		0 0 0 0 schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED 1
	]
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_RELOCATIONS
	fixture-writer/words reduce [
		1 23 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 2 0 0 4 0
	]
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_IMPORTS
	fixture-writer/words reduce [
		glue-exit-library-name glue-exit-external-name 2
		schema/WIRE_CALLING_CONVENTION_STDCALL 0 0
	]
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_FUNCTIONS
	fixture-writer/words [1 1 0 31 32 0 0 0 0 0]
put glue-rscg-payloads schema/WIRE_RSCG_SECTION_GC_FRAMES
	fixture-writer/words [1 2 0 16 0 9]
expected-glue-rscg: build-rscg/module
	glue-rscg-strings/1 glue-rscg-strings/2 glue-rscg-payloads
	[0 4 1 0 0 1 0 0]
result: compiler-wire-rscg-metadata/verify expected-glue-rscg
assert result/valid? ["expected glue RSCG rejected: " result/error]

late-glue-rscg-strings: make-canonical-strings [
	"" ".data" ".text" "ExitProcess" "kernel32.dll"
	"system-exit-process" "zz-entry"
]
late-glue-data-section-name: select late-glue-rscg-strings/3 ".data"
late-glue-code-section-name: select late-glue-rscg-strings/3 ".text"
late-glue-function-name: select late-glue-rscg-strings/3 "zz-entry"
late-glue-exit-symbol-name: select late-glue-rscg-strings/3 "system-exit-process"
late-glue-exit-library-name: select late-glue-rscg-strings/3 "kernel32.dll"
late-glue-exit-external-name: select late-glue-rscg-strings/3 "ExitProcess"
late-glue-rscg-payloads: make map! 24
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
	fixture-writer/words reduce [
		late-glue-code-section-name schema/WIRE_OUTPUT_SECTION_CLASS_CODE 0 16
		0 31 31 0
		late-glue-data-section-name schema/WIRE_OUTPUT_SECTION_CLASS_DATA 0 4
		31 16 16 0
	]
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_OUTPUT_DATA empty-void-entry-output
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_SYMBOLS
	fixture-writer/words reduce [
		late-glue-exit-symbol-name schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_SYMBOL_BINDING_GLOBAL schema/WIRE_VISIBILITY_DEFAULT
		0 0 0 0 schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED 1
		late-glue-function-name schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_SYMBOL_BINDING_LOCAL schema/WIRE_VISIBILITY_HIDDEN
		1 0 31 16 0 1
	]
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_RELOCATIONS
	fixture-writer/words reduce [
		1 23 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 1 0 0 4 0
	]
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_IMPORTS
	fixture-writer/words reduce [
		late-glue-exit-library-name late-glue-exit-external-name 1
		schema/WIRE_CALLING_CONVENTION_STDCALL 0 0
	]
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_FUNCTIONS
	fixture-writer/words [2 1 0 31 32 0 0 0 0 0]
put late-glue-rscg-payloads schema/WIRE_RSCG_SECTION_GC_FRAMES
	fixture-writer/words [1 2 0 16 0 9]
expected-late-name-glue-rscg: build-rscg/module
	late-glue-rscg-strings/1 late-glue-rscg-strings/2 late-glue-rscg-payloads
	[0 4 1 0 0 2 0 0]
result: compiler-wire-rscg-metadata/verify expected-late-name-glue-rscg
assert result/valid? ["expected late-name glue RSCG rejected: " result/error]

build-diagnostic: func [
	status phase [integer!]
	message [string!]
	target abi endian pointer-size features-low features-high [integer!]
	/local message-data payloads sections output result
][
	message-data: to binary! message
	payloads: make map! 12
	put payloads schema/WIRE_RSDG_SECTION_STRINGS
		fixture-writer/words reduce [0 length? message-data]
	put payloads schema/WIRE_RSDG_SECTION_STRING_DATA message-data
	put payloads schema/WIRE_RSDG_SECTION_DIAGNOSTICS fixture-writer/words reduce [
		status schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR phase 1 0 0 0 0 0 0
	]
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSDG payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSDG_SECTION_STRINGS
		index-flags
	output: fixture-writer/build schema/WIRE_MAGIC_RSDG target abi endian
		pointer-size sections
	fixture-mutations/put-u32 output schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		features-low
	fixture-mutations/put-u32 output schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		features-high
	result: compiler-wire-diagnostics/verify output schema/WIRE_MAGIC_RSDG
	assert result/valid? ["expected diagnostic rejected: " result/error]
	assert result/view/status = status "expected diagnostic status changed"
	output
]

expected-invalid-decode: build-diagnostic
	schema/WIRE_STATUS_INVALID_RSIR schema/WIRE_DIAGNOSTIC_PHASE_DECODE
	"invalid RSIR module" 0 0 0 0 0 0
expected-invalid-verify: build-diagnostic
	schema/WIRE_STATUS_INVALID_RSIR schema/WIRE_DIAGNOSTIC_PHASE_VERIFY
	"invalid RSIR module" schema/WIRE_TARGET_X86_64 schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE 8 0 0
expected-target-mismatch: build-diagnostic
	schema/WIRE_STATUS_UNSUPPORTED_TARGET schema/WIRE_DIAGNOSTIC_PHASE_DECODE
	"unsupported codegen target" schema/WIRE_TARGET_ARM64 schema/WIRE_ABI_AAPCS64
	schema/WIRE_ENDIAN_LITTLE 8 0 0
expected-nonempty-failure: build-diagnostic
	schema/WIRE_STATUS_CODEGEN_FAILURE schema/WIRE_DIAGNOSTIC_PHASE_SELECT
	"unsupported RSIR codegen subset"
	schema/WIRE_TARGET_X86_64 schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE 8 0 0
expected-output-limit: build-diagnostic
	schema/WIRE_STATUS_CODEGEN_FAILURE schema/WIRE_DIAGNOSTIC_PHASE_ENCODE
	"native codegen encoding failed"
	schema/WIRE_TARGET_X86_64 schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE 8 0 0

; The layer-specific rich corpora intentionally omit a terminator because their
; standalone verifiers do not own CFG completeness. Add RETURN here to make
; them complete RSIR modules before exercising the aggregate bridge verifier.
generating-wire-atomic-fixtures?: true
do %tests/wire-atomic-test.red
full-atomic-instructions: copy atomic-instructions
append full-atomic-instructions fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
	schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
full-atomic-blocks: fixture-writer/words reduce [
	1 0 1 atomic-next-instruction 0 0 0 0
]
full-atomic-rsir: build-scalar-operation-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	atomic-strings/1 atomic-strings/2 atomic-types #{} atomic-signatures #{}
	atomic-symbols atomic-constants atomic-functions #{} full-atomic-blocks
	atomic-values full-atomic-instructions atomic-operands #{}
verify-rsir "full-atomic" full-atomic-rsir

invalid-atomic-rsir: copy full-atomic-rsir
full-atomic-container: verifier/verify/expect
	invalid-atomic-rsir schema/WIRE_MAGIC_RSIR
full-atomic-section: verifier/find-section
	full-atomic-container schema/WIRE_RSIR_SECTION_INSTRUCTIONS
full-atomic-offset:
	(select full-atomic-section 'payload-offset)
	+ (((atomic-instruction-id 'LOAD-ACQUIRE) - 1)
		* schema/WIRE_RSIR_INSTRUCTION_SIZE)
	+ schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
fixture-mutations/put-u32 invalid-atomic-rsir full-atomic-offset 6
result: compiler-wire-target-intrinsic/verify invalid-atomic-rsir
assert result/valid? "invalid atomic fixture failed before the atomic layer"
result: compiler-wire-atomic/verify invalid-atomic-rsir
assert all [
	not result/valid?
	result/error = schema/WIRE_ATOMIC_ERROR_BAD_ORDER
]["invalid atomic fixture returned error " result/error]
result: compiler-wire-memory-aggregate/verify invalid-atomic-rsir
assert result/valid? "invalid atomic fixture leaked into the memory layer"

generating-wire-memory-aggregate-fixtures?: true
do %tests/wire-memory-aggregate-test.red
full-memory-instructions: copy memory-instructions
append full-memory-instructions fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
	schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
original-memory-blocks: memory-blocks
memory-blocks: fixture-writer/words reduce [
	1 0 1 memory-next-instruction 0 0 0 0
]
full-memory-rsir: build-memory-message
	memory-values full-memory-instructions memory-operands
memory-blocks: original-memory-blocks
verify-rsir "full-memory" full-memory-rsir

invalid-memory-rsir: copy full-memory-rsir
full-memory-container: verifier/verify/expect
	invalid-memory-rsir schema/WIRE_MAGIC_RSIR
full-memory-section: verifier/find-section
	full-memory-container schema/WIRE_RSIR_SECTION_INSTRUCTIONS
full-memory-offset:
	(select full-memory-section 'payload-offset)
	+ (((memory-instruction-id 'LOAD-LOCAL) - 1)
		* schema/WIRE_RSIR_INSTRUCTION_SIZE)
	+ schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
fixture-mutations/put-u32 invalid-memory-rsir full-memory-offset 1
result: compiler-wire-target-intrinsic/verify invalid-memory-rsir
assert result/valid? "invalid memory fixture failed before the memory layer"
result: compiler-wire-atomic/verify invalid-memory-rsir
assert result/valid? "invalid memory fixture leaked into the atomic layer"
result: compiler-wire-memory-aggregate/verify invalid-memory-rsir
assert all [
	not result/valid?
	result/error = schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_SUBOPCODE
]["invalid memory fixture returned error " result/error]

append-fixture: func [output [string!] name [string!] data [binary!]][
	append output rejoin [name ": " mold/flat data newline]
]

source-bytes: make binary! 262144
foreach source-file [
	%generate-codegen-bridge-fixtures.red
	%../../compiler/wire-writer.red
	%../../compiler/rsir-producer.red
	%../../compiler/codegen-bridge.red
	%../../system/codegen/codegen-bridge.reds
	%../../system/codegen/x64-o0-codegen.reds
	%../../system/codegen/x64-encoder.reds
	%../../system/codegen/wire-codegen-strings.reds
	%../../system/codegen/wire-arena.reds
	%../../system/codegen/wire-writer.reds
	%../../system/codegen/wire-rsir.reds
	%../../system/codegen/wire-atomic.reds
	%../../system/codegen/wire-memory-aggregate.reds
	%tests/wire-atomic-test.red
	%tests/wire-memory-aggregate-test.red
	%tests/wire-scalar-operation-test.red
	%tests/wire-constant-initializer-test.red
	%tests/wire-symbol-linkage-test.red
	%tests/wire-function-signature-test.red
	%tests/wire-module-lifecycle-test.red
	%tests/wire-type-layout-test.red
	%tests/wire-data-layout-test.red
	%tests/wire-file-source-test.red
	%tests/wire-string-table-test.red
	%tests/wire-container-test.red
][append source-bytes read source-file]
append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
source-digest: enbase/base checksum source-bytes 'SHA256 16

output: make string! 262144
append output {Red [
	Title: "Hybrid codegen routine bridge integration tests"
]

; Generated by tools/self_hosting/generate-codegen-bridge-fixtures.red.
; Do not edit. Inputs and exact native outputs are frozen by the Red corpus.
}
append output rejoin ["; Fixture source SHA256: " source-digest newline newline]
append output {#include %../../../compiler/int-to-bin.red
#include %../../../compiler/wire-schema.red
#include %../../../compiler/wire-writer.red
#include %../../../compiler/rsir-producer.red
#include %../../../compiler/codegen-bridge.red

}
append-fixture output "empty-rsir" empty-rsir
append-fixture output "string-rsir" string-rsir
append-fixture output "minimal-function-rsir" minimal-function-rsir
append-fixture output "glue-function-rsir" glue-function-rsir
append-fixture output "late-name-glue-rsir" late-name-glue-rsir
append-fixture output "full-atomic-rsir" full-atomic-rsir
append-fixture output "invalid-atomic-rsir" invalid-atomic-rsir
append-fixture output "full-memory-rsir" full-memory-rsir
append-fixture output "invalid-memory-rsir" invalid-memory-rsir
append-fixture output "invalid-container-rsir" invalid-container-rsir
append-fixture output "invalid-semantic-rsir" invalid-semantic-rsir
append-fixture output "mismatched-rsir" mismatched-rsir
append-fixture output "base-config" base-config
append-fixture output "no-diagnostic-config" no-diagnostic-config
append-fixture output "minimum-output-config" minimum-output-config
append-fixture output "unsupported-config" unsupported-config
append-fixture output "expected-empty-rscg" expected-empty-rscg
append-fixture output "expected-function-rscg" expected-function-rscg
append-fixture output "expected-glue-rscg" expected-glue-rscg
append-fixture output "expected-late-name-glue-rscg" expected-late-name-glue-rscg
append-fixture output "expected-invalid-decode" expected-invalid-decode
append-fixture output "expected-invalid-verify" expected-invalid-verify
append-fixture output "expected-target-mismatch" expected-target-mismatch
append-fixture output "expected-nonempty-failure" expected-nonempty-failure
append-fixture output "expected-output-limit" expected-output-limit

append output {
STATUS-SUCCESS:               0
STATUS-INVALID-ARGUMENTS:     1
STATUS-INVALID-CONFIGURATION: 2
STATUS-INVALID-RSIR:          3
STATUS-UNSUPPORTED-TARGET:    4
STATUS-CODEGEN-FAILURE:       5

check: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

check-success: func [
	name [string!]
	ir config expected-artifact [binary!]
	/local ir-before config-before ir-index config-index artifact diagnostics status
][
	ir-before: copy ir
	config-before: copy config
	ir-index: index? ir
	config-index: index? config
	artifact: make binary! 1
	diagnostics: make binary! 1
	status: codegen-module ir config artifact diagnostics
	check status = STATUS-SUCCESS [name " status=" status]
	unless artifact = expected-artifact [
		print [name " artifact length=" length? artifact
			" expected-length=" length? expected-artifact]
		print ["actual=" mold/flat artifact]
		print ["expected=" mold/flat expected-artifact]
		quit/return 1
	]
	check empty? diagnostics [name " emitted diagnostics on success"]
	check all [
		ir = ir-before
		config = config-before
		(index? ir) = ir-index
		(index? config) = config-index
	][name " mutated an input series"]
]

check-failure: func [
	name [string!]
	ir config [binary!]
	expected-status [integer!]
	expected-diagnostics [binary!]
	/local ir-before config-before ir-index config-index artifact diagnostics status
][
	ir-before: copy ir
	config-before: copy config
	ir-index: index? ir
	config-index: index? config
	artifact: make binary! 1
	diagnostics: make binary! 1
	status: codegen-module ir config artifact diagnostics
	check status = expected-status [
		name " expected status=" expected-status " actual=" status
	]
	check empty? artifact [name " committed a partial artifact"]
	check diagnostics = expected-diagnostics [name " diagnostic bytes changed"]
	check all [
		ir = ir-before
		config = config-before
		(index? ir) = ir-index
		(index? config) = config-index
	][name " mutated an input series"]
]

check-invalid-alias: func [
	name [string!]
	ir config artifact diagnostics [binary!]
	/local ir-before config-before artifact-before diagnostics-before
		ir-index config-index artifact-index diagnostics-index status
][
	ir-before: copy ir
	config-before: copy config
	artifact-before: copy artifact
	diagnostics-before: copy diagnostics
	ir-index: index? ir
	config-index: index? config
	artifact-index: index? artifact
	diagnostics-index: index? diagnostics
	status: codegen-module ir config artifact diagnostics
	check status = STATUS-INVALID-ARGUMENTS [name " alias was accepted"]
	check all [
		ir = ir-before
		config = config-before
		artifact = artifact-before
		diagnostics = diagnostics-before
		(index? ir) = ir-index
		(index? config) = config-index
		(index? artifact) = artifact-index
		(index? diagnostics) = diagnostics-index
	][name " alias rejection mutated a series"]
]

check-success "empty module" copy empty-rsir copy base-config expected-empty-rscg
check-success "minimal void function" copy minimal-function-rsir copy base-config
	expected-function-rscg
check-success "minimal glue entry" copy glue-function-rsir copy base-config
	expected-glue-rscg
check-success "late-name glue symbol remap" copy late-name-glue-rsir copy base-config
	expected-late-name-glue-rscg

produced-minimal-function-rsir: compiler-rsir-producer/build-empty-void-module
	none "fn"
	compiler-wire-schema/WIRE_MODULE_KIND_USER
	compiler-wire-schema/WIRE_IMAGE_KIND_EXECUTABLE
check binary? produced-minimal-function-rsir
	"compiled Red RSIR producer rejected its supported module"
check produced-minimal-function-rsir = minimal-function-rsir
	"compiled Red RSIR producer differs from the independent fixture"
check-success "frontend-produced minimal void function"
	produced-minimal-function-rsir copy base-config expected-function-rscg

produced-glue-function-rsir: compiler-rsir-producer/build-empty-void-module
	none "fn"
	compiler-wire-schema/WIRE_MODULE_KIND_GLUE
	compiler-wire-schema/WIRE_IMAGE_KIND_EXECUTABLE
check binary? produced-glue-function-rsir
	"compiled Red RSIR producer rejected its glue module"
check produced-glue-function-rsir = glue-function-rsir
	"compiled Red RSIR glue producer differs from the independent fixture"
check-success "frontend-produced minimal glue entry"
	produced-glue-function-rsir copy base-config expected-glue-rscg

produced-late-name-glue-rsir: compiler-rsir-producer/build-empty-void-module
	none "zz-entry"
	compiler-wire-schema/WIRE_MODULE_KIND_GLUE
	compiler-wire-schema/WIRE_IMAGE_KIND_EXECUTABLE
check binary? produced-late-name-glue-rsir
	"compiled Red RSIR producer rejected its late-name glue module"
check produced-late-name-glue-rsir = late-name-glue-rsir
	"compiled Red RSIR late-name glue producer differs from the independent fixture"
check-success "frontend-produced late-name glue entry"
	produced-late-name-glue-rsir copy base-config expected-late-name-glue-rscg

ir-storage: copy #{A5}
append ir-storage empty-rsir
ir-at-offset: next ir-storage
config-storage: copy #{5A}
append config-storage base-config
config-at-offset: next config-storage
check-success "nonzero input heads" ir-at-offset config-at-offset expected-empty-rscg
check all [ir-storage/1 = 165 config-storage/1 = 90]
	"nonzero-head success mutated input prefixes"

check-failure "invalid configuration"
	copy empty-rsir #{} STATUS-INVALID-CONFIGURATION #{}
check-failure "unsupported configuration target"
	copy empty-rsir copy unsupported-config STATUS-UNSUPPORTED-TARGET #{}
check-failure "truncated RSIR"
	copy invalid-container-rsir copy base-config STATUS-INVALID-RSIR
	expected-invalid-decode
check-failure "invalid RSIR semantics"
	copy invalid-semantic-rsir copy base-config STATUS-INVALID-RSIR
	expected-invalid-verify
check-failure "RSIR/config target mismatch"
	copy mismatched-rsir copy base-config STATUS-UNSUPPORTED-TARGET
	expected-target-mismatch
check-failure "valid full atomic module"
	copy full-atomic-rsir copy base-config STATUS-CODEGEN-FAILURE
	expected-nonempty-failure
check-failure "invalid atomic semantics"
	copy invalid-atomic-rsir copy base-config STATUS-INVALID-RSIR
	expected-invalid-verify
check-failure "valid full memory module"
	copy full-memory-rsir copy base-config STATUS-CODEGEN-FAILURE
	expected-nonempty-failure
check-failure "invalid memory semantics"
	copy invalid-memory-rsir copy base-config STATUS-INVALID-RSIR
	expected-invalid-verify
check-failure "bounded output arena"
	copy string-rsir copy minimum-output-config STATUS-CODEGEN-FAILURE
	expected-output-limit
check-failure "diagnostics disabled"
	copy invalid-semantic-rsir copy no-diagnostic-config STATUS-INVALID-RSIR #{}

ir: copy empty-rsir
config: copy base-config
artifact: copy #{A5}
diagnostics: make binary! 1
artifact-before: copy artifact
status: codegen-module ir config artifact diagnostics
check status = STATUS-INVALID-ARGUMENTS "nonempty artifact was accepted"
check all [artifact = artifact-before empty? diagnostics]
	"nonempty artifact rejection mutated outputs"

ir: copy empty-rsir
config: copy base-config
artifact-storage: copy #{A5}
artifact: next artifact-storage
diagnostics: make binary! 1
artifact-index: index? artifact
status: codegen-module ir config artifact diagnostics
check status = STATUS-INVALID-ARGUMENTS "nonzero artifact head was accepted"
check all [tail? artifact (index? artifact) = artifact-index empty? diagnostics]
	"nonzero artifact head rejection mutated outputs"

ir: copy empty-rsir
config: copy base-config
artifact: make binary! 1
diagnostics-storage: copy #{5A}
diagnostics: next diagnostics-storage
diagnostics-index: index? diagnostics
status: codegen-module ir config artifact diagnostics
check status = STATUS-INVALID-ARGUMENTS "nonzero diagnostic head was accepted"
check all [empty? artifact tail? diagnostics (index? diagnostics) = diagnostics-index]
	"nonzero diagnostic head rejection mutated outputs"

shared: copy empty-rsir
check-invalid-alias "ir/config" shared shared (make binary! 1) (make binary! 1)
shared: copy empty-rsir
check-invalid-alias "ir/artifact" shared (copy base-config) shared (make binary! 1)
shared: copy empty-rsir
check-invalid-alias "ir/diagnostics" shared (copy base-config) (make binary! 1) shared
shared: copy base-config
check-invalid-alias "config/artifact" (copy empty-rsir) shared shared (make binary! 1)
shared: copy base-config
check-invalid-alias "config/diagnostics" (copy empty-rsir) shared (make binary! 1) shared
shared: make binary! 1
check-invalid-alias "artifact/diagnostics"
	(copy empty-rsir) (copy base-config) shared shared

recycle/on
repeat iteration 16 [
	recycle
	check-success "forced-GC repeated call" copy empty-rsir copy base-config
		expected-empty-rscg
]
recycle/off

print "PASS: hybrid codegen routine bridge integration"
}

write/binary %tests/codegen-bridge-integration.red to binary! output
print [
	"Generated tools/self_hosting/tests/codegen-bridge-integration.red"
	"bytes=" length? output
	"digest=" source-digest
]
