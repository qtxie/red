Red [
	Title: "Windows x64 hybrid compiler frontend/linker core"
	File:  %compiler-windows-hybrid-core.red
]

; Keep the hybrid package's source closure independent of the legacy emitter
; and per-function machine IR. Unsupported semantics fail in the direct RSIR
; frontend; neither legacy backend module is compiled into this entry.
#include %compiler-windows-common.red
#include %utils/libRedRT.red
#include %../compiler/system-diagnostics.red
#include %../compiler/rsir-frontend.red
#include %../compiler/codegen-bridge.red
#include %compiler-rsir-core.red
