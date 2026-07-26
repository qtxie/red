Red [
	Title:   "Red/System compiler"
	Author:  "Nenad Rakocevic"
	File:    %compiler.red
	Tabs:    4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#include %compiler-host.red
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
#include %formats/Mach-O.red
#include %formats/Mach-O-ARM64.red
#include %formats/PE.red
#include %formats/ELF.red

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

#include %linker.red
#include %linker-static.red
external-linker: static-link
#include %emitter.red
#include %utils/libRedRT.red
#include %compiler-core.red
