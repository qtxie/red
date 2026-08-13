Red [
	Title: "Hybrid compiler RSIR function and signature tests"
]

do %wire-type-layout-test.red
do %../../../compiler/wire-function-signature.red

function-signature-verifier: compiler-wire-function-signature

build-function-signature-message: func [
	string-records string-data type-records field-records
	signature-records parameter-records
	symbol-records function-records local-records block-records
	/local payloads sections
][
	payloads: make map! 48
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [1 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS string-records
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA string-data
	put payloads schema/WIRE_RSIR_SECTION_TYPES type-records
	put payloads schema/WIRE_RSIR_SECTION_FIELDS field-records
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES signature-records
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS parameter-records
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS symbol-records
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS function-records
	put payloads schema/WIRE_RSIR_SECTION_LOCALS local-records
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS block-records
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_STRINGS
		string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		file-source-verifier/expected-index-flags
	fixture-writer/build
		schema/WIRE_MAGIC_RSIR
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

function-string-records: fixture-writer/words [
	0 0
	0 1
	1 1
	2 1
	3 1
	4 1
]
function-string-data: to binary! "abcde"

; void, signed i32, byte, pointer-to-i32, function-pointer-to-signature 1.
function-types: fixture-writer/words [
	1 0 0 0 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	5 0 8 8 0 2 0 0 0 1
	6 0 8 8 0 1 0 0 0 1
]

basic-function-message: build-function-signature-message
	function-string-records
	function-string-data
	function-types
	#{}
	fixture-writer/words [
		; cc flags return first count logical source reserved
		1 0 2 1 1 1 0 0
	]
	fixture-writer/words [
		; signature name type flags ordinal debug source reserved
		1 2 2 0 0 2 0 0
	]
	fixture-writer/words [
		; name kind linkage visibility type/signature flags owner source
		3 1 2 1 1 0 0 0
	]
	fixture-writer/words [
		; symbol signature flags first-block count entry first-local count source reserved
		1 1 0 1 1 1 1 1 0 0
	]
	fixture-writer/words [
		; function name type kind flags align source ordinal
		1 2 2 1 0 0 0 0
	]
	fixture-writer/words [
		; function flags first-insn insn-count first-edge edge-count source reserved
		1 0 0 0 0 0 0 0
	]

empty-function-message: build-function-signature-message
	fixture-writer/words [0 0] #{}
	#{} #{} #{} #{} #{} #{} #{} #{}

variable-function-message: build-function-signature-message
	function-string-records
	function-string-data
	function-types
	#{}
	fixture-writer/words [
		; ordinary, private typed, private variadic, C variadic, custom,
		; callback, derived control properties, and syscall.
		1 0 2 1 1 1 0 0
		1 2 2 2 2 0 0 0
		3 1 2 4 3 0 0 0
		2 1 2 7 1 1 0 0
		2 4 2 0 0 0 0 0
		2 8 2 8 1 1 0 0
		1 96 1 0 0 0 0 0
		4 0 2 0 0 0 0 0
	]
	fixture-writer/words [
		1 2 2 0 0 2 0 0
		2 4 2 0 0 2 0 0
		2 5 4 0 1 7 0 0
		3 4 2 0 0 2 0 0
		3 5 4 0 1 7 0 0
		3 6 2 0 2 2 0 0
		4 2 4 0 0 7 0 0
		6 2 2 0 0 2 0 0
	]
	#{} #{} #{} #{}

two-function-message: build-function-signature-message
	function-string-records function-string-data function-types #{}
	fixture-writer/words [1 0 2 1 1 1 0 0]
	fixture-writer/words [1 2 2 0 0 2 0 0]
	fixture-writer/words [
		3 1 2 1 1 0 0 0
		4 1 2 1 1 0 0 0
	]
	fixture-writer/words [
		1 1 0 1 1 1 1 2 0 0
		2 1 0 2 1 2 3 2 0 0
	]
	fixture-writer/words [
		1 2 2 1 0 0 0 0
		1 0 2 3 0 4 0 1
		2 2 2 1 0 0 0 0
		2 0 2 4 0 0 0 1
	]
	fixture-writer/words [
		1 0 0 0 0 0 0 0
		2 0 0 0 0 0 0 0
	]

debug-types: fixture-writer/words [
	; void, logic, signed/unsigned integers, floats, pointer families,
	; function, one aggregate, and a pointer to that aggregate.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 1 1 1 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	3 1 2 2 0 0 0 0 0 0
	3 0 2 2 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 0 4 4 0 0 0 0 0 0
	3 1 8 8 0 0 0 0 0 0
	3 0 8 8 0 0 0 0 0 0
	4 0 4 4 0 0 0 0 0 0
	4 0 8 8 0 0 0 0 0 0
	5 4 8 8 0 4 0 0 0 1
	5 0 8 8 0 4 0 0 0 1
	5 0 8 8 0 7 0 0 0 1
	5 0 8 8 0 14 0 0 0 1
	6 0 8 8 0 1 0 0 0 1
	7 0 4 4 0 0 0 1 1 0
	5 0 8 8 0 18 0 0 0 1
]
debug-fields: fixture-writer/words [18 3 7 0 0 0 0 0]
debug-parameter-types-and-codes: [
	2 1
	3 13
	4 3
	4 14
	5 15
	6 16
	7 2
	8 17
	9 11
	10 12
	11 4
	12 5
	13 6
	14 7
	15 8
	16 10
	17 9
	18 100
	19 100
]
debug-parameter-values: make block! 160
debug-ordinal: 0
foreach [debug-type debug-code] debug-parameter-types-and-codes [
	repend debug-parameter-values [
		1 2 debug-type 0 debug-ordinal debug-code 0 0
	]
	debug-ordinal: debug-ordinal + 1
]
debug-code-message: build-function-signature-message
	function-string-records function-string-data debug-types debug-fields
	fixture-writer/words [1 0 1 1 19 19 0 0]
	fixture-writer/words debug-parameter-values
	#{} #{} #{} #{}

protocol-types: fixture-writer/words [
	1 0 0 0 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	5 0 8 8 0 2 0 0 0 1
]
protocol-prefix-message: build-function-signature-message
	function-string-records function-string-data protocol-types #{}
	fixture-writer/words [
		1 2 2 0 0 0 0 0
		1 2 2 1 1 0 0 0
		1 2 2 2 2 0 0 0
		3 1 2 0 0 0 0 0
		3 1 2 4 1 0 0 0
		3 1 2 5 2 0 0 0
		3 1 2 7 3 0 0 0
		2 2 2 0 0 0 0 0
		2 2 2 10 1 0 0 0
		2 2 2 11 2 0 0 0
	]
	fixture-writer/words [
		2 2 2 0 0 2 0 0
		3 2 2 0 0 2 0 0
		3 3 3 0 1 8 0 0
		5 2 2 0 0 2 0 0
		6 2 2 0 0 2 0 0
		6 3 3 0 1 8 0 0
		7 2 2 0 0 2 0 0
		7 3 3 0 1 8 0 0
		7 4 2 0 2 2 0 0
		9 2 2 0 0 2 0 0
		10 2 2 0 0 2 0 0
		10 3 3 0 1 8 0 0
	]
	#{} #{} #{} #{}

valid-function-signatures: make block! 8
add-valid-function-signature: func [name [word!] data [binary!]][
	append/only valid-function-signatures reduce [name data]
]
add-valid-function-signature 'EMPTY empty-function-message
add-valid-function-signature 'BASIC basic-function-message
add-valid-function-signature 'VARIABLE variable-function-message
add-valid-function-signature 'TWO-FUNCTIONS two-function-message
add-valid-function-signature 'DEBUG-CODES debug-code-message
add-valid-function-signature 'PROTOCOL-PREFIXES protocol-prefix-message

result: function-signature-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/type-layout-error = schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
	none? result/strings none? result/files none? result/layout
	none? result/types none? result/view
] "non-binary function/signature input did not return INVALID_ARGUMENTS"

foreach fixture valid-function-signatures [
	result: function-signature-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid function/signature rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		object? result/strings object? result/files map? result/layout
		object? result/types object? result/view
	][fixture/1 " valid function/signature did not publish complete views"]
]

