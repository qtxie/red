Red [
	Title: "Standalone compiler toolchain support"
	File:  %toolchain-support.red
]

compiler-toolchain: context [
	name: "red-toolchain"
	host: "unknown"
	targets: make block! 0
	backend: "unknown"

	install-embedded: does [
		if value? 'toolchain-resource-index [
			unless all [
				value? 'toolchain-resource-data
				value? 'toolchain-resource-manifest-sha256
			][compiler-resource-store/fail "incomplete embedded resource archive"]
			compiler-resource-store/install
				get 'toolchain-resource-index
				get 'toolchain-resource-data
				get 'toolchain-resource-manifest-sha256
		]
	]

	configure: func [
		host-value [string!]
		target-values [block!]
		backend-value [string!]
	][
		host: copy host-value
		targets: copy target-values
		backend: copy backend-value
	]

	resource-count: does [
		either compiler-resource-store/installed? [
			divide length? compiler-resource-store/index 2
		][0]
	]

	print-info: func [version [string!]][
		print ["name:" name]
		print ["version:" version]
		print ["host:" host]
		print ["targets:" reform targets]
		print ["backend:" backend]
		print ["standalone:" compiler-resource-store/installed?]
		print ["resources:" resource-count]
		print [
			"resource-manifest:"
			any [compiler-resource-store/manifest-sha256 "none"]
		]
	]

	dispatch: func [
		info? [logic!]
		list? [logic!]
		manifest? [logic!]
		check? [logic!]
		version [string!]
	][
		case [
			info? [
				print-info version
				return 0
			]
			list? [
				foreach target targets [print target]
				return 0
			]
			manifest? [
				print any [compiler-resource-store/manifest-sha256 "none"]
				return either compiler-resource-store/installed? [0][1]
			]
			check? [
				unless compiler-resource-store/installed? [
					print "*** Red command-line error: resource archive is not installed"
					return 1
				]
				print [
					"resource-self-check: ok resources:"
					compiler-resource-store/self-check
				]
				return 0
			]
			true [none]
		]
	]

	dispatch-options: func [options [object!] version [string!]][
		dispatch
			compiler-options/option-get options 'toolchain-info?
			compiler-options/option-get options 'list-targets?
			compiler-options/option-get options 'resource-manifest?
			compiler-options/option-get options 'self-check?
			version
	]
]

compiler-toolchain/install-embedded
