Red [
	Title: "Red compiler binding identity"
	File:  %binding-identity.red
]

compiler-bindings: context [
	next-id: 1
	scopes: make block! 64
	shadow-contexts: make map! 256

	scope-prototype: object [
		__compiler-scope?: true
		id: 0
		kind: none
		name: none
		parent: none
	]

	reset: does [
		next-id: 1
		clear scopes
		clear shadow-contexts
	]

	context-id: func [value [object!]][
		class-of value
	]

	register-shadow: func [shadow [object!] function-name [word!] function-spec [block!]][
		put shadow-contexts context-id shadow reduce [shadow function-name function-spec]
		function-name
	]

	shadow-entry-of: func [shadow [object! none!]][
		all [object? shadow select shadow-contexts context-id shadow]
	]

	shadow-context-of: func [shadow [object! none!] /local entry][
		all [entry: shadow-entry-of shadow entry/2]
	]

	rebuild-shadows: func [entries [block!]][
		clear shadow-contexts
		foreach [function-symbol shadow function-name function-spec] entries [
			register-shadow shadow function-name function-spec
		]
	]

	new-scope: func [
		kind [word!]
		name [word! string! none!]
		parent [object! none!]
		/local scope
	][
		scope: make scope-prototype [
			id: compiler-bindings/next-id
			kind: kind
			name: name
			parent: parent
		]
		next-id: next-id + 1
		append scopes scope
		scope
	]

	scope?: func [value [any-type!] /local marker][
		to logic! all [
			object? value
			marker: in value '__compiler-scope?
			get marker
		]
	]

	same-scope?: func [left right [object!]][
		all [
			scope? left
			scope? right
			left/id = right/id
		]
	]

	key: func [scope [object!] name [any-word! string!]][
		unless scope? scope [
			make error! "invalid compiler scope"
		]
		reduce [scope/id to word! name]
	]

	same-word-binding?: func [left right [any-word!]][
		same? to word! left to word! right
	]

	context-of: func [word [any-word!]][
		context? word
	]

	same-context?: func [left right [any-word!] /local left-context right-context][
		left-context: context? left
		right-context: context? right
		either any [none? left-context none? right-context][
		all [none? left-context none? right-context]
		][
			same? left-context right-context
		]
	]
]
