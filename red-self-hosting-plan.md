# Red Self-Hosting Plan

## Objective

Replace every active Rebol host script with Red code, then prove that a Red-built
compiler can rebuild the same compiler without invoking Rebol.

This plan distinguishes two goals:

1. **Self-hosted compiler:** one normally compiled Red command-line program
   contains the Red front end, Red/System compiler, linkers, formats, and
   targets, and can rebuild itself without the Rebol SDK encapper.
2. **Rebol-free repository:** build scripts, generators, test runners, and
   documentation tools are also ported, so `git ls-files '*.r'` is empty.

The first goal is the bootstrap-critical path. The second goal finishes the
migration and prevents Rebol from remaining an implicit maintenance dependency.

## Current Cutover Decision

As of 2026-07-30, Windows x64 has reached a normalized self-hosting fixed point.
The canonical path
`build/self-hosting/red-bootstrap-stage1-x64-gc-fixed.exe` now contains the
tested Stage5 image. Its SHA-256 is
`4916BF13E1E9DD52582364C990D1C96AACE96DCD74746AE341CB36FC49FEE589`.
The legacy `stage1` filename is retained for command compatibility; it no longer
describes the artifact's generation.

- All normal Windows x64 compiler, runtime, and test builds use this self-hosted
  compiler.
- Stage4 and Stage5 differ in only eight documented build-specific bytes and
  have identical SHA-256 hashes after those bytes are normalized.
- Rebol Stage0 is excluded from normal build, test, parity, and debugging work.
  The old seed is preserved only for explicitly requested recovery or history.
- Other targets must be added to the Red-hosted compiler; they do not justify
  restoring Stage0 to the primary workflow.
- References below to Rebol behavior remain migration history unless a section
  explicitly identifies an unfinished source-port task.

## Implemented Checkpoints

The Windows x64 transition now has a compiled, Red-hosted bootstrap foundation:

- `build/self-hosting/red-bootstrap-stage1-x64-gc-fixed.exe` is the Stage5
  PE32+ x64 compiler built from the Red frontend and Red/System backend.
- It passes all 59 configured non-View Red unit programs in development mode:
  8,802 tests and 16,850/16,850 assertions.
- It passes the Windows x64 Red/System suite: 10,575 tests and
  12,640/12,640 assertions.
- It passes the release-mode `points-test`: 142/142 assertions.
- It builds the PE32+ x64 `libRedRT.dll` used by development mode, including the
  CSV and JSON codecs.
- Startup GC remains active while the self-hosted compiler builds and runs these
  tests. Disabling GC is not part of the supported bootstrap path.
- Stage4 builds Stage5 with GC active through 541 collector cycles.
- Stage4 and Stage5 are byte-identical after normalizing the PE
  timestamp/checksum, embedded output name, and embedded build time.
- The active driver is `red-bootstrap-windows.red`; the compiler frontend,
  Red/System compiler, x64 target, PE linker, and runtime builder are Red
  sources in the current tree.

## Completion Criteria

The migration is complete only when all of the following are true:

- A fixed, checksummed self-hosted bootstrap executable builds its successor from a clean
  checkout without Rebol installed or available on `PATH`.
- The successor builds one more generation from the same sources and manifest.
- Consecutive generations produce identical normalized compiler intermediates and
  identical binaries after excluding only documented, intentional metadata. The
  end goal is bit-for-bit equality.
- The self-hosted compiler passes the existing Red and Red/System compiler,
  runtime, quick-test, target, shared-library, static-link, and View test lanes
  applicable to each supported host.
- No bootstrap or production load trace opens an `.r` file.
- `git ls-files '*.r'` returns no paths. Historical Rebol sources remain
  available in Git history rather than in the active tree.
- CI has no `rebview`, `rebcmdview`, `rebol`, Rebol SDK, `red.r`, or `.r` source
  dependency.
- `build/build.r`, `build/precap.r`, `build/includes.r`, `utils/encap-fs.r`, and
  the Rebol-specific `utils/call.r` have no Red ports because their jobs are
  replaced by normal Red compilation, compiled includes, and native Red APIs.

