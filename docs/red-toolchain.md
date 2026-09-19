# Standalone Red Toolchains

The standalone toolchains package the Red frontend, Red/System compiler,
native linker, runtime sources, standard modules, View backend, application
assets, and signing or image-writing support into one executable. Compilation
does not depend on a repository checkout or an external compiler or linker.

## Platform Matrix

| Host | Entry point | Backend | Targets | Outputs |
| --- | --- | --- | --- | --- |
| Windows x64 | `red-toolchain-windows-hybrid.red` | typed postfix RSIR and native x64 codegen | `Windows-X86-64`, `Windows-X86-64-DLL` | PE executable, DLL |
| Darwin ARM64 | `red-toolchain.red` | self-hosted ARM64 backend | `Darwin-ARM64`, `Darwin-ARM64-SO`, `macOS-ARM64` | Mach-O executable, dylib, `.app` bundle |

Both toolchains support release and development builds. A development Red
application builds `libRedRT` and its include files beside the output. These
are native host toolchains; cross-compilation is outside this milestone.

## Embedded Resources

The build first generates
`build/generated/red-toolchain-resources.generated.red`, then compiles that
archive and the compiler into the final executable. Resource records are
sorted by normalized path and contain the raw size, storage method, and
SHA-256 digest. The manifest digest covers the ordered path, content digest,
and raw size of every resource.

The compiler and linker are implemented in Red. Normal compilation does not
call an external compiler or linker. Darwin application bundles receive the
ad-hoc signature emitted by Red's Mach-O writer.

## Windows x64 Build

The Windows build uses the fixed-point hybrid compiler at
`build/self-hosting/cc-speed1/red-bootstrap-speed1.exe` by default:

```powershell
& .\tools\self_hosting\build-windows-hybrid-toolchain.ps1
```

The output is
`build/red-toolchain/windows-x64/red-toolchain.exe`. Pass `-Bootstrap`,
`-Output`, or `-Dumpbin` to override the defaults. Every compiler and fixture
process has a bounded timeout, and the build verifies PE32+, x64, dynamic-base,
NX compatibility, embedded resources, target metadata, and the absence of a
release `libRedRT.dll` import.

Run the compiler outside the repository with:

```powershell
red-toolchain.exe -r -t Windows-X86-64 -o hello.exe hello.red
red-toolchain.exe -r -dlib -t Windows-X86-64-DLL -o example.dll example.reds
```

## Darwin ARM64 Build

Use a focused, self-hosted Darwin ARM64 bootstrap compiler. Stage0 is not
used.

```sh
tools/self_hosting/build-red-toolchain.sh \
  build/self-hosting/red-bootstrap-stage2-darwin-arm64-bundle-sign \
  build/red-toolchain/red-toolchain
```

### Darwin ARM64 hybrid cross-build

`red-toolchain-darwin-hybrid.red` is the same closure as the Windows hybrid
toolchain, built for the Mac by cross-compiling from the Windows host:

```sh
SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) \
  build/self-hosting/merge-red64/hybrid-compilerNNN.exe \
  -r -t Darwin-ARM64 \
  -o build/red-toolchain/darwin-arm64/red-toolchain \
  red-toolchain-darwin-hybrid.red
```

The hybrid core is a cross-compiler, so `config/OS` is 'macOS in that build:
`bootstrap-driver.red` then reports Darwin-ARM64 as the host and defaults to
it without `-t`, `compiler-hybrid-common.red` imports the `chmod` its
executables need, and `libRedRT-target` picks `Darwin-ARM64-SO` so
development builds produce a `libRedRT.dylib`.

Verified on an Apple Silicon Mac (Darwin 24.6.0 arm64):

```text
red-toolchain --toolchain-info
  host: Darwin-ARM64   backend: hybrid-rsir   standalone: true
  resources: 276
red-toolchain --self-check        -> resource-self-check: ok resources: 276
red-toolchain -r -o hello.bin hello.red   -> runs, prints
```

and the suites the backend had to grow into: 40/40 Red/System units plus the
logic, integer and function Red units cross-compile and pass on the Mac.

The toolchain's own IR is 19 MB -- roughly a thousandth of everything the
compiler knows how to compile -- so it is the widest ARM64 test there is.
Getting it through took four backend repairs, all of them the same root
cause in a different place: **an expression stack deeper than the seven
temp registers.** x64 has no place concept and no pool this small, so only
the ARM64 backend can notice.

