Red [
	Title: "Exclusive hybrid compiler driver ownership audit"
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
expect core/1 "compiler-hybrid-driver/generate" 1 "compiler-rsir-core"
expect core/1 "compiler-hybrid-driver/adapt" 1 "compiler-rsir-core"
expect core/1 "linker/build" 1 "compiler-rsir-core"
expect core/1 "compiler-rscg-linker-adapter/adapt" 0 "compiler-rsir-core"
expect core/1 "rs-o2-ir/verify-current" 0 "compiler-rsir-core"
expect core/2 "codegen-module" 0 "compiler-rsir-core"
expect core/2 "finish-rscg" 1 "compiler-rsir-core"

driver: inventory/scan load %../../../compiler/hybrid-driver.red
expect driver/2 "invoke-codegen" 0 "hybrid-driver-static-call"
expect driver/2 "invoke-adapter" 0 "hybrid-driver-static-call"
expect driver/2 "adapter-message" 0 "hybrid-driver-static-call"
expect driver/3 "invoke-codegen" 1 "hybrid-driver-dynamic-call"
expect driver/3 "invoke-adapter" 1 "hybrid-driver-dynamic-call"
expect driver/3 "adapter-message" 1 "hybrid-driver-dynamic-call"
expect driver/1 "config-producer/build" 1 "hybrid-driver"
expect driver/1 "diagnostic-verifier/verify" 1 "hybrid-driver"
expect driver/2 "emitter" 0 "hybrid-driver"
expect driver/2 "rs-o2-ir" 0 "hybrid-driver"
expect driver/2 "linker" 0 "hybrid-driver"
expect driver/2 "verify-current" 0 "hybrid-driver"

package: inventory/scan load %../../../system/compiler-windows-hybrid-bootstrap.red
expect package/2 "codegen-module" 1 "hybrid-package"
expect package/1 "compiler-rscg-linker-adapter/adapt" 1 "hybrid-package"
expect package/2 "emitter" 0 "hybrid-package"
expect package/2 "rs-o2-ir" 0 "hybrid-package"
expect package/2 "linker" 0 "hybrid-package"
expect package/2 "verify-current" 0 "hybrid-package"

native-bridge-text: read %../../../system/codegen/codegen-bridge.reds
if find native-bridge-text "binary/rs-append" [
	fail "native codegen bridge depends on non-exported binary/rs-append"
]
unless all [
	find native-bridge-text "commit-arena"
	find native-bridge-text "GET_BUFFER(output)"
][
	fail "native codegen bridge is missing its allocation-free output commit"
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
	if suffix = %.reds [return none]
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
	%compiler/wire-file-source.red
	%compiler/wire-data-layout.red
	%compiler/wire-module-lifecycle.red
	%compiler/wire-rscg-object.red
	%compiler/wire-rscg-relocation.red
	%compiler/wire-rscg-metadata.red
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
	"PASS: exclusive hybrid compiler driver ownership"
	length? closure-files "source files"
]