## Evidence From The Previous Ports

The cited work contains two different approaches. Both are useful, but neither
is a suitable branch to merge wholesale into the current tree.

| Commit | What it established | Lesson to retain |
| --- | --- | --- |
| `688f2bdc4` | Added a close Red translation of the Rebol-hosted Red/System compiler, driver, IA-32 backend, PE/ELF emitters, linker, loader, and utilities. | A direct, component-for-component port is feasible and gives the smallest parity gap. |
| `2be73823d` | Corrected Red/Rebol differences in get-path handling, namespace sorting, float serialization, logic conversion, and object construction. | Textual translation is insufficient; host-language semantic tests must precede bulk conversion. |
| `7f40ded64` | Corrected byte/character emission and integer conversion behavior. | Binary emitters need byte-level golden tests, not only compile-success tests. |
| `9ca25c9c4` | Added a Red ARM target translation. | Backend ports can proceed independently once the compiler/emitter contract is stable. |
| `40d1bc6fe` | Forked the experiment into `system2`, later replacing much of the high-level compiler with a Red/System parser, type checker, IR, optimizer, register allocator, and x86 code generator. | The explicit IR architecture is valuable, but it is a compiler redesign and must not be the parity-critical migration path. |
| `d85b45196` | Added a close Red translation of the Red compiler plus Red versions of extractor, preprocessor, and Redbin utilities. | It identifies the real bootstrap cycles: binding identity, generated runtime IDs, preprocessing the preprocessor, and invoking the new Red/System compiler. |

The unfinished parts are as important as the translated code:

- `encapper/compiler.red` used a low-level `bind?` routine that fabricated an
  object-shaped value around a word context. Binding identity needs a supported,
  GC-safe runtime API instead.
- `utils/extractor.red` hard-coded runtime/action/native IDs that the Rebol
  version extracted from source. Those values would drift as the runtime changes.
- `preprocess-strings` was empty and source loading bypassed
  `encapper/lexer.r` by calling `load`, losing the compiler's canonical lexical
  behavior and source metadata.
- Dynamic-path emission, `libRedRT`, developer mode, cache lookup, resource
  collection, and several save/import paths were commented out or bypassed.
- A `#self-compiling` directive suppressed directives and `#get-definition`
  expansion rather than resolving the dependency cycle explicitly.
- The branch CI still ran `rebview.exe -qws red.r -r red.red`; it built a Red
  program containing the experimental Red/System compiler but did not prove a
  Red compiler could rebuild itself.
- The WIP Red compiler files received no follow-up changes after `d85b45196`.

The current branch diverged from that work at `2e6c84064`. Since then, the
current side has accumulated x86-64, ARM64, Mach-O ARM64, object-format, static
linking, fixed-width integer, runtime, and test work that is absent or incomplete
in the experimental port. The migration therefore starts from the current tree.

## Current Migration Surface

The current tracked tree contains:

- 139 `.r` files and 67,225 lines in total.
- 53 non-test/documentation `.r` files and 55,861 lines.
- About 12,469 of those production lines are generated export tables or other
  mostly declarative data.
- About 43,392 lines are active production/build code requiring a semantic port.

The bootstrap-critical source groups are:

| Group | Current source |
| --- | --- |
| Driver and front end | `red.r`, `encapper/compiler.r`, `encapper/lexer.r`, `encapper/modules.r`, `encapper/version.r` |
| Compiler utilities | `utils/extractor.r`, `utils/preprocessor.r`, `utils/redbin.r` |
| Red/System core | `system/compiler.r`, `system/config.r`, `system/emitter.r`, `system/loader.r`, `system/linker.r`, `system/linker-static.r` |
| Native targets | `system/targets/IA-32.r`, `ARM.r`, `X86-64.r`, `ARM64.r`, and `target-class.r` |
| Binary formats | PE, ELF, COFF, ELF object, Mach-O, Mach-O object/ARM64/signing, Intel HEX, and application packaging under `system/formats/` |
| Compiler support | Files under `system/utils/`, including `libRedRT`, SHA-256, profiling, Unicode, integer/float encoding, and virtual structures |
| Rebol infrastructure to retire | `build/build.r`, `build/includes.r`, `build/precap.r`, `utils/encap-fs.r`, and `utils/call.r` |

