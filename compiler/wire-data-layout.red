Red [
	Title: "Hybrid compiler target data-layout semantic verifier"
	File:  %wire-data-layout.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]

compiler-wire-data-layout: context [
	schema: compiler-wire-schema
	container: compiler-wire-container

	layout-fields: reduce [
		'address-unit             schema/WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET
		'pointer-size             schema/WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET
		'pointer-alignment        schema/WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET
		'stack-alignment          schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET
		'max-scalar-alignment     schema/WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET
		'max-aggregate-alignment  schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET
		'integer-register-width   schema/WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET
		'flags                    schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			layout: none
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

	section-kind-for: func [magic [integer!]][
		case [
			magic = schema/WIRE_MAGIC_RSIR [schema/WIRE_RSIR_SECTION_DATA_LAYOUT]
			magic = schema/WIRE_MAGIC_RSCG [schema/WIRE_RSCG_SECTION_DATA_LAYOUT]
			true [none]
		]
	]

	verify: func [
		data
		expected-magic
		/local result section-kind container-result header section payload-offset
			section-ordinal layout name field-offset value address-unit pointer-size
			pointer-alignment stack-alignment max-scalar-alignment
			max-aggregate-alignment integer-register-width flags
	][
		result: make-result
		unless all [binary? data integer? expected-magic][
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_INVALID_ARGUMENTS 0 0
		]
		section-kind: section-kind-for expected-magic
		if none? section-kind [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_MESSAGE 0 0
		]

		container-result: container/verify/expect data expected-magic
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		header: container-result/header
		if (select header 'target) <> schema/WIRE_TARGET_X86_64 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_TARGET_OFFSET 0
		]
		if (select header 'abi) <> schema/WIRE_ABI_WIN64 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_ABI_OFFSET 0
		]
		if (select header 'target-endian) <> schema/WIRE_ENDIAN_LITTLE [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		if (select header 'pointer-size) <> 8 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]
		if (select header 'feature-mask-low) <> 0 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_CPU_FEATURES
				schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0
		]
		if (select header 'feature-mask-high) <> 0 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_CPU_FEATURES
				schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 0
		]

		section: container/find-section container-result section-kind
		if none? section [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]
		payload-offset: select section 'payload-offset
		section-ordinal: select section 'ordinal
		layout: make map! 16
		foreach [name field-offset] layout-fields [
			value: container/read-i31 data (payload-offset + field-offset)
			if none? value [
				return reject result schema/WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
					(payload-offset + field-offset) section-ordinal
			]
			put layout name value
		]

		address-unit: select layout 'address-unit
		pointer-size: select layout 'pointer-size
		pointer-alignment: select layout 'pointer-alignment
		stack-alignment: select layout 'stack-alignment
		max-scalar-alignment: select layout 'max-scalar-alignment
		max-aggregate-alignment: select layout 'max-aggregate-alignment
		integer-register-width: select layout 'integer-register-width
		flags: select layout 'flags

		if address-unit <> 1 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_BAD_ADDRESS_UNIT
				(payload-offset + schema/WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET)
				section-ordinal
		]
		if pointer-size <> (select header 'pointer-size) [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_POINTER_SIZE_MISMATCH
				(payload-offset + schema/WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET)
				section-ordinal
		]
		if pointer-alignment <> 8 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_BAD_POINTER_ALIGNMENT
				(payload-offset + schema/WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET)
				section-ordinal
		]
		if stack-alignment <> 16 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT
				(payload-offset + schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET)
				section-ordinal
		]
		if max-scalar-alignment <> 8 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_BAD_MAX_SCALAR_ALIGNMENT
				(payload-offset + schema/WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET)
				section-ordinal
		]
		if max-aggregate-alignment <> 8 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_BAD_MAX_AGGREGATE_ALIGNMENT
				(payload-offset + schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET)
				section-ordinal
		]
		if integer-register-width <> 8 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_BAD_INTEGER_REGISTER_WIDTH
				(payload-offset + schema/WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET)
				section-ordinal
		]
		if flags <> 0 [
			return reject result schema/WIRE_DATA_LAYOUT_ERROR_NONZERO_FLAGS
				(payload-offset + schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET) section-ordinal
		]

		result/layout: layout
		result/valid?: true
		result
	]
]