* `site 365`: `plan-function` reserved the region spill window only where a
  call, a native or a subroutine entry happened to observe the depth, so a
  deep `OP_BINARY` reached codegen with nowhere to park. Stated once at the
  top of the instruction walk: a slot deeper than the pool is reserved
  wherever the stack reaches that depth.
* `site 324` (`op=7`, OP_CALL): a call argument held a PLACE. It was not the
  frontend leaving one -- `OP_LOAD`'s inline deep fallback parked the address
  of an inline aggregate but never re-tagged the slot, and an inline
  aggregate *is* that address, so the parked word was already the value.
* `site 293` (`op=6`, OP_MEMBER), `site 282` (`op=21`, OP_INDEX) and the
  tagged-union materializations: out of temp registers with nowhere to put
  the result. `take-temp-register` now parks one live value in its frame
  slot and retries, which is what `spill-value-register` already did for
  `OP_ADDRESS`.
* `site 148` (`op=16`, OP_JUMP): `canonicalize-stack` and
  `restore-control-stack` put every live slot in its canonical temp
  register, because a control-flow edge carries only a depth and a type.
  Slots past the pool now canonicalize into the slot the region reserves
  for that depth, which is the same on both sides of an in-region edge.

The cross-build reproduces. Two generations writing to output names of the
same length (`build/red-toolchain/darwin-arm64/red-toolchain-157|-158`,
6690688 bytes each) differ in 144 bytes: the last character of the embedded
output path in the two places it appears, the two `dd-Mmm-yyyy/h:mm:ss`
clocks, two materialized 64-bit constants and four 32-byte windows of the
compressed resource blob. Compare only equal-length `-o` names -- the
toolchain embeds its own path, so a longer one shifts the resource blob and
repaints every address literal that points into it. 157's `red-toolchain`
against 158's `red-toolchain-158` differ in 1.87 MB, almost all of it that
shift.

## Introspection

Both tools expose the same standalone metadata interface:

```text
red-toolchain --toolchain-info
red-toolchain --list-targets
red-toolchain --resource-manifest
red-toolchain --self-check
```

`--self-check` decompresses every resource and verifies its raw size and
SHA-256 digest.

## Hermetic Tests

The Windows suite copies only the compiler and fixtures into a new temporary
directory:

```powershell
& .\tools\self_hosting\test-windows-hybrid-toolchain.ps1 `
    -Toolchain .\build\red-toolchain\windows-x64\red-toolchain.exe
```

It builds and runs release and development Red programs, `-O2`, JSON and CSV
modules, Red/System, a callable DLL export, and a self-closing native View
window. It verifies output architecture, imports, exports, embedded source
lookup, and repository-path isolation.

The Darwin equivalent is:

```sh
tools/self_hosting/test-toolchain-hermetic.sh \
  build/red-toolchain/red-toolchain
```

## Fixed Point

The Windows gate builds three consecutive generations through one canonical
staging path, snapshots H1/H2/H3, compares H2 and H3 after normalizing only the
PE COFF timestamp and checksum, verifies identical resource manifests, then
runs the hermetic suite with H3. Builds use `SOURCE_DATE_EPOCH` when supplied,
or the current Git commit timestamp otherwise:

```powershell
& .\tools\self_hosting\test-windows-hybrid-toolchain-fixed-point.ps1
```

The Darwin fixed-point comparison uses consecutive generations under
equal-length paths. Its documented normalization additionally covers the
embedded output directory, build clock, and `LC_CODE_SIGNATURE` payload whose
hashes cover those bytes.

## GitHub Actions

`.github/workflows/build-windows-x64-hybrid-toolchain.yml` builds, verifies,
and packages the Windows fixed-point compiler. Set the
`RED_WINDOWS_X64_HYBRID_BOOTSTRAP_URL` repository variable to the public URL
of this pinned bootstrap:

```text
file:   red-bootstrap-speed1.exe
sha256: 53f947164aaeb9912c233a0d7c4fb960ded05932fce809aaf34df75b9f9f7eba
```

`.github/workflows/build-macos-arm64.yml` retains the Darwin ARM64 build and
its separately pinned bootstrap. Replacing either bootstrap requires review
and a checksum update in the corresponding workflow.
