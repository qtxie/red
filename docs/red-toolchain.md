# Standalone Red Toolchain

`red-toolchain.red` builds a single executable containing the self-hosted Red
frontend, Red/System compiler, native linker, runtime sources, standard
modules, View backend, application packager, and signing support.

## Current Milestone

The current executable is deliberately focused on one host/target tuple:

- host: Darwin ARM64
- compile targets: `Darwin-ARM64` and the `macOS-ARM64` GUI packaging variant
- output formats: Mach-O executable, dylib, and `.app` bundle
- modes: release and development (`libRedRT.dylib` generated beside the output)

Cross-compilation is not part of this milestone. Direct calls into Red target
objects are statically bound by the native Red compiler, so a clean multi-target
implementation needs a compiler-level target interface rather than runtime
method lookup in the emitter.

## Build

Use a focused, self-hosted Darwin ARM64 bootstrap compiler. Stage0 is not used.

```sh
tools/self_hosting/build-red-toolchain.sh \
  build/self-hosting/red-bootstrap-stage2-darwin-arm64-bundle-sign \
  build/red-toolchain/red-toolchain
```

The build first generates a deterministic source archive at
`build/generated/red-toolchain-resources.generated.red`, then compiles the
archive and compiler into the final executable. Resource records are sorted by
normalized path and contain the raw size, storage method, and SHA-256 digest.
The manifest digest covers the ordered path, content digest, and raw size of
every resource.

The compiler and linker are implemented in Red. Normal compilation does not
call an external compiler, linker, or `codesign`. Mach-O executables and bundles
receive the ad-hoc signature emitted by Red's Mach-O writer.

## GitHub Actions

`.github/workflows/build-macos-arm64.yml` builds and packages `red-toolchain`,
the native GUI console, and the terminal CLI console on an Apple Silicon runner.
Set the `RED_DARWIN_ARM64_BOOTSTRAP_URL` repository variable to the public URL
of this bootstrap compiler:

```text
file:   red-bootstrap-stage2-darwin-arm64-bundle-sign
sha256: 644bfb20fe52dcb054ed9c63324f31b139fd163904730bb78a08b72617ebc81c
```

The checksum is pinned in the workflow. Uploading a different compiler requires
reviewing the replacement and updating the checksum in the workflow.

## Introspection

```sh
red-toolchain --toolchain-info
red-toolchain --list-targets
red-toolchain --resource-manifest
red-toolchain --self-check
```

`--self-check` decompresses every resource and verifies its raw size and
SHA-256 digest.

## Hermetic Test

```sh
tools/self_hosting/test-toolchain-hermetic.sh \
  build/red-toolchain/red-toolchain
```

The test copies only the executable and user fixtures into a fresh temporary
directory. It builds and runs Red with a relative include, JSON/CSV Red,
Red/System, a development-mode Red client and `libRedRT.dylib`, a Red/System
dylib, and a release native View `.app` bundle.

## Self-Hosting Reproducibility

The standalone executable can be passed back to the build script as the next
generation's bootstrap. For fixed-point comparisons, build consecutive outputs
under equal-length directory names. Normalize only:

- the embedded output directory;
- the embedded build clock;
- the `LC_CODE_SIGNATURE` payload, whose hashes necessarily cover those bytes.

At the current Darwin ARM64 fixed point, consecutive self-hosted generations
have identical size and differ in 69 bytes: one output-directory byte, four
build-clock bytes, and 64 signature-hash bytes. All other bytes are identical.
