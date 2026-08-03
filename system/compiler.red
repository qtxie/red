Red [
	Title:   "Red/System compiler"
	Author:  "Nenad Rakocevic"
	File:    %compiler.red
	Tabs:    4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#include %compiler-host.red
#include %../compiler/host-compat.red
#include %../compiler/int-to-bin.red
#include %../compiler/sha256.red
#include %../compiler/ieee-754.red
#either any [
	config/show = 'ARM-ELF-only
	config/show = 'ARM64-ELF-only
	config/show = 'X86-64-only
][][
	#include %formats/Mach-O-sign.red
]
#include %../compiler/virtual-struct.red
#include %../compiler/paths.red
#include %../compiler/unicode.red
#include %../compiler/target-registry.red
#include %../compiler/system-job.red
#include %../compiler/lexer.red
#include %../compiler/system-source.red
#include %../compiler/system-loader.red
#include %../compiler/embedded-assets.red
#either config/show = 'X86-64-only [
	#include %formats/PE.red
][
#either config/show = 'ARM64-Darwin-only [
	#include %formats/Mach-O-ARM64.red
][
#either any [
	config/show = 'ARM-ELF-only
	config/show = 'ARM64-ELF-only
][
	#include %formats/ELF.red
][
	#include %formats/Mach-O.red
	#include %formats/Mach-O-ARM64.red
	#include %formats/PE.red
	#include %formats/ELF.red
]
]
]

#either config/show = 'X86-64-only [
system-file-extension: func [job [object!]][
	if job/format <> 'PE [
		system-dialect/compiler/throw-error [
			"X86-64 compiler only supports PE output, got:" job/format
		]
	]
	select system-format-PE/defs/extensions job/type
]

emit-system-file: func [job [object!]][
	if job/format <> 'PE [
		system-dialect/compiler/throw-error [
			"X86-64 compiler only supports PE output, got:" job/format
		]
	]
	system-format-PE/build job
]

finish-system-file: func [job [object!] file [file!]][
system-format-PE/on-file-written job file
]
][
#either config/show = 'ARM64-Darwin-only [
system-file-extension: func [job [object!]][
	if job/format <> 'Mach-O [
		system-dialect/compiler/throw-error [
			"Darwin ARM64 compiler only supports Mach-O output, got:" job/format
		]
	]
	select system-format-MachO-ARM64/defs/extensions job/type
]

emit-system-file: func [job [object!]][
	if any [job/format <> 'Mach-O job/target <> 'ARM64][
		system-dialect/compiler/throw-error [
			"Darwin ARM64 compiler received target:" job/format job/target
		]
	]
	system-format-MachO-ARM64/build job
]

finish-system-file: func [job [object!] file [file!]][none]
][
#either any [
	config/show = 'ARM-ELF-only
	config/show = 'ARM64-ELF-only
][
system-file-extension: func [job [object!]][
	if job/format <> 'ELF [
		system-dialect/compiler/throw-error [
			"ARM debug compiler only supports ELF output, got:" job/format
		]
	]
	select system-format-ELF/defs/extensions job/type
]

emit-system-file: func [job [object!]][
	if job/format <> 'ELF [
		system-dialect/compiler/throw-error [
			"ARM debug compiler only supports ELF output, got:" job/format
		]
	]
	system-format-ELF/build job
]

finish-system-file: func [job [object!] file [file!]][none]
][
system-file-extension: func [job [object!]][
	switch/default job/format [
		PE [select system-format-PE/defs/extensions job/type]
		ELF [select system-format-ELF/defs/extensions job/type]
		Mach-O [select system-format-MachO/defs/extensions job/type]
	][
		system-dialect/compiler/throw-error ["unsupported output format:" job/format]
	]
]

emit-system-file: func [job [object!]][
	switch/default job/format [
		PE [system-format-PE/build job]
		ELF [system-format-ELF/build job]
		Mach-O [
			either job/target = 'ARM64 [
				system-format-MachO-ARM64/build job
			][system-format-MachO/build job]
		]
	][
		system-dialect/compiler/throw-error ["unsupported output format:" job/format]
	]
]

finish-system-file: func [job [object!] file [file!]][
	if job/format = 'PE [system-format-PE/on-file-written job file]
]
]
]
]

#include %linker.red
#either any [
	config/show = 'ARM-ELF-only
	config/show = 'ARM64-ELF-only
][
; Dynamic ELF import hooks. Static archives, object readers, and their export
; databases are deliberately absent from the focused ARM debug compiler.
external-linker: context [
	crt-entry: cpp-entry: etls-off: exidx-range: none
	etls-memsz: etls-filesz: 0
	etls-align: 1

	resolve-libname: func [name [string!] format [word!] static? [logic!]][
		if any [static? format <> 'ELF][
			system-dialect/compiler/throw-error
				"ARM debug compiler only supports dynamic ELF imports"
		]
		rejoin [name ".so"]
	]

	framework?: func [name [string!]][false]
	library?: func [name [string!]][
		to logic! find [%.obj %.lib %.o %.a] (suffix? to file! lowercase copy name)
	]
	register: func [job [object!] lib [string!] script cc [word!]][
		system-dialect/compiler/throw-error
			["static linking is unavailable in the ARM debug compiler:" lib]
	]
	merge: func [job [object!]][none]
	apply-relocs: func [
		job [object!] code-base [integer!] data-base [integer!] image-base [integer!]
	][none]
]
][
	#include %linker-static.red
	external-linker: static-link
]
#include %emitter.red
#include %utils/libRedRT.red
#include %compiler-core.red
