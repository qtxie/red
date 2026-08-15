Red [
	Title: "Windows x64 hybrid Red/System compiler"
	File:  %compiler-windows-hybrid-bootstrap.red
]

#include %compiler-windows-hybrid-core.red

; The adapter independently verifies a serialized RSCG object, so every Red
; verifier dependency is compiled into the hybrid package explicitly.
#include %../compiler/wire-file-source.red
#include %../compiler/wire-data-layout.red
#include %../compiler/wire-module-lifecycle.red
#include %../compiler/wire-rscg-object.red
#include %../compiler/wire-rscg-relocation.red
#include %../compiler/wire-rscg-metadata.red
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
