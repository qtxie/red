Red [
	Title: "Compiler backend ownership manifest"
	File:  %backend-ownership-spec.red
]

; Each dependency names its replacement contract and the number of executable
; references currently present in system/compiler-core.red.  Counts make a new
; use of an already-known emitter API visible to the audit.
compiler-backend-ownership-spec: [
	contracts [
		frontend "pure Red semantic/type/layout or driver state"
		rsir     "explicit backend-neutral semantic record or operation"
		codegen  "Red/System-derived ABI, frame, allocation, GC, or target state"
		rscg     "relocatable code/data/symbol/import artifact"
		adapter  "temporary conversion from RSCG to the legacy linker contract"
		linker   "final image construction after the RSCG boundary"
	]

	dependencies [
		frontend [
			"emitter"                              1
			"emitter/datatype-ID"                  1
			"emitter/datatype-ID/float!"           1
			"emitter/datatypes"                    1
			"emitter/get-size"                     1
			"emitter/member-offset?"               2
			"emitter/size-of?"                     1
			"emitter/struct-size?/check"           2
			"emitter/struct-size?/direct"          3
			"emitter/struct-slots?/check"          2
			"emitter/struct-slots?/direct"         2
			"emitter/target/bitwise-op"            1
			"emitter/target/comparison-op"         2
			"emitter/target/math-op"               1
			"emitter/target/ptr-size"              7
			"emitter/target/stack-width"          11
			"emitter/union-size?"                  2
		]

		rsir [
			"emitter/access-path"                                  2
			"emitter/branch/back/on"                               1
			"emitter/branch/back/on/adjust/parity"                 1
			"emitter/branch/back/on/parity"                        1
			"emitter/branch/over"                                  7
			"emitter/branch/over/adjust"                           1
			"emitter/branch/over/adjust/on/parity"                 1
			"emitter/branch/over/on"                               1
			"emitter/branch/over/on/adjust"                        1
			"emitter/branch/over/on/adjust/parity"                 2
			"emitter/branch/over/on/parity"                        2
			"emitter/breaks"                                       1
			"emitter/chunks/empty"                                 2
			"emitter/chunks/join"                                 18
			"emitter/chunks/make-boolean"                          1
			"emitter/chunks/start"                                 3
			"emitter/chunks/stop"                                  3
			"emitter/cont-back"                                    1
			"emitter/cont-next"                                    1
			"emitter/ensure-code-buf"                              1
			"emitter/exits"                                        1
			"emitter/libc-init?"                                   2
			"emitter/logic-to-integer/parity"                      2
			"emitter/logic-to-integer/with/parity"                 2
			"emitter/merge"                                       13
			"emitter/overflow-jumps"                               2
			"emitter/pop-loop-jumps"                               3
			"emitter/push-loop-jumps"                              3
			"emitter/resolve-loop-jumps"                           7
			"emitter/resolve-subrc-points"                         1
			"emitter/rodata?"                                      2
			"emitter/set-signed-state"                             7
			"emitter/start-epilog"                                 1
			"emitter/start-prolog"                                 1
			"emitter/store"                                        1
			"emitter/store-value"                                  2
			"emitter/store/protected"                              1
			"emitter/target/emit-alloc-stack"                      1
			"emitter/target/emit-atomic-cas"                       1
			"emitter/target/emit-atomic-fence"                     1
			"emitter/target/emit-atomic-load"                      1
			"emitter/target/emit-atomic-math"                      1
			"emitter/target/emit-atomic-store"                     1
			"emitter/target/emit-call"                             1
			"emitter/target/emit-call-sub"                         1
			"emitter/target/emit-casting"                          5
			"emitter/target/emit-clear-slot"                       1
			"emitter/target/emit-close-catch"                      1
			"emitter/target/emit-end-loop"                         1
			"emitter/target/emit-free-stack"                       1
			"emitter/target/emit-get-pc"                           1
			"emitter/target/emit-get-stack"                        1
			"emitter/target/emit-init-sub"                         1
			"emitter/target/emit-integer-operation"                5
			"emitter/target/emit-io-read"                          1
			"emitter/target/emit-io-write"                         1
			"emitter/target/emit-jump-point"                       3
			"emitter/target/emit-load"                             1
			"emitter/target/emit-load-literal"                     1
			"emitter/target/emit-load-union-tag"                   1
			"emitter/target/emit-load/with"                        1
			"emitter/target/emit-move-path-alt"                    2
			"emitter/target/emit-move-path-alt/pair"               1
			"emitter/target/emit-open-catch"                       1
			"emitter/target/emit-overflow-epilog-no-ovf"           1
			"emitter/target/emit-overflow-epilog-ovf"              1
			"emitter/target/emit-pop-all"                          1
			"emitter/target/emit-push-all"                         1
			"emitter/target/emit-return-sub"                       1
			"emitter/target/emit-start-loop"                       1
			"emitter/target/emit-switch-dispatch"                  1
			"emitter/target/emit-variant-check"                    1
			"emitter/target/on-global-epilog"                      3
			"emitter/target/on-global-prolog"                      1
			"emitter/target/on-root-level-entry"                   1
		]

		codegen [
			"emitter/arguments-size?"                              1
			"emitter/encode-ptr-bitmap"                            1
			"emitter/encode-ptr-bitmap/metadata"                   1
			"emitter/enter"                                        1
			"emitter/init"                                         1
			"emitter/leave"                                        1
			"emitter/push-struct"                                  1
			"emitter/push-struct-ref"                              1
			"emitter/push-struct/sysv"                             1
			"emitter/stack"                                        2
			"emitter/store-bitmaps"                                1
			"emitter/store-ptr-bitmap"                             1
			"emitter/target"                                       7
			"emitter/target/by-value-args"                         4
			"emitter/target/call-arg-index"                        3
			"emitter/target/call-arg-types"                        3
			"emitter/target/call-extra-slots"                      3
			"emitter/target/call-float-reg-count"                  3
			"emitter/target/call-pad-slots"                        3
			"emitter/target/call-shadow-slots"                     3
			"emitter/target/call-stack-slots"                      3
			"emitter/target/call-struct-temp-slots"                3
			"emitter/target/call-top-arg-rax?"                     2
			"emitter/target/call-variadic?"                        3
			"emitter/target/emit-argument"                         1
			"emitter/target/emit-epilog"                           3
			"emitter/target/emit-float-trash-last"                 1
			"emitter/target/emit-prolog"                           1
			"emitter/target/emit-release-stack"                    1
			"emitter/target/emit-reserve-stack"                    1
			"emitter/target/emit-restore-last"                     2
			"emitter/target/emit-save-last"                        2
			"emitter/target/emit-stack-align-epilog"               1
			"emitter/target/emit-stack-align-prolog"               1
			"emitter/target/last-math-op"                          2
			"emitter/target/last-red-frame"                        1
			"emitter/target/last-saved?"                           2
			"emitter/target/on-finalize"                           1
			"emitter/target/on-init"                               2
			"emitter/target/PIC?"                                  2
			"emitter/target/saved-last-wide?"                      2
			"emitter/target/signed?"                               1
			"emitter/target/stateful-calls?"                       1
			"emitter/target/sysv-aggregate-classes"                2
		]

		rscg [
			"emitter/add-native"   2
			"emitter/code-buf"     4
			"emitter/data-buf"     3
			"emitter/import"       1
			"emitter/import/var"   1
			"emitter/rodata-buf"   2
			"emitter/symbols"      6
			"emitter/tail-ptr"     5
		]

		adapter [
			"emitter/reloc-native-calls" 1
		]

		; The linker consumes the adapter result.  It must not own a direct
		; compiler-core -> emitter dependency in the replacement architecture.
		linker []
	]
]
