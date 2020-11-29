Rebol [
	Title:   "Red binary build script"
	Author:  "Xie Qingtian"
	File: 	 %build-red.r
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2020 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

comment {
1. Open a Rebol console, and CD to the **%build/** folder.

        >> change-dir %<path-to-Red>/build/

2. Run the build script from the console:

        >> do/args %build-red.r "path-to-rebol"
        
3. After a few seconds, a new **red** binary will be available in the **build/bin/** folder.

4. Enjoy!
}

rebol-bin: read/binary to-rebol-file system/script/args
src-files: pick load %includes.r 8

;-- save source files
red-repo: make block! 20
save-files: func [out src-files /local f][
	foreach f src-files [
		either block? f [
			change-dir last out
			append/only out make block! 20
			save-files last out f
			change-dir %..
		][
			append out f
			unless dir? f [append out read/binary f]
		]
	]
]
change-dir %..		;-- change to the root directory of red repo
save-files red-repo src-files

script: [Red [Needs: view]
	red-toolchain: none
	red-toolchain?: yes
	#include %../environment/console/CLI/console.red
]
poke script 4 reduce [rebol-bin red-repo]

change-dir %build/
red-src: %red.red
save red-src script

print "Encapping..."
system/options/args: none
do/args %../red.r join "-r " red-src

if system/version/4 <> 3 [	;-- Unix OSes
	call/wait "chmod 755 ./red"
]