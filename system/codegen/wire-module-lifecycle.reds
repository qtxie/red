Red/System [
	Title: "Hybrid compiler module lifecycle verifier"
	File:  %wire-module-lifecycle.reds
]

#include %wire-file-source.reds

wire-module-lifecycle-result!: alias struct! [
	error             [integer!]
	container-error   [integer!]
	string-error      [integer!]
	file-source-error [integer!]
	error-offset      [integer!]
	error-section     [integer!]
]

wire-module-lifecycle!: alias struct! [
	modules            [byte-ptr!]
	module-count       [integer!]
	module-record-size [integer!]
	modules-offset     [integer!]
	modules-ordinal    [integer!]
	reference-count    [integer!]
	image-kind         [integer!]
	glue-module        [integer!]
]

wire-module-lifecycle-reader: context [
	set-error: func [
		result [wire-module-lifecycle-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	module-section-kind: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_MODULE]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_MODULES]
			true [-1]
		]
	]

	reference-section-kind: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_FUNCTIONS]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_SYMBOLS]
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

	first-bad-scalar: func [
		record [byte-ptr!]
		word-count [integer!]
		return: [integer!]
		/local index relative value [integer!]
	][
		index: 0
		while [index < word-count][
			relative: index * 4
			value: wire-container-reader/read-i31 record relative
			if value < 0 [return relative]
			index: index + 1
		]
		-1
	]

	module-record-offset: func [
		modules [wire-section-slice!]
		id [integer!]
		return: [integer!]
	][
		modules/offset + ((id - 1) * modules/record-size)
	]

	module-value: func [
		modules [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31
			modules/data (((id - 1) * modules/record-size) + field-offset)
	]

	nonempty-string?: func [
		strings [wire-string-table!]
		id [integer!]
		return: [logic!]
		/local slice [wire-string-slice!]
	][
		slice: declare wire-string-slice!
		all [
			wire-string-table-reader/get-slice strings id slice
			slice/size > 0
		]
	]

	copy-strings: func [destination source [wire-string-table!]][
		destination/records: source/records
		destination/record-count: source/record-count
		destination/record-size: source/record-size
		destination/records-offset: source/records-offset
		destination/records-ordinal: source/records-ordinal
		destination/data: source/data
		destination/data-size: source/data-size
		destination/data-offset: source/data-offset
		destination/data-ordinal: source/data-ordinal
	]

	copy-files: func [destination source [wire-file-source!]][
		destination/files: source/files
		destination/file-count: source/file-count
		destination/file-record-size: source/file-record-size
		destination/files-offset: source/files-offset
		destination/files-ordinal: source/files-ordinal
		destination/checksum-data: source/checksum-data
		destination/checksum-data-size: source/checksum-data-size
		destination/checksum-data-offset: source/checksum-data-offset
		destination/checksum-data-ordinal: source/checksum-data-ordinal
		destination/source-present: source/source-present
		destination/sources: source/sources
		destination/source-count: source/source-count
		destination/source-record-size: source/source-record-size
		destination/source-offset: source/source-offset
		destination/source-ordinal: source/source-ordinal
	]

	verify: func [
		data [byte-ptr!]
		size expected-magic [integer!]
		result [wire-module-lifecycle-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		view [wire-module-lifecycle!]
		return: [integer!]
		/local container-result [wire-container-result!]
			metadata-result [wire-file-source-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			modules references [wire-section-slice!]
			module-record [byte-ptr!]
			module-kind reference-kind status module-count reference-count
			record-index record-offset bad-relative module-id name-string kind
			image-kind initializer finalizer entry source-location flags reserved
			first-image glue-module symbol-id symbol-offset origin reference-offset
			module-reference flags-offset name-offset kind-offset image-offset
			initializer-offset finalizer-offset entry-offset [integer!]
	][
		if null? result [return WIRE_MODULE_LIFECYCLE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [
			size < 0
			null? data
			null? strings
			null? files
			null? view
		][
			return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_ARGUMENTS 0 0
		]

		module-kind: module-section-kind expected-magic
		reference-kind: reference-section-kind expected-magic
		if any [module-kind < 0 reference-kind < 0][
			return set-error result WIRE_MODULE_LIFECYCLE_ERROR_UNSUPPORTED_MESSAGE 0 0
		]
		either expected-magic = WIRE_MAGIC_RSIR [
			name-offset: WIRE_RSIR_MODULE_NAME_STRING_OFFSET
			kind-offset: WIRE_RSIR_MODULE_KIND_OFFSET
			image-offset: WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET
			initializer-offset: WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET
			finalizer-offset: WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET
			entry-offset: WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET
		][
			name-offset: WIRE_RSCG_MODULE_NAME_STRING_OFFSET
			kind-offset: WIRE_RSCG_MODULE_KIND_OFFSET
			image-offset: WIRE_RSCG_MODULE_IMAGE_KIND_OFFSET
			initializer-offset: WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
			finalizer-offset: WIRE_RSCG_MODULE_FINALIZER_SYMBOL_OFFSET
			entry-offset: WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET
		]

		container-result: declare wire-container-result!
		status: wire-container-reader/verify data size expected-magic container-result
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			result/container-error: status
			return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		metadata-result: declare wire-file-source-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		status: wire-file-source-reader/verify
			data size expected-magic metadata-result verified-strings verified-files
		if status <> WIRE_FILE_SOURCE_ERROR_SUCCESS [
			result/container-error: metadata-result/container-error
			result/string-error: metadata-result/string-error
			result/file-source-error: status
			case [
				status = WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
						metadata-result/error-offset metadata-result/error-section
				]
				status = WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_STRINGS
						metadata-result/error-offset metadata-result/error-section
				]
				true [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_FILE_SOURCE
						metadata-result/error-offset metadata-result/error-section
				]
			]
		]

		modules: declare wire-section-slice!
		references: declare wire-section-slice!
		unless wire-container-reader/find-verified-section data module-kind modules [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data reference-kind references [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		if modules/flags <> 0 [
			return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_MODULE_SECTION_FLAGS
				section-flags-offset modules modules/ordinal
		]

		module-count: modules/record-count
		reference-count: references/record-count

		; Decode all module scalars before following references.
		record-index: 0
		while [record-index < module-count][
			module-record: modules/data + (record-index * modules/record-size)
			bad-relative: first-bad-scalar module-record 8
			if bad-relative >= 0 [
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_SCALAR_RANGE
					((modules/offset + (record-index * modules/record-size)) + bad-relative)
					modules/ordinal
			]
			record-index: record-index + 1
		]

		; Origin is the only RSCG symbol field consumed by this layer.
		if expected-magic = WIRE_MAGIC_RSCG [
			symbol-id: 1
			while [symbol-id <= reference-count][
				symbol-offset: references/offset
					+ ((symbol-id - 1) * WIRE_RSCG_SYMBOL_SIZE)
				origin: wire-container-reader/read-i31 references/data
					(((symbol-id - 1) * WIRE_RSCG_SYMBOL_SIZE)
						+ WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
				if origin < 0 [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_SCALAR_RANGE
						(symbol-offset + WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
						references/ordinal
				]
				symbol-id: symbol-id + 1
			]
		]

		first-image: 0
		glue-module: 0
		module-id: 1
		while [module-id <= module-count][
			record-offset: module-record-offset modules module-id
			name-string: module-value modules module-id name-offset
			kind: module-value modules module-id kind-offset
			image-kind: module-value modules module-id image-offset
			initializer: module-value modules module-id initializer-offset
			finalizer: module-value modules module-id finalizer-offset
			entry: module-value modules module-id entry-offset
			either expected-magic = WIRE_MAGIC_RSIR [
				source-location: module-value modules module-id
					WIRE_RSIR_MODULE_SOURCE_LOCATION_OFFSET
				flags: module-value modules module-id WIRE_RSIR_MODULE_FLAGS_OFFSET
				reserved: 0
			][
				source-location: 0
				flags: module-value modules module-id WIRE_RSCG_MODULE_FLAGS_OFFSET
				reserved: module-value modules module-id WIRE_RSCG_MODULE_RESERVED_OFFSET
			]

			if any [name-string < 0 name-string > verified-strings/record-count][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_NAME_ID
					(record-offset + name-offset) modules/ordinal
			]
			if all [
				name-string > 0
				not nonempty-string? verified-strings name-string
			][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_EMPTY_NAME
					(record-offset + name-offset) modules/ordinal
			]
			unless all [kind >= WIRE_MODULE_KIND_RUNTIME kind <= WIRE_MODULE_KIND_GLUE][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_MODULE_KIND
					(record-offset + kind-offset) modules/ordinal
			]
			unless any [
				image-kind = WIRE_IMAGE_KIND_EXECUTABLE
				image-kind = WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
			][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_IMAGE_KIND
					(record-offset + image-offset) modules/ordinal
			]
			if any [initializer < 0 initializer > reference-count][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_INITIALIZER_ID
					(record-offset + initializer-offset) modules/ordinal
			]
			if any [finalizer < 0 finalizer > reference-count][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_FINALIZER_ID
					(record-offset + finalizer-offset) modules/ordinal
			]
			if any [entry < 0 entry > reference-count][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_ENTRY_ID
					(record-offset + entry-offset) modules/ordinal
			]
			if all [
				expected-magic = WIRE_MAGIC_RSIR
				any [source-location < 0 source-location > verified-files/source-count]
			][
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_SOURCE_LOCATION
					(record-offset + WIRE_RSIR_MODULE_SOURCE_LOCATION_OFFSET) modules/ordinal
			]
			if flags <> 0 [
				flags-offset: either expected-magic = WIRE_MAGIC_RSIR [
					WIRE_RSIR_MODULE_FLAGS_OFFSET
				][WIRE_RSCG_MODULE_FLAGS_OFFSET]
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_FLAGS
					(record-offset + flags-offset) modules/ordinal
			]
			if reserved <> 0 [
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_RESERVED
					(record-offset + WIRE_RSCG_MODULE_RESERVED_OFFSET) modules/ordinal
			]

			if first-image = 0 [first-image: image-kind]
			if image-kind <> first-image [
				return set-error result WIRE_MODULE_LIFECYCLE_ERROR_IMAGE_KIND_MISMATCH
					(record-offset + image-offset) modules/ordinal
			]
			either kind = WIRE_MODULE_KIND_GLUE [
				if glue-module <> 0 [
					return set-error result
						WIRE_MODULE_LIFECYCLE_ERROR_MULTIPLE_GLUE_MODULES
						(record-offset + kind-offset) modules/ordinal
				]
				glue-module: module-id
				if initializer <> 0 [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + initializer-offset) modules/ordinal
				]
				if finalizer <> 0 [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + finalizer-offset) modules/ordinal
				]
				if entry = 0 [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + entry-offset) modules/ordinal
				]
			][
				if entry <> 0 [
					return set-error result WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
						(record-offset + entry-offset) modules/ordinal
				]
			]
			module-id: module-id + 1
		]

		if expected-magic = WIRE_MAGIC_RSCG [
			symbol-id: 1
			while [symbol-id <= reference-count][
				symbol-offset: references/offset
					+ ((symbol-id - 1) * WIRE_RSCG_SYMBOL_SIZE)
				origin: wire-container-reader/read-i31 references/data
					(((symbol-id - 1) * WIRE_RSCG_SYMBOL_SIZE)
						+ WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
				if any [origin <= 0 origin > module-count][
					return set-error result
						WIRE_MODULE_LIFECYCLE_ERROR_BAD_SYMBOL_ORIGIN_MODULE
						(symbol-offset + WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
						references/ordinal
				]
				symbol-id: symbol-id + 1
			]

			module-id: 1
			while [module-id <= module-count][
				record-offset: module-record-offset modules module-id
					reference-offset: WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
				while [reference-offset <= WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET][
					module-reference: module-value modules module-id reference-offset
					if module-reference <> 0 [
						origin: wire-container-reader/read-i31 references/data
							(((module-reference - 1) * WIRE_RSCG_SYMBOL_SIZE)
								+ WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
						if origin <> module-id [
							return set-error result
								WIRE_MODULE_LIFECYCLE_ERROR_LIFECYCLE_SYMBOL_OWNER
								(record-offset + reference-offset) modules/ordinal
						]
					]
					reference-offset: reference-offset + 4
				]
				module-id: module-id + 1
			]
		]

		copy-strings strings verified-strings
		copy-files files verified-files
		view/modules: modules/data
		view/module-count: module-count
		view/module-record-size: modules/record-size
		view/modules-offset: modules/offset
		view/modules-ordinal: modules/ordinal
		view/reference-count: reference-count
		view/image-kind: first-image
		view/glue-module: glue-module
		WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	]
]
