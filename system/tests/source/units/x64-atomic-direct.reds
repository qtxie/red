Red/System [
	Title: "x64 atomic direct smoke"
]

#if target = 'X86-64 [
	g: 0

	global-ops: func [
		return: [integer!]
		/local n [integer!] previous [integer!] ok [logic!]
	][
		system/atomic/store :g 7
		n: system/atomic/load :g
		if n <> 7 [return 1]

		previous: system/atomic/add/old :g 5
		if previous <> 7 [return 2]
		if g <> 12 [return 3]

		n: system/atomic/sub :g 2
		if n <> 10 [return 4]
		n: system/atomic/or :g 5
		if n <> 15 [return 5]
		n: system/atomic/xor :g 3
		if n <> 12 [return 6]
		n: system/atomic/and :g 10
		if n <> 8 [return 7]

		ok: system/atomic/cas :g 8 11
		if ok = false [return 8]
		if g <> 11 [return 9]
		ok: system/atomic/cas :g 8 12
		if ok [return 10]
		if g <> 11 [return 11]

		system/atomic/add :g 1
		if g <> 12 [return 12]
		system/atomic/fence
		0
	]

	local-ops: func [
		value [int-ptr!]
		return: [integer!]
	][
		system/atomic/add value 3
		system/atomic/sub value 1
		system/atomic/load value
	]

	main: func [
		/local code [integer!] value [integer!]
	][
		code: global-ops
		if code <> 0 [quit code]
		value: 0
		if (local-ops :value) <> 2 [quit 13]
		quit 0
	]

	#user-code
	main
]