The remaining `.r` files are test runners and generators, Quick Test, root test
entry points, the Android build helper, and the MakeDoc tool. They are not needed
to produce the first self-hosted compiler, but they are required for the final
Rebol-free-tree criterion.

## Architectural Decision

Use a **parity-first reimplementation of the current compiler** as the critical
path. The verified Windows x64 fixed-point compiler and current `HEAD` define the
active observable contract, not the shape of the implementation. The committed
Rebol sources remain useful algorithm and migration references, but executing
Stage0 is no longer a normal parity step. Porting a function literally is
optional; simplifying the data flow, removing compatibility scaffolding,
precomputing tables, and using faster algorithms are expected when the
differential gates stay green.
Selectively reuse the best algorithms from `system2` when their contracts are
covered; do not require the unfinished `system2` rewrite as a prerequisite.

Parity applies to the compiler's observable contract, not to Rebol host
implementation details. Use Red's native process, filesystem, module, error,
and compiled-include facilities directly. Do not recreate the Rebol SDK
encapper, its virtual filesystem/cache, `build.r`, or compatibility versions of
functions that Red already provides.

Reasons:

- The Windows x64 fixed-point compiler is the current tested implementation and the
  seed from which the next compiler generation is built.
- A parity-first reimplementation permits component-by-component differential
  testing against that recorded seed while leaving room for a smaller and
  faster Red design.
- Replacing the host language and the compiler architecture simultaneously
  makes failures difficult to localize.
- Self-hosting requires the compiler to be implemented in Red; it does not
  require the entire compiler to be rewritten in Red/System.
- The `system2` parser, typed IR, optimizer, and register allocators remain good
  candidates for later performance work once parity and bootstrap stability are
  established.

During migration, keep sibling `.r` and `.red` implementations only for the
component currently under differential testing. Each vertical slice should
switch its consumers to `.red` and then remove its `.r` source promptly. Avoid a
long-lived pair of manually synchronized compiler trees.

The existing `encapper/` name is historical. Move the translated compiler code
to `compiler/` as slices become independent; `compiler/frontend.red` is the
successor of `encapper/compiler.r`, not a new encapping layer.

## Non-Negotiable Invariants

1. **Current behavior is the oracle.** Use the verified x64 self-hosted behavior and
   current `HEAD`, not old snapshots or an unrecorded Stage0 result.
2. **No silent feature cuts.** A port may not comment out developer mode,
   dynamic paths, resources, `libRedRT`, compression, target formats, or errors
   merely to reach bootstrap.
3. **Canonical lexical behavior.** The compiler must use the ported lexer and
   preprocessor. Host `load` is not a replacement for compiler tokenization.
4. **One source of runtime IDs.** Datatype, action, and native IDs are extracted
   from canonical runtime source with `transcode`; they are never copied by hand
   or duplicated in a generated compiler file.
5. **Supported binding identity.** Add or expose an opaque, GC-safe context
   identity API. Never transport context or object pointers through `integer!`
   and never fabricate a Red object cell on the stack.
6. **Target-neutral integer rules.** Preserve signed 32-bit `integer!` behavior
   and keep addresses in pointer-typed values, especially on x86-64 and ARM64.
7. **Explicit Red/System grouping.** Parenthesize expressions whose meaning
   could be mistaken for C-style precedence. Add conformance tests for
   left-to-right evaluation, `case`, `switch`, pointer scaling, one-based path
   access, casts, and padded struct layout.
8. **Deterministic inputs.** Sort directory-derived manifests, normalize path
   separators and line endings at defined boundaries, and isolate timestamps and
   Git metadata from compiler semantics.
9. **No duplicated runtime tree.** Generate a deterministic runtime bundle from
   canonical `runtime/` and `system/runtime/` sources instead of maintaining a
   copied `system2/runtime/` tree.
10. **Every milestone is bisectable.** Keep the recorded recovery seed and the
    completed Windows x64 test gates green until its successor passes them.
