Red [
	Title: "Windows x64 hybrid Red/System compiler"
	File:  %compiler-windows-hybrid-bootstrap.red
]

#include %compiler-windows-hybrid-core.red

; Native codegen verifies complete RSCG semantics before returning. The Red
; adapter retains bounded container and consumed-field checks only.
#include %../compiler/rscg-linker-adapter.red
#include %../compiler/codegen-bridge.red

set in compiler-hybrid-driver 'invoke-codegen func [ir config artifact diagnostics][
	codegen-module ir config artifact diagnostics
]
set in compiler-hybrid-driver 'invoke-adapter func [artifact job][
	compiler-rscg-linker-adapter/adapt artifact job
]
set in compiler-hybrid-driver 'adapter-message does [
	either compiler-rscg-linker-adapter/last-error [
		compiler-rscg-linker-adapter/last-error/message
	]["RSCG adapter failed without a diagnostic"]
]
set in compiler-hybrid-driver 'installed? true
