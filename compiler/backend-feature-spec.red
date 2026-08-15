Red [
	Title: "Hybrid compiler Windows x64 feature coverage manifest"
	File:  %backend-feature-spec.red
]

; `specified` means the wire representation is complete enough to implement
; independent semantic verifiers. It does not mean frontend or codegen support
; exists. `blocked` entries name the contract that must be resolved first.
compiler-backend-feature-spec: [
	target WINDOWS_X64
	runner "system/tests/run-all.r"
	runner-exclusions [
		"system/tests/source/units/auto-tests/dylib-auto-test.reds"
			"generated suite; covered through its tracked generator and dylib sources"
		"system/tests/source/units/size-test.reds"
			"32-bit alternative excluded by the run-all target condition"
		"system/tests/source/units/struct-test.reds"
			"32-bit alternative excluded by the run-all target condition"
	]
	statuses [
		specified "wire contract is sufficient for independent verifier work"
		blocked   "wire contract or ownership question must be resolved first"
	]
	features [
		container-protocol [
			status specified
			owners [frontend codegen]
			wire [
				RECORD/HEADER RECORD/DIRECTORY
				SECTION_FLAG/ALL_VALUES SECTION_CARDINALITY/ALL_VALUES
				RSCF_SECTION/ALL_VALUES RSIR_SECTION/ALL_VALUES
				RSCG_SECTION/ALL_VALUES RSDG_SECTION/ALL_VALUES
				CONTAINER_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-schema-test.red"
				"tools/self_hosting/tests/wire-container-test.red"
				"tools/self_hosting/tests/wire-container-reds-test.reds"
			]
			blockers []
		]

		target-configuration [
			status specified
			owners [frontend codegen]
			wire [
				RECORD/RSCF_CONFIG
				TARGET/ALL_VALUES ABI/ALL_VALUES ENDIAN/ALL_VALUES
				OPTIMIZATION_LEVEL/ALL_VALUES CPU_BASELINE/ALL_VALUES
				CONFIG_FLAG/ALL_VALUES CODE_MODEL/ALL_VALUES
				RELOCATION_MODEL/ALL_VALUES DEBUG_FORMAT/ALL_VALUES
				RSCF_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-container-test.red"
				"tools/self_hosting/tests/wire-rscf-test.red"
				"tools/self_hosting/tests/wire-rscf-reds-test.reds"
				"system/tests/source/units/size-x64-test.reds"
			]
			blockers []
		]

		diagnostics [
			status specified
			owners [codegen frontend]
			wire [
				RECORD/RSDG_DIAGNOSTIC
				STATUS/ALL_VALUES DIAGNOSTIC_SEVERITY/ALL_VALUES
				DIAGNOSTIC_PHASE/ALL_VALUES DIAGNOSTIC_FLAG/ALL_VALUES
				DIAGNOSTIC_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-container-test.red"
				"tools/self_hosting/tests/wire-diagnostics-test.red"
				"tools/self_hosting/tests/wire-diagnostics-reds-test.reds"
			]
			blockers []
		]

		strings-files-source [
			status specified
			owners [frontend rsir rscg]
			wire [
				RECORD/STRING RECORD/FILE RECORD/SOURCE_LOCATION
				CHECKSUM_KIND/ALL_VALUES STRING_TABLE_ERROR/ALL_VALUES
				FILE_SOURCE_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-string-table-test.red"
				"tools/self_hosting/tests/wire-string-table-reds-test.reds"
				"tools/self_hosting/tests/wire-file-source-test.red"
				"tools/self_hosting/tests/wire-file-source-reds-test.reds"
				"system/tests/source/compiler/output-test.r"
			]
			blockers []
		]

		target-data-layout [
			status specified
			owners [frontend codegen]
			wire [RECORD/DATA_LAYOUT DATA_LAYOUT_ERROR/ALL_VALUES]
			tests [
				"tools/self_hosting/tests/wire-data-layout-test.red"
				"tools/self_hosting/tests/wire-data-layout-reds-test.reds"
				"system/tests/source/units/size-x64-test.reds"
			]
			blockers []
		]

		types-and-aggregate-layout [
			status specified
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_TYPE RECORD/RSIR_FIELD
				TYPE_KIND/ALL_VALUES TYPE_FLAG/ALL_VALUES GC_KIND/ALL_VALUES
				TYPE_LAYOUT_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-type-layout-test.red"
				"tools/self_hosting/tests/wire-type-layout-reds-test.reds"
				"system/tests/source/units/alias-test.reds"
				"system/tests/source/units/array-test.reds"
				"system/tests/source/units/enum-test.reds"
				"system/tests/source/units/protect-test.reds"
				"system/tests/source/units/size-x64-test.reds"
				"system/tests/source/units/struct-x64-test.reds"
				"system/tests/source/units/union-test.reds"
			]
			blockers []
		]

		module-lifecycle [
			status specified
			owners [frontend rsir codegen rscg linker]
			wire [
				RECORD/RSIR_MODULE RECORD/RSCG_MODULE
				MODULE_KIND/ALL_VALUES IMAGE_KIND/ALL_VALUES
				MODULE_LIFECYCLE_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-module-lifecycle-test.red"
				"tools/self_hosting/tests/wire-module-lifecycle-reds-test.reds"
				"system/tests/source/units/x64-image-info-smoke.reds"
			]
			blockers []
		]

		constants-globals-initializers [
			status specified
			owners [frontend rsir codegen rscg]
			wire [
				RECORD/RSIR_CONSTANT RECORD/RSIR_CONSTANT_PART
				RECORD/RSIR_CONSTANT_BINDING RECORD/RSIR_GLOBAL
				CONSTANT_KIND/ALL_VALUES CONSTANT_PART_KIND/ALL_VALUES
				CONSTANT_FLAG/ALL_VALUES CONSTANT_PART_FLAG/ALL_VALUES
				GLOBAL_STORAGE_CLASS/ALL_VALUES GLOBAL_FLAG/ALL_VALUES
				CONSTANT_INITIALIZER_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-constant-initializer-test.red"
				"tools/self_hosting/tests/wire-constant-initializer-reds-test.reds"
				"system/tests/source/units/byte-test.reds"
				"system/tests/source/units/fixed-int-test.reds"
				"system/tests/source/units/float-test.reds"
				"system/tests/source/units/float32-test.reds"
				"system/tests/source/units/int64-test.reds"
			]
			blockers []
		]

		symbols-imports-exports [
			status specified
			owners [frontend rsir rscg adapter linker]
			wire [
				RECORD/RSIR_SYMBOL RECORD/RSIR_GLOBAL RECORD/IMPORT RECORD/EXPORT
				SYMBOL_KIND/ALL_VALUES LINKAGE/ALL_VALUES VISIBILITY/ALL_VALUES
				SYMBOL_LINKAGE_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-symbol-linkage-test.red"
				"tools/self_hosting/tests/wire-symbol-linkage-reds-test.reds"
				"system/tests/source/units/lib-test.reds"
				"system/tests/source/units/namespace-test.reds"
				"system/tests/source/units/use-test.reds"
			]
			blockers []
		]

		functions-signatures-locals [
			status specified
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_SIGNATURE RECORD/RSIR_PARAMETER
				RECORD/RSIR_FUNCTION RECORD/RSIR_LOCAL RECORD/RSIR_BLOCK
				CALLING_CONVENTION/ALL_VALUES FUNCTION_FLAG/ALL_VALUES
				DEBUG_TYPE_CODE/ALL_VALUES LOCAL_KIND/ALL_VALUES
				FUNCTION_SIGNATURE_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-function-signature-test.red"
				"tools/self_hosting/tests/wire-function-signature-reds-test.reds"
				"system/tests/source/units/function-test.reds"
				"system/tests/source/units/infix-test.reds"
				"system/tests/source/units/return-test.reds"
				"system/tests/source/units/x64-variadic-smoke.reds"
				"system/tests/source/units/x64-typed-variadic-smoke.reds"
				"tools/self_hosting/fixtures/backend/custom-call.reds"
			]
			blockers []
		]

		scalar-values-and-operations [
			status specified
			owners [rsir codegen]
			wire [
				RECORD/RSIR_VALUE RECORD/RSIR_INSTRUCTION RECORD/RSIR_OPERAND
				VALUE_DEFINITION/ALL_VALUES VALUE_FLAG/ALL_VALUES
				OPERAND_KIND/ALL_VALUES OPERAND_FLAG/ALL_VALUES
				INSTRUCTION_FLAG/ALL_VALUES SCALAR_OPERATION_ERROR/ALL_VALUES
				OPCODE/CONSTANT OPCODE/COPY
				OPCODE/CONVERT OPCODE/BITCAST
				OPCODE/ADD OPCODE/SUBTRACT OPCODE/MULTIPLY
				OPCODE/DIVIDE OPCODE/REMAINDER OPCODE/MODULO
				OPCODE/NEGATE OPCODE/BIT_NOT OPCODE/LOGIC_NOT
				OPCODE/SHIFT_LEFT OPCODE/SHIFT_RIGHT OPCODE/SHIFT_RIGHT_LOGICAL
				OPCODE/BIT_AND OPCODE/BIT_OR OPCODE/BIT_XOR OPCODE/COMPARE
				COMPARE_KIND/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-scalar-operation-test.red"
				"tools/self_hosting/tests/wire-scalar-operation-reds-test.reds"
				"system/tests/source/units/cast-test.reds"
				"system/tests/source/units/integer-test.reds"
				"system/tests/source/units/logic-test.reds"
				"system/tests/source/units/math-mixed-test.reds"
				"system/tests/source/units/modulo-test.reds"
				"system/tests/source/units/not-test.reds"
				"system/tests/source/units/overflow-test.reds"
			]
			blockers []
		]

		memory-and-aggregate-operations [
			status specified
			owners [rsir codegen]
			wire [
				OPCODE/LOAD_LOCAL OPCODE/STORE_LOCAL OPCODE/ADDRESS_LOCAL
				OPCODE/LOAD_GLOBAL OPCODE/STORE_GLOBAL OPCODE/ADDRESS_GLOBAL
				OPCODE/LOAD_INDIRECT OPCODE/STORE_INDIRECT OPCODE/ADDRESS_FIELD
				OPCODE/AGGREGATE_BUILD OPCODE/AGGREGATE_COPY
				OPCODE/LOAD_UNION_TAG OPCODE/SET_UNION_VARIANT
				EFFECT_FLAG/READ EFFECT_FLAG/WRITE EFFECT_FLAG/VOLATILE
				ALIAS_KIND/ALL_VALUES MEMORY_AGGREGATE_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-memory-aggregate-test.red"
				"tools/self_hosting/tests/wire-memory-aggregate-reds-test.reds"
				"system/tests/source/units/c-string-test.reds"
				"system/tests/source/units/float-pointer-test.reds"
				"system/tests/source/units/get-pointer-test.reds"
				"system/tests/source/units/length-test.reds"
				"system/tests/source/units/null-test.reds"
				"system/tests/source/units/pointer-test.reds"
				"system/tests/source/units/queue-test.reds"
			]
			blockers []
		]

		control-flow [
			status specified
			owners [rsir codegen]
			wire [
				RECORD/RSIR_BLOCK RECORD/RSIR_EDGE
				EDGE_KIND/NORMAL EDGE_KIND/TRUE EDGE_KIND/FALSE
				EDGE_KIND/SWITCH_CASE EDGE_KIND/DEFAULT EDGE_KIND/UNREACHABLE
				OPCODE/BRANCH OPCODE/JUMP OPCODE/SWITCH
				OPCODE/RETURN OPCODE/UNREACHABLE EFFECT_FLAG/CONTROL
				CONTROL_FLOW_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-control-flow-test.red"
				"tools/self_hosting/tests/wire-control-flow-reds-test.reds"
				"system/tests/source/units/case-test.reds"
				"system/tests/source/units/conditional-test.reds"
				"system/tests/source/units/exit-test.reds"
				"system/tests/source/units/return-test.reds"
				"system/tests/source/units/switch-test.reds"
			]
			blockers []
		]

		calls-and-abi [
			status specified
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_CALL OPCODE/CALL
				CALL_KIND/DIRECT CALL_KIND/INDIRECT CALL_KIND/IMPORT
				CALL_KIND/SYSCALL CALL_KIND/CUSTOM
				EFFECT_FLAG/CALL EFFECT_FLAG/MAY_TRAP EFFECT_FLAG/SAFEPOINT
				EFFECT_FLAG/READ EFFECT_FLAG/WRITE EFFECT_FLAG/STACK
				CALL_ABI_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-call-abi-test.red"
				"tools/self_hosting/tests/wire-call-abi-reds-test.reds"
				"system/tests/source/units/function-test.reds"
				"system/tests/source/units/lib-test.reds"
				"system/tests/source/units/vararg-test.reds"
				"tools/self_hosting/fixtures/backend/custom-call.reds"
			]
			blockers []
		]

		atomics [
			status specified
			owners [rsir codegen]
			wire [
				OPCODE/ATOMIC_LOAD OPCODE/ATOMIC_STORE OPCODE/ATOMIC_RMW
				OPCODE/ATOMIC_CAS OPCODE/ATOMIC_FENCE
				ATOMIC_ORDER/ALL_VALUES ATOMIC_RMW_OPERATION/ALL_VALUES
				ATOMIC_FLAG/ALL_VALUES ATOMIC_ERROR/ALL_VALUES
				EFFECT_FLAG/READ EFFECT_FLAG/WRITE EFFECT_FLAG/ATOMIC
				ALIAS_KIND/UNIVERSAL
			]
			tests [
				"tools/self_hosting/tests/wire-atomic-test.red"
				"tools/self_hosting/tests/wire-atomic-reds-test.reds"
				"system/tests/source/units/atomic-test.reds"
			]
			blockers []
		]

		exceptions [
			status specified
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_EXCEPTION_REGION RECORD/RSIR_EXCEPTION_BLOCK
				EDGE_KIND/EXCEPTION
				OPCODE/THROW OPCODE/CATCH_ENTER OPCODE/CATCH_LEAVE
				EXCEPTION_REGION_KIND/ALL_VALUES
				EXCEPTION_REGION_FLAG/ALL_VALUES EXCEPTION_ERROR/ALL_VALUES
				EFFECT_FLAG/THROW EFFECT_FLAG/CONTROL EFFECT_FLAG/WRITE
				FUNCTION_FLAG/MAY_THROW FUNCTION_FLAG/CALLBACK
			]
			tests [
				"tools/self_hosting/tests/wire-exception-test.red"
				"tools/self_hosting/tests/wire-exception-reds-test.reds"
				"system/tests/source/units/exceptions-test.reds"
			]
			blockers []
		]

		 explicit-stack-and-subroutines [
			 status specified
			 owners [frontend rsir codegen]
			 wire [
				 RECORD/RSIR_SUBROUTINE RECORD/RSIR_SUBROUTINE_BLOCK
				 OPCODE/STACK_ALLOC OPCODE/STACK_FREE OPCODE/STACK_PUSH OPCODE/STACK_POP
				 OPCODE/PUSH_ALL OPCODE/POP_ALL OPCODE/SUBROUTINE_RETURN
				 OPCODE/STACK_TOP OPCODE/STACK_FRAME
				 STACK_ALLOCATION_MODE/ALL_VALUES OPERAND_KIND/SUBROUTINE
				 CALL_KIND/SUBROUTINE EFFECT_FLAG/STACK EFFECT_FLAG/OPAQUE
				 SUBROUTINE_ERROR/ALL_VALUES STACK_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-subroutine-test.red"
				"tools/self_hosting/tests/wire-subroutine-reds-test.reds"
				"tools/self_hosting/tests/wire-stack-test.red"
				"tools/self_hosting/tests/wire-stack-reds-test.reds"
				"system/tests/source/units/push-pop-test.reds"
				"system/tests/source/units/queue-test.reds"
				"system/tests/source/units/subroutine-test.reds"
			]
			blockers []
		 ]

		target-intrinsics [
			status specified
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_TARGET_FRAGMENT
				OPCODE/PORT_READ OPCODE/PORT_WRITE OPCODE/GET_PC OPCODE/TARGET_FRAGMENT
				OPCODE/CPU_REGISTER_READ OPCODE/CPU_REGISTER_WRITE
				TARGET_CLOBBER_CLASS/ALL_VALUES X64_REGISTER/ALL_VALUES
				OPERAND_KIND/TARGET_FRAGMENT CALL_KIND/SYSCALL
				EFFECT_FLAG/READ EFFECT_FLAG/WRITE EFFECT_FLAG/VOLATILE
				EFFECT_FLAG/MAY_TRAP EFFECT_FLAG/CONTROL EFFECT_FLAG/OPAQUE
				ALIAS_KIND/NONE ALIAS_KIND/UNIVERSAL TARGET_INTRINSIC_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-target-intrinsic-test.red"
				"tools/self_hosting/tests/wire-target-intrinsic-reds-test.reds"
				"system/tests/source/units/system-test.reds"
				"tools/self_hosting/tests/wire-call-abi-test.red"
				"tools/self_hosting/tests/wire-call-abi-reds-test.reds"
			]
			blockers []
		]

		gc-roots-and-keepalive [
			status blocked
			owners [frontend rsir codegen rscg]
			wire [OPCODE/KEEPALIVE]
			tests ["tools/self_hosting/fixtures/backend/node-handle-across-call.reds"]
			blockers [
				"freeze managed conversion rules and final bitmap treatment of hidden returns, callbacks, spills, and dynamic stack"
			]
		]

		rscg-object-layout [
			status specified
			owners [rscg adapter linker]
			wire [
				RECORD/RSCG_OUTPUT_SECTION RECORD/RSCG_SYMBOL RECORD/RSCG_FUNCTION
				OUTPUT_SECTION_CLASS/ALL_VALUES SYMBOL_BINDING/ALL_VALUES
				RSCG_OUTPUT_SECTION_FLAG/ALL_VALUES RSCG_SYMBOL_FLAG/ALL_VALUES
				RSCG_FUNCTION_FLAG/ALL_VALUES RSCG_OBJECT_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-rscg-object-test.red"
				"tools/self_hosting/tests/wire-rscg-object-reds-test.reds"
				"system/tests/source/units/x64-image-info-smoke.reds"
			]
			blockers []
		]

		rscg-relocations-and-linker [
			status specified
			owners [rscg adapter linker]
			wire [
				RECORD/RSCG_RELOCATION RELOCATION_KIND/ALL_VALUES
				RSCG_RELOCATION_FLAG/ALL_VALUES RSCG_RELOCATION_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-rscg-relocation-test.red"
				"tools/self_hosting/tests/wire-rscg-relocation-reds-test.reds"
				"tools/self_hosting/fixtures/backend/global-memory.reds"
				"tools/self_hosting/fixtures/backend/nested-relocation-order.reds"
			]
			blockers []
		]

		rscg-debug-gc-unwind [
			status specified
			owners [rscg adapter linker]
			wire [
				RECORD/RSCG_DEBUG_LINE RECORD/RSCG_DEBUG_PARAMETER
				RECORD/RSCG_GC_FRAME RECORD/RSCG_UNWIND_FUNCTION
				RSCG_DEBUG_PARAMETER_FLAG/ALL_VALUES
				RSCG_GC_FRAME_FLAG/ALL_VALUES
				RSCG_UNWIND_FUNCTION_FLAG/ALL_VALUES
				RSCG_METADATA_ERROR/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-rscg-metadata-test.red"
				"tools/self_hosting/tests/wire-rscg-metadata-reds-test.reds"
				"system/tests/source/compiler/output-test.r"
				"tools/self_hosting/fixtures/backend/unwind-through-o2.reds"
			]
			blockers []
		]
	]
]
