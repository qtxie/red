Red/System [
	Title: "Hybrid compiler file and source metadata verifier"
	File:  %wire-file-source.reds
]

#include %wire-string-table.reds

wire-file-source-result!: alias struct! [
	error           [integer!]
	container-error [integer!]
	string-error    [integer!]
	error-offset    [integer!]
	error-section   [integer!]
]

wire-file-source!: alias struct! [
	files                 [byte-ptr!]
	file-count            [integer!]
	file-record-size      [integer!]
	files-offset          [integer!]
	files-ordinal         [integer!]
	checksum-data         [byte-ptr!]
	checksum-data-size    [integer!]
	checksum-data-offset  [integer!]
	checksum-data-ordinal [integer!]
	source-present        [integer!]
	sources               [byte-ptr!]
	source-count          [integer!]
	source-record-size    [integer!]
	source-offset         [integer!]
	source-ordinal        [integer!]
]

wire-file-source-reader: context [
	expected-index-flags:
		WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED

	set-error: func [
		result [wire-file-source-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	set-container-error: func [
		result [wire-file-source-result!]
		container [wire-container-result!]
		code [integer!]
		return: [integer!]
	][
		result/container-error: code
		set-error result WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
			container/error-offset container/error-section
	]

	files-kind-for: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_FILES]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_FILES]
			true [-1]
		]
	]

	checksum-kind-for: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA]
			true [-1]
		]
	]

	source-kind-for: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_SOURCE_LOCATIONS]
			magic = WIRE_MAGIC_RSCG [0]
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

	compare-source: func [
		left-file left-byte left-line left-column [integer!]
		right-file right-byte right-line right-column [integer!]
		return: [integer!]
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
		data [byte-ptr!]
		size expected-magic [integer!]
		result [wire-file-source-result!]
		strings [wire-string-table!]
		view [wire-file-source!]
		return: [integer!]
		/local container [wire-container-result!]
			string-result [wire-string-table-result!]
			verified-strings [wire-string-table!]
			files checksum-section source [wire-section-slice!]
			path-slice [wire-string-slice!]
			files-kind checksum-kind source-kind status record-index record-offset
			path-string checksum-kind-value checksum-offset checksum-size value
			previous-path checksum-cursor finish source-file line column byte-offset
			previous-source-file previous-source-byte previous-source-line
			previous-source-column comparison [integer!]
	][
		if null? result [return WIRE_FILE_SOURCE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [size < 0 null? data null? strings null? view][
			return set-error result WIRE_FILE_SOURCE_ERROR_INVALID_ARGUMENTS 0 0
		]
		files-kind: files-kind-for expected-magic
		checksum-kind: checksum-kind-for expected-magic
		source-kind: source-kind-for expected-magic
		if any [files-kind < 0 checksum-kind < 0 source-kind < 0][
			return set-error result WIRE_FILE_SOURCE_ERROR_UNSUPPORTED_MESSAGE 0 0
		]

		container: declare wire-container-result!
		status: wire-container-reader/verify data size expected-magic container
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			return set-container-error result container status
		]

		string-result: declare wire-string-table-result!
		verified-strings: declare wire-string-table!
		status: wire-string-table-reader/verify
			data size expected-magic string-result verified-strings
		if status <> WIRE_STRING_TABLE_ERROR_SUCCESS [
			result/container-error: string-result/container-error
			result/string-error: status
			return set-error result WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS
				string-result/error-offset string-result/error-section
		]

		files: declare wire-section-slice!
		checksum-section: declare wire-section-slice!
		source: declare wire-section-slice!
		unless wire-container-reader/find-verified-section data files-kind files [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data checksum-kind checksum-section
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		if all [
			source-kind <> 0
			not wire-container-reader/find-verified-section data source-kind source
		][
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]

		if files/flags <> expected-index-flags [
			return set-error result WIRE_FILE_SOURCE_ERROR_BAD_FILES_SECTION_FLAGS
				section-flags-offset files files/ordinal
		]
		if checksum-section/flags <> 0 [
			return set-error result
				WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_DATA_SECTION_FLAGS
				section-flags-offset checksum-section checksum-section/ordinal
		]
		if all [source-kind <> 0 source/flags <> expected-index-flags][
			return set-error result WIRE_FILE_SOURCE_ERROR_BAD_SOURCE_SECTION_FLAGS
				section-flags-offset source source/ordinal
		]

		; Decode all file scalars, then all source-location scalars, before
		; applying cross-record rules.
		record-index: 0
		while [record-index < files/record-count][
			record-offset: record-index * WIRE_FILE_SIZE
			value: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_PATH_STRING_OFFSET)
			if value < 0 [
				return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
					(files/offset + record-offset) + WIRE_FILE_PATH_STRING_OFFSET
					files/ordinal
			]
			value: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_CHECKSUM_KIND_OFFSET)
			if value < 0 [
				return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
					(files/offset + record-offset) + WIRE_FILE_CHECKSUM_KIND_OFFSET
					files/ordinal
			]
			value: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
			if value < 0 [
				return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
					(files/offset + record-offset) + WIRE_FILE_CHECKSUM_OFFSET_OFFSET
					files/ordinal
			]
			value: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_CHECKSUM_SIZE_OFFSET)
			if value < 0 [
				return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
					(files/offset + record-offset) + WIRE_FILE_CHECKSUM_SIZE_OFFSET
					files/ordinal
			]
			record-index: record-index + 1
		]
		if source-kind <> 0 [
			record-index: 0
			while [record-index < source/record-count][
				record-offset: record-index * WIRE_SOURCE_LOCATION_SIZE
				value: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_FILE_OFFSET)
				if value < 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
						(source/offset + record-offset) + WIRE_SOURCE_LOCATION_FILE_OFFSET
						source/ordinal
				]
				value: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_LINE_OFFSET)
				if value < 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
						(source/offset + record-offset) + WIRE_SOURCE_LOCATION_LINE_OFFSET
						source/ordinal
				]
				value: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_COLUMN_OFFSET)
				if value < 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
						(source/offset + record-offset) + WIRE_SOURCE_LOCATION_COLUMN_OFFSET
						source/ordinal
				]
				value: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_BYTE_OFFSET_OFFSET)
				if value < 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
						(source/offset + record-offset)
							+ WIRE_SOURCE_LOCATION_BYTE_OFFSET_OFFSET
						source/ordinal
				]
				record-index: record-index + 1
			]
		]

		previous-path: 0
		checksum-cursor: 0
		record-index: 0
		while [record-index < files/record-count][
			record-offset: record-index * WIRE_FILE_SIZE
			path-string: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_PATH_STRING_OFFSET)
			checksum-kind-value: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_CHECKSUM_KIND_OFFSET)
			checksum-offset: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
			checksum-size: wire-container-reader/read-i31
				files/data (record-offset + WIRE_FILE_CHECKSUM_SIZE_OFFSET)

			if any [path-string <= 0 path-string > verified-strings/record-count][
				return set-error result WIRE_FILE_SOURCE_ERROR_FILE_PATH_ID
					(files/offset + record-offset) + WIRE_FILE_PATH_STRING_OFFSET
					files/ordinal
			]
			path-slice: declare wire-string-slice!
			unless wire-string-table-reader/get-slice
				verified-strings path-string path-slice
			[
				return set-error result WIRE_FILE_SOURCE_ERROR_FILE_PATH_ID
					(files/offset + record-offset) + WIRE_FILE_PATH_STRING_OFFSET
					files/ordinal
			]
			if path-slice/size = 0 [
				return set-error result WIRE_FILE_SOURCE_ERROR_EMPTY_FILE_PATH
					(files/offset + record-offset) + WIRE_FILE_PATH_STRING_OFFSET
					files/ordinal
			]
			if record-index > 0 [
				if path-string < previous-path [
					return set-error result WIRE_FILE_SOURCE_ERROR_FILE_ORDER
						(files/offset + record-offset) + WIRE_FILE_PATH_STRING_OFFSET
						files/ordinal
				]
				if path-string = previous-path [
					return set-error result WIRE_FILE_SOURCE_ERROR_DUPLICATE_FILE
						(files/offset + record-offset) + WIRE_FILE_PATH_STRING_OFFSET
						files/ordinal
				]
			]
			unless any [
				checksum-kind-value = WIRE_CHECKSUM_KIND_NONE
				checksum-kind-value = WIRE_CHECKSUM_KIND_SHA256
			][
				return set-error result WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_KIND
					(files/offset + record-offset) + WIRE_FILE_CHECKSUM_KIND_OFFSET
					files/ordinal
			]
			either checksum-kind-value = WIRE_CHECKSUM_KIND_NONE [
				if checksum-offset <> 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_OFFSET
						(files/offset + record-offset) + WIRE_FILE_CHECKSUM_OFFSET_OFFSET
						files/ordinal
				]
				if checksum-size <> 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SIZE
						(files/offset + record-offset) + WIRE_FILE_CHECKSUM_SIZE_OFFSET
						files/ordinal
				]
			][
				if checksum-size <> 32 [
					return set-error result WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SIZE
						(files/offset + record-offset) + WIRE_FILE_CHECKSUM_SIZE_OFFSET
						files/ordinal
				]
				finish: wire-container-reader/checked-add checksum-offset checksum-size
				if any [finish < 0 finish > checksum-section/size][
					return set-error result
						WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SLICE_RANGE
						(files/offset + record-offset) + WIRE_FILE_CHECKSUM_OFFSET_OFFSET
						files/ordinal
				]
				if checksum-offset <> checksum-cursor [
					return set-error result WIRE_FILE_SOURCE_ERROR_CHECKSUM_DATA_COVERAGE
						(files/offset + record-offset) + WIRE_FILE_CHECKSUM_OFFSET_OFFSET
						files/ordinal
				]
				checksum-cursor: finish
			]
			previous-path: path-string
			record-index: record-index + 1
		]

		if checksum-cursor <> checksum-section/size [
			return set-error result WIRE_FILE_SOURCE_ERROR_CHECKSUM_DATA_COVERAGE
				checksum-section/offset + checksum-cursor checksum-section/ordinal
		]

		if source-kind <> 0 [
			previous-source-file: 0
			previous-source-byte: 0
			previous-source-line: 0
			previous-source-column: 0
			record-index: 0
			while [record-index < source/record-count][
				record-offset: record-index * WIRE_SOURCE_LOCATION_SIZE
				source-file: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_FILE_OFFSET)
				line: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_LINE_OFFSET)
				column: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_COLUMN_OFFSET)
				byte-offset: wire-container-reader/read-i31
					source/data (record-offset + WIRE_SOURCE_LOCATION_BYTE_OFFSET_OFFSET)

				if any [source-file <= 0 source-file > files/record-count][
					return set-error result WIRE_FILE_SOURCE_ERROR_SOURCE_FILE_ID
						(source/offset + record-offset) + WIRE_SOURCE_LOCATION_FILE_OFFSET
						source/ordinal
				]
				if line <= 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_SOURCE_LINE
						(source/offset + record-offset) + WIRE_SOURCE_LOCATION_LINE_OFFSET
						source/ordinal
				]
				if column <= 0 [
					return set-error result WIRE_FILE_SOURCE_ERROR_SOURCE_COLUMN
						(source/offset + record-offset) + WIRE_SOURCE_LOCATION_COLUMN_OFFSET
						source/ordinal
				]
				if record-index > 0 [
					comparison: compare-source
						source-file byte-offset line column
						previous-source-file previous-source-byte
						previous-source-line previous-source-column
					if comparison < 0 [
						return set-error result WIRE_FILE_SOURCE_ERROR_SOURCE_ORDER
							(source/offset + record-offset)
								+ WIRE_SOURCE_LOCATION_FILE_OFFSET
							source/ordinal
					]
					if comparison = 0 [
						return set-error result WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE
							(source/offset + record-offset)
								+ WIRE_SOURCE_LOCATION_FILE_OFFSET
							source/ordinal
					]
				]
				previous-source-file: source-file
				previous-source-byte: byte-offset
				previous-source-line: line
				previous-source-column: column
				record-index: record-index + 1
			]
		]

		strings/records: verified-strings/records
		strings/record-count: verified-strings/record-count
		strings/record-size: verified-strings/record-size
		strings/records-offset: verified-strings/records-offset
		strings/records-ordinal: verified-strings/records-ordinal
		strings/data: verified-strings/data
		strings/data-size: verified-strings/data-size
		strings/data-offset: verified-strings/data-offset
		strings/data-ordinal: verified-strings/data-ordinal

		view/files: files/data
		view/file-count: files/record-count
		view/file-record-size: files/record-size
		view/files-offset: files/offset
		view/files-ordinal: files/ordinal
		view/checksum-data: checksum-section/data
		view/checksum-data-size: checksum-section/size
		view/checksum-data-offset: checksum-section/offset
		view/checksum-data-ordinal: checksum-section/ordinal
		either source-kind = 0 [
			view/source-present: 0
			view/sources: as byte-ptr! 0
			view/source-count: 0
			view/source-record-size: WIRE_SOURCE_LOCATION_SIZE
			view/source-offset: 0
			view/source-ordinal: 0
		][
			view/source-present: 1
			view/sources: source/data
			view/source-count: source/record-count
			view/source-record-size: source/record-size
			view/source-offset: source/offset
			view/source-ordinal: source/ordinal
		]
		WIRE_FILE_SOURCE_ERROR_SUCCESS
	]
]
