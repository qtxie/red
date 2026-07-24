Red [
	Title: "Self-hosted Red bootstrap environment"
	File:  %bootstrap-boot.red
]

#if any [not config/dev-mode? config/libRedRT?][
	#include %environment/datatypes.red
	#include %environment/actions.red
	#include %environment/natives.red
	#include %environment/routines.red
	#include %environment/scalars.red
	#include %environment/colors.red

	#register-intrinsics
	#include %environment/functions.red
	#include %environment/system.red
	#include %environment/operators.red

	#include %environment/codecs/PNG.red
	#include %environment/codecs/JPEG.red
	#include %environment/codecs/BMP.red
	#include %environment/codecs/GIF.red
	#include %environment/codecs/redbin.red

	#include %environment/reactivity.red
	#include %environment/networking.red
	#include %utils/preprocessor.r
	#include %environment/tools.red

	#if not find [Windows macOS Linux] config/OS [
		unset [event! image!]
		image?: func ["Returns true if the value is this type" value [any-type!]][false]
	]

	system/version: load system/version

	system/options/cache: either system/platform = 'Windows [
		append any [attempt [to-red-file get-env "APPDATA"] %./] %/Red/
	][
		append any [attempt [to-red-file get-env "HOME"] %/tmp] %/.red/
	]
]

; Bootstrap compiler executables need their command line in release mode too.
#if config/type = 'exe [
	system/script/args: #system [stack/push get-cmdline-args]
	extract-boot-args
]
