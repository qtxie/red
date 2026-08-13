Red [
	Title: "Hybrid compiler wire schema tests"
]

do %../../../compiler/wire-schema-spec.red
do %../../../compiler/wire-schema-generator.red

assert: func [condition [logic!] message [string!]][
	unless condition [
		print ["FAIL:" message]
		quit/return 1
	]
]

generator: compiler-wire-schema-generator
assert generator/validate compiler-wire-schema-spec "schema validation failed"
assert (generator/fingerprint-from-digest #{00000000}) = 0
	"zero fingerprint vector changed"
assert (generator/fingerprint-from-digest #{01020304}) = 16909060
	"ordinary fingerprint vector changed"
assert (generator/fingerprint-from-digest #{80000000}) = 0
	"fingerprint high bit was not cleared"
assert (generator/fingerprint-from-digest #{FFFFFFFF}) = 2147483647
	"maximum fingerprint vector changed"

expected-red: generator/render-red compiler-wire-schema-spec
expected-reds: generator/render-reds compiler-wire-schema-spec
assert expected-red = to string! read %../../../compiler/wire-schema.red
	"generated Red constants are stale"
assert expected-reds = to string! read %../../../system/codegen/wire-schema.reds
	"generated Red/System constants are stale"

do %../../../compiler/wire-schema.red
foreach [name value] generator/constants compiler-wire-schema-spec [
	field: in compiler-wire-schema name
	assert not none? field rejoin ["missing generated Red constant: " name]
	assert (get field) = value rejoin ["wrong generated Red constant: " name]
]

assert compiler-wire-schema/WIRE_HEADER_SIZE = 64 "wrong common header size"
assert compiler-wire-schema/WIRE_DIRECTORY_SIZE = 32 "wrong directory size"
assert compiler-wire-schema/WIRE_MAGIC_RSIR = 1380537170 "wrong RSIR magic encoding"
assert compiler-wire-schema/WIRE_RSIR_REQUIRED_SECTION_COUNT = 30
	"wrong RSIR required section count"
assert compiler-wire-schema/WIRE_RSCG_REQUIRED_SECTION_COUNT = 16
	"wrong RSCG required section count"
assert compiler-wire-schema/WIRE_RSCG_KNOWN_SECTION_COUNT = 17
	"wrong RSCG known section count"
assert compiler-wire-schema/WIRE_RSCF_MINIMUM_SIZE = 160
	"wrong minimum RSCF size"
assert compiler-wire-schema/WIRE_RSIR_MINIMUM_SIZE = 1088
	"wrong minimum RSIR size"
assert compiler-wire-schema/WIRE_RSCG_MINIMUM_SIZE = 640
	"wrong minimum RSCG size"
assert compiler-wire-schema/WIRE_RSDG_MINIMUM_SIZE = 212
	"wrong minimum RSDG size"
assert compiler-wire-schema/WIRE_RSIR_SECTION_STRING_DATA_ALIGNMENT = 1
	"wrong byte-section alignment"
assert compiler-wire-schema/WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA = 6
	"wrong RSIR checksum-data section ID"
assert compiler-wire-schema/WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA = 12
	"wrong RSCG checksum-data section ID"
assert compiler-wire-schema/WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA_ALIGNMENT = 1
	"wrong checksum byte-section alignment"
assert compiler-wire-schema/WIRE_CHECKSUM_KIND_SHA256 = 1
	"wrong SHA-256 checksum kind"
assert compiler-wire-schema/WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE = 22
	"file/source error enum changed"
assert compiler-wire-schema/WIRE_DIAGNOSTIC_ERROR_CONTEXT_WITHOUT_TARGET = 23
	"diagnostic error enum changed"
assert compiler-wire-schema/WIRE_DIAGNOSTIC_FLAG_INSTRUCTION = 8
	"diagnostic flag enum changed"
assert compiler-wire-schema/WIRE_TYPE_KIND_UNION = 8
	"type kind enum changed"
assert compiler-wire-schema/WIRE_TYPE_FLAG_C_STRING = 4
	"type flag enum changed"
assert compiler-wire-schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_RESERVED = 26
	"type-layout error enum changed"
assert compiler-wire-schema/WIRE_MODULE_KIND_GLUE = 4
	"module-kind enum changed"
assert compiler-wire-schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY = 2
	"image-kind enum changed"
assert compiler-wire-schema/WIRE_MODULE_LIFECYCLE_ERROR_LIFECYCLE_SYMBOL_OWNER = 22
	"module-lifecycle error enum changed"
assert compiler-wire-schema/WIRE_DEBUG_TYPE_CODE_AGGREGATE = 100
	"runtime aggregate debug type code changed"
assert compiler-wire-schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_COVERAGE = 54
	"function/signature error enum changed"
assert compiler-wire-schema/WIRE_CONSTANT_KIND_ADDRESS = 5
	"constant kind enum changed"
assert compiler-wire-schema/WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS = 4
	"constant part kind enum changed"
assert compiler-wire-schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_PLACEHOLDER = 66
	"constant/initializer error enum changed"
assert compiler-wire-schema/WIRE_RSIR_CONSTANT_BINDING_SIZE = 8
	"constant binding record size changed"
assert none? in compiler-wire-schema 'WIRE_FUNCTION_FLAG_RED_INTERNAL
	"legacy frontend red-internal state leaked into the wire ABI"
assert compiler-wire-schema/WIRE_RSIR_TYPE_SIZE = 40
	"type record size changed"
assert compiler-wire-schema/WIRE_RSIR_TYPE_RESERVED_0_OFFSET = 16
	"first type reserved word moved"
assert compiler-wire-schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET = 20
	"type detail ID moved"
assert compiler-wire-schema/WIRE_RSIR_TYPE_RESERVED_1_OFFSET = 24
	"second type reserved word moved"
assert none? in compiler-wire-schema 'WIRE_TYPE_KIND_ARRAY
	"source literal-array state leaked into the wire type domain"
assert none? in compiler-wire-schema 'WIRE_TYPE_KIND_OPAQUE
	"machine-IR opaque state leaked into the wire type domain"
assert none? in compiler-wire-schema 'WIRE_TYPE_FLAG_NOMINAL
	"source alias identity leaked into representation flags"
assert compiler-wire-schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_REQUIRED = 0
	"RSCG unwind section must be optional"
assert compiler-wire-schema/WIRE_RSCG_SECTION_MODULES_CARDINALITY =
	compiler-wire-schema/WIRE_SECTION_CARDINALITY_NONEMPTY
	"RSCG modules must be nonempty"
assert compiler-wire-schema/WIRE_RSDG_SECTION_DIAGNOSTICS_CARDINALITY =
	compiler-wire-schema/WIRE_SECTION_CARDINALITY_NONEMPTY
	"RSDG diagnostics must be nonempty"
assert compiler-wire-schema/profiles/RSIR/required-count = 30
	"generated Red RSIR profile is stale"
assert compiler-wire-schema/profiles/RSCG/known-count = 17
	"generated Red RSCG profile is stale"
assert compiler-wire-schema/profiles/RSCG/record-sizes/15 =
	compiler-wire-schema/WIRE_RSCG_SECTION_GC_FRAMES_RECORD_SIZE
	"generated Red required profile record size disagrees with constants"
assert compiler-wire-schema/profiles/RSCG/record-sizes/17 =
	compiler-wire-schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_RECORD_SIZE
	"generated Red profile record size disagrees with constants"
assert compiler-wire-schema/profiles/RSDG/cardinalities/3 =
	compiler-wire-schema/WIRE_SECTION_CARDINALITY_NONEMPTY
	"generated Red profile cardinality disagrees with constants"
assert compiler-wire-schema/profiles/RSDG/cardinalities/1 =
	compiler-wire-schema/WIRE_SECTION_CARDINALITY_NONEMPTY
	"RSDG strings must be nonempty"
assert compiler-wire-schema/profiles/RSDG/cardinalities/2 =
	compiler-wire-schema/WIRE_SECTION_CARDINALITY_NONEMPTY
	"RSDG string data must be nonempty"
assert compiler-wire-schema/WIRE_SCHEMA_FINGERPRINT = generator/fingerprint compiler-wire-schema-spec
	"wrong schema fingerprint"

assert-rejected: func [bad [block!] message [string!] /constants /local error][
	error: try [either constants [generator/constants bad][generator/validate bad]]
	assert error? error message
]

bad: copy/deep compiler-wire-schema-spec
header: select select bad 'records 'HEADER
field: find select header 'fields 'TOTAL_SIZE
field/2: 63
assert-rejected bad "overlapping/out-of-bounds field was accepted"

bad: copy/deep compiler-wire-schema-spec
repend select bad 'enums ['TARGET copy []]
assert-rejected bad "duplicate enum group was accepted"

bad: copy/deep compiler-wire-schema-spec
header: select select bad 'records 'HEADER
fields: select header 'fields
fields/4: 'MAGIC
assert-rejected bad "duplicate record field was accepted"

bad: copy/deep compiler-wire-schema-spec
repend bad ['unexpected copy []]
assert-rejected bad "unknown top-level schema section was accepted"

bad: copy/deep compiler-wire-schema-spec
append select bad 'enums reduce [
	'HEADER reduce ['SIZE 99]
]
assert-rejected/constants bad "generated constant collision was accepted"

bad: copy/deep compiler-wire-schema-spec
profile: select select bad 'profiles 'RSIR
entry: find profile 'TYPES
entry/2: 'MISSING_RECORD
assert-rejected bad "unknown profile record was accepted"

bad: copy/deep compiler-wire-schema-spec
profile: select select bad 'profiles 'RSIR
remove/part find profile 'EXCEPTION_BLOCKS 5
assert-rejected bad "incomplete section profile was accepted"

bad: copy/deep compiler-wire-schema-spec
profile: select select bad 'profiles 'RSIR
entry: find profile 'MODULE
entry/3: 'OPTIONAL
assert-rejected bad "required section after optional section was accepted"

bad: copy/deep compiler-wire-schema-spec
profile: select select bad 'profiles 'RSIR
entry: find profile 'MODULE
entry/5: 3
assert-rejected bad "non-power-of-two section alignment was accepted"

print [
	"PASS: compiler wire schema"
	compiler-wire-schema/WIRE_SCHEMA_FINGERPRINT
]