11. **No Rebol compatibility substrate.** Replace Rebol-only plumbing with a
    small Red-native boundary or delete it. Compatibility code is justified only
    when a compiler-visible semantic difference has a failing parity test.
12. **Simplify before optimizing.** Prefer immutable/generated registries,
    typed phase records, linear source scans, and explicit phase boundaries over
    reflective `do`/`load` dispatch, repeated hash construction, or cache layers
    inherited from Rebol. Every such change needs a parity test and a measured
    before/after benchmark; never trade correctness for a faster smoke test.

## Red Compiler Improvement Finding

Observed on 2026-07-19: interpreted Red can invoke a function through an object
slot whose initial value is `none` and whose object value is injected later, but
compiled Red does not reliably retain that call shape. An expression such as
`service/method argument` can be compiled as a function value or can make an
enclosing `if`, `either`, `case`, or `foreach` appear malformed because the
compiler cannot determine the method arity from the slot's original shape.

The migration workaround is to give compiler services a statically known object
shape. Bootstrap-critical singleton services use direct paths such as
`compiler-system-types/integer-type? value`; replaceable target objects inherit a
base contract that declares every shared field and method. Do not use reflective
`do` or `apply` merely to hide this limitation.

The compiler improvement target is to support runtime object-method dispatch
when the receiver slot is initially `none`, or reject it with a precise compile
diagnostic rather than silently treating the method as a value. The minimal
reproduction is
`tools/self_hosting/fixtures/host-contract/dynamic-object-method.red`. Its
acceptance criterion is identical output (`42`) in interpreted and compiled Red.

The compiled full backend also reaches Red's global-variable-space ceiling after
including the current linker, object readers, PE/ELF/Mach-O formats, and embedded
assets. This is a compiler capacity issue rather than a backend parity failure;
until the limit is raised or globals are packed, the supported bootstrap check is
the interpreted complete backend plus the compiled core executable.

The local language contract is `docs/red-system/red-system-specs.txt`; the
published form is <https://static.red-lang.org/red-system-specs.html>.

## Bootstrap Model

Use explicit names for each compiler generation:

```text
Stage0 recovery seed -> Stage1 -> Stage2 -> Stage3 -> Stage4 -> Stage5
                                                       |          |
                                                       + fixed point
```

- **Stage5** is the compiler currently stored at the canonical compatibility
  path `red-bootstrap-stage1-x64-gc-fixed.exe`.
- **Stage4/Stage5** are the proven normalized fixed-point pair.
- **Stage1 through Stage3** are transition generations retained only as build
  lineage and diagnostic artifacts.
- **Stage0** is outside the normal chain. It may be used only for an explicitly
  requested recovery or historical audit and its output is not a release gate.

The source manifest, target registry, build options, and bootstrap seed hash
must be recorded beside each stage. The direct
entrypoint uses normal compiled includes for its static implementation closure;
runtime sources remain canonical files read through the verified manifest. A
stage must not consume files from a previous stage's cache.

CI and developer builds start from the versioned self-hosted bootstrap binary
with a published checksum. Seed provenance is protected by its recorded source
revision, build command, complete test totals, and Stage4/Stage5 fixed-point
rebuilds. A diverse-compiler audit may be performed separately, but it must not
restore Rebol as a normal build dependency.

## Work Plan

### Milestone 0: Freeze The Oracle And Add Differential Infrastructure

Primary work:

- Record the current source/target manifest and classify every `.r` file as
  executable code, declarative data, generator, test runner, or historical tool.
- Build a representative corpus from `system/tests/source/compiler/`,
  `system/tests/source/units/`, `tests/source/compiler/`, and core Red tests.
- Add a differential runner capable of invoking two compiler commands and
  retaining structured results: exit category, diagnostics, expanded source,
  Red compiler output, Red/System code/data buffers, relocations, final binary
  metadata, and runtime output.
- Normalize only known nondeterminism such as timestamps, absolute paths, and
  platform-specific binary signing fields. Keep raw artifacts on failure.
- Add a load tracer and a static dependency scanner for `.r` files and Rebol-only
  words/APIs.
