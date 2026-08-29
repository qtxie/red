Red [
	Title:   "Windows bootstrap compiler common frontend/linker closure"
	File:    %compiler-windows-common.red
	Tabs:    4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#include %../compiler/phase-timer.red
#include %../compiler/resource-store.red
#include %compiler-host.red
#include %../compiler/host-compat.red
#include %../compiler/int-to-bin.red
#include %../compiler/sha256.red
#include %../compiler/ieee-754.red
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

system-file-extension: func [job [object!]][
	select system-format-PE/defs/extensions job/type
]

emit-system-file: func [job [object!]][
	if job/format <> 'PE [
		system-dialect/compiler/throw-error [
			"Windows bootstrap compiler only supports PE output, got:" job/format
		]
	]
	system-format-PE/build job
]

finish-system-file: func [job [object!] file [file!]][
	system-format-PE/on-file-written job file
]

#include %linker.red

; Dynamic PE import hooks. No static archives, object readers, CRT objects,
; or external relocation machinery are part of the bootstrap compiler.
external-linker: context [
	crt-entry: crodata-base: cafter-base: none

	resolve-libname: func [name [string!] format [word!] static? [logic!]][
		if any [static? format <> 'PE][
			system-dialect/compiler/throw-error
				"Windows bootstrap compiler only supports dynamic PE imports"
		]
		rejoin [name ".dll"]
	]

	framework?: func [name [string!]][false]
	library?: func [name [string!]][false]
	register: func [job [object!] lib [string!] script cc [word!]][
		system-dialect/compiler/throw-error
			["static linking is unavailable in the Windows bootstrap compiler:" lib]
	]
	merge: func [job [object!]][none]
	prepare-pe-tls: func [job [object!] data-rva [integer!] image-base [integer!]][none]
	pe-tls-rva?: func [data-rva [integer!] crodata-rva [integer!]][0]
	pe-tls-size?: func [][0]
	apply-relocs: func [
		job [object!] code-base [integer!] data-base [integer!] image-base [integer!]
	][none]
]
