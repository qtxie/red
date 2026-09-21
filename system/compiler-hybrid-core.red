Red [
	Title: "Hybrid compiler frontend/linker core"
	File:  %compiler-hybrid-core.red
]

; Keep the hybrid package's source closure independent of the legacy emitter
; and per-function machine IR. Unsupported semantics fail in the direct RSIR
; frontend; neither legacy backend module is compiled into this entry.
#include %compiler-hybrid-common.red
#include %utils/libRedRT.red
#include %system-diagnostics.red
#include %codegen-bridge.red
#include %rsir-frontend.red
#include %compiler-rsir-core.red
