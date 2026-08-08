Red [
	Title: "macOS bundle packager"
	File:  %Mach-APP.red
]

#if config/OS = 'macOS [
	#system-global [
		#import [
			LIBC-file cdecl [
				red-chmod: "chmod" [
					path [c-string!]
					mode [integer!]
					return: [integer!]
				]
			]
		]
	]
]

mach-app-packager: context [
	prepared: none
	join-file: func [base [file!] relative [file!]][append copy base relative]
	make-executable: #either config/OS = 'macOS [
		routine [path [file!] return: [logic!] /local value [red-file!]][
			value: as red-file! stack/arguments
			zero? red-chmod file/to-OS-path value 493		;-- 0755
		]
	][
		func [path [file!] return: [logic!]][true]
	]

	remove-tree: func [dir [file!] /local entry path][
		foreach entry read dir [
			path: join-file dir entry
			either dir? path [remove-tree path][delete path]
		]
		delete dir
	]

	copy-file: func [source [file!] target [file!]][
		write/binary target read/binary source
	]

	prepare: func [
		job [object!]
		source [file!]
		/local name executable-name output-dir icon-file icon-data plist-file plist-data identifier
			resources nested-code runtime-file code-resources signature data
	][
		name: form last split-path compiler-system-job/job-get job 'build-basename
		output-dir: compiler-system-job/job-get job 'build-prefix
		resources: make block! 1
		nested-code: make block! 1

		icon-data: none
		icon-file: clean-path append copy system/options/path
			%system/assets/macOS/Resources/AppIcon.icns
		if exists? icon-file [
			icon-data: read/binary icon-file
			append/only resources reduce [%Resources/AppIcon.icns icon-data]
		]

		plist-file: clean-path append copy system/options/path %system/assets/macOS/Info.plist
		data: read plist-file
		executable-name: mach-app-sign/executable-name name
		identifier: rejoin ["org.redlang." mach-app-sign/identifier-component name]
		replace/all data "$Red-App-Executable$" mach-app-sign/xml-escape executable-name
		replace/all data "$Red-App-Identifier$" identifier
		plist-data: to binary! data

		if compiler-system-job/job-get job 'dev-mode? [
			runtime-file: join-file output-dir %libRedRT.dylib
			unless exists? runtime-file [
				do make error! rejoin ["missing development runtime: " runtime-file]
			]
			append/only nested-code mach-app-sign/nested-code-entry
				%MacOS/libRedRT.dylib read/binary runtime-file
		]

		code-resources: mach-app-sign/build-resource-envelope resources nested-code
		signature: make object! [
			identifier: none
			info-hash1: none
			info-hash2: none
			resource-hash1: none
			resource-hash2: none
		]
		set in signature 'identifier identifier
		set in signature 'info-hash1 checksum plist-data 'SHA1
		set in signature 'info-hash2 checksum plist-data 'SHA256
		set in signature 'resource-hash1 checksum code-resources 'SHA1
		set in signature 'resource-hash2 checksum code-resources 'SHA256
		compiler-system-job/job-set job 'bundle-signature signature

		prepared: make object! [
			name: none
			executable-name: none
			identifier: none
			plist-data: none
			icon-data: none
			code-resources: none
		]
		set in prepared 'name name
		set in prepared 'executable-name executable-name
		set in prepared 'identifier identifier
		set in prepared 'plist-data plist-data
		set in prepared 'icon-data icon-data
		set in prepared 'code-resources code-resources
		prepared
	]

	process: func [
		job [object!]
		source [file!]
		executable [file!]
		/local parts output-dir name app-dir contents-dir bin-dir resources-dir
			signature-dir runtime-file bundle-executable data
	][
		parts: split-path executable
		output-dir: parts/1
		name: parts/2
		if any [none? prepared (get in prepared 'name) <> form name][prepare job source]
		app-dir: to-red-file to file! rejoin [form output-dir form name ".app/"]
		if exists? app-dir [remove-tree app-dir]

		contents-dir: join-file app-dir %Contents/
		bin-dir: join-file contents-dir %MacOS/
		resources-dir: join-file contents-dir %Resources/
		signature-dir: join-file contents-dir %_CodeSignature/
		make-dir/deep bin-dir
		make-dir/deep resources-dir
		make-dir/deep signature-dir

		bundle-executable: join-file bin-dir to file! get in prepared 'executable-name
		copy-file executable bundle-executable
		unless make-executable bundle-executable [
			do make error! rejoin [
				"cannot make bundle executable runnable: " bundle-executable
			]
		]
		delete executable

		if compiler-system-job/job-get job 'dev-mode? [
			runtime-file: join-file output-dir %libRedRT.dylib
			unless exists? runtime-file [
				do make error! rejoin ["missing development runtime: " runtime-file]
			]
			copy-file runtime-file join-file bin-dir %libRedRT.dylib
		]

		data: get in prepared 'icon-data
		if data [
			write/binary join-file resources-dir %AppIcon.icns data
		]
		write/binary join-file contents-dir %Info.plist get in prepared 'plist-data
		write/binary join-file signature-dir %CodeResources get in prepared 'code-resources

		app-dir
	]
]
