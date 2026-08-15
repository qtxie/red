Red/System [
	Title: "Hybrid compiler RSCG string-table merger"
	File:  %wire-codegen-strings.reds
]

#include %wire-string-table.reds
#include %wire-writer.reds

wire-codegen-string-map!: alias struct! [
	data-section-name [integer!]
	code-section-name [integer!]
	module-name       [integer!]
	function-name     [integer!]
]

wire-codegen-string-cursor!: alias struct! [
	next-input-id [integer!]
	next-extra-id [integer!]
	data          [byte-ptr!]
	size          [integer!]
	item-input-id [integer!]
	item-extra-id [integer!]
	has-input     [integer!]
	has-extra     [integer!]
	input-pointer [byte-ptr!]
	extra-pointer [byte-ptr!]
	record-offset [integer!]
	input-offset  [integer!]
	input-size    [integer!]
	compare-result [integer!]
]

wire-codegen-strings: context [
	ERROR_SUCCESS:   0
	ERROR_ARGUMENTS: 1
	ERROR_STATE:     2
	ERROR_OVERFLOW:  3

	ITEM_DONE:  0
	ITEM_READY: 1
	ITEM_ERROR: 2

	EXTRA_DATA_SECTION: 1
	EXTRA_CODE_SECTION: 2
	EXTRA_COUNT:        2
	SECTION_NAME_SIZE:  5

	reset-map: func [map [wire-codegen-string-map!]][
		map/data-section-name: 0
		map/code-section-name: 0
		map/module-name: 0
		map/function-name: 0
	]

	reset-cursor: func [cursor [wire-codegen-string-cursor!]][
		cursor/next-input-id: 1
		cursor/next-extra-id: 1
		cursor/data: as byte-ptr! 0
		cursor/size: 0
		cursor/item-input-id: 0
		cursor/item-extra-id: 0
		cursor/has-input: 0
		cursor/has-extra: 0
		cursor/input-pointer: as byte-ptr! 0
		cursor/extra-pointer: as byte-ptr! 0
		cursor/record-offset: 0
		cursor/input-offset: 0
		cursor/input-size: 0
		cursor/compare-result: 0
	]

	extra-data: func [id [integer!] return: [byte-ptr!]][
		case [
			id = EXTRA_DATA_SECTION [as byte-ptr! ".data"]
			id = EXTRA_CODE_SECTION [as byte-ptr! ".text"]
			true [as byte-ptr! 0]
		]
	]

	compare-bytes: func [
		a-data [byte-ptr!]
		a-size [integer!]
		b-data [byte-ptr!]
		b-size [integer!]
		return: [integer!]
		/local index limit a-byte b-byte [integer!]
	][
		index: 0
		limit: either a-size < b-size [a-size][b-size]
		while [index < limit][
			a-byte: as integer! a-data/1
			b-byte: as integer! b-data/1
			if a-byte < b-byte [return -1]
			if a-byte > b-byte [return 1]
			a-data: a-data + 1
			b-data: b-data + 1
			index: index + 1
		]
		either a-size < b-size [
			-1
		][
			either a-size > b-size [1][0]
		]
	]

	advance: func [
		records [byte-ptr!]
		record-count [integer!]
		string-data [byte-ptr!]
		cursor [wire-codegen-string-cursor!]
		return: [integer!]
	][
		if any [record-count < 0 null? cursor][return ITEM_ERROR]
		if all [record-count > 0 null? records][return ITEM_ERROR]
		cursor/has-input: either cursor/next-input-id <= record-count [1][0]
		cursor/has-extra: either cursor/next-extra-id <= EXTRA_COUNT [1][0]
		if all [cursor/has-input = 0 cursor/has-extra = 0][return ITEM_DONE]

		cursor/data: as byte-ptr! 0
		cursor/size: 0
		cursor/item-input-id: 0
		cursor/item-extra-id: 0
		cursor/input-pointer: as byte-ptr! 0
		cursor/input-size: 0
		if cursor/has-input <> 0 [
			cursor/record-offset: (cursor/next-input-id - 1) * WIRE_STRING_SIZE
			cursor/input-offset: wire-container-reader/read-i31 records
				(cursor/record-offset + WIRE_STRING_OFFSET_OFFSET)
			cursor/input-size: wire-container-reader/read-i31 records
				(cursor/record-offset + WIRE_STRING_SIZE_OFFSET)
			if cursor/input-size > 0 [
				if null? string-data [return ITEM_ERROR]
				cursor/input-pointer: string-data + cursor/input-offset
			]
		]
		cursor/extra-pointer: either cursor/has-extra <> 0 [
			extra-data cursor/next-extra-id
		][as byte-ptr! 0]

		case [
			all [cursor/has-input <> 0 cursor/has-extra <> 0][
				cursor/compare-result: compare-bytes cursor/input-pointer
					cursor/input-size cursor/extra-pointer SECTION_NAME_SIZE
				case [
					cursor/compare-result < 0 [
						cursor/data: cursor/input-pointer
						cursor/size: cursor/input-size
						cursor/item-input-id: cursor/next-input-id
						cursor/next-input-id: cursor/next-input-id + 1
					]
					cursor/compare-result > 0 [
						cursor/data: cursor/extra-pointer
						cursor/size: SECTION_NAME_SIZE
						cursor/item-extra-id: cursor/next-extra-id
						cursor/next-extra-id: cursor/next-extra-id + 1
					]
					true [
						cursor/data: cursor/input-pointer
						cursor/size: cursor/input-size
						cursor/item-input-id: cursor/next-input-id
						cursor/item-extra-id: cursor/next-extra-id
						cursor/next-input-id: cursor/next-input-id + 1
						cursor/next-extra-id: cursor/next-extra-id + 1
					]
				]
			]
			cursor/has-input <> 0 [
				cursor/data: cursor/input-pointer
				cursor/size: cursor/input-size
				cursor/item-input-id: cursor/next-input-id
				cursor/next-input-id: cursor/next-input-id + 1
			]
			true [
				cursor/data: cursor/extra-pointer
				cursor/size: SECTION_NAME_SIZE
				cursor/item-extra-id: cursor/next-extra-id
				cursor/next-extra-id: cursor/next-extra-id + 1
			]
		]
		ITEM_READY
	]

	write-records: func [
		writer [wire-container-writer!]
		strings [wire-string-table!]
		module-input-id function-input-id [integer!]
		map [wire-codegen-string-map!]
		return: [integer!]
		/local cursor [wire-codegen-string-cursor!]
			status next-status offset finish output-id [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_STRINGS wire-string-table-reader/expected-string-flags
		if status <> 0 [return status]
		cursor: declare wire-codegen-string-cursor!
		reset-cursor cursor
		offset: 0
		output-id: 1
		next-status: advance strings/records strings/record-count strings/data cursor
		while [next-status = ITEM_READY][
			finish: wire-container-reader/checked-add offset cursor/size
			if finish < 0 [return ERROR_OVERFLOW]
			status: wire-container-writer/append-u32 writer offset
			if status = 0 [
				status: wire-container-writer/append-u32 writer cursor/size
			]
			if status <> 0 [return status]
			if cursor/item-extra-id = EXTRA_DATA_SECTION [
				map/data-section-name: output-id
			]
			if cursor/item-extra-id = EXTRA_CODE_SECTION [
				map/code-section-name: output-id
			]
			if all [
				module-input-id > 0
				cursor/item-input-id = module-input-id
			][map/module-name: output-id]
			if all [
				function-input-id > 0
				cursor/item-input-id = function-input-id
			][map/function-name: output-id]
			offset: finish
			output-id: output-id + 1
			next-status: advance strings/records strings/record-count strings/data cursor
		]
		if next-status <> ITEM_DONE [return ERROR_STATE]
		if any [
			map/data-section-name = 0
			map/code-section-name = 0
			all [module-input-id > 0 map/module-name = 0]
			all [function-input-id > 0 map/function-name = 0]
		][return ERROR_STATE]
		wire-container-writer/end-section writer
	]

	write-data: func [
		writer [wire-container-writer!]
		strings [wire-string-table!]
		return: [integer!]
		/local cursor [wire-codegen-string-cursor!]
			status next-status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_STRING_DATA 0
		if status <> 0 [return status]
		cursor: declare wire-codegen-string-cursor!
		reset-cursor cursor
		next-status: advance strings/records strings/record-count strings/data cursor
		while [next-status = ITEM_READY][
			status: wire-container-writer/append-bytes writer cursor/data cursor/size
			if status <> 0 [return status]
			next-status: advance strings/records strings/record-count strings/data cursor
		]
		if next-status <> ITEM_DONE [return ERROR_STATE]
		wire-container-writer/end-section writer
	]

	write-sections: func [
		writer [wire-container-writer!]
		strings [wire-string-table!]
		module-input-id function-input-id [integer!]
		map [wire-codegen-string-map!]
		return: [integer!]
		/local status [integer!]
	][
		if any [
			null? writer
			null? strings
			null? map
			module-input-id < 0
			module-input-id > strings/record-count
			function-input-id <= 0
			function-input-id > strings/record-count
		][return ERROR_ARGUMENTS]
		reset-map map
		status: write-records writer strings module-input-id function-input-id map
		if status <> 0 [return status]
		write-data writer strings
	]
]
