Red [
	Title: "Windows x64 hybrid compiler frontend/linker core"
	File:  %compiler-windows-hybrid-core.red
]

; Keep the hybrid package's source closure independent of the legacy emitter
; and per-function machine IR. Unsupported semantic paths fail in the RSIR
; sink; they are never satisfied by compiling either legacy backend module.
#include %compiler-windows-common.red
#include %utils/libRedRT.red
#include %compiler-rsir-core.red
