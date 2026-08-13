Red/System [
	Title: "Hybrid compiler checked wire container reader"
	File:  %wire-reader.reds
]

#include %wire-schema.reds

wire-container-result!: alias struct! [
	error            [integer!]
	error-offset     [integer!]
	error-section    [integer!]
	magic            [integer!]
	section-count    [integer!]
	required-sections [integer!]
]

wire-section-slice!: alias struct! [
	data         [byte-ptr!]
	size         [integer!]
	record-count [integer!]
	record-size  [integer!]
	flags        [integer!]
	offset       [integer!]
	ordinal      [integer!]
]

wire-container-reader: context [
	max-scalar: 7FFFFFFFh
	allowed-section-flags: 7

	set-error: func [
		result [wire-container-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	read-le16: func [
		data [byte-ptr!]
		offset [integer!]
		return: [integer!]
		/local p [byte-ptr!]
	][
		p: data + offset
		(as integer! p/1) or ((as integer! p/2) << 8)
	]

	read-le32: func [
		data [byte-ptr!]
		offset [integer!]
		return: [integer!]
		/local p [byte-ptr!] low high [integer!]
	][
		p: data + offset
		low: (as integer! p/1) or ((as integer! p/2) << 8)
		high: (as integer! p/3) or ((as integer! p/4) << 8)
		low or (high << 16)
	]

	read-i31: func [
		data [byte-ptr!]
		offset [integer!]
		return: [integer!]
		/local p [byte-ptr!]
	][
		p: data + offset
		if p/4 > as byte! 127 [return -1]
		read-le32 data offset
	]

	checked-add: func [left right [integer!] return: [integer!]][
		if any [left < 0 right < 0 left > (max-scalar - right)][return -1]
		left + right
	]

	checked-multiply: func [left right [integer!] return: [integer!]][
		if any [left < 0 right < 0][return -1]
		if any [left = 0 right = 0][return 0]
		if left > (max-scalar / right) [return -1]
		left * right
	]

	power-of-two?: func [value [integer!] return: [logic!]][
		all [value > 0 (value and (value - 1)) = 0]
	]

	first-nonzero: func [
		data [byte-ptr!]
		start finish [integer!]
		return: [integer!]
		/local offset [integer!] p [byte-ptr!]
	][
		offset: start
		p: data + start
		while [offset < finish][
			if p/1 <> as byte! 0 [return offset]
			p: p + 1
			offset: offset + 1
		]
		-1
	]

	known-section-count: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSCF [WIRE_RSCF_KNOWN_SECTION_COUNT]
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_KNOWN_SECTION_COUNT]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_KNOWN_SECTION_COUNT]
			magic = WIRE_MAGIC_RSDG [WIRE_RSDG_KNOWN_SECTION_COUNT]
			true [-1]
		]
	]

	required-section-count: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSCF [WIRE_RSCF_REQUIRED_SECTION_COUNT]
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_REQUIRED_SECTION_COUNT]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_REQUIRED_SECTION_COUNT]
			magic = WIRE_MAGIC_RSDG [WIRE_RSDG_REQUIRED_SECTION_COUNT]
			true [-1]
		]
	]

	expected-record-size: func [
		magic kind [integer!]
		return: [integer!]
	][
		case [
			magic = WIRE_MAGIC_RSCF [
				case [
					kind = WIRE_RSCF_SECTION_CONFIG [WIRE_RSCF_SECTION_CONFIG_RECORD_SIZE]
					true [-1]
				]
			]
			magic = WIRE_MAGIC_RSIR [
				case [
					kind = WIRE_RSIR_SECTION_MODULE [WIRE_RSIR_SECTION_MODULE_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_DATA_LAYOUT [WIRE_RSIR_SECTION_DATA_LAYOUT_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_STRINGS [WIRE_RSIR_SECTION_STRINGS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_STRING_DATA [WIRE_RSIR_SECTION_STRING_DATA_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_FILES [WIRE_RSIR_SECTION_FILES_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA [WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_TYPES [WIRE_RSIR_SECTION_TYPES_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_FIELDS [WIRE_RSIR_SECTION_FIELDS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_SIGNATURES [WIRE_RSIR_SECTION_SIGNATURES_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_PARAMETERS [WIRE_RSIR_SECTION_PARAMETERS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_SYMBOLS [WIRE_RSIR_SECTION_SYMBOLS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_CONSTANTS [WIRE_RSIR_SECTION_CONSTANTS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_CONSTANT_DATA [WIRE_RSIR_SECTION_CONSTANT_DATA_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_CONSTANT_PARTS [WIRE_RSIR_SECTION_CONSTANT_PARTS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_GLOBALS [WIRE_RSIR_SECTION_GLOBALS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_IMPORTS [WIRE_RSIR_SECTION_IMPORTS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_EXPORTS [WIRE_RSIR_SECTION_EXPORTS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_FUNCTIONS [WIRE_RSIR_SECTION_FUNCTIONS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_LOCALS [WIRE_RSIR_SECTION_LOCALS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_BLOCKS [WIRE_RSIR_SECTION_BLOCKS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_EDGES [WIRE_RSIR_SECTION_EDGES_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_VALUES [WIRE_RSIR_SECTION_VALUES_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_INSTRUCTIONS [WIRE_RSIR_SECTION_INSTRUCTIONS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_OPERANDS [WIRE_RSIR_SECTION_OPERANDS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_CALLS [WIRE_RSIR_SECTION_CALLS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_TARGET_FRAGMENTS [WIRE_RSIR_SECTION_TARGET_FRAGMENTS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_SOURCE_LOCATIONS [WIRE_RSIR_SECTION_SOURCE_LOCATIONS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_EXCEPTION_REGIONS [WIRE_RSIR_SECTION_EXCEPTION_REGIONS_RECORD_SIZE]
					kind = WIRE_RSIR_SECTION_EXCEPTION_BLOCKS [WIRE_RSIR_SECTION_EXCEPTION_BLOCKS_RECORD_SIZE]
					true [-1]
				]
			]
			magic = WIRE_MAGIC_RSCG [
				case [
					kind = WIRE_RSCG_SECTION_DATA_LAYOUT [WIRE_RSCG_SECTION_DATA_LAYOUT_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_STRINGS [WIRE_RSCG_SECTION_STRINGS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_STRING_DATA [WIRE_RSCG_SECTION_STRING_DATA_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_OUTPUT_SECTIONS [WIRE_RSCG_SECTION_OUTPUT_SECTIONS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_OUTPUT_DATA [WIRE_RSCG_SECTION_OUTPUT_DATA_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_SYMBOLS [WIRE_RSCG_SECTION_SYMBOLS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_RELOCATIONS [WIRE_RSCG_SECTION_RELOCATIONS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_IMPORTS [WIRE_RSCG_SECTION_IMPORTS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_EXPORTS [WIRE_RSCG_SECTION_EXPORTS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_FUNCTIONS [WIRE_RSCG_SECTION_FUNCTIONS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_FILES [WIRE_RSCG_SECTION_FILES_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA [WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_DEBUG_LINES [WIRE_RSCG_SECTION_DEBUG_LINES_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_DEBUG_PARAMETERS [WIRE_RSCG_SECTION_DEBUG_PARAMETERS_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_GC_FRAMES [WIRE_RSCG_SECTION_GC_FRAMES_RECORD_SIZE]
					kind = WIRE_RSCG_SECTION_UNWIND_FUNCTIONS [WIRE_RSCG_SECTION_UNWIND_FUNCTIONS_RECORD_SIZE]
					true [-1]
				]
			]
			magic = WIRE_MAGIC_RSDG [
				case [
					kind = WIRE_RSDG_SECTION_STRINGS [WIRE_RSDG_SECTION_STRINGS_RECORD_SIZE]
					kind = WIRE_RSDG_SECTION_STRING_DATA [WIRE_RSDG_SECTION_STRING_DATA_RECORD_SIZE]
					kind = WIRE_RSDG_SECTION_DIAGNOSTICS [WIRE_RSDG_SECTION_DIAGNOSTICS_RECORD_SIZE]
					true [-1]
				]
			]
			true [-1]
		]
	]

	expected-alignment: func [magic kind [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSCF [
				either kind = WIRE_RSCF_SECTION_CONFIG [WIRE_RSCF_SECTION_CONFIG_ALIGNMENT][-1]
			]
			magic = WIRE_MAGIC_RSIR [
				case [
					kind = WIRE_RSIR_SECTION_STRING_DATA [WIRE_RSIR_SECTION_STRING_DATA_ALIGNMENT]
					kind = WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA [WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA_ALIGNMENT]
					kind = WIRE_RSIR_SECTION_CONSTANT_DATA [WIRE_RSIR_SECTION_CONSTANT_DATA_ALIGNMENT]
					all [kind >= 1 kind <= WIRE_RSIR_KNOWN_SECTION_COUNT] [4]
					true [-1]
				]
			]
			magic = WIRE_MAGIC_RSCG [
				case [
					kind = WIRE_RSCG_SECTION_STRING_DATA [WIRE_RSCG_SECTION_STRING_DATA_ALIGNMENT]
					kind = WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA [WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA_ALIGNMENT]
					kind = WIRE_RSCG_SECTION_OUTPUT_DATA [WIRE_RSCG_SECTION_OUTPUT_DATA_ALIGNMENT]
					all [kind >= 1 kind <= WIRE_RSCG_KNOWN_SECTION_COUNT] [4]
					true [-1]
				]
			]
			magic = WIRE_MAGIC_RSDG [
				case [
					kind = WIRE_RSDG_SECTION_STRING_DATA [WIRE_RSDG_SECTION_STRING_DATA_ALIGNMENT]
					all [kind >= 1 kind <= WIRE_RSDG_KNOWN_SECTION_COUNT] [4]
					true [-1]
				]
			]
			true [-1]
		]
	]

	expected-cardinality: func [magic kind [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSCF [
				either kind = WIRE_RSCF_SECTION_CONFIG [WIRE_SECTION_CARDINALITY_ONE][-1]
			]
			magic = WIRE_MAGIC_RSIR [
				either any [
					kind = WIRE_RSIR_SECTION_MODULE
					kind = WIRE_RSIR_SECTION_DATA_LAYOUT
				][WIRE_SECTION_CARDINALITY_ONE][WIRE_SECTION_CARDINALITY_ANY]
			]
			magic = WIRE_MAGIC_RSCG [
				either kind = WIRE_RSCG_SECTION_DATA_LAYOUT [
					WIRE_SECTION_CARDINALITY_ONE
				][WIRE_SECTION_CARDINALITY_ANY]
			]
			magic = WIRE_MAGIC_RSDG [
				WIRE_SECTION_CARDINALITY_NONEMPTY
			]
			true [-1]
		]
	]

	verify-target-header: func [
		result [wire-container-result!]
		magic target abi endian pointer low high [integer!]
		return: [integer!]
	][
		if all [magic = WIRE_MAGIC_RSDG target = 0][
			if abi <> 0 [
				return set-error result WIRE_CONTAINER_ERROR_BAD_ABI WIRE_HEADER_ABI_OFFSET 0
			]
			if endian <> 0 [
				return set-error result WIRE_CONTAINER_ERROR_BAD_ENDIAN WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
			]
			if pointer <> 0 [
				return set-error result WIRE_CONTAINER_ERROR_BAD_POINTER_SIZE WIRE_HEADER_POINTER_SIZE_OFFSET 0
			]
			if any [low <> 0 high <> 0][
				return set-error result WIRE_CONTAINER_ERROR_BAD_TARGET WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0
			]
			return WIRE_CONTAINER_ERROR_SUCCESS
		]
		unless all [target >= WIRE_TARGET_X86_64 target <= WIRE_TARGET_X86][
			return set-error result WIRE_CONTAINER_ERROR_BAD_TARGET WIRE_HEADER_TARGET_OFFSET 0
		]
		unless all [abi >= WIRE_ABI_WIN64 abi <= WIRE_ABI_WIN32][
			return set-error result WIRE_CONTAINER_ERROR_BAD_ABI WIRE_HEADER_ABI_OFFSET 0
		]
		unless any [endian = WIRE_ENDIAN_LITTLE endian = WIRE_ENDIAN_BIG][
			return set-error result WIRE_CONTAINER_ERROR_BAD_ENDIAN WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		unless any [pointer = 4 pointer = 8][
			return set-error result WIRE_CONTAINER_ERROR_BAD_POINTER_SIZE WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]
		WIRE_CONTAINER_ERROR_SUCCESS
	]

	verify: func [
		data [byte-ptr!]
		size expected-magic [integer!]
		result [wire-container-result!]
		return: [integer!]
		/local magic major minor header-size container-flags total-size section-count
			directory-offset directory-record-size target abi endian pointer low high producer fingerprint
			known-count required-count directory-size directory-end previous-kind payload-end ordinal
			entry-offset kind flags payload-offset payload-size record-count record-size alignment reserved
			expected-size expected-align cardinality product section-end required-seen padding-offset status [integer!]
			known? required? [logic!]
	][
		if null? result [return WIRE_CONTAINER_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_CONTAINER_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0
		result/magic: 0
		result/section-count: 0
		result/required-sections: 0

		if any [size < 0 null? data][
			return set-error result WIRE_CONTAINER_ERROR_INVALID_ARGUMENTS 0 0
		]
		if size < WIRE_HEADER_SIZE [
			return set-error result WIRE_CONTAINER_ERROR_TRUNCATED_HEADER size 0
		]

		magic: read-le32 data WIRE_HEADER_MAGIC_OFFSET
		result/magic: magic
		known-count: known-section-count magic
		if any [known-count < 0 magic <> expected-magic][
			return set-error result WIRE_CONTAINER_ERROR_BAD_MAGIC WIRE_HEADER_MAGIC_OFFSET 0
		]
		required-count: required-section-count magic

		major: read-le16 data WIRE_HEADER_VERSION_MAJOR_OFFSET
		minor: read-le16 data WIRE_HEADER_VERSION_MINOR_OFFSET
		if any [major <> WIRE_VERSION_MAJOR minor > WIRE_VERSION_MINOR][
			return set-error result WIRE_CONTAINER_ERROR_UNSUPPORTED_VERSION WIRE_HEADER_VERSION_MAJOR_OFFSET 0
		]

		header-size: read-i31 data WIRE_HEADER_HEADER_SIZE_OFFSET
		container-flags: read-i31 data WIRE_HEADER_CONTAINER_FLAGS_OFFSET
		total-size: read-i31 data WIRE_HEADER_TOTAL_SIZE_OFFSET
		section-count: read-i31 data WIRE_HEADER_SECTION_COUNT_OFFSET
		directory-offset: read-i31 data WIRE_HEADER_DIRECTORY_OFFSET_OFFSET
		directory-record-size: read-i31 data WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET
		target: read-i31 data WIRE_HEADER_TARGET_OFFSET
		abi: read-i31 data WIRE_HEADER_ABI_OFFSET
		endian: read-i31 data WIRE_HEADER_TARGET_ENDIAN_OFFSET
		pointer: read-i31 data WIRE_HEADER_POINTER_SIZE_OFFSET
		low: read-i31 data WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		high: read-i31 data WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		producer: read-i31 data WIRE_HEADER_PRODUCER_BUILD_OFFSET
		fingerprint: read-i31 data WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET
		if header-size < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_HEADER_SIZE_OFFSET 0
		]
		if container-flags < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_CONTAINER_FLAGS_OFFSET 0
		]
		if total-size < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_TOTAL_SIZE_OFFSET 0
		]
		if section-count < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_SECTION_COUNT_OFFSET 0
		]
		if directory-offset < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_DIRECTORY_OFFSET_OFFSET 0
		]
		if directory-record-size < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET 0
		]
		if target < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_TARGET_OFFSET 0
		]
		if abi < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_ABI_OFFSET 0
		]
		if endian < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		if pointer < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]
		if low < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0
		]
		if high < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 0
		]
		if producer < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_PRODUCER_BUILD_OFFSET 0
		]
		if fingerprint < 0 [
			return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
		]

		if header-size <> WIRE_HEADER_SIZE [
			return set-error result WIRE_CONTAINER_ERROR_BAD_HEADER_SIZE WIRE_HEADER_HEADER_SIZE_OFFSET 0
		]
		if container-flags <> 0 [
			return set-error result WIRE_CONTAINER_ERROR_BAD_CONTAINER_FLAGS WIRE_HEADER_CONTAINER_FLAGS_OFFSET 0
		]
		if total-size <> size [
			return set-error result WIRE_CONTAINER_ERROR_BAD_TOTAL_SIZE WIRE_HEADER_TOTAL_SIZE_OFFSET 0
		]
		if fingerprint <> WIRE_SCHEMA_FINGERPRINT [
			return set-error result WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
		]
		status: verify-target-header result magic target abi endian pointer low high
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [return status]
		if directory-offset <> WIRE_HEADER_SIZE [
			return set-error result WIRE_CONTAINER_ERROR_BAD_DIRECTORY_OFFSET WIRE_HEADER_DIRECTORY_OFFSET_OFFSET 0
		]
		if directory-record-size <> WIRE_DIRECTORY_SIZE [
			return set-error result WIRE_CONTAINER_ERROR_BAD_DIRECTORY_RECORD_SIZE WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET 0
		]

		directory-size: checked-multiply section-count directory-record-size
		if directory-size < 0 [
			return set-error result WIRE_CONTAINER_ERROR_DIRECTORY_RANGE WIRE_HEADER_SECTION_COUNT_OFFSET 0
		]
		directory-end: checked-add directory-offset directory-size
		if any [directory-end < 0 directory-end > size][
			return set-error result WIRE_CONTAINER_ERROR_DIRECTORY_RANGE WIRE_HEADER_DIRECTORY_OFFSET_OFFSET 0
		]

		result/section-count: section-count
		previous-kind: 0
		payload-end: directory-end
		required-seen: 0
		ordinal: 0
		while [ordinal < section-count][
			entry-offset: directory-offset + (ordinal * WIRE_DIRECTORY_SIZE)
			kind: read-i31 data (entry-offset + WIRE_DIRECTORY_KIND_OFFSET)
			flags: read-i31 data (entry-offset + WIRE_DIRECTORY_FLAGS_OFFSET)
			payload-offset: read-i31 data (entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET)
			payload-size: read-i31 data (entry-offset + WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET)
			record-count: read-i31 data (entry-offset + WIRE_DIRECTORY_RECORD_COUNT_OFFSET)
			record-size: read-i31 data (entry-offset + WIRE_DIRECTORY_RECORD_SIZE_OFFSET)
			alignment: read-i31 data (entry-offset + WIRE_DIRECTORY_ALIGNMENT_OFFSET)
			reserved: read-i31 data (entry-offset + WIRE_DIRECTORY_RESERVED_OFFSET)
			if kind < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_KIND_OFFSET) (ordinal + 1)
			]
			if flags < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_FLAGS_OFFSET) (ordinal + 1)
			]
			if payload-offset < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) (ordinal + 1)
			]
			if payload-size < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET) (ordinal + 1)
			]
			if record-count < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_RECORD_COUNT_OFFSET) (ordinal + 1)
			]
			if record-size < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_RECORD_SIZE_OFFSET) (ordinal + 1)
			]
			if alignment < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_ALIGNMENT_OFFSET) (ordinal + 1)
			]
			if reserved < 0 [
				return set-error result WIRE_CONTAINER_ERROR_SCALAR_RANGE
					(entry-offset + WIRE_DIRECTORY_RESERVED_OFFSET) (ordinal + 1)
			]

			if kind <= previous-kind [
				return set-error result WIRE_CONTAINER_ERROR_SECTION_ORDER entry-offset (ordinal + 1)
			]
			previous-kind: kind
			if flags > allowed-section-flags [
				return set-error result WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS
					(entry-offset + WIRE_DIRECTORY_FLAGS_OFFSET) (ordinal + 1)
			]
			if reserved <> 0 [
				return set-error result WIRE_CONTAINER_ERROR_NONZERO_RESERVED
					(entry-offset + WIRE_DIRECTORY_RESERVED_OFFSET) (ordinal + 1)
			]

			known?: kind <= known-count
			either known? [
				expected-size: expected-record-size magic kind
				expected-align: expected-alignment magic kind
				cardinality: expected-cardinality magic kind
				required?: kind <= required-count
				if record-size <> expected-size [
					return set-error result WIRE_CONTAINER_ERROR_BAD_RECORD_SIZE
						(entry-offset + WIRE_DIRECTORY_RECORD_SIZE_OFFSET) (ordinal + 1)
				]
				if alignment <> expected-align [
					return set-error result WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + WIRE_DIRECTORY_ALIGNMENT_OFFSET) (ordinal + 1)
				]
				either required? [
					if (flags and WIRE_SECTION_FLAG_OPTIONAL) <> 0 [
						return set-error result WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS
							(entry-offset + WIRE_DIRECTORY_FLAGS_OFFSET) (ordinal + 1)
					]
					required-seen: required-seen + 1
				][
					if (flags and WIRE_SECTION_FLAG_OPTIONAL) = 0 [
						return set-error result WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS
							(entry-offset + WIRE_DIRECTORY_FLAGS_OFFSET) (ordinal + 1)
					]
				]
			][
				if (flags and WIRE_SECTION_FLAG_OPTIONAL) = 0 [
					return set-error result WIRE_CONTAINER_ERROR_UNKNOWN_REQUIRED_SECTION
						(entry-offset + WIRE_DIRECTORY_KIND_OFFSET) (ordinal + 1)
				]
				if record-size = 0 [
					return set-error result WIRE_CONTAINER_ERROR_BAD_RECORD_SIZE
						(entry-offset + WIRE_DIRECTORY_RECORD_SIZE_OFFSET) (ordinal + 1)
				]
				unless power-of-two? alignment [
					return set-error result WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + WIRE_DIRECTORY_ALIGNMENT_OFFSET) (ordinal + 1)
				]
				cardinality: WIRE_SECTION_CARDINALITY_ANY
			]

			product: checked-multiply record-count record-size
			if any [product < 0 product <> payload-size][
				return set-error result WIRE_CONTAINER_ERROR_SECTION_PRODUCT
					(entry-offset + WIRE_DIRECTORY_RECORD_COUNT_OFFSET) (ordinal + 1)
			]
			if any [
				all [cardinality = WIRE_SECTION_CARDINALITY_ONE record-count <> 1]
				all [cardinality = WIRE_SECTION_CARDINALITY_NONEMPTY record-count = 0]
			][
				return set-error result WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY
					(entry-offset + WIRE_DIRECTORY_RECORD_COUNT_OFFSET) (ordinal + 1)
			]

			either payload-size = 0 [
				if payload-offset <> 0 [
					return set-error result WIRE_CONTAINER_ERROR_EMPTY_SECTION_OFFSET
						(entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) (ordinal + 1)
				]
			][
				unless power-of-two? alignment [
					return set-error result WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + WIRE_DIRECTORY_ALIGNMENT_OFFSET) (ordinal + 1)
				]
				unless (payload-offset // alignment) = 0 [
					return set-error result WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) (ordinal + 1)
				]
				section-end: checked-add payload-offset payload-size
				if any [section-end < 0 section-end > size][
					return set-error result WIRE_CONTAINER_ERROR_SECTION_RANGE
						(entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) (ordinal + 1)
				]
				if payload-offset < payload-end [
					return set-error result WIRE_CONTAINER_ERROR_PAYLOAD_ORDER
						(entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) (ordinal + 1)
				]
				padding-offset: first-nonzero data payload-end payload-offset
				if padding-offset >= 0 [
					return set-error result WIRE_CONTAINER_ERROR_NONZERO_PADDING
						padding-offset (ordinal + 1)
				]
				payload-end: section-end
			]
			ordinal: ordinal + 1
		]

		result/required-sections: required-seen
		if required-seen <> required-count [
			return set-error result WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION directory-offset 0
		]
		padding-offset: first-nonzero data payload-end size
		if padding-offset >= 0 [
			return set-error result WIRE_CONTAINER_ERROR_NONZERO_PADDING padding-offset 0
		]
		WIRE_CONTAINER_ERROR_SUCCESS
	]

	checked-slice: func [
		data [byte-ptr!]
		size offset length [integer!]
		slice [wire-section-slice!]
		return: [logic!]
		/local finish [integer!]
	][
		if null? slice [return false]
		if any [size < 0 all [size > 0 null? data]][return false]
		finish: checked-add offset length
		if any [finish < 0 finish > size][return false]
		slice/data: either length = 0 [as byte-ptr! 0][data + offset]
		slice/size: length
		slice/record-count: 0
		slice/record-size: 1
		slice/flags: 0
		slice/offset: offset
		slice/ordinal: 0
		true
	]

	; The caller must first verify the same immutable data buffer successfully.
	; This lookup intentionally avoids repeating bounds checks on every access.
	find-verified-section: func [
		data [byte-ptr!]
		kind [integer!]
		slice [wire-section-slice!]
		return: [logic!]
		/local count directory-offset ordinal entry-offset current offset size
	][
		if any [null? data null? slice][return false]
		count: read-i31 data WIRE_HEADER_SECTION_COUNT_OFFSET
		directory-offset: read-i31 data WIRE_HEADER_DIRECTORY_OFFSET_OFFSET
		ordinal: 0
		while [ordinal < count][
			entry-offset: directory-offset + (ordinal * WIRE_DIRECTORY_SIZE)
			current: read-i31 data (entry-offset + WIRE_DIRECTORY_KIND_OFFSET)
			if current = kind [
				offset: read-i31 data (entry-offset + WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET)
				size: read-i31 data (entry-offset + WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET)
				slice/data: either size = 0 [as byte-ptr! 0][data + offset]
				slice/size: size
				slice/record-count: read-i31 data (entry-offset + WIRE_DIRECTORY_RECORD_COUNT_OFFSET)
				slice/record-size: read-i31 data (entry-offset + WIRE_DIRECTORY_RECORD_SIZE_OFFSET)
				slice/flags: read-i31 data (entry-offset + WIRE_DIRECTORY_FLAGS_OFFSET)
				slice/offset: offset
				slice/ordinal: ordinal + 1
				return true
			]
			if current > kind [return false]
			ordinal: ordinal + 1
		]
		false
	]
]
