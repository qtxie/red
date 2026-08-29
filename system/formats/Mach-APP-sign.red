Red [
	Title:   "macOS application bundle ad-hoc signing helpers"
	File:    %Mach-APP-sign.red
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

mach-app-sign: context [
	xml-header: {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
}

	xml-footer: {</dict>
</plist>
}

	rules: {<key>rules</key>
<dict>
	<key>^^Resources/</key>
	<true/>
	<key>^^Resources/.*\.lproj/</key>
	<dict><key>optional</key><true/><key>weight</key><real>1000</real></dict>
	<key>^^Resources/.*\.lproj/locversion.plist$</key>
	<dict><key>omit</key><true/><key>weight</key><real>1100</real></dict>
	<key>^^Resources/Base\.lproj/</key>
	<dict><key>weight</key><real>1010</real></dict>
	<key>^^version.plist$</key>
	<true/>
</dict>
<key>rules2</key>
<dict>
	<key>.*\.dSYM($|/)</key>
	<dict><key>weight</key><real>11</real></dict>
	<key>^^.*</key>
	<true/>
	<key>^^(.*/)?\.DS_Store$</key>
	<dict><key>omit</key><true/><key>weight</key><real>2000</real></dict>
	<key>^^(Frameworks|SharedFrameworks|PlugIns|Plug-ins|XPCServices|Helpers|MacOS|Library/(Automator|Spotlight|LoginItems))/</key>
	<dict><key>nested</key><true/><key>weight</key><real>10</real></dict>
	<key>^^[^^/]+$</key>
	<dict><key>nested</key><true/><key>weight</key><real>10</real></dict>
	<key>^^embedded\.provisionprofile$</key>
	<dict><key>weight</key><real>20</real></dict>
	<key>^^Info\.plist$</key>
	<dict><key>omit</key><true/><key>weight</key><real>20</real></dict>
	<key>^^PkgInfo$</key>
	<dict><key>omit</key><true/><key>weight</key><real>20</real></dict>
	<key>^^Resources/</key>
	<dict><key>weight</key><real>20</real></dict>
	<key>^^Resources/.*\.lproj/</key>
	<dict><key>optional</key><true/><key>weight</key><real>1000</real></dict>
	<key>^^Resources/.*\.lproj/locversion.plist$</key>
	<dict><key>omit</key><true/><key>weight</key><real>1100</real></dict>
	<key>^^Resources/Base\.lproj/</key>
	<dict><key>weight</key><real>1010</real></dict>
	<key>^^version\.plist$</key>
	<dict><key>weight</key><real>20</real></dict>
</dict>
}

	xml-escape: func [value [string!] /local out][
		out: copy value
		replace/all out "&" "&amp;"
		replace/all out "<" "&lt;"
		replace/all out ">" "&gt;"
		replace/all out {"} "&quot;"
		replace/all out "'" "&apos;"
		out
	]

	identifier-component: func [value [string!] /local out char][
		out: make string! length? value
		foreach char value [
			append out either find
				"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"
				char
			[char][#"-"]
		]
		if empty? out [append out "red-app"]
		out
	]

	executable-name: func [value [string!] /local out char codepoint][
		out: make string! length? value
		foreach char value [
			codepoint: to integer! char
			append out either all [
				codepoint >= 32
				codepoint <= 126
				char <> #"/"
				char <> #":"
			][char][#"-"]
		]
		if empty? out [append out "red-app"]
		out
	]

	compare-entry: func [left [block!] right [block!]][
		(form pick left 1) < (form pick right 1)
	]

	base64: func [data [binary!]][enbase/base data 64]

	append-key: func [out [string!] key [file! string!]][
		repend out ["<key>" xml-escape form key "</key>^/"]
	]

	append-data: func [out [string!] data [binary!]][
		repend out ["<data>" base64 data "</data>^/"]
	]

	build-resource-envelope: func [
		resources [block!]
		nested-code [block!]
		/local out entry path data hash1 hash2
	][
		resources: sort/compare copy/deep resources :compare-entry
		nested-code: sort/compare copy/deep nested-code :compare-entry
		out: make string! 4096
		append out xml-header
		append out "<key>files</key>^/<dict>^/"
		foreach entry resources [
			path: pick entry 1
			data: pick entry 2
			append-key out path
			append-data out checksum data 'SHA1
		]
		append out "</dict>^/<key>files2</key>^/<dict>^/"
		foreach entry nested-code [
			append-key out pick entry 1
			append out "<dict>^/<key>cdhash</key>^/"
			append-data out pick entry 2
			append out "<key>requirement</key>^/"
			repend out ["<string>" xml-escape pick entry 3 "</string>^/</dict>^/"]
		]
		foreach entry resources [
			path: pick entry 1
			data: pick entry 2
			hash1: checksum data 'SHA1
			hash2: checksum data 'SHA256
			append-key out path
			append out "<dict>^/<key>hash</key>^/"
			append-data out hash1
			append out "<key>hash2</key>^/"
			append-data out hash2
			append out "</dict>^/"
		]
		append out "</dict>^/"
		append out rules
		append out xml-footer
		to binary! out
	]

	read-le32: func [data [binary!] offset [integer!]][
		to integer! reverse copy/part at data (offset + 1) 4
	]

	read-be32: func [data [binary!] offset [integer!]][
		to integer! copy/part at data (offset + 1) 4
	]

	code-directories: func [
		image [binary!]
		/local count command-index command-offset command command-size signature-offset signature-size
			blob-count index slot blob-offset blob-length directories
	][
		unless (copy/part image 4) = #{CFFAEDFE} [
			make error! "nested code is not a little-endian 64-bit Mach-O image"
		]
		count: read-le32 image 16
		command-offset: 32
		signature-offset: none
		repeat command-index count [
			command: read-le32 image command-offset
			command-size: read-le32 image (command-offset + 4)
			if any [command-size < 8 (command-offset + command-size) > length? image][
				make error! "invalid Mach-O load command while reading nested signature"
			]
			if command = 29 [
				signature-offset: read-le32 image (command-offset + 8)
				signature-size: read-le32 image (command-offset + 12)
			]
			command-offset: command-offset + command-size
		]
		if none? signature-offset [make error! "nested Mach-O code has no signature"]
		if (signature-offset + signature-size) > length? image [
			make error! "nested Mach-O code signature exceeds the file"
		]
		unless (read-be32 image signature-offset) = to integer! #{FADE0CC0} [
			make error! "nested Mach-O embedded signature is invalid"
		]
		blob-count: read-be32 image (signature-offset + 8)
		directories: make block! blob-count
		repeat index blob-count [
			slot: read-be32 image (signature-offset + 12 + ((index - 1) * 8))
			blob-offset: read-be32 image (signature-offset + 16 + ((index - 1) * 8))
			if any [slot = 0 all [slot >= 4096 slot < 4102]][
				blob-offset: signature-offset + blob-offset
				unless (read-be32 image blob-offset) = to integer! #{FADE0C02} [
					make error! "nested Mach-O CodeDirectory is invalid"
				]
				blob-length: read-be32 image (blob-offset + 4)
				append/only directories copy/part at image (blob-offset + 1) blob-length
			]
		]
		if empty? directories [make error! "nested Mach-O signature has no CodeDirectory"]
		directories
	]

	nested-code-entry: func [
		path [file! string!]
		image [binary!]
		/local directories directory hash-type digest hashes preferred requirement separator
	][
		directories: code-directories image
		hashes: make block! length? directories
		preferred: none
		foreach directory directories [
			hash-type: to integer! pick directory 38
			digest: switch/default hash-type [
				1 [checksum directory 'SHA1]
				2 [checksum directory 'SHA256]
			][make error! rejoin ["unsupported nested CodeDirectory hash type: " hash-type]]
			digest: copy/part digest 20
			append/only hashes digest
			if any [none? preferred hash-type = 2][preferred: digest]
		]
		requirement: make string! 96
		separator: ""
		foreach digest hashes [
			repend requirement [separator {cdhash H"} lowercase enbase/base digest 16 {"}]
			separator: " or "
		]
		reduce [to file! path preferred requirement]
	]
]
