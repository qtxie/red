Red [
	Title:   "Mach-O linker-signed ad-hoc code signature emitter"
	File:    %Mach-O-sign.red
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

macho-code-sign: context [
	page-size: 16384
	code-directory-header-size: 88
	standalone-superblob-header-size: 20
	bundle-superblob-header-size: 36
	requirements-blob: #{FADE0C010000000C00000000}

	append-be32: func [out [binary!] value [integer! char!]][
		append out sha256/word-to-binary to integer! value
	]

	append-be64: func [out [binary!] value [integer!]][
		append out #{00000000}
		append-be32 out value
	]

	code-slot-count: func [code-limit [integer!]][
		(round/to/ceiling code-limit page-size) / page-size
	]

	code-directory-size: func [
		code-limit [integer!]
		identifier [string!]
		hash-size special-count [integer!]
	][
		code-directory-header-size + 1 + (length? identifier)
			+ (hash-size * (special-count + code-slot-count code-limit))
	]

	size?: func [
		code-limit [integer!]
		identifier [string!]
		/bundle bundle-info [object!]
		/local primary-size alternate-size blob-length
	][
		primary-size: code-directory-size code-limit identifier either bundle [20][32]
			either bundle [3][0]
		blob-length: either bundle [bundle-superblob-header-size][standalone-superblob-header-size]
		blob-length: blob-length + primary-size
		if bundle [
			alternate-size: code-directory-size code-limit identifier 32 3
			blob-length: blob-length + (length? requirements-blob) + alternate-size
		]
		round/to/ceiling blob-length 8
	]

	build-load-command: func [data-offset data-size [integer!] /local out][
		out: make binary! 16
		append out int-to-bin/to-bin32 29                                ; LC_CODE_SIGNATURE
		append out int-to-bin/to-bin32 16
		append out int-to-bin/to-bin32 data-offset
		append out int-to-bin/to-bin32 data-size
		out
	]

	digest-pages: func [
		data [binary!]
		code-limit [integer!]
		method [word!]
		/local hashes offset bytes page
	][
		hashes: make binary! 1024
		offset: 0
		while [offset < code-limit][
			bytes: min page-size (code-limit - offset)
			page: copy/part at data (offset + 1) bytes
			append hashes checksum page method
			offset: offset + bytes
		]
		hashes
	]

	build-code-directory: func [
		image [binary!]
		code-limit [integer!]
		identifier [string!]
		executable-size [integer!]
		main? [logic!]
		hash-type [integer!]
		bundle-info [object! none!]
		/local out slots special-count hash-size method info-key resource-key hash-offset
			directory-size resource-hash info-hash hashes
	][
		set [hash-size method info-key resource-key] switch hash-type [
			1 [reduce [20 'SHA1 'info-hash1 'resource-hash1]]
			2 [reduce [32 'SHA256 'info-hash2 'resource-hash2]]
		]
		slots: code-slot-count code-limit
		special-count: either bundle-info [3][0]
		hash-offset: code-directory-header-size + 1 + (length? identifier)
			+ (hash-size * special-count)
		directory-size: hash-offset + (hash-size * slots)
		out: make binary! directory-size

		append-be32 out to integer! #{FADE0C02}               ; CSMAGIC_CODEDIRECTORY
		append-be32 out directory-size
		append-be32 out 132096                                 ; CS_SUPPORTSEXECSEG (0x20400)
		append-be32 out either bundle-info [2][131074]         ; CS_ADHOC [| CS_LINKER_SIGNED]
		append-be32 out hash-offset
		append-be32 out code-directory-header-size
		append-be32 out special-count
		append-be32 out slots
		append-be32 out code-limit
		append out either hash-type = 1 [#{1401000E}][#{2002000E}]
		append-be32 out 0                                      ; spare2
		append-be32 out 0                                      ; scatterOffset
		append-be32 out 0                                      ; teamOffset
		append-be32 out 0                                      ; spare3
		append-be64 out 0                                      ; codeLimit64
		append-be64 out 0                                      ; __TEXT file offset
		append-be64 out executable-size
		append-be64 out either main? [1][0]                   ; CS_EXECSEG_MAIN_BINARY
		append out to binary! identifier
		append out #{00}

		if bundle-info [
			resource-hash: get in bundle-info resource-key
			info-hash: get in bundle-info info-key
			unless all [
				(length? resource-hash) = hash-size
				(length? info-hash) = hash-size
			][make error! "invalid macOS bundle special-slot hash"]
			append out resource-hash                           ; slot -3: CodeResources
			append out checksum requirements-blob method        ; slot -2: requirements
			append out info-hash                               ; slot -1: Info.plist
		]
		hashes: either hash-type = 2 [
			sha256/digest-pages image code-limit page-size
		][digest-pages image code-limit method]
		append out hashes
		out
	]

	build: func [
		image [binary!]
		code-limit [integer!]
		identifier [string!]
		executable-size [integer!]
		main? [logic!]
		/bundle bundle-info [object!]
		/local out primary alternate primary-offset requirements-offset alternate-offset blob-length
	][
		if code-limit <> (length? image) [
			make error! rejoin [
				"invalid Mach-O code limit " code-limit " for " (length? image) " bytes"
			]
		]
		primary: build-code-directory image code-limit identifier executable-size main?
			either bundle [1][2] either bundle [bundle-info][none]
		primary-offset: either bundle [bundle-superblob-header-size][standalone-superblob-header-size]
		blob-length: primary-offset + length? primary
		if bundle [
			requirements-offset: blob-length
			alternate-offset: requirements-offset + length? requirements-blob
			alternate: build-code-directory image code-limit identifier executable-size main?
				2 bundle-info
			blob-length: alternate-offset + length? alternate
		]
		out: make binary! round/to/ceiling blob-length 8

		append-be32 out to integer! #{FADE0CC0}               ; CSMAGIC_EMBEDDED_SIGNATURE
		append-be32 out blob-length
		append-be32 out either bundle [3][1]
		append-be32 out 0                                      ; CSSLOT_CODEDIRECTORY
		append-be32 out primary-offset
		if bundle [
			append-be32 out 2                                  ; CSSLOT_REQUIREMENTS
			append-be32 out requirements-offset
			append-be32 out 4096                               ; CSSLOT_ALTERNATE_CODEDIRECTORIES
			append-be32 out alternate-offset
		]
		append out primary
		if bundle [
			append out requirements-blob
			append out alternate
		]
		insert/dup tail out #{00} (round/to/ceiling blob-length 8) - length? out
		out
	]
]
