Red/System [
	Title: "Hybrid compiler string-table semantic verifier"
	File:  %wire-string-table.reds
]

#include %wire-reader.reds

wire-string-table-result!: alias struct! [
	error           [integer!]
	container-error [integer!]
	error-offset    [integer!]
	error-section   [integer!]
]

wire-string-table!: alias struct! [
	records         [byte-ptr!]
	record-count    [integer!]
	record-size     [integer!]
	records-offset  [integer!]
	records-ordinal [integer!]
	data            [byte-ptr!]
	data-size       [integer!]
	data-offset     [integer!]
	data-ordinal    [integer!]
]

wire-string-slice!: alias struct! [
	data [byte-ptr!]
	size [integer!]
]

wire-string-table-reader: context [
	expected-string-flags:
		WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED

	set-error: func [
		result [wire-string-table-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	set-container-error: func [
		result [wire-string-table-result!]
		container [wire-container-result!]
		code [integer!]
		return: [integer!]
	][
		result/container-error: code
		set-error result WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
			container/error-offset container/error-section
	]

	strings-kind-for: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_STRINGS]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_STRINGS]
			magic = WIRE_MAGIC_RSDG [WIRE_RSDG_SECTION_STRINGS]
			true [-1]
		]
	]

	data-kind-for: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_STRING_DATA]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_STRING_DATA]
			magic = WIRE_MAGIC_RSDG [WIRE_RSDG_SECTION_STRING_DATA]
			true [-1]
		]
	]

	section-flags-offset: func [
		section [wire-section-slice!]
		return: [integer!]
	][
		WIRE_HEADER_SIZE
			+ (((section/ordinal - 1) * WIRE_DIRECTORY_SIZE)
				+ WIRE_DIRECTORY_FLAGS_OFFSET)
	]

	; Returns 0 for valid UTF-8, a positive encoded bad-byte offset for an
	; invalid sequence, and a negative encoded bad-byte offset for a NUL byte.
	scan-utf8: func [
		data [byte-ptr!]
		start size [integer!]
		return: [integer!]
		/local i b b2 b3 b4 min-second max-second [integer!] p [byte-ptr!]
	][
		i: 0
		while [i < size][
			p: (data + start) + i
			b: as integer! p/1
			if b = 0 [return 0 - (i + 1)]
			either b < 128 [
				i: i + 1
			][
				either all [b >= 194 b <= 223][
					if (i + 2) > size [return size + 1]
					b2: as integer! p/2
					if b2 = 0 [return 0 - (i + 2)]
					unless all [b2 >= 128 b2 <= 191][return i + 2]
					i: i + 2
				][
					either any [
						b = 224
						all [b >= 225 b <= 236]
						b = 237
						all [b >= 238 b <= 239]
					][
						if (i + 3) > size [return size + 1]
						b2: as integer! p/2
						b3: as integer! p/3
						if b2 = 0 [return 0 - (i + 2)]
						if b3 = 0 [return 0 - (i + 3)]
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
						][return i + 2]
						unless all [b3 >= 128 b3 <= 191][return i + 3]
						i: i + 3
					][
						either any [
							b = 240
							all [b >= 241 b <= 243]
							b = 244
						][
							if (i + 4) > size [return size + 1]
							b2: as integer! p/2
							b3: as integer! p/3
							b4: as integer! p/4
							if b2 = 0 [return 0 - (i + 2)]
							if b3 = 0 [return 0 - (i + 3)]
							if b4 = 0 [return 0 - (i + 4)]
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
							][return i + 2]
							unless all [b3 >= 128 b3 <= 191][return i + 3]
							unless all [b4 >= 128 b4 <= 191][return i + 4]
							i: i + 4
						][
							return i + 1
						]
					]
				]
			]
		]
		0
	]

	compare-slices: func [
		data [byte-ptr!]
		left-offset left-size right-offset right-size [integer!]
		return: [integer!]
		/local i limit left-byte right-byte [integer!] left right [byte-ptr!]
	][
		i: 0
		limit: either left-size < right-size [left-size][right-size]
		left: data + left-offset
		right: data + right-offset
		while [i < limit][
			left-byte: as integer! left/1
			right-byte: as integer! right/1
			if left-byte < right-byte [return -1]
			if left-byte > right-byte [return 1]
			left: left + 1
			right: right + 1
			i: i + 1
		]
		either left-size < right-size [
			-1
		][
			either left-size > right-size [1][0]
		]
	]

	; The caller must pass a table published by a successful verify call.
	get-slice: func [
		table [wire-string-table!]
		id [integer!]
		slice [wire-string-slice!]
		return: [logic!]
		/local record-offset offset size [integer!]
	][
		if any [null? table null? slice id <= 0 id > table/record-count][
			return false
		]
		record-offset: (id - 1) * WIRE_STRING_SIZE
		offset: wire-container-reader/read-i31
			table/records (record-offset + WIRE_STRING_OFFSET_OFFSET)
		size: wire-container-reader/read-i31
			table/records (record-offset + WIRE_STRING_SIZE_OFFSET)
		slice/data: either size = 0 [as byte-ptr! 0][table/data + offset]
		slice/size: size
		true
	]

	verify: func [
		data [byte-ptr!]
		size expected-magic [integer!]
		result [wire-string-table-result!]
		table [wire-string-table!]
		return: [integer!]
		/local container [wire-container-result!] strings data-section [wire-section-slice!]
			strings-kind data-kind status record-index record-offset string-offset
			string-size finish cursor previous-offset previous-size comparison
			scan-code error-relative [integer!]
	][
		if null? result [return WIRE_STRING_TABLE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [size < 0 null? data null? table][
			return set-error result WIRE_STRING_TABLE_ERROR_INVALID_ARGUMENTS 0 0
		]
		strings-kind: strings-kind-for expected-magic
		data-kind: data-kind-for expected-magic
		if any [strings-kind < 0 data-kind < 0][
			return set-error result WIRE_STRING_TABLE_ERROR_UNSUPPORTED_MESSAGE 0 0
		]

		container: declare wire-container-result!
		status: wire-container-reader/verify data size expected-magic container
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			return set-container-error result container status
		]

		strings: declare wire-section-slice!
		data-section: declare wire-section-slice!
		unless wire-container-reader/find-verified-section data strings-kind strings [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data data-kind data-section [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]

		if strings/flags <> expected-string-flags [
			return set-error result WIRE_STRING_TABLE_ERROR_BAD_STRING_SECTION_FLAGS
				section-flags-offset strings strings/ordinal
		]
		if data-section/flags <> 0 [
			return set-error result WIRE_STRING_TABLE_ERROR_BAD_STRING_DATA_SECTION_FLAGS
				section-flags-offset data-section data-section/ordinal
		]

		; Decode every signed scalar before applying cross-record rules.
		record-index: 0
		while [record-index < strings/record-count][
			record-offset: record-index * WIRE_STRING_SIZE
			string-offset: wire-container-reader/read-i31
				strings/data (record-offset + WIRE_STRING_OFFSET_OFFSET)
			string-size: wire-container-reader/read-i31
				strings/data (record-offset + WIRE_STRING_SIZE_OFFSET)
			if string-offset < 0 [
				return set-error result WIRE_STRING_TABLE_ERROR_SCALAR_RANGE
					(strings/offset + record-offset) + WIRE_STRING_OFFSET_OFFSET
					strings/ordinal
			]
			if string-size < 0 [
				return set-error result WIRE_STRING_TABLE_ERROR_SCALAR_RANGE
					(strings/offset + record-offset) + WIRE_STRING_SIZE_OFFSET
					strings/ordinal
			]
			record-index: record-index + 1
		]

		cursor: 0
		previous-offset: 0
		previous-size: 0
		record-index: 0
		while [record-index < strings/record-count][
			record-offset: record-index * WIRE_STRING_SIZE
			string-offset: wire-container-reader/read-i31
				strings/data (record-offset + WIRE_STRING_OFFSET_OFFSET)
			string-size: wire-container-reader/read-i31
				strings/data (record-offset + WIRE_STRING_SIZE_OFFSET)
			finish: wire-container-reader/checked-add string-offset string-size
			if any [finish < 0 finish > data-section/size][
				return set-error result WIRE_STRING_TABLE_ERROR_STRING_SLICE_RANGE
					(strings/offset + record-offset) + WIRE_STRING_OFFSET_OFFSET
					strings/ordinal
			]
			if string-offset <> cursor [
				return set-error result WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
					(strings/offset + record-offset) + WIRE_STRING_OFFSET_OFFSET
					strings/ordinal
			]
			if all [string-size = 0 any [record-index <> 0 string-offset <> 0]][
				return set-error result WIRE_STRING_TABLE_ERROR_BAD_EMPTY_STRING
					(strings/offset + record-offset) + WIRE_STRING_OFFSET_OFFSET
					strings/ordinal
			]
			scan-code: scan-utf8 data-section/data string-offset string-size
			if scan-code < 0 [
				error-relative: (0 - scan-code) - 1
				return set-error result WIRE_STRING_TABLE_ERROR_EMBEDDED_NUL
					(data-section/offset + string-offset) + error-relative
					data-section/ordinal
			]
			if scan-code > 0 [
				error-relative: scan-code - 1
				return set-error result WIRE_STRING_TABLE_ERROR_INVALID_UTF8
					(data-section/offset + string-offset) + error-relative
					data-section/ordinal
			]
			if record-index > 0 [
				comparison: compare-slices data-section/data
					string-offset string-size previous-offset previous-size
				if comparison < 0 [
					return set-error result WIRE_STRING_TABLE_ERROR_STRING_ORDER
						(strings/offset + record-offset) + WIRE_STRING_OFFSET_OFFSET
						strings/ordinal
				]
				if comparison = 0 [
					return set-error result WIRE_STRING_TABLE_ERROR_DUPLICATE_STRING
						(strings/offset + record-offset) + WIRE_STRING_OFFSET_OFFSET
						strings/ordinal
				]
			]
			cursor: finish
			previous-offset: string-offset
			previous-size: string-size
			record-index: record-index + 1
		]

		if cursor <> data-section/size [
			return set-error result WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
				data-section/offset + cursor data-section/ordinal
		]

		table/records: strings/data
		table/record-count: strings/record-count
		table/record-size: strings/record-size
		table/records-offset: strings/offset
		table/records-ordinal: strings/ordinal
		table/data: data-section/data
		table/data-size: data-section/size
		table/data-offset: data-section/offset
		table/data-ordinal: data-section/ordinal
		WIRE_STRING_TABLE_ERROR_SUCCESS
	]
]
