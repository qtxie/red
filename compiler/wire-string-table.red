Red [
	Title: "Hybrid compiler string-table semantic verifier"
	File:  %wire-string-table.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]

compiler-wire-string-table: context [
	schema: compiler-wire-schema
	container: compiler-wire-container

	expected-string-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

	string-fields: reduce [
		'offset schema/WIRE_STRING_OFFSET_OFFSET
		'size   schema/WIRE_STRING_SIZE_OFFSET
	]

	make-table: does [
		make object! [
			record-count: 0
			records-offset: 0
			records-ordinal: 0
			record-size: schema/WIRE_STRING_SIZE
			data-offset: 0
			data-ordinal: 0
			data-size: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			table: none
		]
	]

	reject: func [
		result [object!]
		code offset section [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	section-kinds-for: func [magic [integer!]][
		case [
			magic = schema/WIRE_MAGIC_RSIR [
				reduce [
					schema/WIRE_RSIR_SECTION_STRINGS
					schema/WIRE_RSIR_SECTION_STRING_DATA
				]
			]
			magic = schema/WIRE_MAGIC_RSCG [
				reduce [
					schema/WIRE_RSCG_SECTION_STRINGS
					schema/WIRE_RSCG_SECTION_STRING_DATA
				]
			]
			magic = schema/WIRE_MAGIC_RSDG [
				reduce [
					schema/WIRE_RSDG_SECTION_STRINGS
					schema/WIRE_RSDG_SECTION_STRING_DATA
				]
			]
			true [none]
		]
	]

	; Returns 0 for valid UTF-8, a positive encoded bad-byte offset for an
	; invalid sequence, and a negative encoded bad-byte offset for a NUL byte.
	scan-utf8: func [
		data [binary!]
		start size [integer!]
		/local i b b2 b3 b4 min-second max-second
	][
		i: 0
		while [i < size][
			b: to integer! pick data (start + i + 1)
			if b = 0 [return (0 - (i + 1))]
			either b < 128 [
				i: i + 1
			][
				either all [b >= 194 b <= 223][
					if (i + 2) > size [return (size + 1)]
					b2: to integer! pick data (start + i + 2)
					if b2 = 0 [return (0 - (i + 2))]
					unless all [b2 >= 128 b2 <= 191][return (i + 2)]
					i: i + 2
				][
					either any [
						b = 224
						all [b >= 225 b <= 236]
						b = 237
						all [b >= 238 b <= 239]
					][
						if (i + 3) > size [return (size + 1)]
						b2: to integer! pick data (start + i + 2)
						b3: to integer! pick data (start + i + 3)
						if b2 = 0 [return (0 - (i + 2))]
						if b3 = 0 [return (0 - (i + 3))]
						either b = 224 [
							min-second: 160
							max-second: 191
						][
							either b = 237 [
								min-second: 128
								max-second: 159
							][
								min-second: 128
								max-second: 191
							]
						]
						unless all [
							b2 >= min-second
							b2 <= max-second
						][return (i + 2)]
						unless all [b3 >= 128 b3 <= 191][return (i + 3)]
						i: i + 3
					][
						either any [
							b = 240
							all [b >= 241 b <= 243]
							b = 244
						][
							if (i + 4) > size [return (size + 1)]
							b2: to integer! pick data (start + i + 2)
							b3: to integer! pick data (start + i + 3)
							b4: to integer! pick data (start + i + 4)
							if b2 = 0 [return (0 - (i + 2))]
							if b3 = 0 [return (0 - (i + 3))]
							if b4 = 0 [return (0 - (i + 4))]
							either b = 240 [
								min-second: 144
								max-second: 191
							][
								either b = 244 [
									min-second: 128
									max-second: 143
								][
									min-second: 128
									max-second: 191
								]
							]
							unless all [
								b2 >= min-second
								b2 <= max-second
							][return (i + 2)]
							unless all [b3 >= 128 b3 <= 191][return (i + 3)]
							unless all [b4 >= 128 b4 <= 191][return (i + 4)]
							i: i + 4
						][
							return (i + 1)
						]
					]
				]
			]
		]
		0
	]

	compare-slices: func [
		data [binary!]
		left-offset left-size right-offset right-size [integer!]
		/local i limit left-byte right-byte
	][
		i: 0
		limit: either left-size < right-size [left-size][right-size]
		while [i < limit][
			left-byte: to integer! pick data (left-offset + i + 1)
			right-byte: to integer! pick data (right-offset + i + 1)
			if left-byte < right-byte [return -1]
			if left-byte > right-byte [return 1]
			i: i + 1
		]
		either left-size < right-size [
			-1
		][
			either left-size > right-size [1][0]
		]
	]

	verify: func [
		data expected-magic
		/local result kinds strings-kind data-kind container-result strings-section
			data-section header record-count records-offset data-offset data-size
			record-index record-offset string-offset string-size finish cursor
			previous-offset previous-size comparison scan-code error-relative
			table section-ordinal
	][
		result: make-result
		unless all [binary? data integer? expected-magic][
			return reject result schema/WIRE_STRING_TABLE_ERROR_INVALID_ARGUMENTS 0 0
		]
		kinds: section-kinds-for expected-magic
		if none? kinds [
			return reject result schema/WIRE_STRING_TABLE_ERROR_UNSUPPORTED_MESSAGE 0 0
		]
		strings-kind: kinds/1
		data-kind: kinds/2

		container-result: container/verify/expect data expected-magic
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		strings-section: container/find-section container-result strings-kind
		data-section: container/find-section container-result data-kind
		if none? strings-section [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]
		if none? data-section [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		section-ordinal: select strings-section 'ordinal
		if (select strings-section 'flags) <> expected-string-flags [
			return reject result schema/WIRE_STRING_TABLE_ERROR_BAD_STRING_SECTION_FLAGS
				((select strings-section 'entry-offset)
					+ schema/WIRE_DIRECTORY_FLAGS_OFFSET) section-ordinal
		]
		if (select data-section 'flags) <> 0 [
			return reject result schema/WIRE_STRING_TABLE_ERROR_BAD_STRING_DATA_SECTION_FLAGS
				((select data-section 'entry-offset)
					+ schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select data-section 'ordinal)
		]

		record-count: select strings-section 'record-count
		records-offset: select strings-section 'payload-offset
		data-offset: select data-section 'payload-offset
		data-size: select data-section 'payload-size

		; Decode every signed scalar before applying cross-record rules. This
		; keeps malformed high-bit fields deterministic across implementations.
		record-index: 0
		while [record-index < record-count][
			record-offset: records-offset
				+ (record-index * schema/WIRE_STRING_SIZE)
		string-offset: container/read-i31 data
			(record-offset + schema/WIRE_STRING_OFFSET_OFFSET)
		if none? string-offset [
			return reject result schema/WIRE_STRING_TABLE_ERROR_SCALAR_RANGE
				(record-offset + schema/WIRE_STRING_OFFSET_OFFSET) section-ordinal
		]
		string-size: container/read-i31 data
			(record-offset + schema/WIRE_STRING_SIZE_OFFSET)
		if none? string-size [
			return reject result schema/WIRE_STRING_TABLE_ERROR_SCALAR_RANGE
				(record-offset + schema/WIRE_STRING_SIZE_OFFSET) section-ordinal
		]
		record-index: record-index + 1
		]

		cursor: 0
		previous-offset: 0
		previous-size: 0
		record-index: 0
		while [record-index < record-count][
			record-offset: records-offset
				+ (record-index * schema/WIRE_STRING_SIZE)
			string-offset: container/read-i31 data
				(record-offset + schema/WIRE_STRING_OFFSET_OFFSET)
			string-size: container/read-i31 data
				(record-offset + schema/WIRE_STRING_SIZE_OFFSET)
			finish: container/checked-add string-offset string-size
			if any [none? finish finish > data-size][
				return reject result schema/WIRE_STRING_TABLE_ERROR_STRING_SLICE_RANGE
					(record-offset + schema/WIRE_STRING_OFFSET_OFFSET) section-ordinal
			]
			if string-offset <> cursor [
				return reject result schema/WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
					(record-offset + schema/WIRE_STRING_OFFSET_OFFSET) section-ordinal
			]
			if zero? string-size [
				unless all [record-index = 0 string-offset = 0][
					return reject result schema/WIRE_STRING_TABLE_ERROR_BAD_EMPTY_STRING
						(record-offset + schema/WIRE_STRING_OFFSET_OFFSET) section-ordinal
				]
			]
			scan-code: scan-utf8 data (data-offset + string-offset) string-size
			if scan-code < 0 [
				error-relative: (0 - scan-code) - 1
				return reject result schema/WIRE_STRING_TABLE_ERROR_EMBEDDED_NUL
					((data-offset + string-offset) + error-relative)
					(select data-section 'ordinal)
			]
			if scan-code > 0 [
				error-relative: scan-code - 1
				return reject result schema/WIRE_STRING_TABLE_ERROR_INVALID_UTF8
					((data-offset + string-offset) + error-relative)
					(select data-section 'ordinal)
			]
			if record-index > 0 [
				comparison: compare-slices data
					(data-offset + string-offset) string-size
					(data-offset + previous-offset) previous-size
				if comparison < 0 [
					return reject result schema/WIRE_STRING_TABLE_ERROR_STRING_ORDER
						(record-offset + schema/WIRE_STRING_OFFSET_OFFSET) section-ordinal
				]
				if comparison = 0 [
					return reject result schema/WIRE_STRING_TABLE_ERROR_DUPLICATE_STRING
						(record-offset + schema/WIRE_STRING_OFFSET_OFFSET) section-ordinal
				]
			]
			cursor: finish
			previous-offset: string-offset
			previous-size: string-size
			record-index: record-index + 1
		]

		if cursor <> data-size [
			return reject result schema/WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
				(data-offset + cursor) (select data-section 'ordinal)
		]

		table: make-table
		table/record-count: record-count
		table/records-offset: records-offset
		table/records-ordinal: section-ordinal
		table/record-size: select strings-section 'record-size
		table/data-offset: data-offset
		table/data-ordinal: select data-section 'ordinal
		table/data-size: data-size
		result/table: table
		result/valid?: true
		result
	]
]
