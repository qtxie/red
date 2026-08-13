Red [
	Title: "Hybrid compiler RSIR symbol, import, and export tests"
]

do %wire-function-signature-test.red
do %../../../compiler/wire-module-lifecycle.red
do %../../../compiler/wire-symbol-linkage.red

symbol-linkage-verifier: compiler-wire-symbol-linkage

make-canonical-strings: func [
	values [block!]
	/local ordered records data ids offset index value bytes
][
	ordered: sort/case copy values
	records: make block! ((length? ordered) * 2)
	data: make binary! 256
	ids: make map! ((length? ordered) * 2)
	offset: 0
	index: 1
	foreach value ordered [
		bytes: to binary! value
		repend records [offset length? bytes]
		append data bytes
		put ids value index
		offset: offset + length? bytes
		index: index + 1
	]
	reduce [fixture-writer/words records data ids]
]

symbol-string-id: func [table [block!] value [string!]][select table/3 value]

build-symbol-linkage-message: func [
	module-records string-records string-data type-records field-records
	signature-records parameter-records symbol-records global-records
	import-records export-records function-records local-records block-records
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
	fixture-writer/build
		schema/WIRE_MAGIC_RSIR
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

symbol-basic-types: fixture-writer/words [
	; void and signed i32.
	1 0 0 0 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
]

empty-symbol-message: build-symbol-linkage-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	fixture-writer/words [0 0] #{}
	#{} #{} #{} #{} #{} #{} #{} #{} #{} #{} #{}

rich-strings: make-canonical-strings [
	"" "alias" "api" "const" "ext-fn" "ext-var" "fn" "imp-a" "imp-b"
	"imp-var" "lib.dll" "ns>fn" "public-api" "public-var" "sys" "var"
]
rich-id: :symbol-string-id
rich-symbol-values: make block! 96
repend rich-symbol-values [
	rich-id rich-strings "alias" 4 1 2 2 0 0 0
	rich-id rich-strings "api" 1 3 1 2 0 0 0
	rich-id rich-strings "const" 3 1 2 2 0 0 0
	rich-id rich-strings "fn" 1 2 2 1 0 0 0
	rich-id rich-strings "imp-a" 1 4 1 3 0 0 0
	rich-id rich-strings "imp-b" 1 4 1 3 0 0 0
	rich-id rich-strings "imp-var" 2 4 1 2 0 0 0
	rich-id rich-strings "ns>fn" 1 1 2 1 0 0 0
	rich-id rich-strings "sys" 1 3 1 5 0 0 0
	rich-id rich-strings "var" 2 3 1 2 0 0 0
	rich-id rich-strings "var" 4 1 2 2 0 0 0
]
rich-symbol-message: build-symbol-linkage-message
	fixture-writer/words [0 2 2 2 0 0 0 0]
	rich-strings/1 rich-strings/2 symbol-basic-types #{}
	fixture-writer/words [
		; red-system body, C callback export, C import, stdcall import, syscall.
		1 0 2 0 0 0 0 0
		2 8 2 0 0 0 0 0
		2 0 2 0 0 0 0 0
		3 0 2 0 0 0 0 0
		4 0 2 0 0 0 0 0
	]
	#{}
	fixture-writer/words rich-symbol-values
	fixture-writer/words [
		; symbol type initializer align section flags source reserved
		10 2 0 0 0 0 0 0
	]
	fixture-writer/words reduce [
		rich-id rich-strings "lib.dll" rich-id rich-strings "ext-fn" 5 2 0 0
		rich-id rich-strings "lib.dll" rich-id rich-strings "ext-fn" 6 2 0 0
		rich-id rich-strings "lib.dll" rich-id rich-strings "ext-var" 7 0 0 0
	]
	fixture-writer/words reduce [
		rich-id rich-strings "public-api" 2 0 0
		rich-id rich-strings "public-var" 10 0 0
	]
	fixture-writer/words [
		; symbol signature flags first-block count entry first-local count source reserved
		2 2 0 1 1 1 0 0 0 0
		4 1 0 2 1 2 0 0 0 0
		8 1 0 3 1 3 0 0 0 0
	]
	#{}
	fixture-writer/words [
		1 0 0 0 0 0 0 0
		2 0 0 0 0 0 0 0
		3 0 0 0 0 0 0 0
	]

rich-global-section: function-section rich-symbol-message schema/WIRE_RSIR_SECTION_GLOBALS
deferred-global-message: copy rich-symbol-message
deferred-global-offset: select rich-global-section 'payload-offset
foreach [field value] reduce [
	schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET 2147483647
	schema/WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET 3
	schema/WIRE_RSIR_GLOBAL_SECTION_CLASS_OFFSET 99
	schema/WIRE_RSIR_GLOBAL_FLAGS_OFFSET 127
][
	fixture-mutations/put-u32 deferred-global-message (deferred-global-offset + field) value
]

two-global-strings: make-canonical-strings ["" "ga" "gb"]
two-global-message: build-symbol-linkage-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	two-global-strings/1 two-global-strings/2 symbol-basic-types #{} #{} #{}
	fixture-writer/words reduce [
		rich-id two-global-strings "ga" 2 3 1 2 0 0 0
		rich-id two-global-strings "gb" 2 3 1 2 0 0 0
	]
	fixture-writer/words [
		1 2 0 0 0 0 0 0
		2 2 0 0 0 0 0 0
	]
	#{} #{} #{} #{} #{} #{}

runtime-strings: make-canonical-strings ["" "private" "red/private"]
runtime-private-export-message: build-symbol-linkage-message
	fixture-writer/words [0 1 2 0 0 0 0 0]
	runtime-strings/1 runtime-strings/2 symbol-basic-types #{}
	fixture-writer/words [1 0 2 0 0 0 0 0] #{}
	fixture-writer/words reduce [
		rich-id runtime-strings "private" 1 3 1 1 0 0 0
	]
	#{} #{}
	fixture-writer/words reduce [rich-id runtime-strings "red/private" 1 0 0]
	fixture-writer/words [1 1 0 1 1 1 0 0 0 0]
	#{} fixture-writer/words [1 0 0 0 0 0 0 0]

declaration-strings: make-canonical-strings ["" "decl-fn" "decl-var"]
external-declaration-message: build-symbol-linkage-message
	fixture-writer/words [0 3 1 0 0 0 0 0]
	declaration-strings/1 declaration-strings/2 symbol-basic-types #{}
	fixture-writer/words [2 0 2 0 0 0 0 0] #{}
	fixture-writer/words reduce [
		rich-id declaration-strings "decl-fn" 1 3 1 1 0 0 0
		rich-id declaration-strings "decl-var" 2 3 1 2 0 0 0
	]
	#{} #{} #{} #{} #{} #{}

weak-strings: make-canonical-strings ["" "weak-fn" "weak-var"]
weak-definition-message: build-symbol-linkage-message
	fixture-writer/words [0 3 1 0 0 0 0 0]
	weak-strings/1 weak-strings/2 symbol-basic-types #{}
	fixture-writer/words [1 0 2 0 0 0 0 0] #{}
	fixture-writer/words reduce [
		rich-id weak-strings "weak-fn" 1 5 1 1 0 0 0
		rich-id weak-strings "weak-var" 2 5 1 2 0 0 0
	]
	fixture-writer/words [2 2 0 0 0 0 0 0]
	#{} #{}
	fixture-writer/words [1 1 0 1 1 1 0 0 0 0]
	#{} fixture-writer/words [1 0 0 0 0 0 0 0]

glue-strings: make-canonical-strings ["" "entry"]
glue-entry-message: build-symbol-linkage-message
	fixture-writer/words [0 4 1 0 0 1 0 0]
	glue-strings/1 glue-strings/2 symbol-basic-types #{}
	fixture-writer/words [1 0 2 0 0 0 0 0] #{}
	fixture-writer/words reduce [
		rich-id glue-strings "entry" 1 3 1 1 0 0 0
	]
	#{} #{} #{}
	fixture-writer/words [1 1 0 1 1 1 0 0 0 0]
	#{} fixture-writer/words [1 0 0 0 0 0 0 0]

valid-symbol-linkages: make block! 16
add-valid-symbol-linkage: func [name [word!] data [binary!]][
	append/only valid-symbol-linkages reduce [name data]
]
add-valid-symbol-linkage 'EMPTY empty-symbol-message
add-valid-symbol-linkage 'RICH rich-symbol-message
add-valid-symbol-linkage 'DEFERRED-GLOBAL-FIELDS deferred-global-message
add-valid-symbol-linkage 'TWO-GLOBALS two-global-message
add-valid-symbol-linkage 'RUNTIME-PRIVATE-EXPORT runtime-private-export-message
add-valid-symbol-linkage 'EXTERNAL-DECLARATIONS external-declaration-message
add-valid-symbol-linkage 'WEAK-DEFINITIONS weak-definition-message
add-valid-symbol-linkage 'GLUE-ENTRY glue-entry-message

symbol-section: func [data [binary!] kind [integer!]][
	function-section data kind
]

symbol-record-offset: func [section [map!] id record-size [integer!]][
	(select section 'payload-offset) + ((id - 1) * record-size)
]

malformed-symbol-linkages: make block! 1536
add-malformed-symbol-linkage: func [
	name [word!]
	expected-error expected-container expected-string expected-file expected-data-layout
	expected-type-layout expected-function-signature expected-module-lifecycle
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-symbol-linkages reduce [
		name expected-error expected-container expected-string expected-file
		expected-data-layout expected-type-layout expected-function-signature
		expected-module-lifecycle expected-offset expected-section data
	]
]

add-symbol-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-symbol-linkage name expected-error
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		expected-offset expected-section data
]

find-function-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-function-signatures [
		if fixture/1 = name [return fixture]
	]
	assert false ["missing nested function fixture " name]
]

