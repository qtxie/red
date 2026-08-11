Red/System [
	Title: "Hybrid compiler RSCF semantic verifier"
	File:  %wire-rscf.reds
]

#include %wire-reader.reds

wire-rscf-result!: alias struct! [
	error           [integer!]
	container-error [integer!]
	error-offset    [integer!]
	error-section   [integer!]
]

wire-rscf-config!: alias struct! [
	optimization-level   [integer!]
	flags                [integer!]
	code-model           [integer!]
	relocation-model     [integer!]
	debug-format         [integer!]
	cpu-baseline         [integer!]
	cpu-features-low     [integer!]
	cpu-features-high    [integer!]
	max-output-bytes     [integer!]
	max-diagnostic-bytes [integer!]
	worker-count         [integer!]
	deterministic-seed   [integer!]
]

wire-rscf-reader: context [
	allowed-config-flags:
		WIRE_CONFIG_FLAG_DEBUG
		+ WIRE_CONFIG_FLAG_PIC
		+ WIRE_CONFIG_FLAG_DETERMINISTIC
		+ WIRE_CONFIG_FLAG_RUNTIME_MODULE

	set-error: func [
		result [wire-rscf-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	set-container-error: func [
		result [wire-rscf-result!]
		container [wire-container-result!]
		code [integer!]
		return: [integer!]
	][
		result/container-error: code
		set-error result WIRE_RSCF_ERROR_INVALID_CONTAINER
			container/error-offset container/error-section
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-rscf-result!]
		config [wire-rscf-config!]
		return: [integer!]
		/local container [wire-container-result!] section [wire-section-slice!]
			target abi endian pointer header-features-low header-features-high
			optimization-level flags code-model relocation-model debug-format
			cpu-baseline cpu-features-low cpu-features-high max-output-bytes
			max-diagnostic-bytes worker-count deterministic-seed reserved-0
			reserved-1 reserved-2 reserved-3 status payload-offset [integer!]
			debug-enabled? pic-enabled? [logic!]
	][
		if null? result [return WIRE_RSCF_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_RSCF_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [size < 0 null? data null? config][
			return set-error result WIRE_RSCF_ERROR_INVALID_ARGUMENTS 0 0
		]

		container: declare wire-container-result!
		status: wire-container-reader/verify data size WIRE_MAGIC_RSCF container
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			return set-container-error result container status
		]

		target: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_OFFSET
		abi: wire-container-reader/read-i31 data WIRE_HEADER_ABI_OFFSET
		endian: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_ENDIAN_OFFSET
		pointer: wire-container-reader/read-i31 data WIRE_HEADER_POINTER_SIZE_OFFSET
		header-features-low:
			wire-container-reader/read-i31 data WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		header-features-high:
			wire-container-reader/read-i31 data WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		if target <> WIRE_TARGET_X86_64 [
			return set-error result WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_TARGET_OFFSET 0
		]
		if abi <> WIRE_ABI_WIN64 [
			return set-error result WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_ABI_OFFSET 0
		]
		if endian <> WIRE_ENDIAN_LITTLE [
			return set-error result WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		if pointer <> 8 [
			return set-error result WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]

		section: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSCF_SECTION_CONFIG section
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_RSCF_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		payload-offset: as integer! (section/data - data)

		optimization-level: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET
		flags: wire-container-reader/read-i31 section/data WIRE_RSCF_CONFIG_FLAGS_OFFSET
		code-model: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET
		relocation-model: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET
		debug-format: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET
		cpu-baseline: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET
		cpu-features-low: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET
		cpu-features-high: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET
		max-output-bytes: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET
		max-diagnostic-bytes: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET
		worker-count: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET
		deterministic-seed: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET
		reserved-0: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_RESERVED_0_OFFSET
		reserved-1: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_RESERVED_1_OFFSET
		reserved-2: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_RESERVED_2_OFFSET
		reserved-3: wire-container-reader/read-i31
			section/data WIRE_RSCF_CONFIG_RESERVED_3_OFFSET

		if optimization-level < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if flags < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_FLAGS_OFFSET) WIRE_RSCF_SECTION_CONFIG
		]
		if code-model < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if relocation-model < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if debug-format < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-baseline < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-low < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-high < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if max-output-bytes < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if max-diagnostic-bytes < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if worker-count < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if deterministic-seed < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-0 < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_0_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-1 < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_1_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-2 < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_2_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-3 < 0 [
			return set-error result WIRE_RSCF_ERROR_SCALAR_RANGE
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_3_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]

		unless all [
			optimization-level >= WIRE_OPTIMIZATION_LEVEL_O0
			optimization-level <= WIRE_OPTIMIZATION_LEVEL_O2
		][
			return set-error result WIRE_RSCF_ERROR_BAD_OPTIMIZATION_LEVEL
				(payload-offset + WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		unless (flags and allowed-config-flags) = flags [
			return set-error result WIRE_RSCF_ERROR_BAD_CONFIG_FLAGS
				(payload-offset + WIRE_RSCF_CONFIG_FLAGS_OFFSET) WIRE_RSCF_SECTION_CONFIG
		]
		if code-model <> WIRE_CODE_MODEL_SMALL [
			return set-error result WIRE_RSCF_ERROR_BAD_CODE_MODEL
				(payload-offset + WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		unless any [
			relocation-model = WIRE_RELOCATION_MODEL_STATIC
			relocation-model = WIRE_RELOCATION_MODEL_PIC
		][
			return set-error result WIRE_RSCF_ERROR_BAD_RELOCATION_MODEL
				(payload-offset + WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		unless any [
			debug-format = WIRE_DEBUG_FORMAT_NONE
			debug-format = WIRE_DEBUG_FORMAT_RED
		][
			return set-error result WIRE_RSCF_ERROR_BAD_DEBUG_FORMAT
				(payload-offset + WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-baseline <> WIRE_CPU_BASELINE_X86_64_BASE [
			return set-error result WIRE_RSCF_ERROR_BAD_CPU_BASELINE
				(payload-offset + WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-low <> header-features-low [
			return set-error result WIRE_RSCF_ERROR_FEATURE_MISMATCH
				(payload-offset + WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-high <> header-features-high [
			return set-error result WIRE_RSCF_ERROR_FEATURE_MISMATCH
				(payload-offset + WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-low <> 0 [
			return set-error result WIRE_RSCF_ERROR_UNSUPPORTED_CPU_FEATURES
				(payload-offset + WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-high <> 0 [
			return set-error result WIRE_RSCF_ERROR_UNSUPPORTED_CPU_FEATURES
				(payload-offset + WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if max-output-bytes < WIRE_RSCG_MINIMUM_SIZE [
			return set-error result WIRE_RSCF_ERROR_BAD_OUTPUT_LIMIT
				(payload-offset + WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if all [
			max-diagnostic-bytes <> 0
			max-diagnostic-bytes < WIRE_RSDG_MINIMUM_SIZE
		][
			return set-error result WIRE_RSCF_ERROR_BAD_DIAGNOSTIC_LIMIT
				(payload-offset + WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if worker-count <> 1 [
			return set-error result WIRE_RSCF_ERROR_BAD_WORKER_COUNT
				(payload-offset + WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if deterministic-seed <> 0 [
			return set-error result WIRE_RSCF_ERROR_BAD_DETERMINISTIC_SEED
				(payload-offset + WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-0 <> 0 [
			return set-error result WIRE_RSCF_ERROR_NONZERO_RESERVED
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_0_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-1 <> 0 [
			return set-error result WIRE_RSCF_ERROR_NONZERO_RESERVED
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_1_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-2 <> 0 [
			return set-error result WIRE_RSCF_ERROR_NONZERO_RESERVED
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_2_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]
		if reserved-3 <> 0 [
			return set-error result WIRE_RSCF_ERROR_NONZERO_RESERVED
				(payload-offset + WIRE_RSCF_CONFIG_RESERVED_3_OFFSET)
				WIRE_RSCF_SECTION_CONFIG
		]

		debug-enabled?: ((flags and WIRE_CONFIG_FLAG_DEBUG) <> 0)
		if debug-enabled? <> (debug-format = WIRE_DEBUG_FORMAT_RED) [
			return set-error result WIRE_RSCF_ERROR_INCONSISTENT_DEBUG
				(payload-offset + WIRE_RSCF_CONFIG_FLAGS_OFFSET) WIRE_RSCF_SECTION_CONFIG
		]
		pic-enabled?: ((flags and WIRE_CONFIG_FLAG_PIC) <> 0)
		if pic-enabled? <> (relocation-model = WIRE_RELOCATION_MODEL_PIC) [
			return set-error result WIRE_RSCF_ERROR_INCONSISTENT_PIC
				(payload-offset + WIRE_RSCF_CONFIG_FLAGS_OFFSET) WIRE_RSCF_SECTION_CONFIG
		]

		config/optimization-level: optimization-level
		config/flags: flags
		config/code-model: code-model
		config/relocation-model: relocation-model
		config/debug-format: debug-format
		config/cpu-baseline: cpu-baseline
		config/cpu-features-low: cpu-features-low
		config/cpu-features-high: cpu-features-high
		config/max-output-bytes: max-output-bytes
		config/max-diagnostic-bytes: max-diagnostic-bytes
		config/worker-count: worker-count
		config/deterministic-seed: deterministic-seed
		WIRE_RSCF_ERROR_SUCCESS
	]
]
