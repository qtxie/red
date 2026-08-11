Red [
	Title: "Hybrid compiler file and source metadata verifier"
	File:  %wire-file-source.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-string-table [do %wire-string-table.red]

compiler-wire-file-source: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	string-verifier: compiler-wire-string-table

	expected-index-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

	file-fields: reduce [
		'path-string     schema/WIRE_FILE_PATH_STRING_OFFSET
		'checksum-kind   schema/WIRE_FILE_CHECKSUM_KIND_OFFSET
		'checksum-offset schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET
		'checksum-size   schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET
	]

	source-fields: reduce [
		'file        schema/WIRE_SOURCE_LOCATION_FILE_OFFSET
		'line        schema/WIRE_SOURCE_LOCATION_LINE_OFFSET
		'column      schema/WIRE_SOURCE_LOCATION_COLUMN_OFFSET
		'byte-offset schema/WIRE_SOURCE_LOCATION_BYTE_OFFSET_OFFSET
	]

	make-view: does [
		make object! [
			file-count: 0
			files-offset: 0
			files-ordinal: 0
			file-record-size: schema/WIRE_FILE_SIZE
			checksum-data-offset: 0
			checksum-data-size: 0
			checksum-data-ordinal: 0
			source-present?: false
			source-count: 0
			source-offset: 0
			source-ordinal: 0
			source-record-size: schema/WIRE_SOURCE_LOCATION_SIZE
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			view: none
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
					schema/WIRE_RSIR_SECTION_FILES
					schema/WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA
					schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
				]
			]
			magic = schema/WIRE_MAGIC_RSCG [
				reduce [
					schema/WIRE_RSCG_SECTION_FILES
					schema/WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA
					0
				]
			]
			true [none]
		]
	]

	string-size-for-id: func [
		data [binary!]
		table [object!]
		id [integer!]
		/local record-offset value
	][
		if any [id <= 0 id > table/record-count][return none]
		record-offset: table/records-offset
			+ ((id - 1) * schema/WIRE_STRING_SIZE)
		value: container/read-i31 data
			(record-offset + schema/WIRE_STRING_SIZE_OFFSET)
		value
	]

	compare-source: func [
		left-file left-byte left-line left-column [integer!]
		right-file right-byte right-line right-column [integer!]
	][
		if left-file < right-file [return -1]
		if left-file > right-file [return 1]
		if left-byte < right-byte [return -1]
		if left-byte > right-byte [return 1]
		if left-line < right-line [return -1]
		if left-line > right-line [return 1]
		if left-column < right-column [return -1]
		if left-column > right-column [return 1]
		0
	]

	verify: func [
		data expected-magic
		/local result kinds files-kind checksum-kind source-kind container-result
			string-result strings-table files-section checksum-section source-section
			file-count files-offset checksum-data-offset checksum-data-size
			source-count source-offset record-index record-offset field-name field-offset
			value path-string checksum-kind-value checksum-offset checksum-size
			path-size previous-path checksum-cursor finish source-file line column
			byte-offset previous-source-file previous-source-byte previous-source-line
			previous-source-column comparison view
	][
		result: make-result
		unless all [binary? data integer? expected-magic][
			return reject result schema/WIRE_FILE_SOURCE_ERROR_INVALID_ARGUMENTS 0 0
		]
		kinds: section-kinds-for expected-magic
		if none? kinds [
			return reject result schema/WIRE_FILE_SOURCE_ERROR_UNSUPPORTED_MESSAGE 0 0
		]
		files-kind: kinds/1
		checksum-kind: kinds/2
		source-kind: kinds/3

		container-result: container/verify/expect data expected-magic
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		string-result: string-verifier/verify data expected-magic
		unless string-result/valid? [
			result/container-error: string-result/container-error
			result/string-error: string-result/error
			return reject result schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS
				string-result/error-offset string-result/error-section
		]
		strings-table: string-result/table

		files-section: container/find-section container-result files-kind
		checksum-section: container/find-section container-result checksum-kind
		source-section: either source-kind = 0 [
			none
		][
			container/find-section container-result source-kind
		]
		if any [
			none? files-section
			none? checksum-section
			all [source-kind <> 0 none? source-section]
		][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		if (select files-section 'flags) <> expected-index-flags [
			return reject result schema/WIRE_FILE_SOURCE_ERROR_BAD_FILES_SECTION_FLAGS
				((select files-section 'entry-offset)
					+ schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select files-section 'ordinal)
		]
		if (select checksum-section 'flags) <> 0 [
			return reject result
				schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_DATA_SECTION_FLAGS
				((select checksum-section 'entry-offset)
					+ schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select checksum-section 'ordinal)
		]
		if all [
			not none? source-section
			(select source-section 'flags) <> expected-index-flags
		][
			return reject result schema/WIRE_FILE_SOURCE_ERROR_BAD_SOURCE_SECTION_FLAGS
				((select source-section 'entry-offset)
					+ schema/WIRE_DIRECTORY_FLAGS_OFFSET)
				(select source-section 'ordinal)
		]

		file-count: select files-section 'record-count
		files-offset: select files-section 'payload-offset
		checksum-data-offset: select checksum-section 'payload-offset
		checksum-data-size: select checksum-section 'payload-size
		source-count: either none? source-section [0][select source-section 'record-count]
		source-offset: either none? source-section [0][select source-section 'payload-offset]

		; Decode all file scalars, then all source-location scalars, before
		; applying cross-record rules.
		record-index: 0
		while [record-index < file-count][
			record-offset: files-offset + (record-index * schema/WIRE_FILE_SIZE)
			foreach [field-name field-offset] file-fields [
				value: container/read-i31 data (record-offset + field-offset)
				if none? value [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
						(record-offset + field-offset) (select files-section 'ordinal)
				]
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < source-count][
			record-offset: source-offset
				+ (record-index * schema/WIRE_SOURCE_LOCATION_SIZE)
			foreach [field-name field-offset] source-fields [
				value: container/read-i31 data (record-offset + field-offset)
				if none? value [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
						(record-offset + field-offset) (select source-section 'ordinal)
				]
			]
			record-index: record-index + 1
		]

		previous-path: 0
		checksum-cursor: 0
		record-index: 0
		while [record-index < file-count][
			record-offset: files-offset + (record-index * schema/WIRE_FILE_SIZE)
			path-string: container/read-i31 data
				(record-offset + schema/WIRE_FILE_PATH_STRING_OFFSET)
			checksum-kind-value: container/read-i31 data
				(record-offset + schema/WIRE_FILE_CHECKSUM_KIND_OFFSET)
			checksum-offset: container/read-i31 data
				(record-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
			checksum-size: container/read-i31 data
				(record-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET)

			if any [path-string <= 0 path-string > strings-table/record-count][
				return reject result schema/WIRE_FILE_SOURCE_ERROR_FILE_PATH_ID
					(record-offset + schema/WIRE_FILE_PATH_STRING_OFFSET)
					(select files-section 'ordinal)
			]
			path-size: string-size-for-id data strings-table path-string
			if zero? path-size [
				return reject result schema/WIRE_FILE_SOURCE_ERROR_EMPTY_FILE_PATH
					(record-offset + schema/WIRE_FILE_PATH_STRING_OFFSET)
					(select files-section 'ordinal)
			]
			if record-index > 0 [
				if path-string < previous-path [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_FILE_ORDER
						(record-offset + schema/WIRE_FILE_PATH_STRING_OFFSET)
						(select files-section 'ordinal)
				]
				if path-string = previous-path [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_DUPLICATE_FILE
						(record-offset + schema/WIRE_FILE_PATH_STRING_OFFSET)
						(select files-section 'ordinal)
				]
			]
			unless any [
				checksum-kind-value = schema/WIRE_CHECKSUM_KIND_NONE
				checksum-kind-value = schema/WIRE_CHECKSUM_KIND_SHA256
			][
				return reject result schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_KIND
					(record-offset + schema/WIRE_FILE_CHECKSUM_KIND_OFFSET)
					(select files-section 'ordinal)
			]
			either checksum-kind-value = schema/WIRE_CHECKSUM_KIND_NONE [
				if checksum-offset <> 0 [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_OFFSET
						(record-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
						(select files-section 'ordinal)
				]
				if checksum-size <> 0 [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SIZE
						(record-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET)
						(select files-section 'ordinal)
				]
			][
				if checksum-size <> 32 [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SIZE
						(record-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET)
						(select files-section 'ordinal)
				]
				finish: container/checked-add checksum-offset checksum-size
				if any [none? finish finish > checksum-data-size][
					return reject result
						schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SLICE_RANGE
						(record-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
						(select files-section 'ordinal)
				]
				if checksum-offset <> checksum-cursor [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_CHECKSUM_DATA_COVERAGE
						(record-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
						(select files-section 'ordinal)
				]
				checksum-cursor: finish
			]
			previous-path: path-string
			record-index: record-index + 1
		]

		if checksum-cursor <> checksum-data-size [
			return reject result schema/WIRE_FILE_SOURCE_ERROR_CHECKSUM_DATA_COVERAGE
				(checksum-data-offset + checksum-cursor)
				(select checksum-section 'ordinal)
		]

		previous-source-file: 0
		previous-source-byte: 0
		previous-source-line: 0
		previous-source-column: 0
		record-index: 0
		while [record-index < source-count][
			record-offset: source-offset
				+ (record-index * schema/WIRE_SOURCE_LOCATION_SIZE)
			source-file: container/read-i31 data
				(record-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET)
			line: container/read-i31 data
				(record-offset + schema/WIRE_SOURCE_LOCATION_LINE_OFFSET)
			column: container/read-i31 data
				(record-offset + schema/WIRE_SOURCE_LOCATION_COLUMN_OFFSET)
			byte-offset: container/read-i31 data
				(record-offset + schema/WIRE_SOURCE_LOCATION_BYTE_OFFSET_OFFSET)

			if any [source-file <= 0 source-file > file-count][
				return reject result schema/WIRE_FILE_SOURCE_ERROR_SOURCE_FILE_ID
					(record-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET)
					(select source-section 'ordinal)
			]
			if line <= 0 [
				return reject result schema/WIRE_FILE_SOURCE_ERROR_SOURCE_LINE
					(record-offset + schema/WIRE_SOURCE_LOCATION_LINE_OFFSET)
					(select source-section 'ordinal)
			]
			if column <= 0 [
				return reject result schema/WIRE_FILE_SOURCE_ERROR_SOURCE_COLUMN
					(record-offset + schema/WIRE_SOURCE_LOCATION_COLUMN_OFFSET)
					(select source-section 'ordinal)
			]
			if record-index > 0 [
				comparison: compare-source
					source-file byte-offset line column
					previous-source-file previous-source-byte
					previous-source-line previous-source-column
				if comparison < 0 [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_SOURCE_ORDER
						(record-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET)
						(select source-section 'ordinal)
				]
				if comparison = 0 [
					return reject result schema/WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE
						(record-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET)
						(select source-section 'ordinal)
				]
			]
			previous-source-file: source-file
			previous-source-byte: byte-offset
			previous-source-line: line
			previous-source-column: column
			record-index: record-index + 1
		]

		view: make-view
		view/file-count: file-count
		view/files-offset: files-offset
		view/files-ordinal: select files-section 'ordinal
		view/file-record-size: select files-section 'record-size
		view/checksum-data-offset: checksum-data-offset
		view/checksum-data-size: checksum-data-size
		view/checksum-data-ordinal: select checksum-section 'ordinal
		unless none? source-section [
			view/source-present?: true
			view/source-count: source-count
			view/source-offset: source-offset
			view/source-ordinal: select source-section 'ordinal
			view/source-record-size: select source-section 'record-size
		]
		result/strings: strings-table
		result/view: view
		result/valid?: true
		result
	]
]
