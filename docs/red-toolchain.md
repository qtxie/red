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
