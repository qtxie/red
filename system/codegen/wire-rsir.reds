Red/System [
	Title: "Hybrid compiler aggregate RSIR semantic verifier"
	File:  %wire-rsir.reds
]

#include %wire-target-intrinsic.reds
#include %wire-atomic.reds
#include %wire-memory-aggregate.reds

wire-rsir-result!: alias struct! [
	error                  [integer!]
	target-intrinsic-error [integer!]
	atomic-error           [integer!]
	memory-aggregate-error [integer!]
	error-offset           [integer!]
	error-section          [integer!]
]

wire-rsir-reader: context [
	ERROR_SUCCESS:                  0
	ERROR_INVALID_ARGUMENTS:        1
	ERROR_INVALID_TARGET_INTRINSIC: 2
	ERROR_INVALID_ATOMIC:           3
	ERROR_INVALID_MEMORY_AGGREGATE: 4

	set-error: func [
		result [wire-rsir-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		workspace [byte-ptr!]
		workspace-size [integer!]
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
		/local target-result [wire-target-intrinsic-result!]
			atomic-result [wire-atomic-result!]
			memory-result [wire-memory-aggregate-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			verified-functions [wire-function-signature!]
			verified-modules [wire-module-lifecycle!]
			verified-symbols [wire-symbol-linkage!]
			verified-constants [wire-constant-initializer!]
			verified-scalar [wire-scalar-operation!]
			verified-control [wire-control-flow!]
			verified-calls [wire-call-abi!]
			verified-subroutines [wire-subroutine!]
			verified-exceptions [wire-exception!]
			verified-target [wire-target-intrinsic!]
			status [integer!]
	][
		if null? result [return ERROR_INVALID_ARGUMENTS]
		result/error: ERROR_SUCCESS
		result/target-intrinsic-error: WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
		result/atomic-error: WIRE_ATOMIC_ERROR_SUCCESS
		result/memory-aggregate-error: WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0
		if any [
			size < 0
			workspace-size < 0
			null? data
			null? workspace
			null? strings
			null? files
			null? layout
			null? types
			null? functions
			null? modules
			null? symbols
			null? constants
			null? scalar
			null? control
			null? calls
			null? subroutines
			null? exceptions
			null? target-view
		][return set-error result ERROR_INVALID_ARGUMENTS 0 0]

		target-result: declare wire-target-intrinsic-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		verified-functions: declare wire-function-signature!
		verified-modules: declare wire-module-lifecycle!
		verified-symbols: declare wire-symbol-linkage!
		verified-constants: declare wire-constant-initializer!
		verified-scalar: declare wire-scalar-operation!
		verified-control: declare wire-control-flow!
		verified-calls: declare wire-call-abi!
		verified-subroutines: declare wire-subroutine!
		verified-exceptions: declare wire-exception!
		verified-target: declare wire-target-intrinsic!
		status: wire-target-intrinsic-reader/verify data size workspace workspace-size
			target-result verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-scalar verified-control verified-calls verified-subroutines
			verified-exceptions verified-target
		result/target-intrinsic-error: status
		if status <> WIRE_TARGET_INTRINSIC_ERROR_SUCCESS [
			return set-error result ERROR_INVALID_TARGET_INTRINSIC
				target-result/error-offset target-result/error-section
		]

		atomic-result: declare wire-atomic-result!
		status: wire-atomic-reader/verify-view atomic-result verified-types
			verified-scalar
		result/atomic-error: status
		if status <> WIRE_ATOMIC_ERROR_SUCCESS [
			return set-error result ERROR_INVALID_ATOMIC
				atomic-result/error-offset atomic-result/error-section
		]

		memory-result: declare wire-memory-aggregate-result!
		status: wire-memory-aggregate-reader/verify-view memory-result verified-types
			verified-functions verified-symbols verified-scalar
		result/memory-aggregate-error: status
		if status <> WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS [
			return set-error result ERROR_INVALID_MEMORY_AGGREGATE
				memory-result/error-offset memory-result/error-section
		]

		wire-symbol-linkage-reader/copy-strings strings verified-strings
		wire-symbol-linkage-reader/copy-files files verified-files
		wire-symbol-linkage-reader/copy-layout layout verified-layout
		wire-symbol-linkage-reader/copy-types types verified-types
		wire-symbol-linkage-reader/copy-functions functions verified-functions
		wire-symbol-linkage-reader/copy-modules modules verified-modules
		wire-scalar-operation-reader/copy-symbols symbols verified-symbols
		wire-scalar-operation-reader/copy-constants constants verified-constants
		wire-scalar-operation-reader/copy-view scalar verified-scalar
		wire-control-flow-reader/copy-view control verified-control
		wire-call-abi-reader/copy-view calls verified-calls
		wire-subroutine-reader/copy-view subroutines verified-subroutines
		wire-exception-reader/copy-view exceptions verified-exceptions
		wire-target-intrinsic-reader/copy-view target-view verified-target
		ERROR_SUCCESS
	]
]