- Add a dependency-closure consistency test so every entrypoint include and
  target/config-referenced target, format, runtime, and asset is declared
  exactly once. The generated manifest verifies normal compiled includes; it is
  not an encapper input bundle.

Gate:

- The fixed-point baseline compared with itself produces an empty differential
  report. Later candidates use the same artifact schema.
- The corpus covers every current Red/System target class and binary format,
  even where a target is compile-only in CI.

### Milestone 1: Define The Red Host Contract

Primary work:

- Add focused tests that document every Rebol behavior used by the compiler and
  its intended Red equivalent: binding/copying, context identity, series mutation,
  hash lookup/order, error capture, Parse rules, path/file normalization,
  process invocation, floating-point byte encoding, characters/binaries, and
  command-line tokenization.
- Track dynamic object-method invocation when the receiver slot is initially
  `none`. Until the compiler accepts the host-contract fixture in compiled mode,
  compiler services must expose statically declared method shapes.
- Implement a small Red host-support module for the proven gaps only. Do not
  attempt to emulate Rebol generally.
- Add a supported runtime primitive or refactor for opaque word/context binding
  identity. Cover global, object, function, inherited-object, copied-block, and
  rebound-word cases, including GC between lookup and comparison.
- Replace `system/version`, `system/components`, `to-rebol-file`, `get-modes`,
  `disarm`, `parse/all`, and Rebol library-call assumptions with native Red APIs
  at a single boundary.
- Add a source lint for Red/System hazards called out by the specification:
  ambiguous unparenthesized expressions, non-literal `switch` labels, missing
  `true` catch-all branches in potentially unmatched `case` expressions,
  invalid path indexing, pointer/integer confusion, and unsafe numeric casts.

Gate:

- The host-contract suite passes both interpreted and compiled Red.
- No compatibility helper exposes a raw runtime pointer as a Red `integer!`.

### Milestone 2: Port Lexing, Preprocessing, Extraction, And Redbin

Primary files:

- `encapper/lexer.r` -> `compiler/lexer.red`
- `utils/preprocessor.r` -> `compiler/preprocessor.red`
- `utils/extractor.r` -> `compiler/extractor.red`
- `utils/redbin.r` -> `compiler/redbin.red`

Primary work:

- Port the real lexer, including UTF-8 handling, newline flags, source locations,
  compiler directives, special floats, dates, strings, and malformed-input
  diagnostics. Do not use `load` as a compatibility shortcut.
- Make preprocessor self-application an explicit build step with input/output
  artifacts rather than toggling `#process` around large source regions.
- Extract compiler runtime IDs directly from `runtime/macros.reds` with
  `transcode`, and derive scalar types and currencies from their canonical
  environment declarations once per compiler process.
- Port Redbin with byte-for-byte tests for every datatype, binding graph,
  newline flag, module/root reference, compression mode, NaN/infinity/negative
  zero, and cyclic/shared data case.
- Validate extracted ID counts and sentinel values before compilation so a
  bootstrap compiler reports malformed or incompatible runtime declarations.

Gate:

- The Stage1 baseline and candidate lexers emit identical normalized
  token/value/location streams for the corpus.
- Both preprocessors emit structurally identical blocks and identical error
  locations.
- Redbin output is byte-identical, and each implementation can decode the
  other's output.
- Changing a runtime ID is observed immediately by the compiler and parity tests.

### Milestone 3: Port The Red/System Compiler Core For IA-32

Primary files:

- `system/utils/*.r`
- `system/config.r`, `system/loader.r`, `system/compiler.r`
- `system/targets/target-class.r`
- `system/emitter.r`
- `system/targets/IA-32.r`

Primary work:

- Treat current `HEAD` versions of the `.r` files as the sole behavioral source.
  Use the direct translations in `688f2bdc4` through `7f40ded64` only to identify
  host-language substitutions such as `load` to `transcode`, object construction,
  path conversion, and Red-native API reuse. A three-way merge may replay those
  substitutions from their common ancestor onto current code, but no historical
  method body is accepted when it differs from current `HEAD`.
- Port utilities first: integer and IEEE encoding, Unicode, secure paths,
  virtual structures, SHA-256, profiling, and `libRedRT` metadata.
