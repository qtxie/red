Red/System [
	Title: "Hybrid compiler routine bridge"
	File:  %codegen-bridge.reds
]

#include %x64-codegen.reds
#include %arm64-codegen.reds

codegen-bridge: context [
	SUCCESS:         0
	INVALID_ARGUMENTS: 1
	INVALID_IR:      2
	UNSUPPORTED:     3
	OUTPUT_FULL:     4
	INTERNAL_ERROR:  5
	RESOURCE_LIMIT:  6
	OUT_OF_MEMORY:   7
	ARCH_X64:        1
	ARCH_ARM64:      2
	ABI_WIN64:        1
	ABI_SYSV:         2
	ABI_APPLE_AARCH64: 3
	ABI_AAPCS64:      4

	reject-arguments: func [site [integer!] name [c-string!] return: [integer!]][
		codegen-diag/fail codegen-diag/INVALID_ARGUMENTS codegen-diag/FILE_BRIDGE site name
		INVALID_ARGUMENTS
	]

	run: func [
		ir artifact [red-binary!]
		architecture [integer!]
		abi [integer!]
		opt-level [integer!]
		return: [integer!]
		/local series [series!]
			ir-data output [byte-ptr!]
			ir-size capacity written [integer!]
	][
		codegen-diag/reset
		if any [null? ir null? artifact ir/node = artifact/node][
			return reject-arguments 1 "run/input-output-alias"
		]
		if any [artifact/head <> 0 (binary/rs-length? artifact) <> 0][
			return reject-arguments 2 "run/output-not-empty"
		]
		series: GET_BUFFER(artifact)
		if null? series [return reject-arguments 3 "run/output-series"]
		capacity: series/size - artifact/head
		if capacity < 0 [return reject-arguments 4 "run/output-capacity"]
		ir-data: binary/rs-head ir
		ir-size: binary/rs-length? ir
		output: (as byte-ptr! series/offset) + artifact/head
		written: case [
			architecture = ARCH_X64 [
				x64-codegen/generate ir-data ir-size output capacity abi opt-level
			]
			architecture = ARCH_ARM64 [
				arm64-codegen/generate ir-data ir-size output capacity abi opt-level
			]
			true [return reject-arguments 5 "run/architecture"]
		]
		case [
			written > 0 [
				series/tail: as cell! (output + written)
				SUCCESS
			]
			written = x64-codegen/INVALID_IR [INVALID_IR]
			written = x64-codegen/UNSUPPORTED [UNSUPPORTED]
			written = x64-codegen/OUTPUT_FULL [OUTPUT_FULL]
			written = x64-codegen/INTERNAL_ERROR [INTERNAL_ERROR]
			written = x64-codegen/RESOURCE_LIMIT [RESOURCE_LIMIT]
			written = x64-codegen/OUT_OF_MEMORY [OUT_OF_MEMORY]
			true [
				codegen-diag/propagate written codegen-diag/FILE_BRIDGE 6 "run/unexpected-status"
				INTERNAL_ERROR
			]
		]
	]
]
