Red [
	Title: "Hybrid compiler RSCF semantic verifier"
	File:  %wire-rscf.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]

compiler-wire-rscf: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	allowed-config-flags:
		schema/WIRE_CONFIG_FLAG_DEBUG
		+ schema/WIRE_CONFIG_FLAG_PIC
		+ schema/WIRE_CONFIG_FLAG_DETERMINISTIC

	config-fields: reduce [
		'optimization-level    schema/WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET
		'flags                 schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET
		'code-model            schema/WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET
		'relocation-model      schema/WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET
		'debug-format          schema/WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET
		'cpu-baseline          schema/WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET
		'cpu-features-low      schema/WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET
		'cpu-features-high     schema/WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET
		'max-output-bytes      schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET
		'max-diagnostic-bytes  schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET
		'worker-count          schema/WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET
		'deterministic-seed    schema/WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET
		'reserved-0            schema/WIRE_RSCF_CONFIG_RESERVED_0_OFFSET
		'reserved-1            schema/WIRE_RSCF_CONFIG_RESERVED_1_OFFSET
		'reserved-2            schema/WIRE_RSCF_CONFIG_RESERVED_2_OFFSET
		'reserved-3            schema/WIRE_RSCF_CONFIG_RESERVED_3_OFFSET
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_RSCF_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			config: none
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

	verify: func [
		data
		/local result container-result header section payload-offset config name
			field-offset value optimization-level flags code-model relocation-model
			debug-format cpu-baseline cpu-features-low cpu-features-high
			max-output-bytes max-diagnostic-bytes worker-count deterministic-seed
			reserved-0 reserved-1 reserved-2 reserved-3 debug-enabled? pic-enabled?
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_RSCF_ERROR_INVALID_ARGUMENTS 0 0
		]
		container-result: container/verify/expect data schema/WIRE_MAGIC_RSCF
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_RSCF_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		header: container-result/header
		if (select header 'target) <> schema/WIRE_TARGET_X86_64 [
			return reject result schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_TARGET_OFFSET 0
		]
		if (select header 'abi) <> schema/WIRE_ABI_WIN64 [
			return reject result schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_ABI_OFFSET 0
		]
		if (select header 'target-endian) <> schema/WIRE_ENDIAN_LITTLE [
			return reject result schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		if (select header 'pointer-size) <> 8 [
			return reject result schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
				schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]

		section: container/find-section container-result schema/WIRE_RSCF_SECTION_CONFIG
		if none? section [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_RSCF_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]
		payload-offset: select section 'payload-offset
		config: make map! 32
		foreach [name field-offset] config-fields [
			value: container/read-i31 data (payload-offset + field-offset)
			if none? value [
				return reject result schema/WIRE_RSCF_ERROR_SCALAR_RANGE
					(payload-offset + field-offset) schema/WIRE_RSCF_SECTION_CONFIG
			]
			put config name value
		]

		optimization-level: select config 'optimization-level
		flags: select config 'flags
		code-model: select config 'code-model
		relocation-model: select config 'relocation-model
		debug-format: select config 'debug-format
		cpu-baseline: select config 'cpu-baseline
		cpu-features-low: select config 'cpu-features-low
		cpu-features-high: select config 'cpu-features-high
		max-output-bytes: select config 'max-output-bytes
		max-diagnostic-bytes: select config 'max-diagnostic-bytes
		worker-count: select config 'worker-count
		deterministic-seed: select config 'deterministic-seed
		reserved-0: select config 'reserved-0
		reserved-1: select config 'reserved-1
		reserved-2: select config 'reserved-2
		reserved-3: select config 'reserved-3

		unless all [
			optimization-level >= schema/WIRE_OPTIMIZATION_LEVEL_O0
			optimization-level <= schema/WIRE_OPTIMIZATION_LEVEL_O2
		][
			return reject result schema/WIRE_RSCF_ERROR_BAD_OPTIMIZATION_LEVEL
				(payload-offset + schema/WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		unless (flags and allowed-config-flags) = flags [
			return reject result schema/WIRE_RSCF_ERROR_BAD_CONFIG_FLAGS
				(payload-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if code-model <> schema/WIRE_CODE_MODEL_SMALL [
			return reject result schema/WIRE_RSCF_ERROR_BAD_CODE_MODEL
				(payload-offset + schema/WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		unless any [
			relocation-model = schema/WIRE_RELOCATION_MODEL_STATIC
			relocation-model = schema/WIRE_RELOCATION_MODEL_PIC
		][
			return reject result schema/WIRE_RSCF_ERROR_BAD_RELOCATION_MODEL
				(payload-offset + schema/WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		unless any [
			debug-format = schema/WIRE_DEBUG_FORMAT_NONE
			debug-format = schema/WIRE_DEBUG_FORMAT_RED
		][
			return reject result schema/WIRE_RSCF_ERROR_BAD_DEBUG_FORMAT
				(payload-offset + schema/WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-baseline <> schema/WIRE_CPU_BASELINE_X86_64_BASE [
			return reject result schema/WIRE_RSCF_ERROR_BAD_CPU_BASELINE
				(payload-offset + schema/WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-low <> (select header 'feature-mask-low) [
			return reject result schema/WIRE_RSCF_ERROR_FEATURE_MISMATCH
				(payload-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-high <> (select header 'feature-mask-high) [
			return reject result schema/WIRE_RSCF_ERROR_FEATURE_MISMATCH
				(payload-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-low <> 0 [
			return reject result schema/WIRE_RSCF_ERROR_UNSUPPORTED_CPU_FEATURES
				(payload-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if cpu-features-high <> 0 [
			return reject result schema/WIRE_RSCF_ERROR_UNSUPPORTED_CPU_FEATURES
				(payload-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if max-output-bytes < schema/WIRE_RSCG_MINIMUM_SIZE [
			return reject result schema/WIRE_RSCF_ERROR_BAD_OUTPUT_LIMIT
				(payload-offset + schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if all [
			max-diagnostic-bytes <> 0
			max-diagnostic-bytes < schema/WIRE_RSDG_MINIMUM_SIZE
		][
			return reject result schema/WIRE_RSCF_ERROR_BAD_DIAGNOSTIC_LIMIT
				(payload-offset + schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if worker-count <> 1 [
			return reject result schema/WIRE_RSCF_ERROR_BAD_WORKER_COUNT
				(payload-offset + schema/WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		if deterministic-seed <> 0 [
			return reject result schema/WIRE_RSCF_ERROR_BAD_DETERMINISTIC_SEED
				(payload-offset + schema/WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		foreach field-offset reduce [
			schema/WIRE_RSCF_CONFIG_RESERVED_0_OFFSET
			schema/WIRE_RSCF_CONFIG_RESERVED_1_OFFSET
			schema/WIRE_RSCF_CONFIG_RESERVED_2_OFFSET
			schema/WIRE_RSCF_CONFIG_RESERVED_3_OFFSET
		][
			if (container/read-i31 data (payload-offset + field-offset)) <> 0 [
				return reject result schema/WIRE_RSCF_ERROR_NONZERO_RESERVED
					(payload-offset + field-offset) schema/WIRE_RSCF_SECTION_CONFIG
			]
		]

		debug-enabled?: (flags and schema/WIRE_CONFIG_FLAG_DEBUG) <> 0
		if debug-enabled? <> (debug-format = schema/WIRE_DEBUG_FORMAT_RED) [
			return reject result schema/WIRE_RSCF_ERROR_INCONSISTENT_DEBUG
				(payload-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]
		pic-enabled?: (flags and schema/WIRE_CONFIG_FLAG_PIC) <> 0
		if pic-enabled? <> (relocation-model = schema/WIRE_RELOCATION_MODEL_PIC) [
			return reject result schema/WIRE_RSCF_ERROR_INCONSISTENT_PIC
				(payload-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
				schema/WIRE_RSCF_SECTION_CONFIG
		]

		result/config: config
		result/valid?: true
		result
	]
]
