Red/System [
	Title: "Hybrid compiler Windows x64 O0 codegen"
	File:  %x64-o0-codegen.reds
]

#include %wire-codegen-strings.reds
#include %x64-encoder.reds
#include %wire-rsir.reds
#include %wire-rscg-metadata.reds

wire-x64-o0-codegen: context [
	BUILD_SUCCESS:          0
	BUILD_WRITER_ERROR:     1
	BUILD_INVALID_ARTIFACT: 2
	BUILD_UNSUPPORTED_SHAPE: 3

	index-flags: WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED
	EMPTY_BITMAP_SIZE: 16
	SHAPE_NONE:        0
	SHAPE_VOID:        1
	SHAPE_I32_LITERAL: 2

	record-value: func [
		records [byte-ptr!]
		id record-size field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 records
			(((id - 1) * record-size) + field-offset)
	]

	module-value: func [
		modules [wire-module-lifecycle!]
		field-offset [integer!]
		return: [integer!]
	][
		record-value modules/modules 1 modules/module-record-size field-offset
	]

	void-type-record?: func [types [wire-type-layout!] return: [logic!]][
		all [
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_VOID
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_FLAGS_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_SIZE_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_RESERVED_0_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_RESERVED_1_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET) = 0
			(record-value types/types 1 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_GC_KIND_OFFSET) = 0
		]
	]

	void-type?: func [types [wire-type-layout!] return: [logic!]][
		all [
			types/type-count = 1
			types/field-count = 0
			void-type-record? types
		]
	]

	i32-types?: func [types [wire-type-layout!] return: [logic!]][
		all [
			types/type-count = 2
			types/field-count = 0
			void-type-record? types
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_INTEGER
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_FLAGS_OFFSET) = WIRE_TYPE_FLAG_SIGNED
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_ALIGNMENT_OFFSET) = 4
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_RESERVED_0_OFFSET) = 0
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) = 0
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_RESERVED_1_OFFSET) = 0
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET) = 0
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET) = 0
			(record-value types/types 2 WIRE_RSIR_TYPE_SIZE
				WIRE_RSIR_TYPE_GC_KIND_OFFSET) = 0
		]
	]

	signature?: func [
		functions [wire-function-signature!]
		return-type [integer!]
		return: [logic!]
	][
		all [
			functions/signature-count = 1
			functions/parameter-count = 0
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
				= WIRE_CALLING_CONVENTION_RED_SYSTEM
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_FLAGS_OFFSET) = 0
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET) = return-type
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET) = 0
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET) = 0
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET) = 0
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET) = 0
			(record-value functions/signatures 1 WIRE_RSIR_SIGNATURE_SIZE
				WIRE_RSIR_SIGNATURE_RESERVED_OFFSET) = 0
		]
	]

	module-shape?: func [
		modules [wire-module-lifecycle!]
		return: [logic!]
		/local kind entry [integer!]
	][
		if modules/module-count <> 1 [return false]
		kind: module-value modules WIRE_RSIR_MODULE_KIND_OFFSET
		entry: module-value modules WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET
		all [
			any [
				kind = WIRE_MODULE_KIND_USER
				kind = WIRE_MODULE_KIND_SUPPORT
				kind = WIRE_MODULE_KIND_GLUE
			]
			(module-value modules WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET)
				= WIRE_IMAGE_KIND_EXECUTABLE
			(module-value modules WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET) = 0
			(module-value modules WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET) = 0
			either kind = WIRE_MODULE_KIND_GLUE [entry = 1][entry = 0]
			(module-value modules WIRE_RSIR_MODULE_SOURCE_LOCATION_OFFSET) = 0
			(module-value modules WIRE_RSIR_MODULE_FLAGS_OFFSET) = 0
		]
	]

	entry-module?: func [
		modules [wire-module-lifecycle!]
		return: [logic!]
	][
		(module-value modules WIRE_RSIR_MODULE_KIND_OFFSET) = WIRE_MODULE_KIND_GLUE
	]

	function-shape?: func [
		functions [wire-function-signature!]
		symbols [wire-symbol-linkage!]
		return: [logic!]
	][
		all [
			functions/function-count = 1
			functions/local-count = 0
			functions/block-count = 1
			symbols/symbol-count = 1
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET) > 0
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_KIND_OFFSET) = WIRE_SYMBOL_KIND_FUNCTION
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) = WIRE_LINKAGE_INTERNAL
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET) = WIRE_VISIBILITY_HIDDEN
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET) = 1
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_FLAGS_OFFSET) = 0
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET) = 0
			(record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
				WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET) = 0
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) = 1
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET) = 1
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_FLAGS_OFFSET) = 0
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET) = 1
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET) = 1
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET) = 1
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET) = 0
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET) = 0
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET) = 0
			(record-value functions/functions 1 WIRE_RSIR_FUNCTION_SIZE
				WIRE_RSIR_FUNCTION_RESERVED_OFFSET) = 0
		]
	]

	block-shape?: func [
		functions [wire-function-signature!]
		instruction-count [integer!]
		return: [logic!]
	][
		all [
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_FUNCTION_OFFSET) = 1
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_FLAGS_OFFSET) = 0
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET) = 1
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET) = instruction-count
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET) = 0
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET) = 0
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET) = 0
			(record-value functions/blocks 1 WIRE_RSIR_BLOCK_SIZE
				WIRE_RSIR_BLOCK_RESERVED_OFFSET) = 0
		]
	]

	void-return?: func [
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		return: [logic!]
	][
		all [
			scalar/value-count = 0
			scalar/instruction-count = 1
			scalar/operand-count = 0
			block-shape? functions 1
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET) = 1
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = WIRE_OPCODE_RETURN
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) = WIRE_EFFECT_FLAG_CONTROL
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET) = WIRE_ALIAS_KIND_NONE
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET) = 0
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET) = 0
		]
	]

	empty-constants?: func [
		constants [wire-constant-initializer!]
		return: [logic!]
	][
		all [
			constants/constant-count = 0
			constants/constant-data-size = 0
			constants/constant-data-owned-size = 0
		]
	]

	i32-literal-return?: func [
		functions [wire-function-signature!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		return: [logic!]
	][
		all [
			constants/constant-count = 1
			constants/constant-data-size = 4
			constants/constant-data-owned-size = 4
			scalar/value-count = 1
			scalar/instruction-count = 2
			scalar/operand-count = 2
			block-shape? functions 2
			(record-value constants/constants 1 WIRE_RSIR_CONSTANT_SIZE
				WIRE_RSIR_CONSTANT_TYPE_OFFSET) = 2
			(record-value constants/constants 1 WIRE_RSIR_CONSTANT_SIZE
				WIRE_RSIR_CONSTANT_KIND_OFFSET) = WIRE_CONSTANT_KIND_SCALAR
			(record-value scalar/instructions 1 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = WIRE_OPCODE_CONSTANT
			(record-value scalar/instructions 2 WIRE_RSIR_INSTRUCTION_SIZE
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = WIRE_OPCODE_RETURN
		]
	]

	other-inputs-empty?: func [
		files [wire-file-source!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		calls [wire-call-abi!]
		subroutines [wire-subroutine!]
		exceptions [wire-exception!]
		target-view [wire-target-intrinsic!]
		return: [logic!]
	][
		all [
			files/file-count = 0
			files/checksum-data-size = 0
			files/source-count = 0
			symbols/global-count = 0
			symbols/import-count = 0
			symbols/export-count = 0
			constants/part-count = 0
			constants/binding-count = 0
			scalar/target-fragment-count = 0
			scalar/subroutine-count = 0
			control/edge-count = 0
			calls/call-count = 0
			subroutines/subroutine-count = 0
			subroutines/block-member-count = 0
			exceptions/region-count = 0
			exceptions/block-member-count = 0
			target-view/target-fragment-count = 0
		]
	]

	select-shape: func [
		files [wire-file-source!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		modules [wire-module-lifecycle!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		calls [wire-call-abi!]
		subroutines [wire-subroutine!]
		exceptions [wire-exception!]
		target-view [wire-target-intrinsic!]
		return: [integer!]
	][
		unless all [
			module-shape? modules
			function-shape? functions symbols
			other-inputs-empty? files symbols constants scalar control calls
				subroutines exceptions target-view
		][return SHAPE_NONE]
		case [
			all [
				void-type? types
				signature? functions 1
				empty-constants? constants
				void-return? functions scalar
			][SHAPE_VOID]
			all [
				i32-types? types
				signature? functions 2
				i32-literal-return? functions constants scalar
			][SHAPE_I32_LITERAL]
			true [SHAPE_NONE]
		]
	]

	write-layout: func [
		writer [wire-container-writer!]
		layout [wire-data-layout!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_DATA_LAYOUT 0
		if status = 0 [status: wire-container-writer/append-u32 writer layout/address-unit]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/pointer-size]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/pointer-alignment]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/stack-alignment]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/max-scalar-alignment]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/max-aggregate-alignment]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/integer-register-width]
		if status = 0 [status: wire-container-writer/append-u32 writer layout/flags]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-output-sections: func [
		writer [wire-container-writer!]
		map [wire-codegen-string-map!]
		function-size [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_OUTPUT_SECTIONS index-flags
		if status = 0 [status: wire-container-writer/append-u32 writer map/code-section-name]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_OUTPUT_SECTION_CLASS_CODE]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 16]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer function-size]
		if status = 0 [status: wire-container-writer/append-u32 writer function-size]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer map/data-section-name]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_OUTPUT_SECTION_CLASS_DATA]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 4]
		if status = 0 [status: wire-container-writer/append-u32 writer function-size]
		if status = 0 [status: wire-container-writer/append-u32 writer EMPTY_BITMAP_SIZE]
		if status = 0 [status: wire-container-writer/append-u32 writer EMPTY_BITMAP_SIZE]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-output-data: func [
		writer [wire-container-writer!]
		entry? [logic!]
		shape value [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer WIRE_RSCG_SECTION_OUTPUT_DATA 0
		if status <> 0 [return status]
		status: wire-container-writer/ensure-section-start writer
		if status <> 0 [return status]
		case [
			shape = SHAPE_VOID [
				status: either entry? [
					wire-x64-encoder/encode-empty-void-entry writer/arena
				][
					wire-x64-encoder/encode-empty-void-function writer/arena
				]
			]
			shape = SHAPE_I32_LITERAL [
				status: either entry? [
					wire-x64-encoder/encode-i32-entry writer/arena value
				][
					wire-x64-encoder/encode-i32-function writer/arena value
				]
			]
			true [status: wire-x64-encoder/ERROR_ARGUMENTS]
		]
		if status <> wire-x64-encoder/ERROR_SUCCESS [return status]
		status: wire-arena/append-zero writer/arena EMPTY_BITMAP_SIZE
		if status <> wire-arena/ERROR_SUCCESS [return status]
		wire-container-writer/end-section writer
	]

	write-function-symbol-record: func [
		writer [wire-container-writer!]
		map [wire-codegen-string-map!]
		function-size [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/append-u32 writer map/function-name
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_SYMBOL_KIND_FUNCTION]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_SYMBOL_BINDING_LOCAL]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_VISIBILITY_HIDDEN]
		if status = 0 [status: wire-container-writer/append-u32 writer 1]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer function-size]
		if status = 0 [status: wire-container-writer/append-u32 writer 16]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 1]
		status
	]

	write-exit-symbol-record: func [
		writer [wire-container-writer!]
		map [wire-codegen-string-map!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/append-u32 writer map/exit-symbol-name
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_SYMBOL_KIND_FUNCTION]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_SYMBOL_BINDING_GLOBAL]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_VISIBILITY_DEFAULT]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [
			status: wire-container-writer/append-u32 writer WIRE_RSCG_SYMBOL_FLAG_UNDEFINED
		]
		if status = 0 [status: wire-container-writer/append-u32 writer 1]
		status
	]

	write-symbols: func [
		writer [wire-container-writer!]
		map [wire-codegen-string-map!]
		function-size function-symbol [integer!]
		entry? [logic!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_SYMBOLS WIRE_SECTION_FLAG_SORTED
		either any [not entry? function-symbol = 1][
			if status = 0 [
				status: write-function-symbol-record writer map function-size
			]
			if all [status = 0 entry?] [
				status: write-exit-symbol-record writer map
			]
		][
			if status = 0 [status: write-exit-symbol-record writer map]
			if status = 0 [
				status: write-function-symbol-record writer map function-size
			]
		]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-relocations: func [
		writer [wire-container-writer!]
		exit-symbol relocation-offset [integer!]
		entry? [logic!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_RELOCATIONS index-flags
		if all [status = 0 entry?] [status: wire-container-writer/append-u32 writer 1]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer relocation-offset
		]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer
				WIRE_RELOCATION_KIND_X64_RIP_REL32
		]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer exit-symbol
		]
		if all [status = 0 entry?] [status: wire-container-writer/append-u32 writer 0]
		if all [status = 0 entry?] [status: wire-container-writer/append-u32 writer 0]
		if all [status = 0 entry?] [status: wire-container-writer/append-u32 writer 4]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer WIRE_RSCG_RELOCATION_FLAG_NONE
		]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-imports: func [
		writer [wire-container-writer!]
		map [wire-codegen-string-map!]
		exit-symbol [integer!]
		entry? [logic!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_IMPORTS index-flags
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer map/exit-library-name
		]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer map/exit-external-name
		]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer exit-symbol
		]
		if all [status = 0 entry?] [
			status: wire-container-writer/append-u32 writer WIRE_CALLING_CONVENTION_STDCALL
		]
		if all [status = 0 entry?] [status: wire-container-writer/append-u32 writer 0]
		if all [status = 0 entry?] [status: wire-container-writer/append-u32 writer 0]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-function: func [
		writer [wire-container-writer!]
		function-size function-symbol [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_FUNCTIONS index-flags
		if status = 0 [status: wire-container-writer/append-u32 writer function-symbol]
		if status = 0 [status: wire-container-writer/append-u32 writer 1]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer function-size]
		if status = 0 [status: wire-container-writer/append-u32 writer wire-x64-encoder/FRAME_SIZE]
		if status = 0 [status: wire-container-writer/append-u32 writer WIRE_RSCG_FUNCTION_FLAG_NONE]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-gc-frame: func [
		writer [wire-container-writer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_GC_FRAMES index-flags
		if status = 0 [status: wire-container-writer/append-u32 writer 1]
		if status = 0 [status: wire-container-writer/append-u32 writer 2]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer EMPTY_BITMAP_SIZE]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [
			status: wire-container-writer/append-u32 writer
				wire-x64-encoder/BITMAP_PATCH_OFFSET
		]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	write-module: func [
		writer [wire-container-writer!]
		modules [wire-module-lifecycle!]
		map [wire-codegen-string-map!]
		entry-symbol [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer WIRE_RSCG_SECTION_MODULES 0
		if status = 0 [status: wire-container-writer/append-u32 writer map/module-name]
		if status = 0 [
			status: wire-container-writer/append-u32 writer
				(module-value modules WIRE_RSIR_MODULE_KIND_OFFSET)
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer
				(module-value modules WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET)
		]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer entry-symbol]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	verify-artifact: func [
		data [byte-ptr!]
		size [integer!]
		return: [integer!]
		/local result [wire-rscg-metadata-result!]
			strings [wire-string-table!]
			files [wire-file-source!]
			layout [wire-data-layout!]
			modules [wire-module-lifecycle!]
			object-view [wire-rscg-object!]
			relocations [wire-rscg-relocation!]
			metadata [wire-rscg-metadata!]
	][
		result: declare wire-rscg-metadata-result!
		strings: declare wire-string-table!
		files: declare wire-file-source!
		layout: declare wire-data-layout!
		modules: declare wire-module-lifecycle!
		object-view: declare wire-rscg-object!
		relocations: declare wire-rscg-relocation!
		metadata: declare wire-rscg-metadata!
		wire-rscg-metadata-reader/verify data size result strings files layout
			modules object-view relocations metadata
	]

	build-function: func [
		arena [wire-arena!]
		limit target abi endian pointer-size features-low features-high [integer!]
		shape [integer!]
		strings [wire-string-table!]
		layout [wire-data-layout!]
		modules [wire-module-lifecycle!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		return: [integer!]
		/local writer [wire-container-writer!]
			map [wire-codegen-string-map!]
			entry? [logic!]
			status module-name function-name function-size extra-count literal
			function-symbol exit-symbol entry-symbol relocation-offset [integer!]
	][
		writer: declare wire-container-writer!
		map: declare wire-codegen-string-map!
		module-name: module-value modules WIRE_RSIR_MODULE_NAME_STRING_OFFSET
		function-name: record-value symbols/symbols 1 WIRE_RSIR_SYMBOL_SIZE
			WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
		entry?: entry-module? modules
		literal: 0
		relocation-offset: 0
		case [
			shape = SHAPE_VOID [
				function-size: either entry? [
					wire-x64-encoder/EMPTY_VOID_ENTRY_FUNCTION_SIZE
				][wire-x64-encoder/EMPTY_VOID_FUNCTION_SIZE]
				if entry? [
					relocation-offset:
						wire-x64-encoder/EMPTY_VOID_ENTRY_RELOCATION_OFFSET
				]
			]
			shape = SHAPE_I32_LITERAL [
				function-size: either entry? [
					wire-x64-encoder/I32_ENTRY_FUNCTION_SIZE
				][wire-x64-encoder/I32_FUNCTION_SIZE]
				literal: wire-container-reader/read-le32 constants/constant-data 0
				if entry? [
					relocation-offset: wire-x64-encoder/I32_ENTRY_RELOCATION_OFFSET
				]
			]
			true [return BUILD_UNSUPPORTED_SHAPE]
		]
		extra-count: either entry? [
			wire-codegen-strings/ENTRY_EXTRA_COUNT
		][wire-codegen-strings/BASE_EXTRA_COUNT]
		function-symbol: 1
		exit-symbol: 0
		entry-symbol: 0
		status: wire-container-writer/begin writer arena limit WIRE_RSCG_MINIMUM_SIZE
			WIRE_MAGIC_RSCG target abi endian pointer-size features-low features-high
			1 WIRE_RSCG_REQUIRED_SECTION_COUNT
		if status <> 0 [return BUILD_WRITER_ERROR]
		status: write-layout writer layout
		if status = 0 [
			status: wire-codegen-strings/write-sections writer strings
				module-name function-name extra-count map
		]
		if all [status = 0 entry?] [
			either map/function-name <= map/exit-symbol-name [
				function-symbol: 1
				exit-symbol: 2
			][
				function-symbol: 2
				exit-symbol: 1
			]
			entry-symbol: function-symbol
		]
		if status = 0 [status: write-output-sections writer map function-size]
		if status = 0 [status: write-output-data writer entry? shape literal]
		if status = 0 [
			status: write-symbols writer map function-size function-symbol entry?
		]
		if status = 0 [
			status: write-relocations writer exit-symbol relocation-offset entry?
		]
		if status = 0 [status: write-imports writer map exit-symbol entry?]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_EXPORTS index-flags
		]
		if status = 0 [status: write-function writer function-size function-symbol]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_FILES index-flags
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA 0
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_DEBUG_LINES WIRE_SECTION_FLAG_SORTED
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_DEBUG_PARAMETERS index-flags
		]
		if status = 0 [status: write-gc-frame writer]
		if status = 0 [status: write-module writer modules map entry-symbol]
		if status = 0 [status: wire-container-writer/finish writer]
		if status <> 0 [return BUILD_WRITER_ERROR]
		status: verify-artifact arena/data arena/size
		if status <> WIRE_RSCG_METADATA_ERROR_SUCCESS [
			return BUILD_INVALID_ARTIFACT
		]
		BUILD_SUCCESS
	]
]
