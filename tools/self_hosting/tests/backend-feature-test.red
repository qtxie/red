Red [
	Title: "Hybrid compiler Windows x64 feature coverage test"
]

do %../../../compiler/wire-schema-spec.red
do %../../../compiler/backend-ownership-spec.red
do %../../../compiler/backend-feature-spec.red

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

suite-inventory: context [
	files: none

	walk: func [value /local path suffix][
		case [
			file? :value [
				path: lowercase copy form value
				suffix: either (length? path) >= 5 [copy skip tail path -5][copy ""]
				if all [
					find/match/case path "source/units/"
					suffix = ".reds"
				][
					path: rejoin ["system/tests/" path]
					unless find/case files path [append files path]
				]
			]
			any-block? :value [foreach item value [walk :item]]
			true []
		]
	]

	scan: func [source [block!]][
		files: make block! 64
		walk source
		sort files
	]
]

validate-pairs: func [value name][
	unless all [block? value even? length? value][
		fail [name " must contain key/value pairs"]
	]
]

validate-spec: func [
	spec [block!]
	/local allowed-root seen-root key value target runner exclusions statuses features
		status-names status description contracts owner owner-description
		feature-names feature body fields allowed-fields field owners wire tests blockers
		seen-fields seen-owners reference parts group path full
		wire-references test-references records enums record definition entries enum-name enum-value
		runner-source suite-files excluded-files exclusion-reason suite-file
		specified-count blocked-count active-suite-count
][
	validate-pairs spec "feature manifest"
	allowed-root: [target runner runner-exclusions statuses features]
	seen-root: make block! length? allowed-root
	foreach [key value] spec [
		unless find allowed-root key [fail ["unknown feature manifest field: " mold key]]
		if find seen-root key [fail ["duplicate feature manifest field: " mold key]]
		append seen-root key
	]
	foreach key allowed-root [
		unless find seen-root key [fail ["missing feature manifest field: " mold key]]
	]

	target: select spec 'target
	runner: select spec 'runner
	exclusions: select spec 'runner-exclusions
	statuses: select spec 'statuses
	features: select spec 'features
	unless target = 'WINDOWS_X64 [fail "feature manifest target must be WINDOWS_X64"]
	unless string? runner [fail "feature manifest runner must be a root-relative string"]
	validate-pairs exclusions "runner exclusions"
	validate-pairs statuses "feature statuses"
	validate-pairs features "feature list"

	status-names: make block! 8
	foreach [status description] statuses [
		unless all [word? status string? description not empty? description][
			fail ["invalid feature status: " mold reduce [status description]]
		]
		if find status-names status [fail ["duplicate feature status: " mold status]]
		append status-names status
	]
	unless all [find status-names 'specified find status-names 'blocked][
		fail "feature statuses must define specified and blocked"
	]

	contracts: select compiler-backend-ownership-spec 'contracts
	feature-names: make block! 64
	wire-references: make block! 512
	test-references: make block! 128
	specified-count: 0
	blocked-count: 0
	allowed-fields: [status owners wire tests blockers]
	records: select compiler-wire-schema-spec 'records
	enums: select compiler-wire-schema-spec 'enums

	foreach [feature body] features [
		unless all [word? feature block? body even? length? body][
			fail ["invalid feature entry: " mold feature]
		]
		if find feature-names feature [fail ["duplicate feature: " mold feature]]
		append feature-names feature
		seen-fields: make block! 8
		foreach [field value] body [
			unless find allowed-fields field [
				fail ["unknown feature field: " mold reduce [feature field]]
			]
			if find seen-fields field [
				fail ["duplicate feature field: " mold reduce [feature field]]
			]
			append seen-fields field
		]
		foreach field allowed-fields [
			unless find seen-fields field [
				fail ["missing feature field: " mold reduce [feature field]]
			]
		]

		status: select body 'status
		owners: select body 'owners
		wire: select body 'wire
		tests: select body 'tests
		blockers: select body 'blockers
		unless find status-names status [
			fail ["unknown feature status: " mold reduce [feature status]]
		]
		unless all [block? owners not empty? owners][
			fail ["feature has no owners: " mold feature]
		]
		seen-owners: make block! length? owners
		foreach owner owners [
			owner-description: select contracts owner
			unless string? owner-description [
				fail ["unknown feature owner: " mold reduce [feature owner]]
			]
			if find seen-owners owner [
				fail ["duplicate feature owner: " mold reduce [feature owner]]
			]
			append seen-owners owner
		]
		unless all [block? wire not empty? wire][
			fail ["feature has no wire references: " mold feature]
		]
		foreach reference wire [
			unless path? reference [
				fail ["wire reference must be a path: " mold reduce [feature reference]]
			]
			parts: to block! reference
			unless (length? parts) = 2 [
				fail ["wire reference must have two parts: " mold reference]
			]
			either parts/1 = 'RECORD [
				unless all [parts/2 <> 'ALL_VALUES block? select records parts/2][
					fail ["unknown wire record reference: " mold reference]
				]
			][
				group: select enums parts/1
				unless block? group [fail ["unknown wire enum group: " mold reference]]
				unless any [
					parts/2 = 'ALL_VALUES
					not none? select group parts/2
				][fail ["unknown wire enum value: " mold reference]]
			]
			path: uppercase copy form reference
			unless find/case wire-references path [append wire-references path]
		]

		unless all [block? tests not empty? tests][
			fail ["feature has no test evidence: " mold feature]
		]
		foreach path tests [
			unless all [string? path not empty? path][
				fail ["invalid feature test path: " mold reduce [feature path]]
			]
			full: clean-path (to file! (rejoin ["../../../" path]))
			unless exists? full [fail ["missing feature test path: " path]]
			unless find/case test-references path [append test-references path]
		]

		unless block? blockers [fail ["feature blockers must be a block: " mold feature]]
		foreach description blockers [
			unless all [string? description not empty? description][
				fail ["invalid feature blocker: " mold reduce [feature description]]
			]
		]
		either status = 'specified [
			unless empty? blockers [fail ["specified feature still has blockers: " mold feature]]
			specified-count: specified-count + 1
		][
			if empty? blockers [fail ["blocked feature has no blocker: " mold feature]]
			blocked-count: blocked-count + 1
		]
	]

	foreach [record definition] records [
		path: rejoin ["RECORD/" form record]
		unless find/case wire-references path [
			fail ["wire record is absent from feature matrix: " path]
		]
	]
	foreach [group entries] enums [
		foreach [enum-name enum-value] entries [
			path: rejoin [form group "/" form enum-name]
			unless any [
				find/case wire-references path
				find/case wire-references rejoin [form group "/ALL_VALUES"]
			][fail ["wire enum value is absent from feature matrix: " path]]
		]
	]

	full: clean-path (to file! (rejoin ["../../../" runner]))
	unless exists? full [fail ["missing feature suite runner: " runner]]
	runner-source: load full
	suite-files: suite-inventory/scan runner-source
	excluded-files: make block! length? exclusions
	foreach [path exclusion-reason] exclusions [
		unless all [string? path string? exclusion-reason not empty? exclusion-reason][
			fail ["invalid runner exclusion: " mold reduce [path exclusion-reason]]
		]
		if find/case excluded-files path [fail ["duplicate runner exclusion: " path]]
		unless find/case suite-files path [fail ["stale runner exclusion: " path]]
		append excluded-files path
	]

	active-suite-count: 0
	foreach suite-file suite-files [
		unless find/case excluded-files suite-file [
			active-suite-count: active-suite-count + 1
			unless find/case test-references suite-file [
				fail ["unclassified Windows x64 suite file: " suite-file]
			]
		]
	]
	reduce [length? feature-names specified-count blocked-count active-suite-count]
]

result: validate-spec compiler-backend-feature-spec
print [
	"PASS: compiler backend feature matrix"
	result/1 "features"
	result/2 "specified"
	result/3 "blocked"
	result/4 "Windows x64 suite files"
]
