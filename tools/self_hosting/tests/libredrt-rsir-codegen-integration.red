Red [
	Title: "Direct libRedRT RSIR native codegen integration"
]

#include %../../../compiler/codegen-bridge.red

root: either all [block? system/options/args not empty? system/options/args][
	clean-path to-red-file to file! system/options/args/1
][system/options/path]
change-dir root

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

input: %build/self-hosting/libredrt-rsir/libRedRT.rsir
output: %build/self-hosting/libredrt-rsir/libRedRT.image
unless exists? input [fail ["missing frontend RSIR: " mold input]]

ir: read/binary input
image: make binary! 32'000'000
status: codegen-module ir image 1 1
unless status = 0 [fail ["libRedRT native codegen status=" status]]
write/binary output image

print [
	"PASS: direct libRedRT RSIR -> native image"
	length? image "bytes"
]
