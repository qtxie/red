Red/System [
	Title: "Hybrid compiler routine bridge and smoke codegen"
	File:  %codegen-bridge.reds
]

#include %wire-writer.reds
#include %wire-rscf.reds
#include %wire-rsir.reds
#include %wire-rscg-metadata.reds
#include %wire-diagnostics.reds

wire-codegen-bridge: context [
	BUILD_SUCCESS:          0
	BUILD_WRITER_ERROR:     1
	BUILD_INVALID_ARTIFACT: 2
	VERIFY_ALLOCATION_ERROR: -1

	index-flags: WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED

	same-series?: func [left right [red-binary!] return: [logic!]][
		left/node = right/node
	]

	distinct-series?: func [
		ir config artifact diagnostics [red-binary!]
		return: [logic!]
	][
		not any [
			same-series? ir config
			same-series? ir artifact
			same-series? ir diagnostics
			same-series? config artifact
			same-series? config diagnostics
			same-series? artifact diagnostics
		]
	]

	targets-match?: func [
		ir config [byte-ptr!]
		return: [logic!]
		/local offset left right [integer!]
	][
		offset: WIRE_HEADER_TARGET_OFFSET
		left: wire-container-reader/read-i31 ir offset
		right: wire-container-reader/read-i31 config offset
		if left <> right [return false]
		offset: WIRE_HEADER_ABI_OFFSET
		left: wire-container-reader/read-i31 ir offset
		right: wire-container-reader/read-i31 config offset
		if left <> right [return false]
		offset: WIRE_HEADER_TARGET_ENDIAN_OFFSET
		left: wire-container-reader/read-i31 ir offset
		right: wire-container-reader/read-i31 config offset
		if left <> right [return false]
		offset: WIRE_HEADER_POINTER_SIZE_OFFSET
		left: wire-container-reader/read-i31 ir offset
		right: wire-container-reader/read-i31 config offset
		if left <> right [return false]
		offset: WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		left: wire-container-reader/read-i31 ir offset
		right: wire-container-reader/read-i31 config offset
		if left <> right [return false]
		offset: WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		left: wire-container-reader/read-i31 ir offset
		right: wire-container-reader/read-i31 config offset
		left = right
	]

	write-layout: func [
		writer [wire-container-writer!]
		layout [wire-data-layout!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer
			WIRE_RSCG_SECTION_DATA_LAYOUT 0
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/address-unit
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/pointer-size
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/pointer-alignment
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/stack-alignment
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/max-scalar-alignment
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/max-aggregate-alignment
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/integer-register-width
		]
		if status = 0 [
			status: wire-container-writer/append-u32 writer layout/flags
		]
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	copy-section: func [
		writer [wire-container-writer!]
		kind flags [integer!]
		data [byte-ptr!]
		size [integer!]
		return: [integer!]
		/local status [integer!]
	][
		status: wire-container-writer/start-section writer kind flags
		if status <> 0 [return status]
		status: wire-container-writer/append-bytes writer data size
		if status <> 0 [return status]
		wire-container-writer/end-section writer
	]

	module-value: func [
		modules [wire-module-lifecycle!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 modules/modules
			(((id - 1) * modules/module-record-size) + field-offset)
	]

	write-module: func [
		writer [wire-container-writer!]
		modules [wire-module-lifecycle!]
		return: [integer!]
		/local status value [integer!]
	][
		status: wire-container-writer/start-section writer WIRE_RSCG_SECTION_MODULES 0
		if status <> 0 [return status]
		value: module-value modules 1
			WIRE_RSIR_MODULE_NAME_STRING_OFFSET
		status: wire-container-writer/append-u32 writer value
		if status = 0 [
			value: module-value modules 1
				WIRE_RSIR_MODULE_KIND_OFFSET
			status: wire-container-writer/append-u32 writer value
		]
		if status = 0 [
			value: module-value modules 1
				WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET
			status: wire-container-writer/append-u32 writer value
		]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
		if status = 0 [status: wire-container-writer/append-u32 writer 0]
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

	build-empty-rscg: func [
		arena [wire-arena!]
		limit target abi endian pointer-size features-low features-high [integer!]
		strings [wire-string-table!]
		layout [wire-data-layout!]
		modules [wire-module-lifecycle!]
		return: [integer!]
		/local writer [wire-container-writer!]
			status records-size [integer!]
	][
		writer: declare wire-container-writer!
		records-size: wire-container-reader/checked-multiply
			strings/record-count strings/record-size
		if records-size < 0 [return BUILD_WRITER_ERROR]
		status: wire-container-writer/begin writer arena limit 576 WIRE_MAGIC_RSCG
			target abi endian pointer-size features-low features-high 1
			WIRE_RSCG_REQUIRED_SECTION_COUNT
		if status <> 0 [return BUILD_WRITER_ERROR]
		status: write-layout writer layout
		if status = 0 [
			status: copy-section writer WIRE_RSCG_SECTION_STRINGS index-flags
				strings/records records-size
		]
		if status = 0 [
			status: copy-section writer WIRE_RSCG_SECTION_STRING_DATA 0
				strings/data strings/data-size
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_OUTPUT_SECTIONS index-flags
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_OUTPUT_DATA 0
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_SYMBOLS WIRE_SECTION_FLAG_SORTED
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_RELOCATIONS index-flags
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_IMPORTS index-flags
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_EXPORTS index-flags
		]
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_FUNCTIONS index-flags
		]
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
		if status = 0 [
			status: wire-container-writer/empty-section writer
				WIRE_RSCG_SECTION_GC_FRAMES index-flags
		]
		if status = 0 [status: write-module writer modules]
		if status = 0 [status: wire-container-writer/finish writer]
		if status <> 0 [return BUILD_WRITER_ERROR]
		status: verify-artifact arena/data arena/size
		if status <> WIRE_RSCG_METADATA_ERROR_SUCCESS [
			return BUILD_INVALID_ARTIFACT
		]
		BUILD_SUCCESS
	]

	diagnostic-message: func [
		status phase [integer!]
		return: [c-string!]
	][
		case [
			status = WIRE_STATUS_INVALID_ARGUMENTS ["invalid bridge arguments"]
			status = WIRE_STATUS_INVALID_CONFIGURATION ["invalid codegen configuration"]
			status = WIRE_STATUS_INVALID_RSIR ["invalid RSIR module"]
			status = WIRE_STATUS_UNSUPPORTED_TARGET ["unsupported codegen target"]
			all [
				status = WIRE_STATUS_CODEGEN_FAILURE
					phase = WIRE_DIAGNOSTIC_PHASE_ALLOCATE
			]["native codegen allocation failed"]
			all [
				status = WIRE_STATUS_CODEGEN_FAILURE
					phase = WIRE_DIAGNOSTIC_PHASE_ENCODE
			]["native codegen encoding failed"]
			status = WIRE_STATUS_CODEGEN_FAILURE [
				"smoke backend accepts only empty modules"
			]
			status = WIRE_STATUS_INVALID_ARTIFACT ["invalid generated artifact"]
			true ["native codegen failed"]
		]
	]

	build-diagnostic: func [
		arena [wire-arena!]
		limit status phase target abi endian pointer-size features-low features-high
			[integer!]
		return: [integer!]
		/local writer [wire-container-writer!]
			result [wire-diagnostic-result!]
			strings [wire-string-table!]
			view [wire-diagnostics!]
			message [c-string!]
			message-size writer-status verify-status [integer!]
	][
		writer: declare wire-container-writer!
		message: diagnostic-message status phase
		message-size: length? message
		writer-status: wire-container-writer/begin writer arena limit 160
			WIRE_MAGIC_RSDG target abi endian pointer-size features-low features-high
			1 WIRE_RSDG_REQUIRED_SECTION_COUNT
		if writer-status <> 0 [return writer-status]
		writer-status: wire-container-writer/start-section writer
			WIRE_RSDG_SECTION_STRINGS index-flags
		if writer-status = 0 [
			writer-status: wire-container-writer/append-u32 writer 0
		]
		if writer-status = 0 [
			writer-status: wire-container-writer/append-u32 writer message-size
		]
		if writer-status = 0 [writer-status: wire-container-writer/end-section writer]
		if writer-status = 0 [
			writer-status: copy-section writer WIRE_RSDG_SECTION_STRING_DATA 0
				as byte-ptr! message message-size
		]
		if writer-status = 0 [
			writer-status: wire-container-writer/start-section writer
				WIRE_RSDG_SECTION_DIAGNOSTICS 0
		]
		if writer-status = 0 [
			writer-status: wire-container-writer/append-u32 writer status
		]
		if writer-status = 0 [
			writer-status: wire-container-writer/append-u32 writer
				WIRE_DIAGNOSTIC_SEVERITY_ERROR
		]
		if writer-status = 0 [
			writer-status: wire-container-writer/append-u32 writer phase
		]
		if writer-status = 0 [
			writer-status: wire-container-writer/append-u32 writer 1
		]
		if writer-status = 0 [writer-status: wire-container-writer/append-u32 writer 0]
		if writer-status = 0 [writer-status: wire-container-writer/append-u32 writer 0]
		if writer-status = 0 [writer-status: wire-container-writer/append-u32 writer 0]
		if writer-status = 0 [writer-status: wire-container-writer/append-u32 writer 0]
		if writer-status = 0 [writer-status: wire-container-writer/append-u32 writer 0]
		if writer-status = 0 [writer-status: wire-container-writer/append-u32 writer 0]
		if writer-status = 0 [writer-status: wire-container-writer/end-section writer]
		if writer-status = 0 [writer-status: wire-container-writer/finish writer]
		if writer-status <> 0 [return writer-status]
		result: declare wire-diagnostic-result!
		strings: declare wire-string-table!
		view: declare wire-diagnostics!
		verify-status: wire-diagnostic-reader/verify arena/data arena/size
			WIRE_MAGIC_RSDG result strings view
		if verify-status <> WIRE_DIAGNOSTIC_ERROR_SUCCESS [
			return wire-container-writer/ERROR_STATE
		]
		if view/status <> status [return wire-container-writer/ERROR_STATE]
		wire-container-writer/ERROR_SUCCESS
	]

	emit-diagnostic: func [
		diagnostics [red-binary!]
		limit status phase target abi endian pointer-size features-low features-high
			[integer!]
		/local arena [wire-arena!] build-status [integer!]
	][
		if limit = 0 [exit]
		arena: declare wire-arena!
		wire-arena/reset arena
		build-status: build-diagnostic arena limit status phase target abi endian
			pointer-size features-low features-high
		if build-status = wire-container-writer/ERROR_SUCCESS [
			binary/rs-append diagnostics arena/data arena/size
		]
		wire-arena/release arena
	]

	verify-rsir: func [
		data [byte-ptr!]
		size [integer!]
		blocks [wire-section-slice!]
		result [wire-rsir-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
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
		/local workspace [wire-arena!] workspace-size status [integer!]
	][
		workspace: declare wire-arena!
		wire-arena/reset workspace
		workspace-size: blocks/size
		if workspace-size = 0 [workspace-size: 1]
		status: wire-arena/init workspace workspace-size workspace-size
		if status <> wire-arena/ERROR_SUCCESS [return VERIFY_ALLOCATION_ERROR]
		status: wire-rsir-reader/verify data size workspace/data workspace-size result
			strings files layout types functions modules symbols constants scalar
			control calls subroutines exceptions target-view
		wire-arena/release workspace
		status
	]

	empty-module?: func [
		functions [wire-function-signature!]
		modules [wire-module-lifecycle!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		target-view [wire-target-intrinsic!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: module-value modules 1
			WIRE_RSIR_MODULE_KIND_OFFSET
		all [
			modules/module-count = 1
			any [kind = WIRE_MODULE_KIND_USER kind = WIRE_MODULE_KIND_SUPPORT]
			functions/function-count = 0
			functions/block-count = 0
			symbols/symbol-count = 0
			symbols/global-count = 0
			symbols/import-count = 0
			symbols/export-count = 0
			constants/constant-count = 0
			constants/constant-data-size = 0
			constants/part-count = 0
			constants/binding-count = 0
			scalar/value-count = 0
			scalar/instruction-count = 0
			scalar/operand-count = 0
			target-view/target-fragment-count = 0
		]
	]

	run: func [
		ir config artifact diagnostics [red-binary!]
		return: [integer!]
		/local ir-data config-data [byte-ptr!]
			ir-size config-size status phase target abi endian pointer-size
			features-low features-high build-status [integer!]
			config-result [wire-rscf-result!]
			verified-config [wire-rscf-config!]
			container-result [wire-container-result!]
			blocks [wire-section-slice!]
			rsir-result [wire-rsir-result!]
			strings [wire-string-table!]
			files [wire-file-source!]
			layout [wire-data-layout!]
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
			output [wire-arena!]
	][
		if any [null? ir null? config null? artifact null? diagnostics][
			return WIRE_STATUS_INVALID_ARGUMENTS
		]
		unless distinct-series? ir config artifact diagnostics [
			return WIRE_STATUS_INVALID_ARGUMENTS
		]
		if any [
			artifact/head <> 0
			diagnostics/head <> 0
			(binary/rs-length? artifact) <> 0
			(binary/rs-length? diagnostics) <> 0
		][return WIRE_STATUS_INVALID_ARGUMENTS]

		ir-data: binary/rs-head ir
		ir-size: binary/rs-length? ir
		config-data: binary/rs-head config
		config-size: binary/rs-length? config
		config-result: declare wire-rscf-result!
		verified-config: declare wire-rscf-config!
		status: wire-rscf-reader/verify config-data config-size config-result
			verified-config
		if status <> WIRE_RSCF_ERROR_SUCCESS [
			return either status = WIRE_RSCF_ERROR_UNSUPPORTED_TARGET [
				WIRE_STATUS_UNSUPPORTED_TARGET
			][WIRE_STATUS_INVALID_CONFIGURATION]
		]

		container-result: declare wire-container-result!
		status: wire-container-reader/verify ir-data ir-size WIRE_MAGIC_RSIR
			container-result
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes
				WIRE_STATUS_INVALID_RSIR WIRE_DIAGNOSTIC_PHASE_DECODE 0 0 0 0 0 0
			return WIRE_STATUS_INVALID_RSIR
		]
		target: wire-container-reader/read-i31 ir-data WIRE_HEADER_TARGET_OFFSET
		abi: wire-container-reader/read-i31 ir-data WIRE_HEADER_ABI_OFFSET
		endian: wire-container-reader/read-i31 ir-data WIRE_HEADER_TARGET_ENDIAN_OFFSET
		pointer-size: wire-container-reader/read-i31 ir-data WIRE_HEADER_POINTER_SIZE_OFFSET
		features-low: wire-container-reader/read-i31 ir-data WIRE_HEADER_FEATURE_MASK_LOW_OFFSET
		features-high: wire-container-reader/read-i31 ir-data WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET
		unless targets-match? ir-data config-data [
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes
				WIRE_STATUS_UNSUPPORTED_TARGET WIRE_DIAGNOSTIC_PHASE_DECODE
				target abi endian pointer-size features-low features-high
			return WIRE_STATUS_UNSUPPORTED_TARGET
		]
		blocks: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			ir-data WIRE_RSIR_SECTION_BLOCKS blocks
		[
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes
				WIRE_STATUS_INVALID_RSIR WIRE_DIAGNOSTIC_PHASE_DECODE
				target abi endian pointer-size features-low features-high
			return WIRE_STATUS_INVALID_RSIR
		]

		rsir-result: declare wire-rsir-result!
		strings: declare wire-string-table!
		files: declare wire-file-source!
		layout: declare wire-data-layout!
		types: declare wire-type-layout!
		functions: declare wire-function-signature!
		modules: declare wire-module-lifecycle!
		symbols: declare wire-symbol-linkage!
		constants: declare wire-constant-initializer!
		scalar: declare wire-scalar-operation!
		control: declare wire-control-flow!
		calls: declare wire-call-abi!
		subroutines: declare wire-subroutine!
		exceptions: declare wire-exception!
		target-view: declare wire-target-intrinsic!
		status: verify-rsir ir-data ir-size blocks rsir-result strings files layout
			types functions modules symbols constants scalar control calls subroutines
			exceptions target-view
		if status = VERIFY_ALLOCATION_ERROR [
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes
				WIRE_STATUS_CODEGEN_FAILURE WIRE_DIAGNOSTIC_PHASE_ALLOCATE
				target abi endian pointer-size features-low features-high
			return WIRE_STATUS_CODEGEN_FAILURE
		]
		if status <> wire-rsir-reader/ERROR_SUCCESS [
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes
				WIRE_STATUS_INVALID_RSIR WIRE_DIAGNOSTIC_PHASE_VERIFY
				target abi endian pointer-size features-low features-high
			return WIRE_STATUS_INVALID_RSIR
		]
		unless empty-module? functions modules symbols constants scalar target-view [
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes
				WIRE_STATUS_CODEGEN_FAILURE WIRE_DIAGNOSTIC_PHASE_SELECT
				target abi endian pointer-size features-low features-high
			return WIRE_STATUS_CODEGEN_FAILURE
		]

		output: declare wire-arena!
		wire-arena/reset output
		build-status: build-empty-rscg output verified-config/max-output-bytes
			target abi endian pointer-size features-low features-high strings layout modules
		if build-status <> BUILD_SUCCESS [
			phase: either all [
				build-status = BUILD_WRITER_ERROR
				output/error = wire-arena/ERROR_ALLOCATION
			][WIRE_DIAGNOSTIC_PHASE_ALLOCATE][WIRE_DIAGNOSTIC_PHASE_ENCODE]
			status: either build-status = BUILD_INVALID_ARTIFACT [
				WIRE_STATUS_INVALID_ARTIFACT
			][WIRE_STATUS_CODEGEN_FAILURE]
			if status = WIRE_STATUS_INVALID_ARTIFACT [
				phase: WIRE_DIAGNOSTIC_PHASE_ARTIFACT
			]
			wire-arena/release output
			emit-diagnostic diagnostics verified-config/max-diagnostic-bytes status phase
				target abi endian pointer-size features-low features-high
			return status
		]

		; No input-series pointer is used after this point. The sole runtime call
		; commits the already self-verified native arena atomically.
		binary/rs-append artifact output/data output/size
		wire-arena/release output
		WIRE_STATUS_SUCCESS
	]
]