- Port loader/preprocessor integration, type resolution, compiler core, target
  contract, emitter, and IA-32 backend in that order.
- Add component checkpoints after load, preprocessing, type checking, emitted
  code/data, symbol collection, and relocation collection.
- Run every existing Red/System compiler and IA-32 unit test through both
  implementations. Compare diagnostics for negative tests as well as output for
  positive tests.

Gate:

- The Red-hosted compiler passes the complete existing IA-32 Red/System suite on
  Windows and Linux in interpreted and compiled forms.
- Code/data buffers and relocation records match the Stage1 baseline, or each
  reviewed difference has an explicit test proving equivalent behavior.

### Milestone 4: Port Linkers, Formats, And Remaining Targets

Port in independently gated slices:

1. PE and ELF executable/dynamic-library linking for IA-32.
2. ARM and its ELF/runtime paths.
3. COFF, ELF object, Mach-O object, and `system/linker-static.r`.
4. X86-64 plus ELF64/PE32+ and current ABI/PIE/PIC behavior.
5. ARM64 plus ELF64 and Mach-O ARM64, application packaging, and signing.
6. Intel HEX and remaining platform/package formats.

For declarative export tables, regenerate Red data artifacts rather than
hand-editing thousands of lines. Port their generators and compare sorted
symbols, ordinals, aliases, and hashes with the current files.

The `system2` x86 parser/IR/register-allocation code may be imported behind an
experimental switch only after its input/output contract is covered by the same
differential runner. It must not remove any target or format from this milestone.

Gate for each slice:

- All applicable compiler/unit tests pass.
- Produced binaries pass format inspection (`dumpbin`, `readelf`, `objdump`,
  `otool`, and `codesign` as applicable), load/run on a native target runner,
  and preserve current import/export/relocation behavior.
- Existing IA-32 and ARM lanes remain green after shared compiler/emitter changes.

### Milestone 5: Port The Red Compiler Front End

Primary files:

- `encapper/compiler.r` -> `compiler/frontend.red`
- `encapper/modules.r` -> `compiler/modules.red`
- `encapper/version.r` -> a generated or literal version value in the direct
  entrypoint

Primary work:

- Use `d85b45196` as a behavior/change checklist, not as the new file. Rebuild
  the current 5,000-line compiler as smaller phase-oriented Red modules and
  retain all behavior added since the historical branch point.
- Consume the real lexer, preprocessor, Redbin encoder, canonical runtime-ID
  extractor, and ported Red/System compiler.
- Replace `rebol-gctx`/`bind?` assumptions with the supported binding identity
  API from Milestone 1.
- Preserve dynamic paths, module/resource collection, developer and release
  modes, `libRedRT`, compression, Redbin, errors, and source-line behavior.
  Replace source-cache and encap branches with direct filesystem/manifest code.
- Remove the `#self-compiling` suppression mechanism. Bootstrap-only generated
  data must enter through an explicit manifest/input, not altered compiler
  semantics.
- Add checkpoints for compiler output blocks, deferred function bodies,
  literals, symbol/context tables, Redbin payload, resources, and generated
  Red/System source.
- Record phase timings and peak working-set data for the Stage1 baseline and
  candidate implementation. A rewrite may change algorithms freely, but each
  accepted slice must match or improve the documented baseline on its
  representative corpus.

Gate:

- The complete Red compiler regression suite passes through both front ends.
- For the core corpus, normalized generated Red/System and Redbin are identical.
- Release, development, debug, module, `libRedRT`, Red-only, and
  show-expanded modes have explicit passing integration tests.

### Milestone 6: Promote The Direct Driver And Retire The Rebol Build

Status: complete for the normal Windows x64 path. Follow-up cleanup remains for
other targets and auxiliary scripts.

Primary files:

- `red.r` -> temporary `red-selfhost.red`, then final `red.red`
- Delete `utils/call.r` in favor of native Red `call` once no Rebol consumer
  remains.
- Delete `build/includes.r`, `build/precap.r`, and `build/build.r`; do not port
  them. Replace `build/git-version.r` with an explicit generated metadata input
  or omit Git metadata from reproducible bootstrap builds.