foreach [name nested-name expected-error] reduce [
	'INVALID-CONTAINER 'INVALID-CONTAINER
		schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER
	'INVALID-STRINGS 'INVALID-STRINGS
		schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_STRINGS
	'INVALID-FILE-SOURCE 'INVALID-FILE-SOURCE
		schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FILE_SOURCE
	'INVALID-DATA-LAYOUT 'INVALID-DATA-LAYOUT
		schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_DATA_LAYOUT
	'INVALID-TYPE-LAYOUT 'INVALID-TYPE-LAYOUT
		schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_TYPE_LAYOUT
	'INVALID-FUNCTION-SIGNATURE 'BAD-CALLING-CONVENTION
		schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FUNCTION_SIGNATURE
][
	nested: find-function-fixture nested-name
	add-malformed-symbol-linkage name expected-error
		nested/3 nested/4 nested/5 nested/6 nested/7 nested/2
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		nested/8 nested/9 nested/10
]

rich-module-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_MODULE
bad: copy rich-symbol-message
bad-offset: (select rich-module-section 'payload-offset) + schema/WIRE_RSIR_MODULE_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset 1
add-malformed-symbol-linkage 'INVALID-MODULE-LIFECYCLE
	schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_MODULE_LIFECYCLE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
	schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_FLAGS
	bad-offset (select rich-module-section 'ordinal) bad

rich-symbols-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_SYMBOLS
rich-globals-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_GLOBALS
rich-imports-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_IMPORTS
rich-exports-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_EXPORTS
rich-functions-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_FUNCTIONS
rich-signatures-section: symbol-section rich-symbol-message schema/WIRE_RSIR_SECTION_SIGNATURES

foreach [name section expected-error] reduce [
	'BAD-SYMBOL-SECTION-FLAGS rich-symbols-section
		schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_SECTION_FLAGS
	'BAD-GLOBAL-SECTION-FLAGS rich-globals-section
		schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SECTION_FLAGS
	'BAD-IMPORT-SECTION-FLAGS rich-imports-section
		schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SECTION_FLAGS
	'BAD-EXPORT-SECTION-FLAGS rich-exports-section
		schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SECTION_FLAGS
][
	bad: copy rich-symbol-message
	bad-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad bad-offset either section = rich-globals-section [
		schema/WIRE_SECTION_FLAG_SORTED
	][0]
	add-symbol-semantic-error name expected-error bad-offset
		(select section 'ordinal) bad
]

; All four records are signed-31 scalar tables. Decode the complete tables first.
foreach [prefix fields section record-size] reduce [
	"SYMBOL" symbol-linkage-verifier/symbol-fields
		rich-symbols-section schema/WIRE_RSIR_SYMBOL_SIZE
	"GLOBAL" symbol-linkage-verifier/global-fields
		rich-globals-section schema/WIRE_RSIR_GLOBAL_SIZE
	"IMPORT" symbol-linkage-verifier/import-fields
		rich-imports-section schema/WIRE_IMPORT_SIZE
	"EXPORT" symbol-linkage-verifier/export-fields
		rich-exports-section schema/WIRE_EXPORT_SIZE
][
	foreach [field-name field-relative] fields [
		bad: copy rich-symbol-message
		bad-offset: (select section 'payload-offset) + field-relative
		fixture-mutations/put-bytes bad bad-offset #{00000080}
		add-symbol-semantic-error
			to word! rejoin ["SCALAR-" prefix "-" field-name]
			schema/WIRE_SYMBOL_LINKAGE_ERROR_SCALAR_RANGE
			bad-offset (select section 'ordinal) bad
	]
]

mutate-symbol-record: func [
	name [word!] source [binary!] section [map!]
	id record-size field-relative value expected-error expected-relative [integer!]
	/local mutated base
][
	mutated: copy source
	base: symbol-record-offset section id record-size
	fixture-mutations/put-u32 mutated (base + field-relative) value
	add-symbol-semantic-error name expected-error
		(base + expected-relative) (select section 'ordinal) mutated
]

; Symbol identity, canonical ordering, domains, and source ownership.
mutate-symbol-record 'BAD-SYMBOL-NAME-ID rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_NAME_ID
	schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
mutate-symbol-record 'EMPTY-SYMBOL-NAME rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_SYMBOL_NAME
	schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
mutate-symbol-record 'SYMBOL-ORDER rich-symbol-message rich-symbols-section
	2 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
	(rich-id rich-strings "alias") schema/WIRE_SYMBOL_LINKAGE_ERROR_SYMBOL_ORDER
	schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET

bad: copy rich-symbol-message
base: symbol-record-offset rich-symbols-section 2 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET)
	rich-id rich-strings "alias"
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
	schema/WIRE_SYMBOL_KIND_TYPE
add-symbol-semantic-error 'DUPLICATE-SYMBOL-NAME
	schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_SYMBOL_NAME
	(base + schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET)
	(select rich-symbols-section 'ordinal) bad

mutate-symbol-record 'BAD-SYMBOL-KIND rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_KIND_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
mutate-symbol-record 'BAD-LINKAGE rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LINKAGE schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
mutate-symbol-record 'BAD-VISIBILITY rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_VISIBILITY
	schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET
mutate-symbol-record 'BAD-FUNCTION-SIGNATURE-REF rich-symbol-message rich-symbols-section
	2 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_TYPE_OR_SIGNATURE
	schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
mutate-symbol-record 'BAD-VALUE-TYPE-REF rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_TYPE_OR_SIGNATURE
	schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
mutate-symbol-record 'NONZERO-SYMBOL-FLAGS rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_FLAGS_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_SYMBOL_FLAGS
	schema/WIRE_RSIR_SYMBOL_FLAGS_OFFSET
mutate-symbol-record 'NONZERO-OWNER-SYMBOL rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_OWNER_SYMBOL
	schema/WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET
mutate-symbol-record 'BAD-SYMBOL-SOURCE rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_SOURCE_LOCATION
	schema/WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET
mutate-symbol-record 'BAD-LINKAGE-VISIBILITY rich-symbol-message rich-symbols-section
	1 schema/WIRE_RSIR_SYMBOL_SIZE schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
	schema/WIRE_LINKAGE_EXTERNAL schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LINKAGE_VISIBILITY
	schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET

bad: copy rich-symbol-message
base: symbol-record-offset rich-symbols-section 3 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	schema/WIRE_LINKAGE_EXTERNAL
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET)
	schema/WIRE_VISIBILITY_DEFAULT
add-symbol-semantic-error 'BAD-SYMBOL-KIND-LINKAGE
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND_LINKAGE
	(base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	(select rich-symbols-section 'ordinal) bad

; Global definition identity and ordering. Initializer/layout fields remain deferred.
mutate-symbol-record 'BAD-GLOBAL-SYMBOL rich-symbol-message rich-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SYMBOL
	schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
mutate-symbol-record 'BAD-GLOBAL-SYMBOL-KIND rich-symbol-message rich-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET 2
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SYMBOL_KIND
	schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
mutate-symbol-record 'GLOBAL-TYPE-MISMATCH rich-symbol-message rich-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_GLOBAL_TYPE_MISMATCH
	schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET

two-globals-section: symbol-section two-global-message schema/WIRE_RSIR_SECTION_GLOBALS
bad: copy two-global-message
fixture-mutations/put-u32 bad
	((symbol-record-offset two-globals-section 1 schema/WIRE_RSIR_GLOBAL_SIZE)
		+ schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) 2
bad-offset: (symbol-record-offset two-globals-section 2 schema/WIRE_RSIR_GLOBAL_SIZE)
	+ schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
fixture-mutations/put-u32 bad bad-offset 1
add-symbol-semantic-error 'GLOBAL-ORDER schema/WIRE_SYMBOL_LINKAGE_ERROR_GLOBAL_ORDER
	bad-offset (select two-globals-section 'ordinal) bad
mutate-symbol-record 'DUPLICATE-GLOBAL-DEFINITION two-global-message two-globals-section
	2 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_GLOBAL_DEFINITION
	schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
mutate-symbol-record 'IMPORTED-GLOBAL-DEFINITION rich-symbol-message rich-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET 7
	schema/WIRE_SYMBOL_LINKAGE_ERROR_IMPORTED_GLOBAL_DEFINITION
	schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
mutate-symbol-record 'BAD-GLOBAL-SOURCE rich-symbol-message rich-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SOURCE_LOCATION
	schema/WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET
mutate-symbol-record 'NONZERO-GLOBAL-RESERVED rich-symbol-message rich-globals-section
	1 schema/WIRE_RSIR_GLOBAL_SIZE schema/WIRE_RSIR_GLOBAL_RESERVED_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_GLOBAL_RESERVED
	schema/WIRE_RSIR_GLOBAL_RESERVED_OFFSET

; Function records must be a sorted, unique definition map back to function symbols.
mutate-symbol-record 'BAD-FUNCTION-SYMBOL-KIND rich-symbol-message rich-functions-section
	1 schema/WIRE_RSIR_FUNCTION_SIZE schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET 10
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_FUNCTION_SYMBOL_KIND
	schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
mutate-symbol-record 'FUNCTION-SIGNATURE-MISMATCH rich-symbol-message rich-functions-section
	1 schema/WIRE_RSIR_FUNCTION_SIZE schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_FUNCTION_SIGNATURE_MISMATCH
	schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET

bad: copy rich-symbol-message
base: symbol-record-offset rich-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) 8
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET) 1
bad-offset: (symbol-record-offset rich-functions-section 2 schema/WIRE_RSIR_FUNCTION_SIZE)
	+ schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
add-symbol-semantic-error 'FUNCTION-ORDER schema/WIRE_SYMBOL_LINKAGE_ERROR_FUNCTION_ORDER
	bad-offset (select rich-functions-section 'ordinal) bad

bad: copy rich-symbol-message
base: symbol-record-offset rich-functions-section 2 schema/WIRE_RSIR_FUNCTION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) 2
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET) 2
add-symbol-semantic-error 'DUPLICATE-FUNCTION-DEFINITION
	schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_FUNCTION_DEFINITION
	(base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
	(select rich-functions-section 'ordinal) bad

bad: copy rich-symbol-message
base: symbol-record-offset rich-functions-section 1 schema/WIRE_RSIR_FUNCTION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) 5
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET) 3
add-symbol-semantic-error 'IMPORTED-FUNCTION-DEFINITION
	schema/WIRE_SYMBOL_LINKAGE_ERROR_IMPORTED_FUNCTION_DEFINITION
	(base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
	(select rich-functions-section 'ordinal) bad

; Import records are sorted by local symbol. Alias records may share external identity.
mutate-symbol-record 'BAD-IMPORT-LIBRARY-ID rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_LIBRARY_ID
	schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
mutate-symbol-record 'EMPTY-IMPORT-LIBRARY rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_IMPORT_LIBRARY
	schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
mutate-symbol-record 'BAD-IMPORT-EXTERNAL-NAME-ID rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_EXTERNAL_NAME_ID
	schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
mutate-symbol-record 'EMPTY-IMPORT-EXTERNAL-NAME rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_IMPORT_EXTERNAL_NAME
	schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
mutate-symbol-record 'BAD-IMPORT-SYMBOL rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_SYMBOL_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SYMBOL schema/WIRE_IMPORT_SYMBOL_OFFSET
mutate-symbol-record 'BAD-IMPORT-SYMBOL-KIND rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_SYMBOL_OFFSET 3
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SYMBOL_KIND
	schema/WIRE_IMPORT_SYMBOL_OFFSET
mutate-symbol-record 'BAD-IMPORT-LINKAGE rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_SYMBOL_OFFSET 2
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_LINKAGE schema/WIRE_IMPORT_SYMBOL_OFFSET
mutate-symbol-record 'BAD-IMPORT-CALLING-CONVENTION rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
	schema/WIRE_CALLING_CONVENTION_STDCALL
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_CALLING_CONVENTION
	schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
mutate-symbol-record 'NONZERO-IMPORT-FLAGS rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_FLAGS_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_IMPORT_FLAGS schema/WIRE_IMPORT_FLAGS_OFFSET
mutate-symbol-record 'BAD-IMPORT-SOURCE rich-symbol-message rich-imports-section
	1 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SOURCE_LOCATION
	schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET

bad: copy rich-symbol-message
base: symbol-record-offset rich-imports-section 1 schema/WIRE_IMPORT_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_IMPORT_SYMBOL_OFFSET) 7
fixture-mutations/put-u32 bad (base + schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET) 0
bad-offset: (symbol-record-offset rich-imports-section 2 schema/WIRE_IMPORT_SIZE)
	+ schema/WIRE_IMPORT_SYMBOL_OFFSET
add-symbol-semantic-error 'IMPORT-ORDER schema/WIRE_SYMBOL_LINKAGE_ERROR_IMPORT_ORDER
	bad-offset (select rich-imports-section 'ordinal) bad
mutate-symbol-record 'DUPLICATE-IMPORT-SYMBOL rich-symbol-message rich-imports-section
	2 schema/WIRE_IMPORT_SIZE schema/WIRE_IMPORT_SYMBOL_OFFSET 5
	schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_IMPORT_SYMBOL
	schema/WIRE_IMPORT_SYMBOL_OFFSET

external-symbols-section: symbol-section external-declaration-message
	schema/WIRE_RSIR_SECTION_SYMBOLS
bad: copy external-declaration-message
base: symbol-record-offset external-symbols-section 1 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	schema/WIRE_LINKAGE_IMPORT
add-symbol-semantic-error 'MISSING-IMPORT schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_IMPORT
	(base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	(select external-symbols-section 'ordinal) bad

bad: copy external-declaration-message
base: symbol-record-offset external-symbols-section 2 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	schema/WIRE_LINKAGE_INTERNAL
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET)
	schema/WIRE_VISIBILITY_HIDDEN
add-symbol-semantic-error 'MISSING-GLOBAL-DEFINITION
	schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_GLOBAL_DEFINITION
	(base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	(select external-symbols-section 'ordinal) bad

bad: copy external-declaration-message
base: symbol-record-offset external-symbols-section 1 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	schema/WIRE_LINKAGE_INTERNAL
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET)
	schema/WIRE_VISIBILITY_HIDDEN
add-symbol-semantic-error 'MISSING-FUNCTION-DEFINITION
	schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_FUNCTION_DEFINITION
	(base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	(select external-symbols-section 'ordinal) bad

bad: copy rich-symbol-message
base: symbol-record-offset rich-symbols-section 9 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	schema/WIRE_LINKAGE_LOCAL
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET)
	schema/WIRE_VISIBILITY_HIDDEN
add-symbol-semantic-error 'SYSCALL-NONEXTERNAL
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYSCALL_DECLARATION
	(base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
	(select rich-symbols-section 'ordinal) bad

syscall-body-strings: make-canonical-strings ["" "sys"]
syscall-body-message: build-symbol-linkage-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	syscall-body-strings/1 syscall-body-strings/2 symbol-basic-types #{}
	fixture-writer/words [4 0 2 0 0 0 0 0] #{}
	fixture-writer/words reduce [
		rich-id syscall-body-strings "sys" 1 3 1 1 0 0 0
	]
	#{} #{} #{}
	fixture-writer/words [1 1 0 1 1 1 0 0 0 0]
	#{} fixture-writer/words [1 0 0 0 0 0 0 0]
syscall-body-symbols: symbol-section syscall-body-message schema/WIRE_RSIR_SECTION_SYMBOLS
syscall-symbol-offset: (select syscall-body-symbols 'payload-offset)
	+ schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
add-symbol-semantic-error 'SYSCALL-HAS-BODY
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYSCALL_DECLARATION
	syscall-symbol-offset (select syscall-body-symbols 'ordinal) syscall-body-message

; Export names are unique/sorted; RSIR ordinals are always zero.
mutate-symbol-record 'BAD-EXPORT-EXTERNAL-NAME-ID rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_EXTERNAL_NAME_ID
	schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
mutate-symbol-record 'EMPTY-EXPORT-EXTERNAL-NAME rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_EXPORT_EXTERNAL_NAME
	schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
mutate-symbol-record 'BAD-EXPORT-SYMBOL rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_SYMBOL_OFFSET 0
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SYMBOL schema/WIRE_EXPORT_SYMBOL_OFFSET
mutate-symbol-record 'BAD-EXPORT-SYMBOL-KIND rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_SYMBOL_OFFSET 3
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SYMBOL_KIND
	schema/WIRE_EXPORT_SYMBOL_OFFSET

bad: copy rich-symbol-message
first-export: symbol-record-offset rich-exports-section 1 schema/WIRE_EXPORT_SIZE
second-export: symbol-record-offset rich-exports-section 2 schema/WIRE_EXPORT_SIZE
fixture-mutations/put-u32 bad
	(first-export + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
	rich-id rich-strings "public-var"
fixture-mutations/put-u32 bad
	(second-export + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
	rich-id rich-strings "public-api"
add-symbol-semantic-error 'EXPORT-ORDER schema/WIRE_SYMBOL_LINKAGE_ERROR_EXPORT_ORDER
	(second-export + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
	(select rich-exports-section 'ordinal) bad
mutate-symbol-record 'DUPLICATE-EXPORT-NAME rich-symbol-message rich-exports-section
	2 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
	(rich-id rich-strings "public-api") schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_EXPORT_NAME
	schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
mutate-symbol-record 'NONZERO-EXPORT-ORDINAL rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_ORDINAL_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_EXPORT_ORDINAL
	schema/WIRE_EXPORT_ORDINAL_OFFSET
mutate-symbol-record 'NONZERO-EXPORT-FLAGS rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_FLAGS_OFFSET 1
	schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_EXPORT_FLAGS schema/WIRE_EXPORT_FLAGS_OFFSET
mutate-symbol-record 'BAD-EXPORT-LINKAGE rich-symbol-message rich-exports-section
	1 schema/WIRE_EXPORT_SIZE schema/WIRE_EXPORT_SYMBOL_OFFSET 4
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_LINKAGE schema/WIRE_EXPORT_SYMBOL_OFFSET

export-declaration-strings: make-canonical-strings ["" "decl" "public"]
export-declaration-message: build-symbol-linkage-message
	fixture-writer/words [0 2 2 0 0 0 0 0]
	export-declaration-strings/1 export-declaration-strings/2 symbol-basic-types #{}
	fixture-writer/words [2 8 2 0 0 0 0 0] #{}
	fixture-writer/words reduce [
		rich-id export-declaration-strings "decl" 1 3 1 1 0 0 0
	]
	#{} #{}
	fixture-writer/words reduce [rich-id export-declaration-strings "public" 1 0 0]
	#{} #{} #{}
export-declaration-section: symbol-section export-declaration-message
	schema/WIRE_RSIR_SECTION_EXPORTS
add-symbol-semantic-error 'MISSING-EXPORT-DEFINITION
	schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_EXPORT_DEFINITION
	((select export-declaration-section 'payload-offset) + schema/WIRE_EXPORT_SYMBOL_OFFSET)
	(select export-declaration-section 'ordinal) export-declaration-message

bad: copy rich-symbol-message
base: symbol-record-offset rich-signatures-section 2 schema/WIRE_RSIR_SIGNATURE_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET) 0
add-symbol-semantic-error 'USER-C-EXPORT-WITHOUT-CALLBACK
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SIGNATURE
	(first-export + schema/WIRE_EXPORT_SYMBOL_OFFSET)
	(select rich-exports-section 'ordinal) bad

runtime-modules-section: symbol-section runtime-private-export-message
	schema/WIRE_RSIR_SECTION_MODULE
runtime-exports-section: symbol-section runtime-private-export-message
	schema/WIRE_RSIR_SECTION_EXPORTS
bad: copy runtime-private-export-message
fixture-mutations/put-u32 bad
	((select runtime-modules-section 'payload-offset) + schema/WIRE_RSIR_MODULE_KIND_OFFSET)
	schema/WIRE_MODULE_KIND_USER
add-symbol-semantic-error 'USER-PRIVATE-EXPORT
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SIGNATURE
	((select runtime-exports-section 'payload-offset) + schema/WIRE_EXPORT_SYMBOL_OFFSET)
	(select runtime-exports-section 'ordinal) bad

bad: copy rich-symbol-message
fixture-mutations/put-u32 bad
	((select rich-module-section 'payload-offset) + schema/WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET)
	schema/WIRE_IMAGE_KIND_EXECUTABLE
add-symbol-semantic-error 'BAD-EXPORT-IMAGE-KIND
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_IMAGE_KIND
	(select rich-exports-section 'payload-offset)
	(select rich-exports-section 'ordinal) bad

weak-module-section: symbol-section weak-definition-message schema/WIRE_RSIR_SECTION_MODULE
bad: copy weak-definition-message
bad-offset: (select weak-module-section 'payload-offset)
	+ schema/WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET
fixture-mutations/put-u32 bad bad-offset 1
add-symbol-semantic-error 'WEAK-LIFECYCLE-FUNCTION
	schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LIFECYCLE_FUNCTION
	bad-offset (select weak-module-section 'ordinal) bad

result: symbol-linkage-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/function-signature-error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
	result/module-lifecycle-error = schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	none? result/strings none? result/files none? result/layout none? result/types
	none? result/functions none? result/modules none? result/view
] "non-binary symbol/linkage input did not return INVALID_ARGUMENTS"

foreach fixture valid-symbol-linkages [
	result: symbol-linkage-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid symbol/linkage rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/error = schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
		object? result/strings object? result/files map? result/layout
		object? result/types object? result/functions object? result/modules
		object? result/view
	][fixture/1 " valid symbol/linkage did not publish complete views"]
]

result: symbol-linkage-verifier/verify rich-symbol-message
assert to logic! all [
	result/view/symbol-count = 11
	result/view/global-count = 1
	result/view/import-count = 3
	result/view/export-count = 2
	result/view/function-count = 3
	result/view/module-kind = schema/WIRE_MODULE_KIND_USER
	result/view/image-kind = schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
] "verified symbol/linkage view changed"

covered-symbol-errors: reduce [
	schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
	schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-symbol-linkages [
	result: symbol-linkage-verifier/verify fixture/12
	assert not result/valid? [fixture/1 " malformed symbol/linkage was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert result/container-error = fixture/3 [fixture/1 " wrong container error"]
	assert result/string-error = fixture/4 [fixture/1 " wrong string error"]
	assert result/file-source-error = fixture/5 [fixture/1 " wrong file/source error"]
	assert result/data-layout-error = fixture/6 [fixture/1 " wrong data-layout error"]
	assert result/type-layout-error = fixture/7 [fixture/1 " wrong type-layout error"]
	assert result/function-signature-error = fixture/8 [
		fixture/1 " wrong function/signature error"
	]
	assert result/module-lifecycle-error = fixture/9 [
		fixture/1 " wrong module lifecycle error"
	]
	assert to logic! all [
		result/error-offset = fixture/10
		result/error-section = fixture/11
	][
		fixture/1 " expected location " fixture/10 ":" fixture/11
		" got " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		none? result/strings none? result/files none? result/layout none? result/types
		none? result/functions none? result/modules none? result/view
	][fixture/1 " published output views on failure"]
	unless find covered-symbol-errors fixture/2 [append covered-symbol-errors fixture/2]
]

repeat coverage-index (schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LIFECYCLE_FUNCTION + 1) [
	assert not none? find covered-symbol-errors (coverage-index - 1) [
		"symbol/linkage error code has no executable corpus case: " coverage-index - 1
	]
]

unless value? 'generating-wire-symbol-linkage-fixtures? [
	source-bytes: make binary! 1'048'576
	foreach source-file [
		%wire-symbol-linkage-test.red
		%wire-function-signature-test.red
		%wire-type-layout-test.red
		%wire-file-source-test.red
		%wire-string-table-test.red
		%wire-container-test.red
		%../generate-wire-symbol-linkage-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-symbol-linkage-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System symbol/linkage fixtures are stale"
	print [
		"PASS: Red RSIR symbol/linkage semantics"
		length? valid-symbol-linkages "valid"
		length? malformed-symbol-linkages "malformed" lf
	]
]
