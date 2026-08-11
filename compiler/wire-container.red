Red [
	Title: "Hybrid compiler wire container verifier"
	File:  %wire-container.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]

compiler-wire-container: context [
	schema: compiler-wire-schema
	limit: 2147483648
	max-scalar: 2147483647
	allowed-section-flags: 7

	header-fields: reduce [
		'header-size             schema/WIRE_HEADER_HEADER_SIZE_OFFSET
		'container-flags         schema/WIRE_HEADER_CONTAINER_FLAGS_OFFSET
		'total-size              schema/WIRE_HEADER_TOTAL_SIZE_OFFSET
		'section-count           schema/WIRE_HEADER_SECTION_COUNT_OFFSET
		'directory-offset        schema/WIRE_HEADER_DIRECTORY_OFFSET_OFFSET
		'directory-record-size   schema/WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET
		'target                  schema/WIRE_HEADER_TARGET_OFFSET
		'abi                     schema/WIRE_HEADER_ABI_OFFSET
		'target-endian           schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET
		'pointer-size            schema/WIRE_HEADER_POINTER_SIZE_OFFSET
		'feature-mask-low        schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		'feature-mask-high       schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		'producer-build          schema/WIRE_HEADER_PRODUCER_BUILD_OFFSET
		'schema-fingerprint      schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET
	]

	directory-fields: reduce [
		'kind             schema/WIRE_DIRECTORY_KIND_OFFSET
		'flags            schema/WIRE_DIRECTORY_FLAGS_OFFSET
		'payload-offset   schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET
		'payload-size     schema/WIRE_DIRECTORY_PAYLOAD_SIZE_OFFSET
		'record-count     schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET
		'record-size      schema/WIRE_DIRECTORY_RECORD_SIZE_OFFSET
		'alignment        schema/WIRE_DIRECTORY_ALIGNMENT_OFFSET
		'reserved         schema/WIRE_DIRECTORY_RESERVED_OFFSET
	]

	make-result: does [
		make object! [
			valid?: false
			error: 0
			error-offset: 0
			error-section: 0
			magic: 0
			header: none
			sections: copy []
		]
	]

	reject: func [
		result [object!]
		code [integer!]
		offset [integer!]
		section [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	read-u16: func [data [binary!] offset [integer!]][
		(to integer! pick data (offset + 1))
			+ ((to integer! pick data (offset + 2)) * 256)
	]

	read-u32: func [data [binary!] offset [integer!]][
		(to integer! pick data (offset + 1))
			+ ((to integer! pick data (offset + 2)) * 256)
			+ ((to integer! pick data (offset + 3)) * 65536)
			+ ((to integer! pick data (offset + 4)) * 16777216)
	]

	read-i31: func [data [binary!] offset [integer!]][
		if (to integer! pick data (offset + 4)) > 127 [return none]
		read-u32 data offset
	]

	checked-add: func [left [integer!] right [integer!]][
		if any [left < 0 right < 0 left > (max-scalar - right)] [return none]
		left + right
	]

	checked-multiply: func [left [integer!] right [integer!]][
		if any [left < 0 right < 0] [return none]
		if any [zero? left zero? right] [return 0]
		if left > (max-scalar / right) [return none]
		left * right
	]

	power-of-two?: func [value [integer!]][
		all [value > 0 zero? (value and (value - 1))]
	]

	first-nonzero: func [
		data [binary!]
		start [integer!]
		finish [integer!]
		/local offset
	][
		offset: start
		while [offset < finish][
			if (to integer! pick data (offset + 1)) <> 0 [return offset]
			offset: offset + 1
		]
		none
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

	valid-target-header?: func [
		result [object!]
		magic [integer!]
		header [map!]
		/local target abi endian pointer low high
	][
		target: select header 'target
		abi: select header 'abi
		endian: select header 'target-endian
		pointer: select header 'pointer-size
		low: select header 'feature-mask-low
		high: select header 'feature-mask-high

		if all [magic = schema/WIRE_MAGIC_RSDG target = 0][
			if abi <> 0 [
				return reject result schema/WIRE_CONTAINER_ERROR_BAD_ABI
					schema/WIRE_HEADER_ABI_OFFSET 0
			]
			if endian <> 0 [
				return reject result schema/WIRE_CONTAINER_ERROR_BAD_ENDIAN
					schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
			]
			if pointer <> 0 [
				return reject result schema/WIRE_CONTAINER_ERROR_BAD_POINTER_SIZE
					schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0
			]
			if any [low <> 0 high <> 0][
				return reject result schema/WIRE_CONTAINER_ERROR_BAD_TARGET
					schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0
			]
			return result
		]

		unless all [target >= schema/WIRE_TARGET_X86_64 target <= schema/WIRE_TARGET_X86][
			return reject result schema/WIRE_CONTAINER_ERROR_BAD_TARGET
				schema/WIRE_HEADER_TARGET_OFFSET 0
		]
		unless all [abi >= schema/WIRE_ABI_WIN64 abi <= schema/WIRE_ABI_WIN32][
			return reject result schema/WIRE_CONTAINER_ERROR_BAD_ABI
				schema/WIRE_HEADER_ABI_OFFSET 0
		]
		unless any [endian = schema/WIRE_ENDIAN_LITTLE endian = schema/WIRE_ENDIAN_BIG][
			return reject result schema/WIRE_CONTAINER_ERROR_BAD_ENDIAN
				schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		unless any [pointer = 4 pointer = 8][
			return reject result schema/WIRE_CONTAINER_ERROR_BAD_POINTER_SIZE
				schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]
		result
	]

	verify: func [
		data [binary!]
		/expect expected-magic [integer!]
		/local result size magic profile major minor header name field-offset value target-result
			directory-size directory-end previous-kind payload-end ordinal entry-offset section
			kind flags payload-offset payload-size record-count record-size alignment reserved
			known? expected-size expected-alignment cardinality required? product section-end
			required-seen padding-offset
	][
		result: make-result
		size: length? data
		if size < schema/WIRE_HEADER_SIZE [
			return (reject result schema/WIRE_CONTAINER_ERROR_TRUNCATED_HEADER size 0)
		]
		if size >= limit [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_TOTAL_SIZE
				schema/WIRE_HEADER_TOTAL_SIZE_OFFSET 0)
		]

		magic: read-u32 data schema/WIRE_HEADER_MAGIC_OFFSET
		result/magic: magic
		profile: profile-for magic
		if any [none? profile all [expect magic <> expected-magic]][
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_MAGIC
				schema/WIRE_HEADER_MAGIC_OFFSET 0)
		]

		major: read-u16 data schema/WIRE_HEADER_VERSION_MAJOR_OFFSET
		minor: read-u16 data schema/WIRE_HEADER_VERSION_MINOR_OFFSET
		if any [
			major <> schema/WIRE_VERSION_MAJOR
			minor > schema/WIRE_VERSION_MINOR
		][
			return (reject result schema/WIRE_CONTAINER_ERROR_UNSUPPORTED_VERSION
				schema/WIRE_HEADER_VERSION_MAJOR_OFFSET 0)
		]

		header: make map! 32
		foreach [name field-offset] header-fields [
			value: read-i31 data field-offset
			if none? value [
				return (reject result schema/WIRE_CONTAINER_ERROR_SCALAR_RANGE field-offset 0)
			]
			put header name value
		]
		result/header: header

		unless (select header 'header-size) = schema/WIRE_HEADER_SIZE [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_HEADER_SIZE
				schema/WIRE_HEADER_HEADER_SIZE_OFFSET 0)
		]
		unless (select header 'container-flags) = 0 [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_CONTAINER_FLAGS
				schema/WIRE_HEADER_CONTAINER_FLAGS_OFFSET 0)
		]
		unless (select header 'total-size) = size [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_TOTAL_SIZE
				schema/WIRE_HEADER_TOTAL_SIZE_OFFSET 0)
		]
		unless (select header 'schema-fingerprint) = schema/WIRE_SCHEMA_FINGERPRINT [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
				schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0)
		]

		target-result: valid-target-header? result magic header
		if target-result/error <> schema/WIRE_CONTAINER_ERROR_SUCCESS [return target-result]

		unless (select header 'directory-offset) = schema/WIRE_HEADER_SIZE [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_DIRECTORY_OFFSET
				schema/WIRE_HEADER_DIRECTORY_OFFSET_OFFSET 0)
		]
		unless (select header 'directory-record-size) = schema/WIRE_DIRECTORY_SIZE [
			return (reject result schema/WIRE_CONTAINER_ERROR_BAD_DIRECTORY_RECORD_SIZE
				schema/WIRE_HEADER_DIRECTORY_RECORD_SIZE_OFFSET 0)
		]

		directory-size: checked-multiply
			select header 'section-count
			select header 'directory-record-size
		if none? directory-size [
			return (reject result schema/WIRE_CONTAINER_ERROR_DIRECTORY_RANGE
				schema/WIRE_HEADER_SECTION_COUNT_OFFSET 0)
		]
		directory-end: checked-add select header 'directory-offset directory-size
		if any [none? directory-end directory-end > size][
			return (reject result schema/WIRE_CONTAINER_ERROR_DIRECTORY_RANGE
				schema/WIRE_HEADER_DIRECTORY_OFFSET_OFFSET 0)
		]

		previous-kind: 0
		payload-end: directory-end
		required-seen: 0
		repeat ordinal select header 'section-count [
			entry-offset: (select header 'directory-offset)
				+ ((ordinal - 1) * schema/WIRE_DIRECTORY_SIZE)
			section: make map! 16
			foreach [name field-offset] directory-fields [
				value: read-i31 data (entry-offset + field-offset)
				if none? value [
					return (reject result schema/WIRE_CONTAINER_ERROR_SCALAR_RANGE
						(entry-offset + field-offset) ordinal)
				]
				put section name value
			]
			put section 'ordinal ordinal
			put section 'entry-offset entry-offset

			kind: select section 'kind
			flags: select section 'flags
			payload-offset: select section 'payload-offset
			payload-size: select section 'payload-size
			record-count: select section 'record-count
			record-size: select section 'record-size
			alignment: select section 'alignment
			reserved: select section 'reserved

			if kind <= previous-kind [
				return (reject result schema/WIRE_CONTAINER_ERROR_SECTION_ORDER entry-offset ordinal)
			]
			previous-kind: kind
			if flags > allowed-section-flags [
				return (reject result schema/WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS
					(entry-offset + schema/WIRE_DIRECTORY_FLAGS_OFFSET) ordinal)
			]
			if reserved <> 0 [
				return (reject result schema/WIRE_CONTAINER_ERROR_NONZERO_RESERVED
					(entry-offset + schema/WIRE_DIRECTORY_RESERVED_OFFSET) ordinal)
			]

			known?: kind <= profile/known-count
			either known? [
				expected-size: pick profile/record-sizes kind
				expected-alignment: pick profile/alignments kind
				cardinality: pick profile/cardinalities kind
				required?: (pick profile/required kind) = 1
				if record-size <> expected-size [
					return (reject result schema/WIRE_CONTAINER_ERROR_BAD_RECORD_SIZE
						(entry-offset + schema/WIRE_DIRECTORY_RECORD_SIZE_OFFSET) ordinal)
				]
				if alignment <> expected-alignment [
					return (reject result schema/WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + schema/WIRE_DIRECTORY_ALIGNMENT_OFFSET) ordinal)
				]
				either required? [
					if (flags and schema/WIRE_SECTION_FLAG_OPTIONAL) <> 0 [
						return (reject result schema/WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS
							(entry-offset + schema/WIRE_DIRECTORY_FLAGS_OFFSET) ordinal)
					]
					required-seen: required-seen + 1
				][
					if (flags and schema/WIRE_SECTION_FLAG_OPTIONAL) = 0 [
						return (reject result schema/WIRE_CONTAINER_ERROR_BAD_SECTION_FLAGS
							(entry-offset + schema/WIRE_DIRECTORY_FLAGS_OFFSET) ordinal)
					]
				]
			][
				if (flags and schema/WIRE_SECTION_FLAG_OPTIONAL) = 0 [
					return (reject result schema/WIRE_CONTAINER_ERROR_UNKNOWN_REQUIRED_SECTION
						(entry-offset + schema/WIRE_DIRECTORY_KIND_OFFSET) ordinal)
				]
				if record-size = 0 [
					return (reject result schema/WIRE_CONTAINER_ERROR_BAD_RECORD_SIZE
						(entry-offset + schema/WIRE_DIRECTORY_RECORD_SIZE_OFFSET) ordinal)
				]
				unless power-of-two? alignment [
					return (reject result schema/WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + schema/WIRE_DIRECTORY_ALIGNMENT_OFFSET) ordinal)
				]
				cardinality: schema/WIRE_SECTION_CARDINALITY_ANY
			]

			product: checked-multiply record-count record-size
			if any [none? product product <> payload-size][
				return (reject result schema/WIRE_CONTAINER_ERROR_SECTION_PRODUCT
					(entry-offset + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) ordinal)
			]
			if any [
				all [cardinality = schema/WIRE_SECTION_CARDINALITY_ONE record-count <> 1]
				all [cardinality = schema/WIRE_SECTION_CARDINALITY_NONEMPTY record-count = 0]
			][
				return (reject result schema/WIRE_CONTAINER_ERROR_BAD_SECTION_CARDINALITY
					(entry-offset + schema/WIRE_DIRECTORY_RECORD_COUNT_OFFSET) ordinal)
			]

			either payload-size = 0 [
				if payload-offset <> 0 [
					return (reject result schema/WIRE_CONTAINER_ERROR_EMPTY_SECTION_OFFSET
						(entry-offset + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) ordinal)
				]
			][
				unless power-of-two? alignment [
					return (reject result schema/WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + schema/WIRE_DIRECTORY_ALIGNMENT_OFFSET) ordinal)
				]
				unless zero? (payload-offset // alignment) [
					return (reject result schema/WIRE_CONTAINER_ERROR_BAD_ALIGNMENT
						(entry-offset + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) ordinal)
				]
				section-end: checked-add payload-offset payload-size
				if any [none? section-end section-end > size][
					return (reject result schema/WIRE_CONTAINER_ERROR_SECTION_RANGE
						(entry-offset + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) ordinal)
				]
				if payload-offset < payload-end [
					return (reject result schema/WIRE_CONTAINER_ERROR_PAYLOAD_ORDER
						(entry-offset + schema/WIRE_DIRECTORY_PAYLOAD_OFFSET_OFFSET) ordinal)
				]
				padding-offset: first-nonzero data payload-end payload-offset
				unless none? padding-offset [
					return (reject result schema/WIRE_CONTAINER_ERROR_NONZERO_PADDING
						padding-offset ordinal)
				]
				payload-end: section-end
			]
			append/only result/sections section
		]

		unless required-seen = profile/required-count [
			return (reject result schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
				(select header 'directory-offset) 0)
		]
		padding-offset: first-nonzero data payload-end size
		unless none? padding-offset [
			return (reject result schema/WIRE_CONTAINER_ERROR_NONZERO_PADDING
				padding-offset 0)
		]

		result/valid?: true
		result
	]

	find-section: func [result [object!] kind [integer!] /local section][
		unless result/valid? [return none]
		foreach section result/sections [
			if (select section 'kind) = kind [return section]
		]
		none
	]
]