Primary work:

- Port all command-line parsing and target selection, preserving current option
  compatibility and exit codes.
- Compile the static compiler implementation with ordinary `#include`
  directives from `red-selfhost.red`. Verify that include closure against the
  generated, sorted source manifest from Milestone 0.
- Read canonical runtime sources through the verified manifest; do not create an
  encap cache or duplicate runtime source under another compiler directory.
- Make Git version, build date, signing, and output paths explicit inputs so
  reproducibility tests can substitute deterministic values.
- Use the verified canonical compiler to build the next generation. The standard Windows x64 command
  is:

  ```powershell
  build\self-hosting\red-bootstrap-stage1-x64-gc-fixed.exe `
      -r -d -t Windows-X86-64 `
      -o build\self-hosting\red-bootstrap-next-x64.exe `
      red-bootstrap-windows.red
  ```

- The candidate must expose the same command interface and build its successor from the exact
  same manifest and options.

Gate:

- The canonical compiler supports the required Windows x64 CLI and passes the complete Red and
  Red/System Windows x64 test matrices recorded above.
- A candidate matches or improves the recorded compiler-phase benchmark, or
  includes a reviewed explanation and follow-up issue for any intentional
  regression.
- A clean build produces no untracked source/cache files outside a designated
  build directory.

### Milestone 7: Close The Bootstrap Loop (Windows x64 complete)

Primary work:

- Starting from the recorded recovery seed, build successive generations in
  fresh directories with empty caches.
- Compare source manifests, generated definitions, expanded compiler source,
  Red compiler output, Red/System IR/code/data/relocations, and final binaries at
  each stage.
- Run the fixed-point generations against the full compiler/runtime corpus through the
  Red differential harness, not only a hello program or compiler smoke test.
  Legacy test-runner parity moves to Milestone 8 where those runners are still
  being ported.
- Run the build in an environment where Rebol executables are absent and network
  access is disabled after the self-hosted bootstrap seed is supplied.
- Run a filesystem trace that fails on an attempted `.r` open or undeclared
  input.
- Investigate every consecutive-generation difference. Maintain a short, machine-readable
  normalization list; do not normalize code, data, symbols, or relocations.

Gate:

- Stage4 and Stage5 reach the fixed-point criteria in the Completion Criteria.
- All bootstrap-critical compiler, runtime, target, and format tests pass under
  the Red harness without a Rebol process.

### Milestone 8: Port Tests, Generators, Documentation, And Auxiliary Scripts

Primary work:

- Port `quick-test/*.r`, root test entry points, `tests/**/*.r`, and
  `system/tests/**/*.r` to Red while preserving command-line behavior and result
  accounting.
- Port all auto-test generators and compare generated `.reds`/`.red` fixtures
  byte-for-byte before switching consumers.
- Port the Android build helper and `docs/red-system/makedoc2.r`.
- Convert remaining Rebol-header data files to Red data or a documented binary
  format and port the producing generator.
- Remove Stage 0 branches from normal build/test scripts and delete active `.r`
  sources after their Red replacements pass.

Gate:

- `git ls-files '*.r'` is empty.
- A repository-wide scan finds no Rebol executable names, Rebol headers, or
  Rebol-only file/API calls outside migration documentation.
- All tests run under Red and preserve the recorded self-hosted test totals while
  fixing any explicitly tracked failures.
- The full supported CI matrix passes using the self-hosted compiler and the
  ported Red test runners.

### Milestone 9: Cut Over CI And Release The Bootstrap Seed

Primary work:

- Publish bootstrap seed binaries for supported build hosts with SHA-256 hashes,
  provenance, source revision, and reproduction instructions.
- Change CI to fetch/verify the seed, build the next generations, verify the fixed point, and
  run the existing target matrix.
- Add a scheduled job that rebuilds the seed and compares it with the published
  artifact.
- Keep any diverse-compiler comparison as an optional release audit that is
  independent of the normal developer and CI workflows.
- Update build and contributor documentation to describe the Red-only path.

Gate:

- A new machine can clone the repository, verify the seed, rebuild the compiler,
  and run the compiler suites without obtaining Rebol or a Rebol SDK.

## Verification Matrix

Each ported component must pass all applicable columns before its Rebol source is
removed.

| Layer | Structural comparison | Behavioral comparison | Negative cases |
| --- | --- | --- | --- |
| Lexer | value/type/newline/location token stream | accepted source corpus | malformed literals, strings, UTF-8, headers |
| Preprocessor | expanded block and include graph | macro/directive corpus | recursion, invalid arity, missing include, bad condition |
| Redbin | exact bytes and decoded graph | cross-decoding and runtime load | corrupt/truncated/version-mismatched payloads |
| Red compiler | symbols, contexts, literals, bodies, generated R/S | Red compiler/core suites | compile and runtime diagnostic corpus |
| R/S loader/compiler | loaded block, types, IR/checkpoints | R/S compiler/unit suites | type, namespace, call, cast, directive errors |
| Emitter/backend | code/data buffers, symbols, relocations | native execution per target | range, ABI, unsupported relocation errors |
| Linker/format | headers, sections, imports/exports, relocations | OS loader and library tests | malformed object/library, missing symbols |
| Driver/build | manifest, options, hashes | CLI and clean bootstrap | bad options, paths, targets, stale generated data |

Minimum continuous lanes during the migration:

- Windows IA-32 and Windows x86-64.
- Linux IA-32 and Linux x86-64.
- Linux ARM/RPi and Linux ARM64.
- macOS ARM64, including Mach-O signing and View smoke coverage.
- Compile-only checks for other configured OS/format combinations where native
  runners are unavailable.

## Suggested Change Sequence

The active sequence after the Windows x64 fixed point is:

1. Publish the canonical compiler and runtime as checksummed artifacts available
   to clean CI checkouts.
2. Replace Windows CI's downloaded Rebol host with the published self-hosted
   compiler and the Red runners under `tools/self_hosting/`.
3. Cross-compile the ARM and ARM64 suites with the canonical compiler and run
   them through `ssh armbian`.
4. Remove remaining normal-path `.r` loads and Rebol executable references from
   build, test, and CI entrypoints.
5. Port the remaining test runners, generators, tools, targets, and host
   configurations into the Red-only path without reintroducing Stage0.
6. Keep macOS work deferred until the requested Windows, ARM, and ARM64 lanes
   are stable.

## Principal Risks And Controls

| Risk | Control |
| --- | --- |
| Red/Rebol semantic drift hidden by similar syntax | Host-contract tests and component checkpoints before final binaries |
| Current work lost by importing historical ports | Port current files; use historical diffs only as reviewed recipes |
| Two implementations drift during a long migration | Port vertical slices, switch consumers, and remove the old slice promptly |
| Runtime IDs create a self-reference cycle | Deterministic generated manifest with stale-output checks |
| Binding hack breaks under GC or 64-bit hosts | Supported opaque context identity API; no pointer-to-integer transport |
| Lexer shortcut accepts a different language | Token/location parity; prohibit host `load` as the compiler lexer |
| Compiler reaches bootstrap by disabling features | Mode/feature integration matrix and the no-silent-feature-cuts invariant |
| Backend redesign delays self-hosting | Parity-first reimplementation first; `system2` IR remains optional until its contract is proven |
| Literal translation preserves Rebol overhead | Parity-first phase design, generated registries, and benchmark gates |
| Reproducibility is masked by broad normalization | Record all inputs; normalize only named metadata; compare intermediates |
| A bootstrap binary weakens supply-chain trust | Checksums, provenance, fixed-point rebuilds, and an optional independent diverse-compiler audit |
| Direct entrypoint or target registry omits a dependency | Generated registry-based manifest and closure test |

## Next Executable Deliverable

The next implementation work is the Linux ARM and ARM64 validation gate. Build
both suites with the canonical Windows x64 self-hosted compiler, transfer the
artifacts to `ssh armbian`, and run the native test launchers. Record test totals,
target ELF headers, compiler checksum, and any target-specific exclusions.
macOS is explicitly deferred.
