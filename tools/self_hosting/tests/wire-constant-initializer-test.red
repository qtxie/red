Red [
	Title: "Hybrid compiler RSIR constant and global-initializer tests"
]

do %wire-symbol-linkage-test.red
do %../../../compiler/wire-constant-initializer.red

constant-initializer-verifier: compiler-wire-constant-initializer

build-constant-initializer-message: func [
	module-records string-records string-data type-records field-records
	signature-records parameter-records symbol-records constant-records
	constant-data part-records binding-records global-records import-records
	export-records function-records local-records block-records
	/local payloads sections
][
	payloads: make map! 64
	put payloads schema/WIRE_RSIR_SECTION_MODULE module-records
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS string-records
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA string-data
	put payloads schema/WIRE_RSIR_SECTION_TYPES type-records
	put payloads schema/WIRE_RSIR_SECTION_FIELDS field-records
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES signature-records
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS parameter-records
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS symbol-records
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS constant-records
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA constant-data
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_PARTS part-records
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS binding-records
	put payloads schema/WIRE_RSIR_SECTION_GLOBALS global-records
	put payloads schema/WIRE_RSIR_SECTION_IMPORTS import-records
	put payloads schema/WIRE_RSIR_SECTION_EXPORTS export-records
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS function-records
	put payloads schema/WIRE_RSIR_SECTION_LOCALS local-records
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS block-records
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_STRINGS
		string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		file-source-verifier/expected-index-flags
	foreach kind reduce [
		schema/WIRE_RSIR_SECTION_SYMBOLS
		schema/WIRE_RSIR_SECTION_IMPORTS
		schema/WIRE_RSIR_SECTION_EXPORTS
	][
		fixture-writer/set-section-flags sections kind
			symbol-linkage-verifier/expected-index-flags
	]
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		constant-initializer-verifier/expected-index-flags
	fixture-writer/build
		schema/WIRE_MAGIC_RSIR
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

empty-constant-message: build-constant-initializer-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	#{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{}

constant-strings: make-canonical-strings [
	"" "c-scalar" "c-storage" "fn" "global" "i" "p" "t-i" "t-p" "u-f" "u-i"
]
constant-id: :symbol-string-id

constant-types: fixture-writer/words [
	; void, u8, i32, logic, f64, ptr-u8, c-string, ptr-i32, function pointer.
	1 0 0 0 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	4 0 8 8 0 0 0 0 0 0
	5 0 8 8 0 2 0 0 0 1
	5 4 8 8 0 2 0 0 0 1
	5 0 8 8 0 3 0 0 0 1
	6 0 8 8 0 1 0 0 0 1
	; struct {i32, c-string}, raw union {i32, f64}, tagged union {i32, c-string}.
	7 0 16 8 0 0 0 1 2 0
	8 0 8 8 0 0 0 3 2 0
	8 2 16 8 0 2 0 5 2 0
]

constant-fields: fixture-writer/words reduce [
	10 constant-id constant-strings "i" 3 0 0 0 0 0
	10 constant-id constant-strings "p" 7 8 0 1 0 0
	11 constant-id constant-strings "u-i" 3 0 0 0 0 0
	11 constant-id constant-strings "u-f" 5 0 0 1 0 0
	12 constant-id constant-strings "t-i" 3 8 0 0 0 0
	12 constant-id constant-strings "t-p" 7 8 0 1 0 0
]

constant-signatures: fixture-writer/words [
	; Red/System, no flags, void return.
	1 0 1 0 0 0 0 0
]

constant-symbols: fixture-writer/words reduce [
	constant-id constant-strings "c-scalar" 3 1 2 3 0 0 0
	constant-id constant-strings "c-storage" 3 1 2 7 0 0 0
	constant-id constant-strings "fn" 1 3 1 1 0 0 0
	constant-id constant-strings "global" 2 3 1 3 0 0 0
]

constant-records: fixture-writer/words [
	; type kind flags data-offset data-size first-part part-count auxiliary
	3 2 0 0 4 0 0 0
	7 3 0 4 4 0 0 4
	7 5 0 0 0 1 1 0
	10 1 0 0 0 0 0 0
	10 4 0 0 0 2 2 0
	5 2 0 16 8 0 0 0
	11 4 0 0 0 4 1 4
	12 4 0 0 0 5 1 6
	9 5 0 0 0 6 1 0
	8 5 0 0 0 7 1 0
	8 5 0 0 0 8 1 0
	6 3 0 48 16 9 2 16
]

constant-parts: fixture-writer/words [
	; parent byte-offset type kind child target addend-offset flags
	3 0 7 3 2 0 8 0
	5 0 3 1 1 0 0 0
	5 8 7 1 3 0 0 0
	7 0 5 1 6 0 0 0
	8 8 7 1 3 0 0 0
	9 0 9 2 0 3 24 0
	10 0 8 2 0 4 32 0
	11 0 8 4 0 0 40 0
	12 0 8 2 0 4 64 0
	12 8 8 4 0 0 72 0
]

constant-data: copy #{2A00000061626300}
append constant-data #{0000000000000000}
append constant-data #{000000000000F03F}
append constant-data #{0000000000000000}
append constant-data #{0400000000000000}
append constant-data #{3412000000000000}
append constant-data #{00000000000000000000000000000000}
append constant-data #{0000000000000000}
append constant-data #{7856000000000000}
assert (length? constant-data) = 80 "rich constant-data size changed"

rich-constant-message: build-constant-initializer-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	constant-strings/1 constant-strings/2 constant-types constant-fields
	constant-signatures #{} constant-symbols constant-records constant-data constant-parts
	fixture-writer/words [1 1 2 2]
	fixture-writer/words [4 3 1 0 1 0 0 0]
	#{} #{} #{} #{} #{}

valid-constant-initializers: make block! 8
add-valid-constant-initializer: func [name [word!] data [binary!]][
	append/only valid-constant-initializers reduce [name data]
]
add-valid-constant-initializer 'EMPTY empty-constant-message
add-valid-constant-initializer 'RICH rich-constant-message

foreach fixture valid-constant-initializers [
	result: constant-initializer-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid constant initializer rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert result/error = schema/WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS [
		fixture/1 " valid constant initializer returned nonzero error"
	]
]

result: constant-initializer-verifier/verify rich-constant-message
assert to logic! all [
	result/view/constant-count = 12
	result/view/constant-data-size = 80
	result/view/part-count = 10
	result/view/binding-count = 2
	result/view/global-count = 1
	result/symbols/symbol-count = 4
	result/types/type-count = 12
]["verified constant/initializer view changed"]

constant-section: func [data [binary!] kind [integer!]][symbol-section data kind]

rich-constants-section:
	constant-section rich-constant-message schema/WIRE_RSIR_SECTION_CONSTANTS
rich-constant-data-section:
	constant-section rich-constant-message schema/WIRE_RSIR_SECTION_CONSTANT_DATA
rich-parts-section:
	constant-section rich-constant-message schema/WIRE_RSIR_SECTION_CONSTANT_PARTS
rich-bindings-section:
	constant-section rich-constant-message schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
rich-constant-symbols-section:
	constant-section rich-constant-message schema/WIRE_RSIR_SECTION_SYMBOLS
rich-constant-globals-section:
	constant-section rich-constant-message schema/WIRE_RSIR_SECTION_GLOBALS

constant-record-offset: func [section [map!] id record-size [integer!]][
	(select section 'payload-offset) + ((id - 1) * record-size)
]

build-rich-constant-message: func [
	constants* constant-data* parts* bindings* symbols* globals* [binary!]
][
	build-constant-initializer-message
		fixture-writer/words [0 2 1 0 0 0 0 0]
		constant-strings/1 constant-strings/2 constant-types constant-fields
		constant-signatures #{} symbols* constants* constant-data* parts* bindings* globals*
		#{} #{} #{} #{} #{}
]

malformed-constant-initializers: make block! 2048
add-malformed-constant-initializer: func [
	name [word!]
	expected-error expected-container expected-string expected-file expected-layout
	expected-type expected-function expected-module expected-symbol
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-constant-initializers reduce [
		name expected-error expected-container expected-string expected-file expected-layout
		expected-type expected-function expected-module expected-symbol
		expected-offset expected-section data
	]
]

add-constant-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-constant-initializer name expected-error
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
		expected-offset expected-section data
]

find-symbol-linkage-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-symbol-linkages [
		if fixture/1 = name [return fixture]
	]
	assert false ["missing nested symbol/linkage fixture " name]
]

