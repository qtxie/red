Red [
	Title:   "Hybrid compiler common frontend and linker closure"
	File:    %compiler-hybrid-common.red
	Tabs:    4
	License: "BSD-3 - https://github.com/red/red/blob/master/LICENSE"
]

#include %../compiler/phase-timer.red
#include %../compiler/resource-store.red
#include %../compiler/toolchain-support.red
#include %compiler-host.red
#include %../compiler/host-compat.red
#include %../compiler/int-to-bin.red
#include %../compiler/sha256.red
#include %../compiler/ieee-754.red
#include %formats/Mach-O-sign.red
#include %../compiler/virtual-struct.red
#include %../compiler/paths.red
#include %../compiler/unicode.red
#include %../compiler/target-registry.red
#include %../compiler/system-job.red
#include %../compiler/lexer.red
#include %../compiler/system-source.red
#include %../compiler/system-loader.red
#include %../compiler/embedded-assets.red
#include %formats/PE.red
#include %formats/Mach-O-ARM64.red

#if config/OS = 'macOS [
	#system-global [
		#import [
			LIBC-file cdecl [
			hybrid-chmod: "chmod" [
					path [c-string!]
					mode [integer!]
					return: [integer!]
				]
			]
		]
	]
]

make-system-file-executable: #either config/OS = 'macOS [
	routine [path [file!] return: [logic!] /local value [red-file!]][
		value: as red-file! stack/arguments
		zero? hybrid-chmod file/to-OS-path value 493
	]
][
	func [path [file!] return: [logic!]][true]
]

system-file-extension: func [job [object!]][
	case [
		job/format = 'PE [select system-format-PE/defs/extensions job/type]
		job/format = 'Mach-O [
			if job/target <> 'ARM64 [
				system-dialect/compiler/throw-error
					["hybrid compiler received unsupported Mach-O target:" job/target]
			]
			select system-format-MachO-ARM64/defs/extensions job/type
		]
		true [
			system-dialect/compiler/throw-error
				["hybrid compiler received unsupported output format:" job/format]
		]
	]
]

emit-system-file: func [job [object!]][
	case [
		job/format = 'PE [
			if job/target <> 'X86-64 [
				system-dialect/compiler/throw-error
					["hybrid compiler received unsupported PE target:" job/target]
			]
			system-format-PE/build job
		]
		job/format = 'Mach-O [
			if job/target <> 'ARM64 [
				system-dialect/compiler/throw-error
					["hybrid compiler received unsupported Mach-O target:" job/target]
			]
			system-format-MachO-ARM64/build job
		]
		true [
			system-dialect/compiler/throw-error
				["hybrid compiler received unsupported output format:" job/format]
		]
	]
]

finish-system-file: func [job [object!] file [file!]][
	case [
		job/format = 'PE [system-format-PE/on-file-written job file]
		all [job/format = 'Mach-O job/type = 'exe][
			unless make-system-file-executable file [
				system-dialect/compiler/throw-error
					["could not mark generated Mach-O executable:" file]
			]
		]
		true [none]
	]
]

#include %linker.red

; Hybrid bootstrap builds consume dynamic imports already present in the
; compact image. Static object discovery and archive relocation stay outside
; this focused closure.
external-linker: context [
	crt-entry: crodata-base: cafter-base: none

	resolve-libname: func [name [string!] format [word!] static? [logic!]][
		if static? [
			system-dialect/compiler/throw-error
				"static linking is unavailable in the hybrid compiler"
		]
		switch/default format [
			PE [rejoin [name ".dll"]]
			Mach-O [name]
		][
			system-dialect/compiler/throw-error
				["unsupported hybrid import format:" format]
		]
	]

	framework?: func [name [string!]][false]
	library?: func [name [string!]][false]
	register: func [job [object!] lib [string!] script cc [word!]][
		system-dialect/compiler/throw-error
			["static linking is unavailable in the hybrid compiler:" lib]
	]
	merge: func [job [object!]][none]
	prepare-pe-tls: func [job [object!] data-rva [integer!] image-base [integer!]][none]
	pe-tls-rva?: func [data-rva [integer!] crodata-rva [integer!]][0]
	pe-tls-size?: func [][0]
	apply-relocs: func [
		job [object!] code-base [integer!] data-base [integer!] image-base [integer!]
	][none]
]
