Red [
	Title: "Saved Red frontend artifact test"
]

#include %../../../compiler/saved-frontend.red
#include %../../../compiler/bootstrap-options.red

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic!] message [string! block!]][
	unless condition [fail message]
]

root: clean-path to file! rejoin [system/options/path %../../../]
source: clean-path to file! rejoin [root %tools/self_hosting/fixtures/backend/rsir-empty-void.reds]
base: clean-path to file! rejoin [root %build/self-hosting/saved-frontend-test.reds]
dependency: clean-path to file! rejoin [
	root %build/self-hosting/saved-frontend-dependency.red
]
generated: compose/deep [
	Red/System []
	#script (dependency)
	fn: func [][]
]
redbin: #{01020304}
resources: [version [Title "test"]]

parsed: compiler-options/parse-args [
	"--loaded-red" "cached.reds" "-o" "compiler.exe" "compiler.red"
]
check all [
	object? parsed
	(compiler-options/option-get parsed 'loaded-red) = "cached.reds"
	(compiler-options/option-get parsed 'output) = "compiler.exe"
	(compiler-options/option-get parsed 'source) = "compiler.red"
]["--loaded-red option parsing failed"]
check error? compiler-options/parse-args ["--loaded-red"]
	"--loaded-red without a value was accepted"

files: reduce [
	base
	dependency
	compiler-saved-frontend/redbin-file base
	compiler-saved-frontend/resources-file base
	compiler-saved-frontend/manifest-file base
]
foreach file files [if exists? file [delete file]]
write dependency "dependency-v1"

check file? compiler-saved-frontend/write-artifacts
	base source generated redbin resources 'Windows-X86-64
	"could not write the saved frontend artifact set"
loaded: compiler-saved-frontend/load-artifacts base source 'Windows-X86-64
check all [
	block? loaded
	loaded/1 = base
	loaded/2 = 0:0:0
	loaded/3 = redbin
	loaded/4 = resources
]["saved frontend artifact set did not round-trip"]

write dependency "dependency-v2"
check none? compiler-saved-frontend/load-artifacts base source 'Windows-X86-64
	"stale frontend dependency passed manifest verification"
check (compiler-saved-frontend/last-error/message =
	"saved frontend dependency checksum mismatch")
	"stale frontend dependency returned the wrong diagnostic"
write dependency "dependency-v1"
check block? compiler-saved-frontend/load-artifacts base source 'Windows-X86-64
	"restored frontend dependency did not recover the artifact set"

write/append base " "
check none? compiler-saved-frontend/load-artifacts base source 'Windows-X86-64
	"corrupt generated source passed manifest verification"
check (compiler-saved-frontend/last-error/message =
	"saved frontend Red/System checksum mismatch")
	"corrupt generated source returned the wrong diagnostic"

foreach file files [if exists? file [delete file]]
print "PASS: saved Red frontend artifacts"
