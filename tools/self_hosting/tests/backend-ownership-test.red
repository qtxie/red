Red [
	Title: "Compiler backend ownership coverage test"
]

do %../../../compiler/backend-ownership-spec.red

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

emitter-inventory: context [
	counts: none

	add: func [key [string!] /local current][
		current: select counts key
		put counts key either none? current [1][current + 1]
	]

	walk: func [value][
		case [
			any-path? :value [
				if (to word! first :value) = 'emitter [
					add form to path! :value
				]
			]
			all [any-word? :value (to word! :value) = 'emitter] [
				add "emitter"
			]
			any-block? :value [foreach item value [walk :item]]
			true []
		]
	]

	scan: func [source [block!]][
		counts: make map! 256
		walk source
		counts
	]
]

validate-manifest: func [
	spec [block!]
	/local contracts dependencies owners seen-owners seen-paths owner description entries path count
][
	contracts: select spec 'contracts
	dependencies: select spec 'dependencies
	unless all [block? contracts block? dependencies][
		fail "ownership manifest is missing contracts or dependencies"
	]
	unless even? length? contracts [fail "ownership contracts must be name/text pairs"]
	unless even? length? dependencies [fail "ownership dependencies must be owner/body pairs"]

	owners: make block! 8
	foreach [owner description] contracts [
		unless all [word? owner string? description not empty? description][
			fail ["invalid ownership contract: " mold reduce [owner description]]
		]
		if find owners owner [fail ["duplicate ownership contract: " mold owner]]
		append owners owner
	]

	seen-owners: make block! 8
	seen-paths: make block! 256
	foreach [owner entries] dependencies [
		unless all [word? owner find owners owner block? entries][
			fail ["invalid dependency owner: " mold owner]
		]
		if find seen-owners owner [fail ["duplicate dependency owner: " mold owner]]
		append seen-owners owner
		unless even? length? entries [
			fail ["dependency entries must be path/count pairs: " mold owner]
		]
		foreach [path count] entries [
			unless all [
				string? path
				find/match/case path "emitter"
				integer? count
				count > 0
			][fail ["invalid dependency entry: " mold reduce [owner path count]]]
			if find/case seen-paths path [fail ["duplicate dependency path: " path]]
			append seen-paths path
		]
	]
	foreach owner owners [
		unless find seen-owners owner [fail ["missing dependency owner: " mold owner]]
	]
	true
]

verify-inventory: func [
	spec [block!]
	actual [map!]
	/local expected owners dependencies owner entries path count actual-count expected-count total
][
	expected: make map! 256
	owners: make map! 256
	dependencies: select spec 'dependencies
	foreach [owner entries] dependencies [
		foreach [path count] entries [
			put expected path count
			put owners path owner
		]
	]

	foreach [path count] actual [
		expected-count: select expected path
		if none? expected-count [fail ["unclassified emitter dependency: " path]]
		unless count = expected-count [
			fail rejoin [
				"emitter dependency count changed: " path
				" expected=" expected-count " actual=" count
				" owner=" select owners path
			]
		]
	]

	total: 0
	foreach [path count] expected [
		actual-count: select actual path
		if none? actual-count [fail ["stale emitter dependency: " path]]
		total: total + count
	]
	reduce [length? expected total]
]

validate-manifest compiler-backend-ownership-spec

; Prove that path access modes normalize to one dependency key and that a bare
; emitter object reference is still visible.
probe-source: load {
[
	emitter/example
	:emitter/example
	emitter/example:
	'emitter/example
	emitter
]
}
probe-inventory: emitter-inventory/scan probe-source
unless all [
	(select probe-inventory "emitter/example") = 4
	(select probe-inventory "emitter") = 1
][fail "emitter dependency scanner does not normalize all path access modes"]

source: load %../../../system/compiler-core.red
actual: emitter-inventory/scan source
result: verify-inventory compiler-backend-ownership-spec actual

print [
	"PASS: compiler backend ownership"
	result/1 "APIs"
	result/2 "references"
]
