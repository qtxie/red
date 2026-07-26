Red/System [
	Title: "Context local-field relocation fixture"
]

fake-load: func [
	value [c-string!]
	return: [pointer! [integer!]]
][
	as pointer! [integer!] value
]

refs: context [
	local: as pointer! [integer!] 0
	extern: as pointer! [integer!] 0

	build: func [
		/local tmp [pointer! [integer!]]
	][
		tmp: fake-load "tmp"
		local: fake-load "local"
		extern: fake-load "extern"
	]
]

refs/build
