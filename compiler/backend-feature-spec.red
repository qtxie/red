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
			status blocked
			owners [frontend codegen]
			wire [
				RECORD/RSCF_CONFIG
				TARGET/ALL_VALUES ABI/ALL_VALUES ENDIAN/ALL_VALUES
				CONFIG_FLAG/ALL_VALUES CODE_MODEL/ALL_VALUES
				RELOCATION_MODEL/ALL_VALUES DEBUG_FORMAT/ALL_VALUES
			]
			tests [
				"tools/self_hosting/tests/wire-container-test.red"
				"system/tests/source/units/size-x64-test.reds"
			]
			blockers [
				"add stable optimization-level and CPU-baseline enums"
				"freeze target/ABI/endian/pointer compatibility and config flag consistency"
				"define zero/nonzero limits for output and diagnostic arenas"
			]
		]

		diagnostics [
			status blocked
			owners [codegen frontend]
			wire [
				RECORD/RSDG_DIAGNOSTIC
				STATUS/ALL_VALUES DIAGNOSTIC_SEVERITY/ALL_VALUES
				DIAGNOSTIC_PHASE/ALL_VALUES
			]
			tests ["tools/self_hosting/tests/wire-container-test.red"]
			blockers [
				"define diagnostic flag mask and which file/function/instruction IDs may be zero"
			]
		]

		strings-files-source [
			status blocked
			owners [frontend rsir rscg]
			wire [RECORD/STRING RECORD/FILE RECORD/SOURCE_LOCATION]
			tests ["system/tests/source/compiler/output-test.r"]
			blockers [
				"define checksum-kind IDs, UTF-8 validity, deduplication, and empty-string rules"
			]
		]

		target-data-layout [
			status blocked
			owners [frontend codegen]
			wire [RECORD/DATA_LAYOUT]
			tests ["system/tests/source/units/size-x64-test.reds"]
			blockers [
				"freeze the Windows x64 layout tuple and its equality rules with the header"
			]
		]

		types-and-aggregate-layout [
			status blocked
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_TYPE RECORD/RSIR_FIELD
				TYPE_KIND/ALL_VALUES TYPE_FLAG/ALL_VALUES GC_KIND/ALL_VALUES
			]
			tests [
				"system/tests/source/units/alias-test.reds"
				"system/tests/source/units/array-test.reds"
				"system/tests/source/units/enum-test.reds"
				"system/tests/source/units/protect-test.reds"
				"system/tests/source/units/struct-x64-test.reds"
				"system/tests/source/units/union-test.reds"
			]
			blockers [
				"define field flags and exact kind-specific zero/required fields"
				"freeze packed, union, opaque, nominal, array, and managed-handle layout rules"
			]
		]

		module-lifecycle [
			status blocked
			owners [frontend rsir rscg linker]
			wire [RECORD/RSIR_MODULE]
			tests ["system/tests/source/units/x64-image-info-smoke.reds"]
			blockers [
				"define module flags and lifecycle requirements for exe, DLL, runtime, user, and glue modules"
			]
		]

		constants-globals-initializers [
			status blocked
			owners [frontend rsir codegen rscg]
			wire [
				RECORD/RSIR_CONSTANT RECORD/RSIR_CONSTANT_PART RECORD/RSIR_GLOBAL
				OPCODE/CONSTANT OPCODE/COPY
			]
			tests [
				"system/tests/source/units/byte-test.reds"
				"system/tests/source/units/fixed-int-test.reds"
				"system/tests/source/units/float-test.reds"
				"system/tests/source/units/float32-test.reds"
				"system/tests/source/units/int64-test.reds"
			]
			blockers [
				"add constant-kind and constant-part-kind enums"
				"define global, constant, and part flags plus symbolic addend encoding"
				"define cycle, overlap, padding, and exact-type initializer rules"
			]
		]

		symbols-imports-exports [
			status blocked
			owners [frontend rsir rscg adapter linker]
			wire [
				RECORD/RSIR_SYMBOL RECORD/IMPORT RECORD/EXPORT
				SYMBOL_KIND/ALL_VALUES LINKAGE/ALL_VALUES VISIBILITY/ALL_VALUES
			]
			tests [
				"system/tests/source/units/lib-test.reds"
				"system/tests/source/units/namespace-test.reds"
				"system/tests/source/units/use-test.reds"
			]
			blockers [
				"define symbol/import/export flags, ownership, duplicate-name, and ordinal rules"
				"freeze function versus variable import representation and required runtime roles"
			]
		]

		functions-signatures-locals [
			status blocked
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_SIGNATURE RECORD/RSIR_PARAMETER
				RECORD/RSIR_FUNCTION RECORD/RSIR_LOCAL
				CALLING_CONVENTION/ALL_VALUES FUNCTION_FLAG/ALL_VALUES
				LOCAL_KIND/ALL_VALUES
			]
			tests [
				"system/tests/source/units/function-test.reds"
				"system/tests/source/units/infix-test.reds"
				"system/tests/source/units/return-test.reds"
			]
			blockers [
				"define signature, parameter, function, and local flag masks"
				"freeze hidden-return, callback, variadic, typed, and custom logical arity rules"
			]
		]

		scalar-values-and-operations [
			status blocked
			owners [rsir codegen]
			wire [
				RECORD/RSIR_VALUE RECORD/RSIR_INSTRUCTION RECORD/RSIR_OPERAND
				VALUE_DEFINITION/ALL_VALUES OPERAND_KIND/ALL_VALUES
				OPCODE/CONVERT OPCODE/BITCAST
				OPCODE/ADD OPCODE/SUBTRACT OPCODE/MULTIPLY
				OPCODE/DIVIDE OPCODE/REMAINDER OPCODE/MODULO
				OPCODE/NEGATE OPCODE/BIT_NOT OPCODE/LOGIC_NOT
				OPCODE/SHIFT_LEFT OPCODE/SHIFT_RIGHT OPCODE/SHIFT_RIGHT_LOGICAL
				OPCODE/BIT_AND OPCODE/BIT_OR OPCODE/BIT_XOR OPCODE/COMPARE
				COMPARE_KIND/ALL_VALUES
			]
			tests [
				"system/tests/source/units/cast-test.reds"
				"system/tests/source/units/integer-test.reds"
				"system/tests/source/units/logic-test.reds"
				"system/tests/source/units/math-mixed-test.reds"
				"system/tests/source/units/modulo-test.reds"
				"system/tests/source/units/not-test.reds"
				"system/tests/source/units/overflow-test.reds"
			]
			blockers [
				"define instruction, value, and operand flag masks and every subopcode domain"
				"freeze overflow, signedness, shift-count, float, and conversion type tables"
			]
		]

		memory-and-aggregate-operations [
			status blocked
			owners [rsir codegen]
			wire [
				OPCODE/LOAD_LOCAL OPCODE/STORE_LOCAL OPCODE/ADDRESS_LOCAL
				OPCODE/LOAD_GLOBAL OPCODE/STORE_GLOBAL OPCODE/ADDRESS_GLOBAL
				OPCODE/LOAD_INDIRECT OPCODE/STORE_INDIRECT OPCODE/ADDRESS_FIELD
				OPCODE/AGGREGATE_BUILD OPCODE/AGGREGATE_COPY
				EFFECT_FLAG/READ EFFECT_FLAG/WRITE EFFECT_FLAG/VOLATILE
				ALIAS_KIND/ALL_VALUES
			]
			tests [
				"system/tests/source/units/c-string-test.reds"
				"system/tests/source/units/float-pointer-test.reds"
				"system/tests/source/units/get-pointer-test.reds"
				"system/tests/source/units/length-test.reds"
				"system/tests/source/units/null-test.reds"
				"system/tests/source/units/pointer-test.reds"
				"system/tests/source/units/queue-test.reds"
			]
			blockers [
				"freeze address-path, alias identity, volatility, union-tag, and aggregate-copy rules"
			]
		]

		control-flow [
			status blocked
			owners [rsir codegen]
			wire [
				RECORD/RSIR_BLOCK RECORD/RSIR_EDGE EDGE_KIND/ALL_VALUES
				OPCODE/BRANCH OPCODE/JUMP OPCODE/SWITCH
				OPCODE/RETURN OPCODE/UNREACHABLE EFFECT_FLAG/CONTROL
			]
			tests [
				"system/tests/source/units/case-test.reds"
				"system/tests/source/units/conditional-test.reds"
				"system/tests/source/units/exit-test.reds"
				"system/tests/source/units/return-test.reds"
				"system/tests/source/units/switch-test.reds"
			]
			blockers [
				"define block/edge flags and the exact terminator-to-edge/type table"
				"freeze dominance, unreachable-continuation, and merge-slot ownership rules"
			]
		]

		calls-and-abi [
			status blocked
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_CALL OPCODE/CALL
				CALL_KIND/DIRECT CALL_KIND/INDIRECT CALL_KIND/IMPORT
				CALL_KIND/SYSCALL CALL_KIND/CUSTOM
				EFFECT_FLAG/CALL EFFECT_FLAG/MAY_TRAP EFFECT_FLAG/SAFEPOINT
			]
			tests [
				"system/tests/source/units/function-test.reds"
				"system/tests/source/units/lib-test.reds"
				"system/tests/source/units/vararg-test.reds"
				"tools/self_hosting/fixtures/backend/custom-call.reds"
			]
			blockers [
				"define call flags, callee-reference domains, and logical argument slices"
				"freeze all Win64 scalar/aggregate/hidden-return/callback/variadic/typed/custom cases"
			]
		]

		atomics [
			status blocked
			owners [rsir codegen]
			wire [
				OPCODE/ATOMIC_LOAD OPCODE/ATOMIC_STORE OPCODE/ATOMIC_RMW
				OPCODE/ATOMIC_CAS OPCODE/ATOMIC_FENCE
				ATOMIC_ORDER/ALL_VALUES EFFECT_FLAG/ATOMIC
			]
			tests ["system/tests/source/units/atomic-test.reds"]
			blockers [
				"add atomic-RMW operation IDs and freeze legal order/type/result combinations"
			]
		]

		exceptions [
			status blocked
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_EXCEPTION_REGION RECORD/RSIR_EXCEPTION_BLOCK
				OPCODE/THROW OPCODE/CATCH_ENTER OPCODE/CATCH_LEAVE
				EFFECT_FLAG/THROW
			]
			tests ["system/tests/source/units/exceptions-test.reds"]
			blockers [
				"add exception-region kind/flag IDs and freeze handler-edge and stack-state semantics"
			]
		]

		explicit-stack-and-subroutines [
			status blocked
			owners [frontend rsir codegen]
			wire [
				OPCODE/STACK_ALLOC OPCODE/STACK_FREE OPCODE/STACK_PUSH OPCODE/STACK_POP
				OPCODE/PUSH_ALL OPCODE/POP_ALL CALL_KIND/SUBROUTINE EFFECT_FLAG/STACK
			]
			tests [
				"system/tests/source/units/push-pop-test.reds"
				"system/tests/source/units/queue-test.reds"
				"system/tests/source/units/subroutine-test.reds"
			]
			blockers [
				"freeze dynamic stack-state joins, alignment regions, and ordinary-exit balance"
				"resolve subroutine definition ownership, address-taking, recursion, and exception interaction"
			]
		]

		target-intrinsics [
			status blocked
			owners [frontend rsir codegen]
			wire [
				RECORD/RSIR_TARGET_FRAGMENT
				OPCODE/PORT_READ OPCODE/PORT_WRITE OPCODE/GET_PC OPCODE/TARGET_FRAGMENT
				EFFECT_FLAG/OPAQUE
			]
			tests ["system/tests/source/units/system-test.reds"]
			blockers [
				"add target-fragment clobber IDs and freeze conservative effects and return convention"
				"define legal port widths, syscall numbers, and target-specific intrinsic failures"
			]
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
			status blocked
			owners [rscg adapter linker]
			wire [
				RECORD/RSCG_OUTPUT_SECTION RECORD/RSCG_SYMBOL RECORD/RSCG_FUNCTION
				OUTPUT_SECTION_CLASS/ALL_VALUES SYMBOL_BINDING/ALL_VALUES
			]
			tests ["system/tests/source/units/x64-image-info-smoke.reds"]
			blockers [
				"define output-section, RSCG symbol, and function flag masks plus required named roles"
				"freeze BSS, alignment, extent, duplicate symbol, and absolute/unresolved rules"
			]
		]

		rscg-relocations-and-linker [
			status blocked
			owners [rscg adapter linker]
			wire [RECORD/RSCG_RELOCATION RELOCATION_KIND/ALL_VALUES]
			tests [
				"tools/self_hosting/fixtures/backend/global-memory.reds"
				"tools/self_hosting/fixtures/backend/nested-relocation-order.reds"
			]
			blockers [
				"audit every PE linker fixup and freeze width, addend, range, import-variable, data, and rodata mappings"
			]
		]

		rscg-debug-gc-unwind [
			status blocked
			owners [rscg adapter linker]
			wire [
				RECORD/RSCG_DEBUG_LINE RECORD/RSCG_DEBUG_PARAMETER
				RECORD/RSCG_GC_FRAME RECORD/RSCG_UNWIND_FUNCTION
			]
			tests [
				"system/tests/source/compiler/output-test.r"
				"tools/self_hosting/fixtures/backend/unwind-through-o2.reds"
			]
			blockers [
				"define debug, GC-frame, and unwind flags and exact owned-range/bounds rules"
				"freeze current Windows x64 unwind equivalence and merged debug offset behavior"
			]
		]
	]
]
