Red [
	Title: "Embedded compiler resource store"
	File:  %compiler/resource-store.red
]

compiler-resource-store: context [
	virtual-prefix: "/__red_toolchain__/"
	index: make hash! 512
	payload: make binary! 0
	cache: make hash! 128
	manifest-sha256: none
	installed?: false

	fail: func [message [string! block!]][
		do make error! rejoin [
			"compiler resource store: "
			either block? message [reform message][message]
		]
	]

	normalize-key: func [path [file! string!] /local value prefix-size parts stack part out][
		value: to string! copy path
		replace/all value #"\" #"/"
		prefix-size: length? virtual-prefix
		if all [
			(length? value) >= prefix-size
			(copy/part value prefix-size) = virtual-prefix
		][remove/part value prefix-size]
		while [all [not empty? value value/1 = #"/"]][remove value]
		parts: split value #"/"
		stack: make block! length? parts
		foreach part parts [
			case [
				any [empty? part part = "."] [none]
				part = ".." [
					if empty? stack [fail ["path escapes embedded root: " mold path]]
					take/last stack
				]
				true [append stack part]
			]
		]
		out: make string! length? value
		foreach part stack [
			if not empty? out [append out #"/"]
			append out part
		]
		out
	]

	virtual?: func [path [file! string!] /local value][
		value: to string! path
		replace/all value #"\" #"/"
		all [
			(length? value) >= length? virtual-prefix
			(copy/part value length? virtual-prefix) = virtual-prefix
		]
	]

	virtual-path: func [path [file! string!]][
		to file! rejoin [virtual-prefix normalize-key path]
	]

	resolve: func [
		path [file! string!] parent [file! string!]
		/directory
		/local base key parent-value parent-key parent-directory?
	][
		if virtual? path [return virtual-path path]
		key: to string! path
		replace/all key #"\" #"/"
		if all [not empty? key key/1 = #"/"][return virtual-path key]
		parent-value: to string! copy parent
		replace/all parent-value #"\" #"/"
		parent-directory?: any [
			directory
			all [not empty? parent-value (last parent-value) = #"/"]
		]
		parent-key: normalize-key parent-value
		base: either parent-directory? [
			copy parent-key
		][
			to string! first split-path to file! parent-key
		]
		if all [not empty? base (last base) <> #"/"][append base #"/"]
		virtual-path rejoin [base path]
	]

	key-of: func [path [file! string!]][
		either virtual? path [normalize-key path][none]
	]

	install: func [records [block!] data [binary!] digest [string!] /local record key][
		clear index
		clear cache
		foreach record records [
			unless all [block? record (length? record) = 6][
				fail ["invalid resource record: " mold record]
			]
			key: normalize-key record/1
			if select index key [fail ["duplicate resource path: " key]]
			append index key
			append/only index copy next record
		]
		payload: data
		manifest-sha256: copy digest
		installed?: true
		self
	]

	exists?: func [path [file! string!] /local key][
		all [installed? key: normalize-key path not none? select index key]
	]

	source-path: func [path [file! string!]][
		either all [installed? exists? path][virtual-path path][to file! path]
	]

	read-binary: func [path [file! string!] /local key cached record stored data actual][
		unless installed? [fail "resource archive is not installed"]
		key: normalize-key path
		if cached: select cache key [return copy cached]
		record: select index key
		unless record [fail ["resource not found: " key]]
		unless all [
			integer? record/1
			integer? record/2
			integer? record/3
			word? record/4
			string? record/5
			record/1 > 0
			record/2 >= 0
			record/3 >= 0
			(record/1 + record/2 - 1) <= length? payload
		][fail ["invalid resource bounds: " key]]
		stored: copy/part at payload record/1 record/2
		data: switch/default record/4 [
			raw [stored]
			crush [decompress stored 'crush]
		][fail ["unsupported resource encoding: " record/4]]
		unless all [binary? data (length? data) = record/3][
			fail ["resource size mismatch: " key]
		]
		actual: lowercase enbase/base checksum data 'SHA256 16
		unless actual = record/5 [fail ["resource checksum mismatch: " key]]
		append cache key
		append/only cache data
		copy data
	]

	read-text: func [path [file! string!] /local value][
		value: to string! read-binary path
		replace/all value "^M^/" "^/"
		replace/all value "^M" "^/"
		value
	]

	self-check: func [/local key record data count][
		unless installed? [fail "resource archive is not installed"]
		count: 0
		foreach [key record] index [
			data: read-binary key
			unless (length? data) = record/3 [fail ["resource verification failed: " key]]
			count: count + 1
		]
		count
	]
]