foreach [name nested-name expected-error] reduce [
	'INVALID-CONTAINER 'INVALID-CONTAINER
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
	'INVALID-STRINGS 'INVALID-STRINGS
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_STRINGS
	'INVALID-FILE-SOURCE 'INVALID-FILE-SOURCE
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FILE_SOURCE
	'INVALID-DATA-LAYOUT 'INVALID-DATA-LAYOUT
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_DATA_LAYOUT
	'INVALID-TYPE-LAYOUT 'INVALID-TYPE-LAYOUT
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_TYPE_LAYOUT
	'INVALID-FUNCTION-SIGNATURE 'INVALID-FUNCTION-SIGNATURE
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FUNCTION_SIGNATURE
	'INVALID-MODULE-LIFECYCLE 'INVALID-MODULE-LIFECYCLE
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_MODULE_LIFECYCLE
	'INVALID-SYMBOL-LINKAGE 'BAD-SYMBOL-KIND
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_SYMBOL_LINKAGE
][
	nested: find-symbol-linkage-fixture nested-name
	add-malformed-constant-initializer name expected-error
		nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9 nested/2
		nested/10 nested/11 nested/12
]

foreach [name section expected-flags expected-error] reduce [
	'BAD-CONSTANT-SECTION-FLAGS rich-constants-section 2
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_SECTION_FLAGS
	'BAD-CONSTANT-DATA-SECTION-FLAGS rich-constant-data-section 2
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_DATA_SECTION_FLAGS
	'BAD-CONSTANT-PART-SECTION-FLAGS rich-parts-section 2
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_SECTION_FLAGS
	'BAD-CONSTANT-BINDING-SECTION-FLAGS rich-bindings-section 0
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_BINDING_SECTION_FLAGS
][
	bad: copy rich-constant-message
	bad-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad bad-offset expected-flags
	add-constant-semantic-error name expected-error bad-offset
		(select section 'ordinal) bad
]

foreach [prefix fields section record-size] reduce [
	"CONSTANT" constant-initializer-verifier/constant-fields
		rich-constants-section schema/WIRE_RSIR_CONSTANT_SIZE
	"PART" constant-initializer-verifier/part-fields
		rich-parts-section schema/WIRE_RSIR_CONSTANT_PART_SIZE
	"BINDING" constant-initializer-verifier/binding-fields
		rich-bindings-section schema/WIRE_RSIR_CONSTANT_BINDING_SIZE
][
	foreach [field-name field-relative] fields [
		bad: copy rich-constant-message
		bad-offset: (select section 'payload-offset) + field-relative
		fixture-mutations/put-bytes bad bad-offset #{00000080}
		add-constant-semantic-error
			to word! rejoin ["SCALAR-" prefix "-" field-name]
			schema/WIRE_CONSTANT_INITIALIZER_ERROR_SCALAR_RANGE
			bad-offset (select section 'ordinal) bad
	]
]

mutate-constant-record: func [
	name [word!] source [binary!] section [map!]
	id record-size field-relative value expected-error expected-relative [integer!]
	/local mutated base
][
	mutated: copy source
	base: constant-record-offset section id record-size
	fixture-mutations/put-u32 mutated (base + field-relative) value
	add-constant-semantic-error name expected-error
		(base + expected-relative) (select section 'ordinal) mutated
]

; Constant record domains and kind-specific shapes.
mutate-constant-record 'BAD-CONSTANT-TYPE rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_TYPE
	schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
mutate-constant-record 'BAD-CONSTANT-KIND rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_KIND_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_KIND
	schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
mutate-constant-record 'NONZERO-CONSTANT-FLAGS rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_FLAGS_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_CONSTANT_FLAGS
	schema/WIRE_RSIR_CONSTANT_FLAGS_OFFSET
mutate-constant-record 'BAD-EMPTY-PART-RANGE rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
	schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET
mutate-constant-record 'BAD-NONEMPTY-PART-RANGE rich-constant-message rich-constants-section
	3 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET 2
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
	schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET
mutate-constant-record 'BAD-ZERO-SHAPE rich-constant-message rich-constants-section
	4 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ZERO_SHAPE
	schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
mutate-constant-record 'BAD-SCALAR-TYPE rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET 7
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_TYPE
	schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
mutate-constant-record 'BAD-SCALAR-DATA-SIZE rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET 3
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_DATA_SIZE
	schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
mutate-constant-record 'BAD-SCALAR-SHAPE rich-constant-message rich-constants-section
	1 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_SHAPE
	schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET

bad: copy rich-constant-message
bad-constant-base: constant-record-offset rich-constants-section 1
	schema/WIRE_RSIR_CONSTANT_SIZE
fixture-mutations/put-u32 bad
	(bad-constant-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET) 4
bad-offset: select rich-constant-data-section 'payload-offset
fixture-mutations/put-u32 bad bad-offset 2
add-constant-semantic-error 'BAD-LOGIC-ENCODING
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_LOGIC_ENCODING
	bad-offset rich-constant-data-section/ordinal bad

mutate-constant-record 'BAD-STORAGE-TYPE rich-constant-message rich-constants-section
	2 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET 3
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_TYPE
	schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
mutate-constant-record 'BAD-STORAGE-COUNT rich-constant-message rich-constants-section
	2 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_COUNT
	schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET
mutate-constant-record 'BAD-STORAGE-DATA-SIZE rich-constant-message rich-constants-section
	2 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET 3
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_DATA_SIZE
	schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
bad: copy rich-constant-message
bad-constant-base: constant-record-offset rich-constants-section 2
	schema/WIRE_RSIR_CONSTANT_SIZE
fixture-mutations/put-u32 bad
	(bad-constant-base + schema/WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET) 1
fixture-mutations/put-u32 bad
	(bad-constant-base + schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET) 1
add-constant-semantic-error 'BAD-CSTRING-PART-COUNT
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_PART_COUNT
	(bad-constant-base + schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
	(select rich-constants-section 'ordinal) bad

bad: copy rich-constant-message
bad-offset: (select rich-constant-data-section 'payload-offset) + 6
fixture-mutations/put-bytes bad bad-offset #{00}
add-constant-semantic-error 'BAD-CSTRING-ENCODING
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_C_STRING_ENCODING
	bad-offset (select rich-constant-data-section 'ordinal) bad

mutate-constant-record 'BAD-AGGREGATE-TYPE rich-constant-message rich-constants-section
	5 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET 3
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_TYPE
	schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
mutate-constant-record 'BAD-AGGREGATE-PART-COUNT rich-constant-message rich-constants-section
	5 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_PART_COUNT
	schema/WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET
mutate-constant-record 'BAD-AGGREGATE-AUXILIARY rich-constant-message rich-constants-section
	5 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_AUXILIARY
	schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET
mutate-constant-record 'BAD-AGGREGATE-DATA-SHAPE rich-constant-message rich-constants-section
	5 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_AUXILIARY
	schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
mutate-constant-record 'BAD-ADDRESS-TYPE rich-constant-message rich-constants-section
	9 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET 3
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TYPE
	schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
mutate-constant-record 'BAD-ADDRESS-SHAPE rich-constant-message rich-constants-section
	9 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_SHAPE
	schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
mutate-constant-record 'BAD-CONSTANT-DATA-OFFSET rich-constant-message rich-constants-section
	2 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET 5
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_DATA_OFFSET
	schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
short-data: copy/part constant-data 20
short-data-message: build-rich-constant-message
	constant-records short-data constant-parts fixture-writer/words [1 1 2 2]
	constant-symbols fixture-writer/words [4 3 1 0 1 0 0 0]
short-constants-section:
	constant-section short-data-message schema/WIRE_RSIR_SECTION_CONSTANTS
add-constant-semantic-error 'CONSTANT-DATA-RANGE
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_RANGE
	((constant-record-offset short-constants-section 6 schema/WIRE_RSIR_CONSTANT_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET)
	(select short-constants-section 'ordinal) short-data-message

; Part ownership, type, ordering, target identity, addends, and placeholders.
mutate-constant-record 'BAD-PART-PARENT rich-constant-message rich-parts-section
	1 schema/WIRE_RSIR_CONSTANT_PART_SIZE
	schema/WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET 2
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_PARENT
	schema/WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET
mutate-constant-record 'BAD-PART-TYPE rich-constant-message rich-parts-section
	1 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_TYPE
	schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET
mutate-constant-record 'BAD-PART-KIND rich-constant-message rich-parts-section
	1 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_KIND_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_KIND
	schema/WIRE_RSIR_CONSTANT_PART_KIND_OFFSET
mutate-constant-record 'BAD-PART-OFFSET rich-constant-message rich-parts-section
	2 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET 4
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
	schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET
mutate-constant-record 'BAD-CHILD-CONSTANT rich-constant-message rich-parts-section
	2 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CHILD_CONSTANT
	schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET
mutate-constant-record 'CONSTANT-ORDER rich-constant-message rich-parts-section
	2 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET 5
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_ORDER
	schema/WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET
mutate-constant-record 'PART-TYPE-MISMATCH rich-constant-message rich-parts-section
	2 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET 4
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
	schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET
mutate-constant-record 'BAD-TARGET-SYMBOL rich-constant-message rich-parts-section
	6 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_TARGET_SYMBOL
	schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET
type-target-symbols: copy constant-symbols
fixture-mutations/put-u32 type-target-symbols schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
	schema/WIRE_SYMBOL_KIND_TYPE
type-target-parts: copy constant-parts
fixture-mutations/put-u32 type-target-parts
	((5 * schema/WIRE_RSIR_CONSTANT_PART_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET) 1
type-target-message: build-rich-constant-message
	constant-records constant-data type-target-parts fixture-writer/words [1 1 2 2]
	type-target-symbols fixture-writer/words [4 3 1 0 1 0 0 0]
type-target-parts-section:
	constant-section type-target-message schema/WIRE_RSIR_SECTION_CONSTANT_PARTS
add-constant-semantic-error 'BAD-TARGET-SYMBOL-KIND
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_TARGET_SYMBOL_KIND
	((constant-record-offset type-target-parts-section 6 schema/WIRE_RSIR_CONSTANT_PART_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
	(select type-target-parts-section 'ordinal) type-target-message
bad: copy rich-constant-message
bad-constant-base: constant-record-offset rich-constants-section 10
	schema/WIRE_RSIR_CONSTANT_SIZE
bad-part-base: constant-record-offset rich-parts-section 7
	schema/WIRE_RSIR_CONSTANT_PART_SIZE
fixture-mutations/put-u32 bad
	(bad-constant-base + schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET) 6
fixture-mutations/put-u32 bad
	(bad-part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET) 6
add-constant-semantic-error 'BAD-ADDRESS-TARGET-TYPE
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
	(bad-part-base + schema/WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
	(select rich-parts-section 'ordinal) bad
mutate-constant-record 'BAD-ADDEND-OFFSET rich-constant-message rich-parts-section
	6 schema/WIRE_RSIR_CONSTANT_PART_SIZE
	schema/WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET 25
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDEND_OFFSET
	schema/WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET

bad: copy rich-constant-message
bad-offset: (select rich-constant-data-section 'payload-offset) + 29
fixture-mutations/put-bytes bad bad-offset #{01}
add-constant-semantic-error 'BAD-ADDEND-ENCODING
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDEND_ENCODING
	bad-offset (select rich-constant-data-section 'ordinal) bad

mutate-constant-record 'NONZERO-PART-FLAGS rich-constant-message rich-parts-section
	1 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_FLAGS
	schema/WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET
mutate-constant-record 'BAD-PART-SHAPE rich-constant-message rich-parts-section
	2 schema/WIRE_RSIR_CONSTANT_PART_SIZE schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
	schema/WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET

unused-part-message: build-rich-constant-message
	constant-records constant-data
	append copy constant-parts fixture-writer/words [12 0 8 4 0 0 80 0]
	fixture-writer/words [1 1 2 2] constant-symbols
	fixture-writer/words [4 3 1 0 1 0 0 0]
unused-parts-section:
	constant-section unused-part-message schema/WIRE_RSIR_SECTION_CONSTANT_PARTS
add-constant-semantic-error 'CONSTANT-PART-COVERAGE
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_PART_COVERAGE
	((select unused-parts-section 'payload-offset) + (10 * schema/WIRE_RSIR_CONSTANT_PART_SIZE))
	(select unused-parts-section 'ordinal) unused-part-message

trailing-data: append copy constant-data #{00}
trailing-data-message: build-rich-constant-message
	constant-records trailing-data constant-parts fixture-writer/words [1 1 2 2]
	constant-symbols fixture-writer/words [4 3 1 0 1 0 0 0]
trailing-data-section:
	constant-section trailing-data-message schema/WIRE_RSIR_SECTION_CONSTANT_DATA
add-constant-semantic-error 'CONSTANT-DATA-COVERAGE
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_COVERAGE
	((select trailing-data-section 'payload-offset) + 80)
	(select trailing-data-section 'ordinal) trailing-data-message

mutate-constant-record 'BAD-UNION-FIELD rich-constant-message rich-constants-section
	7 schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET 6
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_UNION_FIELD
	schema/WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET

overlap-data: copy constant-data
overlap-parts: copy constant-parts
fixture-mutations/put-u32 overlap-parts
	((9 * schema/WIRE_RSIR_CONSTANT_PART_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET) 0
overlap-message: build-rich-constant-message
	constant-records overlap-data overlap-parts fixture-writer/words [1 1 2 2]
	constant-symbols fixture-writer/words [4 3 1 0 1 0 0 0]
overlap-parts-section:
	constant-section overlap-message schema/WIRE_RSIR_SECTION_CONSTANT_PARTS
add-constant-semantic-error 'PART-OVERLAP
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_PART_OVERLAP
	((constant-record-offset overlap-parts-section 10 schema/WIRE_RSIR_CONSTANT_PART_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
	(select overlap-parts-section 'ordinal) overlap-message

bad: copy rich-constant-message
bad-offset: (select rich-constant-data-section 'payload-offset) + 48
fixture-mutations/put-bytes bad bad-offset #{01}
add-constant-semantic-error 'NONZERO-PART-PLACEHOLDER
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_PLACEHOLDER
	bad-offset (select rich-constant-data-section 'ordinal) bad

; Constant-symbol bindings and global initialization policy.
mutate-constant-record 'BAD-BINDING-SYMBOL rich-constant-message rich-bindings-section
	1 schema/WIRE_RSIR_CONSTANT_BINDING_SIZE schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_SYMBOL
	schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET

nonconstant-binding: fixture-writer/words [1 1 2 2 3 1]
nonconstant-binding-message: build-rich-constant-message
	constant-records constant-data constant-parts nonconstant-binding constant-symbols
	fixture-writer/words [4 3 1 0 1 0 0 0]
nonconstant-binding-section:
	constant-section nonconstant-binding-message schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
add-constant-semantic-error 'BAD-BINDING-SYMBOL-KIND
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_SYMBOL_KIND
	((constant-record-offset nonconstant-binding-section 3
		schema/WIRE_RSIR_CONSTANT_BINDING_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
	(select nonconstant-binding-section 'ordinal) nonconstant-binding-message

mutate-constant-record 'BAD-BINDING-CONSTANT rich-constant-message rich-bindings-section
	1 schema/WIRE_RSIR_CONSTANT_BINDING_SIZE schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_CONSTANT
	schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET
mutate-constant-record 'BINDING-TYPE-MISMATCH rich-constant-message rich-bindings-section
	1 schema/WIRE_RSIR_CONSTANT_BINDING_SIZE schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET 2
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BINDING_TYPE_MISMATCH
	schema/WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET

binding-order: fixture-writer/words [2 2 1 1]
binding-order-message: build-rich-constant-message
	constant-records constant-data constant-parts binding-order constant-symbols
	fixture-writer/words [4 3 1 0 1 0 0 0]
binding-order-section:
	constant-section binding-order-message schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
add-constant-semantic-error 'BINDING-ORDER
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BINDING_ORDER
	((constant-record-offset binding-order-section 2 schema/WIRE_RSIR_CONSTANT_BINDING_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
	(select binding-order-section 'ordinal) binding-order-message

duplicate-binding: fixture-writer/words [1 1 1 1 2 2]
duplicate-binding-message: build-rich-constant-message
	constant-records constant-data constant-parts duplicate-binding constant-symbols
	fixture-writer/words [4 3 1 0 1 0 0 0]
duplicate-binding-section:
	constant-section duplicate-binding-message schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
add-constant-semantic-error 'DUPLICATE-BINDING-SYMBOL
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_DUPLICATE_BINDING_SYMBOL
	((constant-record-offset duplicate-binding-section 2 schema/WIRE_RSIR_CONSTANT_BINDING_SIZE)
		+ schema/WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
	(select duplicate-binding-section 'ordinal) duplicate-binding-message

missing-binding: fixture-writer/words [1 1]
missing-binding-message: build-rich-constant-message
	constant-records constant-data constant-parts missing-binding constant-symbols
	fixture-writer/words [4 3 1 0 1 0 0 0]
missing-binding-symbols-section:
	constant-section missing-binding-message schema/WIRE_RSIR_SECTION_SYMBOLS
add-constant-semantic-error 'MISSING-CONSTANT-BINDING
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_MISSING_CONSTANT_BINDING
	((constant-record-offset missing-binding-symbols-section 2 schema/WIRE_RSIR_SYMBOL_SIZE)
		+ schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
	(select missing-binding-symbols-section 'ordinal) missing-binding-message

mutate-constant-record 'BAD-GLOBAL-INITIALIZER rich-constant-message rich-constant-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET 13
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_INITIALIZER
	schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET
mutate-constant-record 'GLOBAL-INITIALIZER-TYPE-MISMATCH
	rich-constant-message rich-constant-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET 2
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_GLOBAL_INITIALIZER_TYPE_MISMATCH
	schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET
mutate-constant-record 'BAD-GLOBAL-ALIGNMENT rich-constant-message rich-constant-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET 3
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_ALIGNMENT
	schema/WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET
mutate-constant-record 'BAD-GLOBAL-STORAGE-CLASS
	rich-constant-message rich-constant-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_STORAGE_CLASS_OFFSET 0
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_STORAGE_CLASS
	schema/WIRE_RSIR_GLOBAL_STORAGE_CLASS_OFFSET
mutate-constant-record 'NONZERO-GLOBAL-FLAGS rich-constant-message rich-constant-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_FLAGS_OFFSET 1
	schema/WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_GLOBAL_FLAGS
	schema/WIRE_RSIR_GLOBAL_FLAGS_OFFSET

zero-global-message: build-rich-constant-message
	constant-records constant-data constant-parts fixture-writer/words [1 1 2 2]
	constant-symbols fixture-writer/words [4 3 0 0 1 0 0 0]
add-valid-constant-initializer 'ZERO-GLOBAL zero-global-message

result: constant-initializer-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/symbol-linkage-error = schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
	result/error-offset = 0 result/error-section = 0
	none? result/strings none? result/symbols none? result/view
]["non-binary constant input did not return INVALID_ARGUMENTS atomically"]

covered-errors: make block! 128
append covered-errors schema/WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
append covered-errors schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS
foreach fixture malformed-constant-initializers [
	result: constant-initializer-verifier/verify fixture/13
	assert not result/valid? [fixture/1 " malformed constant initializer was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/container-error = fixture/3
		result/string-error = fixture/4
		result/file-source-error = fixture/5
		result/data-layout-error = fixture/6
		result/type-layout-error = fixture/7
		result/function-signature-error = fixture/8
		result/module-lifecycle-error = fixture/9
		result/symbol-linkage-error = fixture/10
		result/error-offset = fixture/11
		result/error-section = fixture/12
	][fixture/1 " nested error or location changed"]
	append covered-errors fixture/2
]

repeat code 67 [
	assert not none? find covered-errors (code - 1) [
		"constant/initializer error code not covered: " code - 1
	]
]

foreach fixture valid-constant-initializers [
	result: constant-initializer-verifier/verify fixture/2
	assert result/valid? [fixture/1 " valid constant initializer failed after corpus build"]
]

unless value? 'generating-wire-constant-initializer-fixtures? [
	source-bytes: make binary! 2'097'152
	foreach source-file [
		%wire-constant-initializer-test.red
		%wire-symbol-linkage-test.red
		%wire-function-signature-test.red
		%wire-module-lifecycle-test.red
		%wire-type-layout-test.red
		%wire-data-layout-test.red
		%wire-file-source-test.red
		%wire-string-table-test.red
		%wire-container-test.red
		%../generate-wire-constant-initializer-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-constant-initializer-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System constant/initializer fixtures are stale"
	print [
		"PASS: RSIR constant/initializer semantics"
		length? valid-constant-initializers "valid"
		length? malformed-constant-initializers "malformed"
	]
]
