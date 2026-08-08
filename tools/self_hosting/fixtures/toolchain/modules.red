Red [
	Title: "Standalone toolchain module fixture"
	Needs: [JSON CSV]
]

unless {"toolchain"} = to-json "toolchain" [quit/return 1]
unless "1,2,3^/" = to-csv [1 2 3] [quit/return 2]
print "RED-TOOLCHAIN-MODULES-OK"
