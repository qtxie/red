Red/System [
	Title: "Hybrid compiler routine bridge"
	File:  %codegen-bridge.reds
]

#include %x64-codegen.reds

codegen-bridge: context [
	SUCCESS:         0
	INVALID_ARGUMENTS: 1
	INVALID_IR:      2
	UNSUPPORTED:     3
	OUTPUT_FULL:     4

	run: func [
		ir artifact [red-binary!]
		opt-level [integer!]
		return: [integer!]
		/local series [series!]
			ir-data output [byte-ptr!]
			ir-size capacity written [integer!]
	][
		if any [null? ir null? artifact ir/node = artifact/node][
			return INVALID_ARGUMENTS
		]
		if any [artifact/head <> 0 (binary/rs-length? artifact) <> 0][
			return INVALID_ARGUMENTS
		]
		series: GET_BUFFER(artifact)
		if null? series [return INVALID_ARGUMENTS]
		capacity: series/size - artifact/head
		if capacity < 0 [return INVALID_ARGUMENTS]
		ir-data: binary/rs-head ir
		ir-size: binary/rs-length? ir
		output: (as byte-ptr! series/offset) + artifact/head
		written: x64-codegen/generate ir-data ir-size output capacity opt-level
		case [
			written > 0 [
				series/tail: as cell! (output + written)
				SUCCESS
			]
			written = x64-codegen/INVALID_IR [INVALID_IR]
			written = x64-codegen/UNSUPPORTED [UNSUPPORTED]
			written = x64-codegen/OUTPUT_FULL [OUTPUT_FULL]
			true [UNSUPPORTED]
		]
	]
]
