Red [Title: "source loader fixture"]

#if config/debug? [
	#include %child.red
]
#include-binary %payload.bin
#include %child.red
#system [
	#include %runtime-only.reds
]
