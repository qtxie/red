Red [
	Title: "Red compiler SHA-256 utilities"
	File:  %sha256.red
]

; Red's checksum native already implements SHA-256 in the runtime.  The old
; Rebol host needed a slow arithmetic fallback plus a dynamically built helper
; library; neither layer is needed in a compiled Red compiler.
compiler-sha256: context [
	digest: func [data [binary! string!]][
		checksum data 'SHA256
	]

	word-to-binary: func [value [integer!]][
		reverse int-to-bin/to-bin32 value
	]

	digest-pages: func [
		data [binary!]
		code-limit page-size [integer!]
		/local output offset bytes slots page
	][
		if any [
			code-limit < 0
			code-limit > (length? data)
			page-size <= 0
		][
			make error! "invalid SHA-256 page range"
		]
		slots: to integer! (
			(to float! code-limit) / (to float! page-size)
		)
		unless zero? (code-limit // page-size) [slots: slots + 1]
		output: make binary! (32 * slots)
		offset: 0
		while [offset < code-limit][
			bytes: min page-size (code-limit - offset)
			page: copy/part (at data (offset + 1)) bytes
			append output digest page
			offset: offset + bytes
		]
		output
	]
]

sha256: compiler-sha256
