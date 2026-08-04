Red [
	Title: "macOS bundle packager"
	File:  %Mach-APP.red
]

mach-app-packager: context [
	join-file: func [base [file!] relative [file!]][append copy base relative]

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

	process: func [
		job [object!]
		source [file!]
		executable [file!]
		/local parts output-dir name app-dir contents-dir bin-dir resources-dir
			icon-file plist-file plist runtime-file
	][
		parts: split-path executable
		output-dir: parts/1
		name: parts/2
		app-dir: to-red-file to file! rejoin [form output-dir form name ".app/"]
		if exists? app-dir [remove-tree app-dir]

		contents-dir: join-file app-dir %Contents/
		bin-dir: join-file contents-dir %MacOS/
		resources-dir: join-file contents-dir %Resources/
		make-dir/deep bin-dir
		make-dir/deep resources-dir

		copy-file executable join-file bin-dir name
		delete executable

		if compiler-system-job/job-get job 'dev-mode? [
			runtime-file: join-file output-dir %libRedRT.dylib
			unless exists? runtime-file [
				do make error! rejoin ["missing development runtime: " runtime-file]
			]
			copy-file runtime-file join-file bin-dir %libRedRT.dylib
		]

		icon-file: clean-path append copy system/options/path %system/assets/macOS/Resources/AppIcon.icns
		if exists? icon-file [
			copy-file icon-file join-file resources-dir %AppIcon.icns
		]
		plist-file: clean-path append copy system/options/path %system/assets/macOS/Info.plist
		plist: read plist-file
		replace/all plist "$Red-App-Name$" form name
		write/binary join-file contents-dir %Info.plist to binary! plist

		app-dir
	]
]