result: function-signature-verifier/verify basic-function-message
assert to logic! all [
	result/view/signature-count = 1
	result/view/parameter-count = 1
	result/view/symbol-count = 1
	result/view/function-count = 1
	result/view/local-count = 1
	result/view/block-count = 1
	result/view/source-location-count = 0
] "verified function/signature view changed"

malformed-function-signatures: make block! 768
add-malformed-function-signature: func [
	name [word!]
	expected-error expected-container expected-string expected-file expected-data-layout
	expected-type-layout expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-function-signatures reduce [
		name expected-error expected-container expected-string expected-file
		expected-data-layout expected-type-layout expected-offset expected-section data
	]
]

add-function-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-function-signature name expected-error
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		expected-offset expected-section data
]

function-section: func [data [binary!] kind [integer!] /local verified][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSIR
	assert verified/valid? "function/signature fixture is not a valid common container"
	container-verifier/find-section verified kind
]

function-record-offset: func [section [map!] id record-size [integer!]][
	(select section 'payload-offset) + ((id - 1) * record-size)
]

mutate-function-record: func [
	name [word!] source [binary!] section [map!]
	id record-size field-relative value expected-error expected-relative [integer!]
	/local bad base
][
	bad: copy source
	base: function-record-offset section id record-size
	fixture-mutations/put-u32 bad (base + field-relative) value
	add-function-semantic-error name expected-error
		(base + expected-relative) (select section 'ordinal) bad
]

basic-signatures-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_SIGNATURES
basic-parameters-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_PARAMETERS
basic-functions-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_FUNCTIONS
basic-locals-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_LOCALS
basic-blocks-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_BLOCKS
basic-types-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_TYPES
basic-source-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
basic-data-layout-section: function-section basic-function-message
	schema/WIRE_RSIR_SECTION_DATA_LAYOUT
basic-string-sections: string-sections basic-function-message schema/WIRE_MAGIC_RSIR
basic-string-data-section: basic-string-sections/2

basic-signature-offset: function-record-offset basic-signatures-section 1
	schema/WIRE_RSIR_SIGNATURE_SIZE
basic-parameter-offset: function-record-offset basic-parameters-section 1
	schema/WIRE_RSIR_PARAMETER_SIZE
basic-function-offset: function-record-offset basic-functions-section 1
	schema/WIRE_RSIR_FUNCTION_SIZE
basic-local-offset: function-record-offset basic-locals-section 1
	schema/WIRE_RSIR_LOCAL_SIZE
basic-block-offset: function-record-offset basic-blocks-section 1
	schema/WIRE_RSIR_BLOCK_SIZE

; Nested verifier failures retain their exact inner status and location.
bad: copy basic-function-message
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-function-signature 'INVALID-CONTAINER
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy basic-function-message
fixture-mutations/put-bytes bad (select basic-string-data-section 'payload-offset) #{80}
add-malformed-function-signature 'INVALID-STRINGS
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_STRINGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_INVALID_UTF8
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_STRINGS
	(select basic-string-data-section 'payload-offset)
	(select basic-string-data-section 'ordinal) bad

bad: copy basic-function-message
bad-offset: (select basic-source-section 'entry-offset)
	+ schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset 0
add-malformed-function-signature 'INVALID-FILE-SOURCE
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_FILE_SOURCE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_BAD_SOURCE_SECTION_FLAGS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_FILE_SOURCE
	bad-offset (select basic-source-section 'ordinal) bad

bad: copy basic-function-message
bad-offset: (select basic-data-layout-section 'payload-offset)
	+ schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET
fixture-mutations/put-u32 bad bad-offset 8
add-malformed-function-signature 'INVALID-DATA-LAYOUT
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_DATA_LAYOUT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_DATA_LAYOUT
	bad-offset (select basic-data-layout-section 'ordinal) bad

bad: copy basic-function-message
bad-offset: (function-record-offset basic-types-section 2 schema/WIRE_RSIR_TYPE_SIZE)
	+ schema/WIRE_RSIR_TYPE_KIND_OFFSET
fixture-mutations/put-u32 bad bad-offset 9
add-malformed-function-signature 'INVALID-TYPE-LAYOUT
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_TYPE_LAYOUT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_KIND
	bad-offset (select basic-types-section 'ordinal) bad

; These tables are unsorted semantic records, so every v1 section flag is zero.
foreach [name section expected-error] reduce [
	'BAD-SIGNATURE-SECTION-FLAGS basic-signatures-section
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_SECTION_FLAGS
	'BAD-PARAMETER-SECTION-FLAGS basic-parameters-section
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SECTION_FLAGS
	'BAD-FUNCTION-SECTION-FLAGS basic-functions-section
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SECTION_FLAGS
	'BAD-LOCAL-SECTION-FLAGS basic-locals-section
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_SECTION_FLAGS
	'BAD-BLOCK-SECTION-FLAGS basic-blocks-section
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_SECTION_FLAGS
][
	bad: copy basic-function-message
	bad-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
	add-function-semantic-error name expected-error bad-offset
		(select section 'ordinal) bad
]

; Every record scalar is signed-31-bit. Decode all of them before semantics.
foreach [prefix fields section record-size] reduce [
	"SIGNATURE" function-signature-verifier/signature-fields
		basic-signatures-section schema/WIRE_RSIR_SIGNATURE_SIZE
	"PARAMETER" function-signature-verifier/parameter-fields
		basic-parameters-section schema/WIRE_RSIR_PARAMETER_SIZE
	"FUNCTION" function-signature-verifier/function-fields
		basic-functions-section schema/WIRE_RSIR_FUNCTION_SIZE
	"LOCAL" function-signature-verifier/local-fields
		basic-locals-section schema/WIRE_RSIR_LOCAL_SIZE
	"BLOCK" function-signature-verifier/block-fields
		basic-blocks-section schema/WIRE_RSIR_BLOCK_SIZE
][
	foreach [field-name field-relative] fields [
		bad: copy basic-function-message
		bad-offset: (select section 'payload-offset) + field-relative
		fixture-mutations/put-bytes bad bad-offset #{00000080}
		add-function-semantic-error
			to word! rejoin ["SCALAR-" prefix "-" field-name]
			schema/WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
			bad-offset (select section 'ordinal) bad
	]
]

; Signature domains, ranges, logical arity, and source metadata.
mutate-function-record 'BAD-CALLING-CONVENTION basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_CALLING_CONVENTION
	schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
mutate-function-record 'UNKNOWN-SIGNATURE-FLAG basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET 16
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_FLAGS
	schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET

bad: copy basic-function-message
fixture-mutations/put-u32 bad
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
	schema/WIRE_CALLING_CONVENTION_CDECL
fixture-mutations/put-u32 bad
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(schema/WIRE_FUNCTION_FLAG_CALLBACK + schema/WIRE_FUNCTION_FLAG_TYPED)
add-function-semantic-error 'CALLBACK-VARIABLE-MODE
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_FLAGS
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(select basic-signatures-section 'ordinal) bad

mutate-function-record 'INTERNAL-CALLBACK basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET schema/WIRE_FUNCTION_FLAG_CALLBACK
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_FLAGS
	schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET

bad: copy basic-function-message
fixture-mutations/put-u32 bad
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
	schema/WIRE_CALLING_CONVENTION_SYSCALL
fixture-mutations/put-u32 bad
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	schema/WIRE_FUNCTION_FLAG_VARIADIC
add-function-semantic-error 'SYSCALL-VARIADIC
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_FLAGS
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(select basic-signatures-section 'ordinal) bad

mutate-function-record 'BAD-RETURN-TYPE basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_RETURN_TYPE
	schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
mutate-function-record 'BAD-PARAMETER-RANGE basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_RANGE
	schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
mutate-function-record 'PARAMETER-RANGE-OVERFLOW basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET 2147483647
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_RANGE
	schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
mutate-function-record 'BAD-LOGICAL-ARITY basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOGICAL_ARITY
	schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET
mutate-function-record 'BAD-SIGNATURE-SOURCE basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_SOURCE_LOCATION
	schema/WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET
mutate-function-record 'NONZERO-SIGNATURE-RESERVED basic-function-message
	basic-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
	schema/WIRE_RSIR_SIGNATURE_RESERVED_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_SIGNATURE_RESERVED
	schema/WIRE_RSIR_SIGNATURE_RESERVED_OFFSET

parameter-coverage-message: build-function-signature-message
	function-string-records function-string-data function-types #{}
	fixture-writer/words [1 0 2 0 0 0 0 0]
	fixture-writer/words [1 2 2 0 0 2 0 0]
	#{} #{} #{} #{}
parameter-coverage-section: function-section parameter-coverage-message
	schema/WIRE_RSIR_SECTION_PARAMETERS
add-function-semantic-error 'BAD-PARAMETER-COVERAGE
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_COVERAGE
	(select parameter-coverage-section 'payload-offset)
	(select parameter-coverage-section 'ordinal) parameter-coverage-message

; Parameter backreferences and source-level debug metadata.
mutate-function-record 'BAD-PARAMETER-SIGNATURE basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SIGNATURE
	schema/WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET
mutate-function-record 'BAD-PARAMETER-NAME basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_NAME_ID
	schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
mutate-function-record 'EMPTY-PARAMETER-NAME basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_EMPTY_PARAMETER_NAME
	schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
mutate-function-record 'BAD-PARAMETER-TYPE basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_TYPE
	schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
mutate-function-record 'NONZERO-PARAMETER-FLAGS basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_FLAGS_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_PARAMETER_FLAGS
	schema/WIRE_RSIR_PARAMETER_FLAGS_OFFSET
mutate-function-record 'BAD-PARAMETER-ORDINAL basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_ORDINAL_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_ORDINAL
	schema/WIRE_RSIR_PARAMETER_ORDINAL_OFFSET
mutate-function-record 'BAD-DEBUG-TYPE-CODE basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_DEBUG_TYPE_CODE
	schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET
mutate-function-record 'BAD-PARAMETER-SOURCE basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SOURCE_LOCATION
	schema/WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET
mutate-function-record 'NONZERO-PARAMETER-RESERVED basic-function-message
	basic-parameters-section 1 schema/WIRE_RSIR_PARAMETER_SIZE
	schema/WIRE_RSIR_PARAMETER_RESERVED_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_PARAMETER_RESERVED
	schema/WIRE_RSIR_PARAMETER_RESERVED_OFFSET

bad: copy basic-function-message
fixture-mutations/put-u32 bad
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	schema/WIRE_FUNCTION_FLAG_CUSTOM
fixture-mutations/put-u32 bad
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET) 0
add-function-semantic-error 'CUSTOM-HAS-PARAMETERS
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
	(basic-signature-offset + schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET)
	(select basic-signatures-section 'ordinal) bad

variable-signatures-section: function-section variable-function-message
	schema/WIRE_RSIR_SECTION_SIGNATURES
variable-parameters-section: function-section variable-function-message
	schema/WIRE_RSIR_SECTION_PARAMETERS

bad: copy variable-function-message
bad-offset: (function-record-offset variable-parameters-section 2
	schema/WIRE_RSIR_PARAMETER_SIZE) + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
fixture-mutations/put-u32 bad bad-offset 4
fixture-mutations/put-u32 bad
	((function-record-offset variable-parameters-section 2 schema/WIRE_RSIR_PARAMETER_SIZE)
		+ schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
	schema/WIRE_DEBUG_TYPE_CODE_BYTE_POINTER
add-function-semantic-error 'TYPED-BAD-COUNT-RECEIVER
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
	bad-offset (select variable-parameters-section 'ordinal) bad

bad: copy variable-function-message
bad-offset: (function-record-offset variable-parameters-section 3
	schema/WIRE_RSIR_PARAMETER_SIZE) + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
fixture-mutations/put-u32 bad bad-offset 2
fixture-mutations/put-u32 bad
	((function-record-offset variable-parameters-section 3 schema/WIRE_RSIR_PARAMETER_SIZE)
		+ schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
	schema/WIRE_DEBUG_TYPE_CODE_INTEGER
add-function-semantic-error 'TYPED-BAD-LIST-RECEIVER
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
	bad-offset (select variable-parameters-section 'ordinal) bad

bad: copy variable-function-message
bad-offset: (function-record-offset variable-parameters-section 6
	schema/WIRE_RSIR_PARAMETER_SIZE) + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
fixture-mutations/put-u32 bad bad-offset 4
fixture-mutations/put-u32 bad
	((function-record-offset variable-parameters-section 6 schema/WIRE_RSIR_PARAMETER_SIZE)
		+ schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
	schema/WIRE_DEBUG_TYPE_CODE_BYTE_POINTER
add-function-semantic-error 'VARIADIC-BAD-SIZE-RECEIVER
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
	bad-offset (select variable-parameters-section 'ordinal) bad

protocol-count-message: build-function-signature-message
	function-string-records function-string-data function-types #{}
	fixture-writer/words [1 2 2 1 3 0 0 0]
	fixture-writer/words [
		1 2 2 0 0 2 0 0
		1 3 4 0 1 7 0 0
		1 4 2 0 2 2 0 0
	]
	#{} #{} #{} #{}
protocol-count-signatures: function-section protocol-count-message
	schema/WIRE_RSIR_SECTION_SIGNATURES
add-function-semantic-error 'TYPED-TOO-MANY-RECEIVERS
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
	((select protocol-count-signatures 'payload-offset)
		+ schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET)
	(select protocol-count-signatures 'ordinal) protocol-count-message

protocol-prefix-parameters: function-section protocol-prefix-message
	schema/WIRE_RSIR_SECTION_PARAMETERS
bad: copy protocol-prefix-message
bad-offset: (function-record-offset protocol-prefix-parameters 10
	schema/WIRE_RSIR_PARAMETER_SIZE) + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
fixture-mutations/put-u32 bad bad-offset 3
fixture-mutations/put-u32 bad
	((function-record-offset protocol-prefix-parameters 10
		schema/WIRE_RSIR_PARAMETER_SIZE)
		+ schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
	schema/WIRE_DEBUG_TYPE_CODE_INTEGER_POINTER
add-function-semantic-error 'CDECL-TYPED-BAD-COUNT-RECEIVER
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
	bad-offset (select protocol-prefix-parameters 'ordinal) bad

; Function definitions partition block and local tables.
mutate-function-record 'BAD-FUNCTION-SYMBOL basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SYMBOL
	schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
mutate-function-record 'BAD-FUNCTION-SIGNATURE basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SIGNATURE
	schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
mutate-function-record 'NONZERO-FUNCTION-FLAGS basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_FLAGS_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_FUNCTION_FLAGS
	schema/WIRE_RSIR_FUNCTION_FLAGS_OFFSET
mutate-function-record 'BAD-FUNCTION-BLOCK-RANGE basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_BLOCK_RANGE
	schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
mutate-function-record 'BAD-FUNCTION-ENTRY-BLOCK basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_ENTRY_BLOCK
	schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
mutate-function-record 'BAD-FUNCTION-LOCAL-RANGE basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
	schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
mutate-function-record 'BAD-FUNCTION-SOURCE basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SOURCE_LOCATION
	schema/WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET
mutate-function-record 'NONZERO-FUNCTION-RESERVED basic-function-message
	basic-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
	schema/WIRE_RSIR_FUNCTION_RESERVED_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_FUNCTION_RESERVED
	schema/WIRE_RSIR_FUNCTION_RESERVED_OFFSET

two-functions-section: function-section two-function-message
	schema/WIRE_RSIR_SECTION_FUNCTIONS
two-locals-section: function-section two-function-message
	schema/WIRE_RSIR_SECTION_LOCALS
two-blocks-section: function-section two-function-message
	schema/WIRE_RSIR_SECTION_BLOCKS

bad: copy two-function-message
bad-offset: (function-record-offset two-functions-section 1
	schema/WIRE_RSIR_FUNCTION_SIZE) + schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
fixture-mutations/put-u32 bad bad-offset 2
add-function-semantic-error 'NONCONTIGUOUS-FUNCTION-LOCALS
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
	bad-offset (select two-functions-section 'ordinal) bad

block-coverage-message: build-function-signature-message
	fixture-writer/words [0 0] #{} #{} #{} #{} #{} #{} #{} #{}
	fixture-writer/words [0 0 0 0 0 0 0 0]
block-coverage-section: function-section block-coverage-message
	schema/WIRE_RSIR_SECTION_BLOCKS
add-function-semantic-error 'BAD-BLOCK-COVERAGE
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_COVERAGE
	(select block-coverage-section 'payload-offset)
	(select block-coverage-section 'ordinal) block-coverage-message

local-coverage-message: build-function-signature-message
	fixture-writer/words [0 0] #{} #{} #{} #{} #{} #{} #{}
	fixture-writer/words [0 0 0 0 0 0 0 0] #{}
local-coverage-section: function-section local-coverage-message
	schema/WIRE_RSIR_SECTION_LOCALS
add-function-semantic-error 'BAD-LOCAL-COVERAGE
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_COVERAGE
	(select local-coverage-section 'payload-offset)
	(select local-coverage-section 'ordinal) local-coverage-message

bad: copy two-function-message
bad-offset: (function-record-offset two-blocks-section 1
	schema/WIRE_RSIR_BLOCK_SIZE) + schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
fixture-mutations/put-u32 bad bad-offset 2
add-function-semantic-error 'BAD-BLOCK-OWNER
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_OWNER
	bad-offset (select two-blocks-section 'ordinal) bad

mutate-function-record 'NONZERO-BLOCK-FLAGS basic-function-message
	basic-blocks-section 1 schema/WIRE_RSIR_BLOCK_SIZE
	schema/WIRE_RSIR_BLOCK_FLAGS_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_BLOCK_FLAGS
	schema/WIRE_RSIR_BLOCK_FLAGS_OFFSET
mutate-function-record 'BAD-BLOCK-SOURCE basic-function-message
	basic-blocks-section 1 schema/WIRE_RSIR_BLOCK_SIZE
	schema/WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_SOURCE_LOCATION
	schema/WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET
mutate-function-record 'NONZERO-BLOCK-RESERVED basic-function-message
	basic-blocks-section 1 schema/WIRE_RSIR_BLOCK_SIZE
	schema/WIRE_RSIR_BLOCK_RESERVED_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_BLOCK_RESERVED
	schema/WIRE_RSIR_BLOCK_RESERVED_OFFSET

; Local ownership, naming, type, alignment, and argument-prefix identity.
bad: copy two-function-message
bad-offset: (function-record-offset two-locals-section 1
	schema/WIRE_RSIR_LOCAL_SIZE) + schema/WIRE_RSIR_LOCAL_FUNCTION_OFFSET
fixture-mutations/put-u32 bad bad-offset 2
add-function-semantic-error 'BAD-LOCAL-FUNCTION
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_FUNCTION
	bad-offset (select two-locals-section 'ordinal) bad

mutate-function-record 'BAD-LOCAL-NAME basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_NAME_ID
	schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET
mutate-function-record 'EMPTY-LOCAL-NAME basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_EMPTY_LOCAL_NAME
	schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET
mutate-function-record 'BAD-LOCAL-TYPE basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_TYPE_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_TYPE
	schema/WIRE_RSIR_LOCAL_TYPE_OFFSET
mutate-function-record 'BAD-LOCAL-KIND basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_KIND_OFFSET 0
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_KIND
	schema/WIRE_RSIR_LOCAL_KIND_OFFSET
mutate-function-record 'NONZERO-LOCAL-FLAGS basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_FLAGS_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_LOCAL_FLAGS
	schema/WIRE_RSIR_LOCAL_FLAGS_OFFSET
mutate-function-record 'BAD-LOCAL-ALIGNMENT basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET 2
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_ALIGNMENT
	schema/WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET
mutate-function-record 'BAD-LOCAL-SOURCE basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_SOURCE_LOCATION
	schema/WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET
mutate-function-record 'BAD-LOCAL-ORDINAL basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_ORDINAL_OFFSET 1
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_ORDINAL
	schema/WIRE_RSIR_LOCAL_ORDINAL_OFFSET
mutate-function-record 'ARGUMENT-LOCAL-KIND basic-function-message
	basic-locals-section 1 schema/WIRE_RSIR_LOCAL_SIZE
	schema/WIRE_RSIR_LOCAL_KIND_OFFSET schema/WIRE_LOCAL_KIND_LOCAL
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
	schema/WIRE_RSIR_LOCAL_KIND_OFFSET

missing-argument-local-message: build-function-signature-message
	function-string-records function-string-data function-types #{}
	fixture-writer/words [1 0 2 1 1 1 0 0]
	fixture-writer/words [1 2 2 0 0 2 0 0]
	fixture-writer/words [3 1 2 1 1 0 0 0]
	fixture-writer/words [1 1 0 1 1 1 0 0 0 0]
	#{}
	fixture-writer/words [1 0 0 0 0 0 0 0]
missing-argument-functions: function-section missing-argument-local-message
	schema/WIRE_RSIR_SECTION_FUNCTIONS
add-function-semantic-error 'MISSING-ARGUMENT-LOCAL
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
	((select missing-argument-functions 'payload-offset)
		+ schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET)
	(select missing-argument-functions 'ordinal) missing-argument-local-message

foreach fixture malformed-function-signatures [
	result: function-signature-verifier/verify fixture/10
	assert not result/valid? [fixture/1 " malformed function/signature was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
	]
	assert result/container-error = fixture/3 [fixture/1 " wrong container error"]
	assert result/string-error = fixture/4 [fixture/1 " wrong string error"]
	assert result/file-source-error = fixture/5 [fixture/1 " wrong file/source error"]
	assert result/data-layout-error = fixture/6 [fixture/1 " wrong data-layout error"]
	assert result/type-layout-error = fixture/7 [fixture/1 " wrong type-layout error"]
	assert to logic! all [result/error-offset = fixture/8 result/error-section = fixture/9][
		fixture/1 " wrong error location " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/view
	][fixture/1 " published output views on failure"]
]

covered-function-errors: reduce [
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-function-signatures [
	unless find covered-function-errors fixture/2 [append covered-function-errors fixture/2]
]
repeat index 55 [
	assert not none? find covered-function-errors (index - 1) [
		"function/signature error code lacks executable coverage: " index - 1
	]
]

unless value? 'generating-wire-function-signature-fixtures? [
	source-bytes: make binary! 524288
	append source-bytes read %wire-function-signature-test.red
	append source-bytes read %wire-type-layout-test.red
	append source-bytes read %wire-file-source-test.red
	append source-bytes read %wire-string-table-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-function-signature-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-function-signature-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System function/signature fixtures are stale"
	print [
		"PASS: RSIR function/signature semantics"
		length? valid-function-signatures "valid"
		length? malformed-function-signatures "malformed"
	]
]
