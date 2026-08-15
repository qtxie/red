Red [
	Title: "Direct hybrid compiler source-closure audit"
]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

inventory: context [
	paths: none
	words: none
	get-words: none

	add: func [table [map!] key [string!] /local count][
		count: select table key
		put table key either none? count [1][count + 1]
	]

	walk: func [value /local root][
		case [
			any-path? :value [
				add paths form to path! :value
				root: first :value
				if any-word? :root [add words form to word! :root]
			]
			get-word? :value [add get-words form to word! :value]
			word? :value [add words form value]
			any-block? :value [foreach item value [walk :item]]
			true []
		]
	]

	scan: func [source [block!]][
		paths: make map! 256
		words: make map! 256
		get-words: make map! 64
		walk source
		reduce [paths words get-words]
	]
]

count-of: func [table [map!] key [string!] /local count][
	count: select table key
	any [count 0]
]

expect: func [
	table [map!]
	key [string!]
	expected [integer!]
	owner [string!]
	/local actual
][
	actual: count-of table key
	unless actual = expected [
		fail [owner " reference " key " expected=" expected " actual=" actual]
	]
]

core: inventory/scan load %../../../system/compiler-rsir-core.red
expect core/2 "codegen-module" 1 "compiler-rsir-core"
expect core/1 "linker/load-codegen" 1 "compiler-rsir-core"
expect core/1 "linker/build" 1 "compiler-rsir-core"
expect core/1 "compiler-rscg-linker-adapter/adapt" 0 "compiler-rsir-core"
expect core/1 "rs-o2-ir/verify-current" 0 "compiler-rsir-core"
expect core/2 "finish-code" 1 "compiler-rsir-core"
expect core/2 "schema" 0 "compiler-rsir-core"
expect core/2 "adapter" 0 "compiler-rsir-core"

package: inventory/scan load %../../../system/compiler-windows-hybrid-bootstrap.red
expect package/2 "codegen-module" 0 "hybrid-package"
expect package/1 "compiler-rscg-linker-adapter/adapt" 0 "hybrid-package"
expect package/2 "emitter" 0 "hybrid-package"
expect package/2 "rs-o2-ir" 0 "hybrid-package"
expect package/2 "linker" 0 "hybrid-package"
expect package/2 "verify-current" 0 "hybrid-package"
unless find read %../../../system/compiler-windows-hybrid-bootstrap.red
	"#include %compiler-windows-hybrid-core.red"
[
	fail "hybrid package does not include its direct core"
]

native-bridge-text: read %../../../system/codegen/codegen-bridge.reds
if find native-bridge-text "binary/rs-append" [
	fail "native codegen bridge depends on non-exported binary/rs-append"
]
unless all [
	find native-bridge-text "GET_BUFFER(artifact)"
	find native-bridge-text "x64-codegen/generate"
	not find native-bridge-text "WIRE_"
	not find native-bridge-text "wire-"
][
	fail "native codegen bridge is not the direct compact path"
]

include-directive: to issue! "include"
closure-seen: make map! 256
closure-files: make block! 256

walk-include-values: func [
	values [block! paren!]
	base [file!]
	/local position included candidate spelling
][
	position: values
	while [not tail? position][
		either all [
			issue? position/1
			position/1 = include-directive
			not tail? next position
			file? position/2
		][
			included: position/2
			spelling: to string! included
			unless find spelling "$" [
				candidate: clean-path append copy base included
				unless exists? candidate [
					fail ["unresolved hybrid include " included " from " base]
				]
				walk-include-file candidate
			]
			position: skip position 2
		][
			if any [block? :position/1 paren? :position/1][
				walk-include-values position/1 base
			]
			position: next position
		]
	]
]

walk-include-file: func [
	file [file!]
	/local normalized key suffix source base
][
	normalized: clean-path file
	key: to string! normalized
	if select closure-seen key [return none]
	put closure-seen key true
	append closure-files normalized
	suffix: suffix? normalized
	set/any 'source try [load/all read normalized]
	if error? :source [fail ["cannot load hybrid closure file " normalized ": " mold source]]
	base: first split-path normalized
	walk-include-values source base
]

root: clean-path to file! rejoin [system/options/path %../../../]
walk-include-file clean-path to file! rejoin [
	root %system/compiler-windows-hybrid-bootstrap.red
]
walk-include-file clean-path to file! rejoin [
	root %red-bootstrap-windows-hybrid-backend.red
]

foreach forbidden [
	%system/compiler-windows-bootstrap.red
	%system/compiler-core.red
	%system/emitter.red
	%system/machine-ir.red
	%system/machine-ir-x64.red
	%compiler/wire-schema.red
	%compiler/wire-writer.red
	%compiler/wire-container.red
	%compiler/rscf-producer.red
	%compiler/hybrid-driver.red
	%compiler/rscg-linker-adapter.red
	%compiler/wire-file-source.red
	%compiler/wire-data-layout.red
	%compiler/wire-module-lifecycle.red
	%compiler/wire-rscg-object.red
	%compiler/wire-rscg-relocation.red
	%compiler/wire-rscg-metadata.red
	%compiler/wire-string-table.red
	%compiler/wire-diagnostics.red
	%system/codegen/wire-schema.reds
	%system/codegen/wire-reader.reds
	%system/codegen/wire-writer.reds
	%system/codegen/wire-rsir.reds
	%system/codegen/wire-rscg-metadata.reds
	%system/codegen/wire-diagnostics.reds
	%system/codegen/wire-codegen-strings.reds
	%system/codegen/x64-o0-codegen.reds
][
	forbidden: clean-path to file! rejoin [root forbidden]
	if find closure-files forbidden [
		fail ["hybrid backend closure contains forbidden Red ownership " forbidden]
	]
]

foreach required [
	%system/compiler-windows-hybrid-core.red
	%system/compiler-windows-common.red
	%system/compiler-rsir-core.red
	%system/linker.red
	%system/codegen/codegen-bridge.reds
	%system/codegen/x64-codegen.reds
	%system/codegen/x64-encoder.reds
	%compiler/rsir-frontend.red
	%compiler/codegen-bridge.red
	%compiler/saved-frontend.red
	%red-bootstrap-windows-hybrid-backend.red
][
	required: clean-path to file! rejoin [root required]
	unless find closure-files required [
		fail ["hybrid source closure is missing " required]
	]
]

print [
	"PASS: direct hybrid compiler source closure"
	length? closure-files "source files"
]
