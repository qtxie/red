# Standalone Red Toolchains

The standalone toolchains package the Red frontend, Red/System compiler,
native linker, runtime sources, standard modules, View backend, application
assets, and signing or image-writing support into one executable. Compilation
does not depend on a repository checkout or an external compiler or linker.

## Platform Matrix

| Host | Entry point | Backend | Targets | Outputs |
| --- | --- | --- | --- | --- |
| any, one cross-compiler | `red-toolchain-hybrid.red` | typed postfix RSIR and native x64/ARM64 codegen | `Windows-X86-64`, `Windows-X86-64-DLL`, `Linux-X86-64`, `Linux-X86-64-SO`, `Linux-ARM64`, `Linux-ARM64-SO`, `Darwin-ARM64`, `Darwin-ARM64-SO`, `macOS-ARM64` | PE executable and DLL, ELF executable, Mach-O executable, `.app` bundle |

The toolchain supports release and development builds. A development Red
application builds `libRedRT` and its include files beside the output. The
hybrid core is a cross-compiler: `-t <target>` at build time decides the
platform, and the same entry point produces every toolchain. The legacy
per-platform compilers (`red.r`, `red-toolchain.red`,
`red-bootstrap-windows.red`) and their backend sources were removed; the
hybrid RSIR pipeline is the only compiler in the tree.

## Embedded Resources

The build first generates
`build/generated/red-toolchain-resources.generated.red`, then compiles that
archive and the compiler into the final executable. Resource records are
sorted by normalized path and contain the raw size, storage method, and
SHA-256 digest. The manifest digest covers the ordered path, content digest,
and raw size of every resource.

The archive is a build artifact and is **not committed** (`build/generated/`
is ignored). Every build regenerates it, so a fresh clone has none: the
toolchain sources `#include` it, which is why
`tools/self_hosting/build-red-toolchain.red` is the only supported way to
build them. Generation is deterministic -- paths sorted, digests per record,
`SOURCE_DATE_EPOCH` pinned -- so three consecutive builds of the same tree
produce the same manifest.

The compiler and linker are implemented in Red. Normal compilation does not
call an external compiler or linker. Darwin application bundles receive the
ad-hoc signature emitted by Red's Mach-O writer.

## Building With Red

One Red script builds every toolchain on every host, driven by a Red console.
It needs no shell, no Windows scripting host, no Python, and no `dumpbin.exe`:

```text
console tools/self_hosting/build-red-toolchain.red --bootstrap <compiler>
```

`--bootstrap` is the only option without a default when the fixed-point
compilers are not in `build/self-hosting/merge-red64/`; `--help` prints the
rest. The defaults are the newest `hybrid-compilerN.exe` there, the host as
both generator and toolchain target, and
`build/red-toolchain/<target>/red-toolchain-<N>`.

The script:

1. pins `SOURCE_DATE_EPOCH` to `--epoch`, to the environment, or to the HEAD
   commit time, so the embedded compiler date does not move between runs;
2. compiles `tools/self_hosting/generate-toolchain-resources.red` **for the
   host** -- it has to run here -- and regenerates
   `build/generated/red-toolchain-resources.generated.red`;
3. compiles the toolchain source for `--target` -- always
   `red-toolchain-hybrid.red`, the one cross-compiler, whatever the target;
4. verifies `--self-check`, `--toolchain-info`, `--list-targets` and
   `--resource-manifest` (the manifest must also agree with `--toolchain-info`)
   and reads the finished binary's own headers: PE32+ x64, dynamic base, NX
   compatibility and no `libRedRT.dll` import on Windows, ELF class and machine
   on Linux, Mach-O cputype on Darwin.

Every child runs from the repository root with absolute paths and logs both
streams to `build/red-toolchain/<target>/logs/`. Red's `call` waits but cannot
kill a child, so a wedged compiler wedges the build instead of timing out.

The Windows and Darwin recipes below are the host-specific scripts this one
supersedes.

## Windows x64 Build

The Red script above is the only supported path:

```text
console tools/self_hosting/build-red-toolchain.red \
    --bootstrap build/self-hosting/merge-red64/hybrid-compilerNNN.exe
```

The output is
`build/red-toolchain/windows-x64/red-toolchain-<N>.exe`. It verifies PE32+,
x64, dynamic-base, NX compatibility, embedded resources, target metadata, and
the absence of a release `libRedRT.dll` import. Red's `call` cannot kill a
child, so steps are not individually bounded the way the host scripts used to
bound them.

Run the compiler outside the repository with:

```powershell
red-toolchain.exe -r -t Windows-X86-64 -o hello.exe hello.red
red-toolchain.exe -r -dlib -t Windows-X86-64-DLL -o example.dll example.reds
```

## Darwin ARM64 Build

Use a focused, self-hosted Darwin ARM64 bootstrap compiler. Stage0 is not
used. The Red script drives it:

```text
console tools/self_hosting/build-red-toolchain.red \
    --target Darwin-ARM64 \
    --bootstrap <darwin-arm64 bootstrap> \
    --output build/red-toolchain/red-toolchain
```

### Cross-building for another host

One source serves every target, built for a target by cross-compiling from
the host:

Generate the resource archive first -- the source `#include`s it, and it is
not in the repository -- then cross-compile:

