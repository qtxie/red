Red [
	Title: "Hybrid compiler wire container tests"
]

do %../../../compiler/int-to-bin.red
do %../../../compiler/wire-schema.red
do %../../../compiler/wire-container.red

schema: compiler-wire-schema
verifier: compiler-wire-container

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

fixture-writer: context [
	append-u16: func [output [binary!] value [integer!]][
		append output int-to-bin/to-bin16 value
	]

	append-u32: func [output [binary!] value [integer!]][
		append output int-to-bin/to-bin32 value
	]

	words: func [values [block!] /local output][
		output: make binary! ((length? values) * 4)
		foreach value values [append-u32 output value]
		output
	]

	align-size: func [size [integer!] alignment [integer!] /local remainder][
		remainder: size // alignment
		either zero? remainder [size][size + alignment - remainder]
	]

	profile-for: func [magic [integer!]][
		case [
			magic = schema/WIRE_MAGIC_RSCF [schema/profiles/RSCF]
			magic = schema/WIRE_MAGIC_RSIR [schema/profiles/RSIR]
			magic = schema/WIRE_MAGIC_RSCG [schema/profiles/RSCG]
			magic = schema/WIRE_MAGIC_RSDG [schema/profiles/RSDG]
			true [none]
		]
	]

	sections-for: func [
		magic [integer!]
		payloads [map!]
		/local profile sections kind payload
	][
		profile: profile-for magic
		sections: make block! profile/required-count
		repeat kind profile/required-count [
			payload: any [select payloads kind #{}]
			append/only sections reduce [
				kind
				0
				pick profile/record-sizes kind
				pick profile/alignments kind
				payload
			]
		]
		sections
	]

	set-section-flags: func [
		sections [block!]
		kind flags [integer!]
		/local section
	][
		foreach section sections [
			if section/1 = kind [section/2: flags return sections]
		]
		assert false ["fixture section not found for flags: " kind]
	]

	build: func [
		magic [integer!]
		target [integer!]
		abi [integer!]
		endian [integer!]
		pointer-size [integer!]
		sections [block!]
		/local directory-end cursor layouts section kind flags record-size alignment payload
			payload-size payload-offset record-count total-size output layout
	][
		directory-end: schema/WIRE_HEADER_SIZE
			+ ((length? sections) * schema/WIRE_DIRECTORY_SIZE)
		cursor: directory-end
		layouts: make block! length? sections
		foreach section sections [
			set [kind flags record-size alignment payload] section
			payload-size: length? payload
			either zero? payload-size [
				payload-offset: 0
				record-count: 0
			][
				cursor: align-size cursor alignment
				payload-offset: cursor
				assert zero? (payload-size // record-size) [
					"fixture payload is not a whole record for section " kind
				]
				record-count: payload-size / record-size
				cursor: cursor + payload-size
			]
			append/only layouts reduce [
				kind flags payload-offset payload-size record-count record-size alignment 0 payload
			]
		]
		total-size: cursor
		output: make binary! total-size

		append-u32 output magic
		append-u16 output schema/WIRE_VERSION_MAJOR
		append-u16 output schema/WIRE_VERSION_MINOR
		append-u32 output schema/WIRE_HEADER_SIZE
		append-u32 output 0
		append-u32 output total-size
		append-u32 output length? sections
		append-u32 output schema/WIRE_HEADER_SIZE
		append-u32 output schema/WIRE_DIRECTORY_SIZE
		append-u32 output target
		append-u32 output abi
		append-u32 output endian
		append-u32 output pointer-size
		append-u32 output 0
		append-u32 output 0
		append-u32 output 1
		append-u32 output schema/WIRE_SCHEMA_FINGERPRINT

		foreach layout layouts [
			repeat index 8 [append-u32 output layout/:index]
		]
		foreach layout layouts [
			payload-offset: layout/3
			payload: layout/9
			unless empty? payload [
				append/dup output 0 (payload-offset - length? output)
				append output payload
			]
		]
		assert (length? output) = total-size "fixture writer produced wrong size"
		output
	]
]

data-layout: fixture-writer/words [1 8 8 16 8 8 8 0]

rscf-payloads: make map! reduce [
	schema/WIRE_RSCF_SECTION_CONFIG fixture-writer/words [
		0 0 1 1 0 1 0 0 1048576 65536 1 0 0 0 0 0
	]
]
rscf: fixture-writer/build
	schema/WIRE_MAGIC_RSCF
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8
	fixture-writer/sections-for schema/WIRE_MAGIC_RSCF rscf-payloads

rsir-payloads: make map! reduce [
	schema/WIRE_RSIR_SECTION_MODULE fixture-writer/words [0 2 1 0 0 0 0 0]
	schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
]
rsir-sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR rsir-payloads
fixture-writer/set-section-flags rsir-sections schema/WIRE_RSIR_SECTION_STRINGS
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
fixture-writer/set-section-flags rsir-sections schema/WIRE_RSIR_SECTION_FILES
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
fixture-writer/set-section-flags rsir-sections schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
rsir: fixture-writer/build
	schema/WIRE_MAGIC_RSIR
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8
	rsir-sections

rscg-payloads: make map! reduce [
	schema/WIRE_RSCG_SECTION_DATA_LAYOUT data-layout
	schema/WIRE_RSCG_SECTION_MODULES fixture-writer/words [0 2 1 0 0 0 0 0]
]
rscg-sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSCG rscg-payloads
fixture-writer/set-section-flags rscg-sections schema/WIRE_RSCG_SECTION_STRINGS
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
fixture-writer/set-section-flags rscg-sections schema/WIRE_RSCG_SECTION_FILES
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
rscg: fixture-writer/build
	schema/WIRE_MAGIC_RSCG
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8
	rscg-sections

rsdg-payloads: make map! reduce [
	schema/WIRE_RSDG_SECTION_STRINGS fixture-writer/words [0 1]
	schema/WIRE_RSDG_SECTION_STRING_DATA #{78}
	schema/WIRE_RSDG_SECTION_DIAGNOSTICS fixture-writer/words [
		3 3 3 1 0 0 0 0 0 0
	]
]
rsdg-sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSDG rsdg-payloads
fixture-writer/set-section-flags rsdg-sections schema/WIRE_RSDG_SECTION_STRINGS
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
rsdg: fixture-writer/build
	schema/WIRE_MAGIC_RSDG
	0 0 0 0
	rsdg-sections

rscg-optional-sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSCG rscg-payloads
fixture-writer/set-section-flags rscg-optional-sections schema/WIRE_RSCG_SECTION_STRINGS
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
fixture-writer/set-section-flags rscg-optional-sections schema/WIRE_RSCG_SECTION_FILES
	(schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED)
append/only rscg-optional-sections reduce [
	schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS
	schema/WIRE_SECTION_FLAG_OPTIONAL
	schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_RECORD_SIZE
	schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_ALIGNMENT
	#{}
]
rscg-optional: fixture-writer/build
	schema/WIRE_MAGIC_RSCG
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8
	rscg-optional-sections

rscf-unknown-sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSCF rscf-payloads
append/only rscf-unknown-sections reduce [
	99 schema/WIRE_SECTION_FLAG_OPTIONAL 1 1 #{}
]
rscf-unknown-optional: fixture-writer/build
	schema/WIRE_MAGIC_RSCF
	schema/WIRE_TARGET_X86_64
	schema/WIRE_ABI_WIN64
	schema/WIRE_ENDIAN_LITTLE
	8
	rscf-unknown-sections

foreach [name magic data section-count] reduce [
	'RSCF schema/WIRE_MAGIC_RSCF rscf 1
	'RSIR schema/WIRE_MAGIC_RSIR rsir 30
	'RSCG schema/WIRE_MAGIC_RSCG rscg 16
	'RSDG schema/WIRE_MAGIC_RSDG rsdg 3
	'RSCG-OPTIONAL schema/WIRE_MAGIC_RSCG rscg-optional 17
	'RSCF-UNKNOWN-OPTIONAL schema/WIRE_MAGIC_RSCF rscf-unknown-optional 2
][
	result: verifier/verify/expect data magic
	assert result/valid? [name " fixture rejected with error " result/error]
	assert (length? result/sections) = section-count [name " section count mismatch"]
]

assert (checksum rscf 'SHA256) =
	#{76ABF89D112EE861B35E5B3588A2E3AD6866820216CCC30DBDFEA5FF125288D4}
	"RSCF golden bytes changed"
assert (checksum rsir 'SHA256) =
	#{CAAC04EA6603F7BE14BC5EF1D43049D0C1A878913D168241F7C32AEE63DACCFC}
	"RSIR golden bytes changed"
assert (checksum rscg 'SHA256) =
	#{B81A876D8157D032DBAF95E248AE2AA07C800AAC836BCB2B51F06B9A83BFF0EB}
	"RSCG golden bytes changed"
assert (checksum rsdg 'SHA256) =
	#{3EEE4999E1BA9F32D9F794DD3C8C83AE5DF80E93D9E03AF200AA9BB3563DAA2A}
	"RSDG golden bytes changed"
assert (length? rsdg) = schema/WIRE_RSDG_MINIMUM_SIZE
	"RSDG golden fixture is not the schema minimum"
assert all [
	(length? rscf) = schema/WIRE_RSCF_MINIMUM_SIZE
	(length? rsir) = schema/WIRE_RSIR_MINIMUM_SIZE
	(length? rscg) = schema/WIRE_RSCG_MINIMUM_SIZE
]["RSCF, RSIR, or RSCG golden fixture is not the schema minimum"]

fixture-mutations: context [
	put-u16: func [data [binary!] offset [integer!] value [integer!]][
		change/part at data (offset + 1) int-to-bin/to-bin16 value 2
		data
	]

	put-u32: func [data [binary!] offset [integer!] value [integer!]][
		change/part at data (offset + 1) int-to-bin/to-bin32 value 4
		data
	]

	put-bytes: func [data [binary!] offset [integer!] value [binary!]][
		change/part at data (offset + 1) value length? value
		data
	]

	entry-offset: func [ordinal [integer!]][
		schema/WIRE_HEADER_SIZE + ((ordinal - 1) * schema/WIRE_DIRECTORY_SIZE)
	]
]

malformed: make block! 32
add-malformed: func [
	name [word!]
	magic [integer!]
	expected-error [integer!]
	data [binary!]
][
	append/only malformed reduce [name magic expected-error data]
]

add-malformed 'TRUNCATED-HEADER schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_TRUNCATED_HEADER copy/part rscf 63

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_MAGIC_OFFSET 0
add-malformed 'BAD-MAGIC schema/WIRE_MAGIC_RSCF schema/WIRE_CONTAINER_ERROR_BAD_MAGIC bad

bad: copy rscf
fixture-mutations/put-u16 bad schema/WIRE_HEADER_VERSION_MAJOR_OFFSET 2
add-malformed 'BAD-VERSION schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_UNSUPPORTED_VERSION bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_HEADER_SIZE_OFFSET 63
add-malformed 'BAD-HEADER-SIZE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_HEADER_SIZE bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_CONTAINER_FLAGS_OFFSET 1
add-malformed 'BAD-CONTAINER-FLAGS schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_CONTAINER_FLAGS bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TOTAL_SIZE_OFFSET 159
add-malformed 'BAD-TOTAL-SIZE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_TOTAL_SIZE bad

bad: copy rscf
fixture-mutations/put-bytes bad schema/WIRE_HEADER_SECTION_COUNT_OFFSET #{00000080}
add-malformed 'SCALAR-RANGE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_SCALAR_RANGE bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed 'BAD-FINGERPRINT schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TARGET_OFFSET 0
add-malformed 'BAD-TARGET schema/WIRE_MAGIC_RSCF schema/WIRE_CONTAINER_ERROR_BAD_TARGET bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_ABI_OFFSET 0
add-malformed 'BAD-ABI schema/WIRE_MAGIC_RSCF schema/WIRE_CONTAINER_ERROR_BAD_ABI bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
add-malformed 'BAD-ENDIAN schema/WIRE_MAGIC_RSCF schema/WIRE_CONTAINER_ERROR_BAD_ENDIAN bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0
add-malformed 'BAD-POINTER-SIZE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_POINTER_SIZE bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_DIRECTORY_OFFSET_OFFSET 60
add-malformed 'BAD-DIRECTORY-OFFSET schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_DIRECTORY_OFFSET bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET 28
add-malformed 'BAD-DIRECTORY-RECORD-SIZE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_DIRECTORY_RECORD_SIZE bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SECTION_COUNT_OFFSET 4
add-malformed 'DIRECTORY-RANGE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_DIRECTORY_RANGE bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SECTION_COUNT_OFFSET 2147483647
add-malformed 'DIRECTORY-MULTIPLY-OVERFLOW schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_DIRECTORY_RANGE bad

bad: copy rsir
entry: fixture-mutations/entry-offset 2
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_KIND_OFFSET) 1
add-malformed 'SECTION-ORDER schema/WIRE_MAGIC_RSIR
	schema/WIRE_CONTAINER_ERROR_SECTION_ORDER bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_OPTIONAL
add-malformed 'REQUIRED-MARKED-OPTIONAL schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_KIND_OFFSET) 99
add-malformed 'UNKNOWN-REQUIRED schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_UNKNOWN_REQUIRED_SECTION bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_SIZE_OFFSET) 32
add-malformed 'BAD-RECORD-SIZE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_RECORD_SIZE bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 2
add-malformed 'SECTION-PRODUCT schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_SECTION_PRODUCT bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 2147483647
add-malformed 'SECTION-MULTIPLY-OVERFLOW schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_SECTION_PRODUCT bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_ALIGNMENT_OFFSET) 3
add-malformed 'BAD-ALIGNMENT schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_ALIGNMENT bad

bad: copy rsir
entry: fixture-mutations/entry-offset 5
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 4
add-malformed 'EMPTY-SECTION-OFFSET schema/WIRE_MAGIC_RSIR
	schema/WIRE_CONTAINER_ERROR_EMPTY_SECTION_OFFSET bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 160
add-malformed 'SECTION-RANGE schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_SECTION_RANGE bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 2147483644
add-malformed 'SECTION-ADD-OVERFLOW schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_SECTION_RANGE bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 97
add-malformed 'MISALIGNED-PAYLOAD schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_ALIGNMENT bad

bad: copy rsir
entry: fixture-mutations/entry-offset 2
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 960
add-malformed 'PAYLOAD-ORDER schema/WIRE_MAGIC_RSIR
	schema/WIRE_CONTAINER_ERROR_PAYLOAD_ORDER bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RESERVED_OFFSET) 1
add-malformed 'NONZERO-RESERVED schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_NONZERO_RESERVED bad

bad: copy rsdg
result: verifier/verify/expect rsdg schema/WIRE_MAGIC_RSDG
section: verifier/find-section result schema/WIRE_RSDG_SECTION_STRING_DATA
padding-offset: (select section 'payload-offset) + (select section 'payload-size)
poke bad (padding-offset + 1) 1
add-malformed 'NONZERO-PADDING schema/WIRE_MAGIC_RSDG
	schema/WIRE_CONTAINER_ERROR_NONZERO_PADDING bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_KIND_OFFSET) 99
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_OPTIONAL
add-malformed 'MISSING-REQUIRED schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION bad

bad: copy rscf
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 0
add-malformed 'BAD-CARDINALITY schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY bad

bad: copy rscg
result: verifier/verify/expect rscg schema/WIRE_MAGIC_RSCG
section: verifier/find-section result schema/WIRE_RSCG_SECTION_MODULES
entry: fixture-mutations/entry-offset schema/WIRE_RSCG_SECTION_MODULES
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 0
fixture-mutations/put-bytes bad (select section 'payload-offset)
	#{0000000000000000000000000000000000000000000000000000000000000000}
add-malformed 'RSCG-EMPTY-MODULES schema/WIRE_MAGIC_RSCG
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY bad

bad: copy rsdg
entry: fixture-mutations/entry-offset 3
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 0
add-malformed 'NONEMPTY-CARDINALITY schema/WIRE_MAGIC_RSDG
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY bad

bad: copy rsdg
entry: fixture-mutations/entry-offset 1
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 0
result: verifier/verify/expect rsdg schema/WIRE_MAGIC_RSDG
section: verifier/find-section result schema/WIRE_RSDG_SECTION_STRINGS
fixture-mutations/put-bytes bad (select section 'payload-offset)
	#{0000000000000000}
add-malformed 'RSDG-EMPTY-STRINGS schema/WIRE_MAGIC_RSDG
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY bad

bad: copy rsdg
entry: fixture-mutations/entry-offset 2
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET) 0
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) 0
result: verifier/verify/expect rsdg schema/WIRE_MAGIC_RSDG
section: verifier/find-section result schema/WIRE_RSDG_SECTION_STRING_DATA
fixture-mutations/put-bytes bad (select section 'payload-offset) #{00}
add-malformed 'RSDG-EMPTY-STRING-DATA schema/WIRE_MAGIC_RSDG
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY bad

bad: copy rsdg
fixture-mutations/put-u32 bad schema/WIRE_HEADER_ABI_OFFSET 1
add-malformed 'PARTIAL-ZERO-TARGET schema/WIRE_MAGIC_RSDG
	schema/WIRE_CONTAINER_ERROR_BAD_ABI bad

bad: copy rscg-optional
entry: fixture-mutations/entry-offset 17
fixture-mutations/put-u32 bad (entry + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed 'OPTIONAL-FLAG-MISSING schema/WIRE_MAGIC_RSCG
	schema/WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TOTAL_SIZE_OFFSET 161
append bad 1
add-malformed 'NONZERO-TRAILING-PADDING schema/WIRE_MAGIC_RSCF
	schema/WIRE_CONTAINER_ERROR_NONZERO_PADDING bad

foreach fixture-case malformed [
	result: verifier/verify/expect fixture-case/4 fixture-case/2
	assert not result/valid? [fixture-case/1 " malformed fixture was accepted"]
	assert result/error = fixture-case/3 [
		fixture-case/1 " expected error " fixture-case/3 " but got " result/error
	]
]

result: verifier/verify/expect rscf schema/WIRE_MAGIC_RSCF
assert result/valid? "valid RSCF was rejected before section lookup"
section: verifier/find-section result schema/WIRE_RSCF_SECTION_CONFIG
assert not none? section "verified RSCF config section was not found"
assert (select section 'record-count) = 1 "verified RSCF config cardinality changed"
assert (select section 'ordinal) = 1 "verified RSCF config ordinal changed"
assert (select section 'entry-offset) = schema/WIRE_HEADER_SIZE
	"verified RSCF config directory offset changed"

invalid-with-section: copy rscf
fixture-mutations/put-u32 invalid-with-section schema/WIRE_HEADER_TOTAL_SIZE_OFFSET 161
append invalid-with-section 1
result: verifier/verify/expect invalid-with-section schema/WIRE_MAGIC_RSCF
assert not result/valid? "invalid RSCF was accepted before section lookup"
assert none? verifier/find-section result schema/WIRE_RSCF_SECTION_CONFIG
	"section lookup exposed a partially verified directory"

result: verifier/verify/expect rscf schema/WIRE_MAGIC_RSIR
assert result/error = schema/WIRE_CONTAINER_ERROR_BAD_MAGIC
	"expected-magic mismatch was accepted"

foreach [name magic data] reduce [
	'RSCF schema/WIRE_MAGIC_RSCF rscf
	'RSIR schema/WIRE_MAGIC_RSIR rsir
	'RSCG schema/WIRE_MAGIC_RSCG rscg
	'RSDG schema/WIRE_MAGIC_RSDG rsdg
][
	repeat truncated-size length? data [
		truncated: copy/part data (truncated-size - 1)
		error: try [result: verifier/verify/expect truncated magic]
		assert not error? error [name " truncation raised an interpreter error at " truncated-size - 1]
		assert not result/valid? [name " truncation accepted at " truncated-size - 1]
	]
]

generating?: all [
	value? 'generating-wire-container-fixtures?
	get 'generating-wire-container-fixtures?
]
unless generating? [
	source-bytes: make binary! 65536
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-container-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-container-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System wire fixtures are stale"
]

print [
	"PASS: compiler wire containers"
	"RSCF=" length? rscf
	"RSIR=" length? rsir
	"RSCG=" length? rscg
	"RSDG=" length? rsdg
	"malformed=" length? malformed
]
