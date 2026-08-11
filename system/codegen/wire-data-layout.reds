Red/System [
	Title: "Hybrid compiler target data-layout semantic verifier"
	File:  %wire-data-layout.reds
]

#include %wire-reader.reds

wire-data-layout-result!: alias struct! [
	error           [integer!]
	container-error [integer!]
	error-offset    [integer!]
	error-section   [integer!]
]

wire-data-layout!: alias struct! [
	address-unit            [integer!]
	pointer-size            [integer!]
	pointer-alignment       [integer!]
	stack-alignment         [integer!]
	max-scalar-alignment    [integer!]
	max-aggregate-alignment [integer!]
	integer-register-width  [integer!]
	flags                   [integer!]
]

wire-data-layout-reader: context [
	set-error: func [
		result [wire-data-layout-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	set-container-error: func [
		result [wire-data-layout-result!]
		container [wire-container-result!]
		code [integer!]
		return: [integer!]
	][
		result/container-error: code
		set-error result WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER
			container/error-offset container/error-section
	]

	section-kind-for: func [magic [integer!] return: [integer!]][
		case [
			magic = WIRE_MAGIC_RSIR [WIRE_RSIR_SECTION_DATA_LAYOUT]
			magic = WIRE_MAGIC_RSCG [WIRE_RSCG_SECTION_DATA_LAYOUT]
			true [-1]
		]
	]

	verify: func [
		data [byte-ptr!]
		size expected-magic [integer!]
		result [wire-data-layout-result!]
		layout [wire-data-layout!]
		return: [integer!]
		/local container [wire-container-result!] section [wire-section-slice!]
			section-kind target abi endian header-pointer feature-low feature-high
			address-unit pointer-size pointer-alignment stack-alignment
			max-scalar-alignment max-aggregate-alignment integer-register-width
			flags status [integer!]
	][
		if null? result [return WIRE_DATA_LAYOUT_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [size < 0 null? data null? layout][
			return set-error result WIRE_DATA_LAYOUT_ERROR_INVALID_ARGUMENTS 0 0
		]
		section-kind: section-kind-for expected-magic
		if section-kind < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_MESSAGE 0 0
		]

		container: declare wire-container-result!
		status: wire-container-reader/verify data size expected-magic container
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			return set-container-error result container status
		]

		target: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_OFFSET
		abi: wire-container-reader/read-i31 data WIRE_HEADER_ABI_OFFSET
		endian: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_ENDIAN_OFFSET
		header-pointer: wire-container-reader/read-i31 data WIRE_HEADER_POINTER_SIZE_OFFSET
		feature-low: wire-container-reader/read-i31 data WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		feature-high: wire-container-reader/read-i31 data WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		if target <> WIRE_TARGET_X86_64 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_TARGET_OFFSET 0
		]
		if abi <> WIRE_ABI_WIN64 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_ABI_OFFSET 0
		]
		if endian <> WIRE_ENDIAN_LITTLE [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		if header-pointer <> 8 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]
		if feature-low <> 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_CPU_FEATURES
				WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0
		]
		if feature-high <> 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_CPU_FEATURES
				WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 0
		]

		section: declare wire-section-slice!
		unless wire-container-reader/find-verified-section data section-kind section [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]

		address-unit: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET
		pointer-size: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET
		pointer-alignment: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET
		stack-alignment: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET
		max-scalar-alignment: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET
		max-aggregate-alignment: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET
		integer-register-width: wire-container-reader/read-i31
			section/data WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET
		flags: wire-container-reader/read-i31 section/data WIRE_DATA_LAYOUT_FLAGS_OFFSET

		if address-unit < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET) section/ordinal
		]
		if pointer-size < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET) section/ordinal
		]
		if pointer-alignment < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET) section/ordinal
		]
		if stack-alignment < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET) section/ordinal
		]
		if max-scalar-alignment < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET) section/ordinal
		]
		if max-aggregate-alignment < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET) section/ordinal
		]
		if integer-register-width < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET) section/ordinal
		]
		if flags < 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
				(section/offset + WIRE_DATA_LAYOUT_FLAGS_OFFSET) section/ordinal
		]

		if address-unit <> 1 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_BAD_ADDRESS_UNIT
				(section/offset + WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET) section/ordinal
		]
		if pointer-size <> header-pointer [
			return set-error result WIRE_DATA_LAYOUT_ERROR_POINTER_SIZE_MISMATCH
				(section/offset + WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET) section/ordinal
		]
		if pointer-alignment <> 8 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_BAD_POINTER_ALIGNMENT
				(section/offset + WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET) section/ordinal
		]
		if stack-alignment <> 16 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT
				(section/offset + WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET) section/ordinal
		]
		if max-scalar-alignment <> 8 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_BAD_MAX_SCALAR_ALIGNMENT
				(section/offset + WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET) section/ordinal
		]
		if max-aggregate-alignment <> 8 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_BAD_MAX_AGGREGATE_ALIGNMENT
				(section/offset + WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET) section/ordinal
		]
		if integer-register-width <> 8 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_BAD_INTEGER_REGISTER_WIDTH
				(section/offset + WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET) section/ordinal
		]
		if flags <> 0 [
			return set-error result WIRE_DATA_LAYOUT_ERROR_NONZERO_FLAGS
				(section/offset + WIRE_DATA_LAYOUT_FLAGS_OFFSET) section/ordinal
		]

		layout/address-unit: address-unit
		layout/pointer-size: pointer-size
		layout/pointer-alignment: pointer-alignment
		layout/stack-alignment: stack-alignment
		layout/max-scalar-alignment: max-scalar-alignment
		layout/max-aggregate-alignment: max-aggregate-alignment
		layout/integer-register-width: integer-register-width
		layout/flags: flags
		WIRE_DATA_LAYOUT_ERROR_SUCCESS
	]
]
