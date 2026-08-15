Red [
	Title: "Seal legacy --red-only output for the hybrid backend"
]

#include %../../compiler/saved-frontend.red

fail: func [message][
	print ["*** saved frontend error:" message]
	quit/return 1
]

args: any [system/options/args copy []]
unless (length? args) = 3 [
	print "Usage: seal-saved-frontend generated.reds original.red Windows-X86-64"
	quit/return 2
]

root: clean-path to file! rejoin [system/options/path %../../]
resolve-input: func [raw /local candidate][
	candidate: clean-path to-red-file to file! raw
	if exists? candidate [return candidate]
	clean-path to file! rejoin [root to-red-file to file! raw]
]

generated: resolve-input args/1
source: resolve-input args/2
target: to word! args/3
unless compiler-saved-frontend/seal-existing generated source target [
	fail compiler-saved-frontend/last-error/message
]
print ["Sealed saved frontend:" generated]
quit/return 0