```sh
SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) \
  build/self-hosting/merge-red64/hybrid-compilerNNN.exe \
  -r -t Windows-X86-64 \
  -o build/tmp/gen-res.exe \
  tools/self_hosting/generate-toolchain-resources.red
build/tmp/gen-res.exe "$PWD" \
  build/generated/red-toolchain-resources.generated.red

SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) \
  build/self-hosting/merge-red64/hybrid-compilerNNN.exe \
  -r -t Darwin-ARM64 \
  -o build/red-toolchain/darwin-arm64/red-toolchain \
  red-toolchain-hybrid.red
```

The hybrid core is a cross-compiler, so the `-t` decides `config/OS`: for
`Darwin-ARM64` that is 'macOS, and `bootstrap-driver.red` then reports
Darwin-ARM64 as the host and defaults to it without `-t`,
`compiler-hybrid-common.red` imports the `chmod` its executables need, and
`libRedRT-target` picks `Darwin-ARM64-SO` so development builds produce a
`libRedRT.dylib`.

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

The suite copies only the compiler and the fixtures in
`tools/self_hosting/fixtures/toolchain` into a new temporary directory and
makes it the working directory, so every path the toolchain sees is relative:

```text
console tools/self_hosting/test-red-toolchain-hermetic.red \
    --toolchain build/red-toolchain/windows-x64/red-toolchain.exe
```

It builds and runs release and development Red programs, `-O2`, JSON and CSV
modules, Red/System, a callable DLL export, and a self-closing native View
window. It verifies output architecture, imports, exports and
repository-path isolation. Pass `--keep` to preserve the scratch directory
when it fails, `--no-view` to skip the View fixture.

Images are read directly, so the suite needs no `dumpbin`; and the DLL export
is called back through a Red/System loader that the toolchain under test
compiles, so it needs no host loader either.

The Darwin equivalent is:

```sh
tools/self_hosting/test-toolchain-hermetic.sh \
  build/red-toolchain/red-toolchain
```

## Fixed Point

The gate builds three consecutive generations through one canonical staging
path, snapshots H1/H2/H3, compares H2 and H3 after normalizing only the PE COFF
timestamp and checksum, and verifies identical resource manifests. Builds use
`SOURCE_DATE_EPOCH` when supplied, or the current Git commit timestamp
otherwise:

```text
console tools/self_hosting/build-red-toolchain-fixed-point.red
```

Each generation is compiled to the same staging path and copied out afterwards,
because the toolchain embeds its own output path: building H2 and H3 under
different names would make them differ for a reason that has nothing to do with
the fixed point. The PE comparison is in Red too, so
`python selfhost.py compare-pe` is no longer part of the gate.

The Darwin fixed-point comparison uses consecutive generations under
equal-length paths. Its documented normalization additionally covers the
embedded output directory, build clock, and `LC_CODE_SIGNATURE` payload whose
hashes cover those bytes.

## GitHub Actions

Every CI job takes its compiler and console from a **seed**: one toolchain, one
CLI console, and where one exists a GUI console, per platform, published as
GitHub release assets. No workflow reads a repository variable to find them.

Every target uses the same source: `red-toolchain-hybrid.red` is a
cross-compiler, so the `-t` at build time decides the platform. The manifest
reads its platform list from the artifact directories, so a new platform joins
by getting a leg in the `plan` job of `build-hybrid-toolchain.yml` -- the one
place the matrix is defined -- and nothing else has to change.

- `ci-seed` is a floating release that holds nothing but `MANIFEST.json`,
  mapping each platform to its asset name, its SHA-256, and the generation
  release that holds it.
- Each generation is an immutable release named `seed-<run id>`.
- `.github/actions/fetch-seed` resolves the manifest and downloads one
  component, verifying its checksum. Every URL is derived from
  `github.repository`, which is why promoting a seed needs no configuration.

### Cold start

The chain still begins from a pinned binary. Run the **Seed the CI toolchain
chain** workflow (`seed-toolchain.yml`) once: it builds every platform from its
pinned bootstrap URL and publishes the first generation. After that the chain
builds from the seed and the pinned URLs go unused.

With `bootstrap-source=auto` a platform that has no seed yet falls back to its
pinned URL and reports it in the job summary, because a silent fallback would
mix generations. The pinned bootstraps are:

```text
file:   red-bootstrap-speed1.exe
sha256: 53f947164aaeb9912c233a0d7c4fb960ded05932fce809aaf34df75b9f9f7eba
```

The Darwin leg additionally builds `gui-console.app` and checks it the way
Apple does — `dyld_info -validate_only`, a valid `LC_CODE_SIGNATURE`,
`codesign --verify --strict`, and the AppKit link — so a generation that
produces a bundle Apple's loader rejects is never published. It ships as the
`gui` component of the Darwin seed; the other platforms have no bundle and so
no `gui` entry.

### Promotion

`build-toolchain.yml` builds every platform on each push, but only the nightly
run and an explicit dispatch publish. Promotion is not on the push path
because a release notifies every repository watcher.

Promotion writes the new generation release first and then repoints `ci-seed`.
GitHub cannot overwrite a release asset in place, so the pointer release is
recreated: that swap is the only moment the manifest URL answers 404, and
`fetch-seed` retries through it. The newest five generations are kept; the rest
are pruned.

To roll back, re-run `seed-toolchain.yml` at an older commit — the dispatch
lets you choose the ref, and publishing rebuilds that generation.
