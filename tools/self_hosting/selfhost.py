#!/usr/bin/env python3
"""Deterministic source inventory and compiler differential runner.

This module is deliberately a transitional developer tool.  It does not build
or package the compiler: the eventual Red entrypoint is compiled directly.
The tool records enough evidence to make each Red reimplementation slice
reviewable and reproducible while Rebol sources still exist in the tree.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = 1
SOURCE_SUFFIXES = {".r", ".red", ".reds"}
TEXT_SUFFIXES = {
    ".c",
    ".h",
    ".json",
    ".log",
    ".md",
    ".r",
    ".raw",
    ".red",
    ".reds",
    ".s",
    ".sh",
    ".txt",
    ".yml",
    ".yaml",
}

REBOl_APIS = {
    "system/version": r"\bsystem/version\b",
    "system/components": r"\bsystem/components\b",
    "to-rebol-file": r"\bto-rebol-file\b",
    "get-modes": r"\bget-modes\b",
    "disarm": r"\bdisarm\b",
    "do-cache": r"\bdo-cache\b",
    "load-cache": r"\bload-cache\b",
    "read-cache": r"\bread-cache\b",
    "encap?": r"\bencap\?\b",
    "load/library": r"\bload/library\b",
    "make routine!": r"\bmake\s+routine!\b",
    "make struct!": r"\bmake\s+struct!\b",
    "parse/all": r"\bparse/all\b",
    "call/show": r"\bcall/show\b",
}

FILE_LITERAL_RE = re.compile(
    r"(?P<op>#include|do-cache|load-cache|read-cache|read-binary-cache|"
    r"do|load|read(?:/binary)?|write(?:/binary)?)?\s*"
    r"(?P<literal>%[^\s\[\]\(\){}\";,]+)",
    re.IGNORECASE,
)
TARGET_NAME_RE = re.compile(r"(?m)^\s*([A-Za-z][A-Za-z0-9_-]*)\s*\[")
FIELD_RE = re.compile(r"(?m)^\s*(target|format|packager)\s*:\s*'?(\S+)")
COMPILER_DURATION_RE = re.compile(
    r"(?m)^(\.\.\.(?:compilation|linking) time\s*:\s*)"
    r"\d+(?:\.\d+)?[ \t]*(?:ms|s|sec|seconds?)[ \t]*$"
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read_bytes(path: Path) -> bytes:
    return path.read_bytes()


def _read_text(path: Path) -> str:
    return _read_bytes(path).decode("utf-8", errors="replace")


def _posix(path: Path) -> str:
    return path.as_posix()


def _root_path(root: Path, value: str | Path) -> Path:
    path = Path(value)
    return path if path.is_absolute() else root / path


def _source_paths(root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    paths = [item for item in result.stdout.decode("utf-8").split("\0") if item]
    allowed_untracked_prefixes = ("compiler/", "tools/self_hosting/")
    allowed_untracked_files = {"red-selfhost.red", "red.red"}
    tracked = set(
        subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout.decode("utf-8").split("\0")
    )
    paths = [
        item
        for item in paths
        if item in tracked
        or item.replace("\\", "/") in allowed_untracked_files
        or item.replace("\\", "/").startswith(allowed_untracked_prefixes)
    ]
    return [Path(item.replace("\\", "/")) for item in sorted(paths)]


def _classify(path: PurePosixPath, text: str) -> str:
    value = path.as_posix()
    name = path.name.lower()
    if value.startswith("docs/old/") or value.startswith("public/"):
        return "historical-tool"
    if value.startswith("docs/"):
        return "documentation-tool"
    if value.startswith("quick-test/"):
        return "test-runner"
    if value.startswith("tests/") or value.startswith("system/tests/"):
        if name.startswith(("make-", "generate-", "build-")):
            return "test-generator"
        return "test-runner"
    if value.startswith("build/") or value in {"red.r", "run-all-tests.r", "run-all-tests-x64.r", "run-all-tests-linux-x64.r"}:
        return "rebol-build-driver"
    if value.startswith("bridges/"):
        return "auxiliary-tool"
    if value.startswith("system/formats/") and any(
        token in name for token in ("exports", "libsystem", "crt-helpers", "lib-exports")
    ):
        return "declarative-data"
    if value.startswith("system/targets/") or value.startswith("system/"):
        return "compiler-backend"
    if value.startswith("encapper/"):
        return "compiler-frontend"
    if value.startswith("utils/"):
        return "compiler-utility"
    if "red" in text[:256].lower() and path.suffix.lower() == ".r":
        return "production-code"
    return "other-rebol-source"


def _scan_api_usage(text: str) -> list[str]:
    return sorted(name for name, pattern in REBOl_APIS.items() if re.search(pattern, text))


def _normalize_literal(raw: str) -> str:
    value = raw.strip()
    while value and value[-1] in ".:))]":
        value = value[:-1]
    return value.replace("\\", "/")


def _resolve_literal(root: Path, source: Path, raw: str) -> str | None:
    value = _normalize_literal(raw)
    if not value.startswith("%"):
        return None
    value = value[1:]
    if not value or any(char in value for char in ("*", "?", "$", "(")):
        return None
    candidates: list[Path] = []
    relative = Path(value)
    candidates.append(source.parent / relative)
    candidates.append(root / relative)
    # Rebol scripts commonly resolve paths relative to the repository's current
    # directory even when the literal appears in a nested source file.
    if value.startswith("../"):
        candidates.append(root / value[3:])
    for candidate in candidates:
        try:
            resolved = candidate.resolve()
            if resolved.is_file() and resolved.is_relative_to(root.resolve()):
                return _posix(resolved.relative_to(root.resolve()))
        except (OSError, ValueError):
            continue
    return None


def _scan_literals(root: Path, source: Path, text: str) -> dict[str, Any]:
    references: list[dict[str, Any]] = []
    unresolved: list[str] = []
    for match in FILE_LITERAL_RE.finditer(text):
        raw = match.group("literal")
        normalized = _normalize_literal(raw)
        resolved = _resolve_literal(root, source, normalized)
        record: dict[str, Any] = {"literal": normalized}
        if match.group("op"):
            record["operation"] = match.group("op")
        if resolved:
            record["path"] = resolved
        else:
            unresolved.append(normalized)
        references.append(record)
    # Preserve source order for diagnostics, while the enclosing manifest stays
    # deterministic because files and records are sorted by the caller.
    return {"references": references, "unresolved": sorted(set(unresolved))}


def _target_registry(root: Path, tracked: set[str]) -> dict[str, Any]:
    config_path = root / "system" / "config.r"
    config_text = _read_text(config_path) if config_path.is_file() else ""
    names = [name for name in TARGET_NAME_RE.findall(config_text) if name != "REBOL"]
    fields = FIELD_RE.findall(config_text)
    field_map: dict[str, list[str]] = {"target": [], "format": [], "packager": []}
    for field, value in fields:
        field_map[field].append(value.rstrip("]"))
    target_sources = sorted(
        path for path in tracked if path.startswith("system/targets/") and path.endswith(".r")
    )
    format_sources = sorted(
        path for path in tracked if path.startswith("system/formats/") and path.endswith(".r")
    )
    red_registry_path = root / "compiler" / "target-registry.red"
    red_registry: dict[str, dict[str, str]] = {}
    if red_registry_path.is_file():
        red_text = _read_text(red_registry_path)
        red_text = red_text.split("target-registry:", 1)[-1]
        red_text = red_text.split("compiler-target-classes:", 1)[0]
        for name, spec in re.findall(
            r"(?m)^\s*([A-Za-z][A-Za-z0-9_-]*)\s*\[([^\]]*)\]", red_text
        ):
            fields_in_spec = dict(
                re.findall(r"\b(os|format|type|target|packager)\s+([A-Za-z0-9_-]+)", spec)
            )
            red_registry[name] = fields_in_spec
    return {
        "configured_names": sorted(set(names)),
        "configured_cpu_values": sorted(set(field_map["target"])),
        "configured_format_values": sorted(set(field_map["format"])),
        "configured_packagers": sorted(set(field_map["packager"])),
        "target_sources": target_sources,
        "format_sources": format_sources,
        "red_registry": red_registry,
        "generated": _target_registry_info(root),
    }


def _parse_target_blocks(text: str) -> list[tuple[str, list[tuple[str, str]]]]:
    targets: list[tuple[str, list[tuple[str, str]]]] = []
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        match = re.match(
            r"^\s*([A-Za-z][A-Za-z0-9_-]*)\s*\[\s*(?:;.*)?$",
            lines[index],
        )
        if not match or match.group(1) == "REBOL":
            index += 1
            continue
        name = match.group(1)
        fields: list[tuple[str, str]] = []
        index += 1
        while index < len(lines):
            line = lines[index]
            if re.match(r"^\s*\]\s*(?:;.*)?$", line):
                break
            field = re.match(
                r"^\s*([A-Za-z][A-Za-z0-9_?-]*)\s*:\s*(.*?)\s*(?:;.*)?$",
                line,
            )
            if field:
                key = field.group(1)
                value = field.group(2).strip()
                if value.startswith("'"):
                    value = value[1:]
                elif value == "yes":
                    value = "#(true)"
                elif value == "no":
                    value = "#(false)"
                fields.append((key, value))
            index += 1
        targets.append((name, fields))
        index += 1
    return targets


def _target_registry_text(root: Path) -> tuple[str, dict[str, Any]]:
    source_path = root / "system" / "config.r"
    source = _read_bytes(source_path)
    targets = _parse_target_blocks(source.decode("utf-8", errors="replace"))
    if not targets:
        raise ValueError("system/config.r contains no target definitions")
    source_sha256 = _sha256(source)
    lines = [
        "Red [",
        '\tTitle: "Generated Red compiler target registry"',
        "\tFile:  %target-registry.red",
        "]",
        "",
        "; Generated from system/config.r. Do not edit by hand.",
        f'target-registry-source-sha256: "{source_sha256}"',
        "target-registry: [",
    ]
    for name, fields in targets:
        known = {key.lower() for key, _ in fields}
        if "target" not in known:
            fields = [*fields, ("target", "IA-32")]
        lines.append(f"\t{name} [")
        for key, value in fields:
            lines.append(f"\t\t{key} {value}")
        lines.append("\t]")
    lines.extend(
        [
            "]",
            "",
            "compiler-target-classes: [IA-32 ARM X86-64 ARM64]",
            "compiler-formats: [PE ELF Mach-O]",
            "compiler-object-formats: [COFF ELF-obj Mach-O-obj]",
            "",
        ]
    )
    return "\n".join(lines), {
        "source": "system/config.r",
        "source_sha256": source_sha256,
        "target_count": len(targets),
    }


def _target_registry_info(root: Path) -> dict[str, Any]:
    generated, info = _target_registry_text(root)
    generated_path = root / "compiler" / "target-registry.red"
    generated_bytes = generated.encode("utf-8")
    actual = generated_path.read_bytes() if generated_path.is_file() else b""
    info.update(
        {
            "path": "compiler/target-registry.red",
            "expected_sha256": _sha256(generated_bytes),
            "actual_sha256": _sha256(actual) if actual else None,
            "stale": actual != generated_bytes,
        }
    )
    return info


def build_manifest(root: Path) -> dict[str, Any]:
    root = root.resolve()
    tracked = _source_paths(root)
    source_records: list[dict[str, Any]] = []
    rebol_records: list[dict[str, Any]] = []
    for relative in tracked:
        if relative.suffix.lower() not in SOURCE_SUFFIXES:
            continue
        absolute = root / relative
        if not absolute.is_file():
            continue
        data = _read_bytes(absolute)
        text = data.decode("utf-8", errors="replace")
        literal_scan = _scan_literals(root, absolute, text)
        record: dict[str, Any] = {
            "path": _posix(relative),
            "kind": _classify(PurePosixPath(relative.as_posix()), text),
            "bytes": len(data),
            "lines": text.count("\n") + (1 if text and not text.endswith("\n") else 0),
            "sha256": _sha256(data),
            "red_header": bool(re.search(r"(?m)^\s*Red\s*\[", text[:512])),
            "red_system_header": bool(re.search(r"(?m)^\s*Red/System\s*\[", text[:512])),
            "rebol_header": bool(re.search(r"(?m)^\s*REBOL\s*\[", text[:512])),
            "rebol_apis": _scan_api_usage(text),
            "file_references": literal_scan["references"],
            "unresolved_file_references": literal_scan["unresolved"],
        }
        source_records.append(record)
        if relative.suffix.lower() == ".r":
            rebol_records.append(record)

    source_records.sort(key=lambda record: record["path"])
    rebol_records.sort(key=lambda record: record["path"])
    tracked_names = {_posix(path) for path in tracked}
    registry = _target_registry(root, tracked_names)
    entrypoints = [
        path
        for path in ("red-selfhost.red", "red.red", "red.r")
        if path in tracked_names or (root / path).is_file()
    ]
    reference_graph = {
        record["path"]: sorted(
            {
                reference["path"]
                for reference in record["file_references"]
                if reference.get("path")
            }
        )
        for record in source_records
    }
    entrypoint_closures: dict[str, list[str]] = {}
    for entrypoint in entrypoints:
        closure: set[str] = set()
        pending = [entrypoint]
        while pending:
            path = pending.pop()
            if path in closure:
                continue
            closure.add(path)
            pending.extend(reference_graph.get(path, []))
        entrypoint_closures[entrypoint] = sorted(closure)
    combined_closure = sorted(
        {
            path
            for closure in entrypoint_closures.values()
            for path in closure
        }
    )
    entrypoint_rebol_dependencies = {
        entrypoint: [path for path in closure if path.endswith(".r")]
        for entrypoint, closure in entrypoint_closures.items()
    }
    canonical_lines = [
        f"{record['path']}\0{record['sha256']}\0{record['bytes']}"
        for record in source_records
    ]
    tree_digest = _sha256("\n".join(canonical_lines).encode("utf-8"))
    return {
        "schema": SCHEMA_VERSION,
        "root": ".",
        "source_tree_sha256": tree_digest,
        "entrypoints": sorted(set(entrypoints)),
        "entrypoint_literal_closure": combined_closure,
        "entrypoint_literal_closures": entrypoint_closures,
        "entrypoint_rebol_dependencies": entrypoint_rebol_dependencies,
        "target_registry": registry,
        "rebol_source_count": len(rebol_records),
        "source_count": len(source_records),
        "rebol_sources": rebol_records,
        "sources": source_records,
    }


def _baseline_from_manifest(manifest: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "schema": SCHEMA_VERSION,
        "kind": "rebol-migration-baseline",
        "source_tree_sha256": manifest["source_tree_sha256"],
        "entrypoints": manifest["entrypoints"],
        "entrypoint_literal_closure": manifest["entrypoint_literal_closure"],
        "entrypoint_literal_closures": manifest["entrypoint_literal_closures"],
        "entrypoint_rebol_dependencies": manifest["entrypoint_rebol_dependencies"],
        "target_registry": manifest["target_registry"],
        "source_count": manifest["source_count"],
        "rebol_source_count": manifest["rebol_source_count"],
        "rebol_sources": manifest["rebol_sources"],
    }


def build_baseline(root: Path) -> dict[str, Any]:
    return _baseline_from_manifest(build_manifest(root))


def _manifest_errors(manifest: Mapping[str, Any]) -> list[str]:
    errors: list[str] = []
    source_paths = {record["path"] for record in manifest.get("sources", [])}
    registry = manifest.get("target_registry", {})
    if registry.get("generated", {}).get("stale"):
        errors.append("compiler/target-registry.red is stale")
    for path in registry.get("target_sources", []) + registry.get("format_sources", []):
        if path not in source_paths:
            errors.append(f"registry source is missing from manifest: {path}")
    entrypoint_dependencies = manifest.get("entrypoint_rebol_dependencies", {})
    for entrypoint in ("red.red", "red-selfhost.red"):
        direct_dependencies = entrypoint_dependencies.get(entrypoint, [])
        if direct_dependencies:
            errors.append(
                f"direct Red entrypoint {entrypoint} has Rebol dependencies: "
                + ", ".join(direct_dependencies)
            )
    configured_names = set(registry.get("configured_names", []))
    red_names = set(registry.get("red_registry", {}))
    if red_names and configured_names != red_names:
        errors.append(
            "Red target registry differs from system/config.r: "
            f"missing={sorted(configured_names - red_names)} "
            f"extra={sorted(red_names - configured_names)}"
        )
    return errors


def _canonical_json(value: Any) -> str:
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n"


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(_canonical_json(value))


def _write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(value)


def _normalize_text(text: str, replacements: Mapping[str, str]) -> str:
    value = text.replace("\r\n", "\n").replace("\r", "\n")
    for source, target in sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True):
        if source:
            value = value.replace(source, target)
    value = COMPILER_DURATION_RE.sub(r"\1<DURATION>", value)
    return value


def _normalize_pe(data: bytes) -> tuple[bytes, list[str]]:
    """Normalize the two volatile PE header fields emitted by Stage 0."""
    if len(data) < 64 or data[:2] != b"MZ":
        return data, []
    pe_offset = int.from_bytes(data[60:64], "little")
    optional_offset = pe_offset + 24
    if (
        pe_offset < 0
        or pe_offset + 12 > len(data)
        or data[pe_offset : pe_offset + 4] != b"PE\0\0"
        or optional_offset + 68 > len(data)
    ):
        return data, []
    normalized = bytearray(data)
    normalized[pe_offset + 8 : pe_offset + 12] = b"\0" * 4
    normalized[optional_offset + 64 : optional_offset + 68] = b"\0" * 4
    return bytes(normalized), ["pe.coff_timestamp", "pe.checksum"]


def _command_tokens(command: Sequence[str] | str) -> list[str]:
    if isinstance(command, str):
        return shlex.split(command, posix=os.name != "nt")
    return [str(item) for item in command]


def _render_tokens(command: Sequence[str] | str, values: Mapping[str, str]) -> list[str]:
    return [token.format_map(values) for token in _command_tokens(command)]


def _status(exit_code: int | None, timed_out: bool) -> str:
    if timed_out:
        return "timeout"
    if exit_code == 0:
        return "success"
    if exit_code is None or exit_code < 0:
        return "crash"
    return "compiler-error"


def _artifact_records(root: Path, replacements: Mapping[str, str]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if not root.exists():
        return records
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix()
        if relative in {"stdout.raw", "stderr.raw"}:
            continue
        data = path.read_bytes()
        record: dict[str, Any] = {
            "path": relative,
            "bytes": len(data),
            "sha256": _sha256(data),
        }
        if path.suffix.lower() in TEXT_SUFFIXES:
            text = data.decode("utf-8", errors="replace")
            normalized = _normalize_text(text, replacements)
            record["normalized_bytes"] = len(normalized.encode("utf-8"))
            record["normalized_sha256"] = _sha256(normalized.encode("utf-8"))
            record["normalized_text"] = normalized
        else:
            normalized, normalizations = _normalize_pe(data)
            if normalizations:
                record["normalizations"] = normalizations
                record["normalized_bytes"] = len(normalized)
                record["normalized_sha256"] = _sha256(normalized)
        records.append(record)
    return records


def _run_command(
    command: Sequence[str] | str,
    values: Mapping[str, str],
    output_dir: Path,
    timeout: float,
) -> dict[str, Any]:
    rendered = _render_tokens(command, values)
    started = time.monotonic()
    timed_out = False
    try:
        completed = subprocess.run(
            rendered,
            cwd=values["root"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
        exit_code: int | None = completed.returncode
        stdout = completed.stdout.decode("utf-8", errors="replace")
        stderr = completed.stderr.decode("utf-8", errors="replace")
    except subprocess.TimeoutExpired as error:
        timed_out = True
        exit_code = None
        stdout = (error.stdout or b"").decode("utf-8", errors="replace") if isinstance(error.stdout, bytes) else (error.stdout or "")
        stderr = (error.stderr or b"").decode("utf-8", errors="replace") if isinstance(error.stderr, bytes) else (error.stderr or "")
    duration_ms = int((time.monotonic() - started) * 1000)
    replacements = {
        values["root"]: "<ROOT>",
        values["work"]: "<WORK>",
        values["source"]: "<SOURCE>",
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    _write_text(output_dir / "stdout.raw", stdout)
    _write_text(output_dir / "stderr.raw", stderr)
    return {
        "command": rendered,
        "exit_code": exit_code,
        "status": _status(exit_code, timed_out),
        "duration_ms": duration_ms,
        "stdout": _normalize_text(stdout, replacements),
        "stderr": _normalize_text(stderr, replacements),
        "artifacts": _artifact_records(output_dir, replacements),
    }


def _result_key(
    result: Mapping[str, Any], compare: Mapping[str, Any] | None = None
) -> dict[str, Any]:
    compare = compare or {}
    comparable_artifacts: list[dict[str, Any]] = []
    if compare.get("artifacts", True):
        for artifact in result.get("artifacts", []):
            if "normalized_sha256" in artifact:
                comparable_artifacts.append(
                    {
                        key: artifact.get(key)
                        for key in (
                            "path",
                            "normalized_bytes",
                            "normalized_sha256",
                            "normalized_text",
                        )
                    }
                )
            else:
                comparable_artifacts.append(
                    {key: artifact.get(key) for key in ("path", "bytes", "sha256")}
                )
    key = {
        "status": result.get("status"),
        "exit_code": result.get("exit_code"),
    }
    if compare.get("stdout", True):
        key["stdout"] = result.get("stdout")
    if compare.get("stderr", True):
        key["stderr"] = result.get("stderr")
    if compare.get("artifacts", True):
        key["artifacts"] = comparable_artifacts
    return key


def run_differential(config: Mapping[str, Any], root: Path, work_root: Path | None = None) -> dict[str, Any]:
    root = root.resolve()
    work_root = (work_root or Path(tempfile.mkdtemp(prefix="red-selfhost-diff-"))).resolve()
    work_root.mkdir(parents=True, exist_ok=True)
    timeout = float(config.get("timeout_seconds", 120))
    left_command = config["left"]["command"]
    right_command = config["right"]["command"]
    cases = config.get("cases", [])
    shared_variables = {
        str(key): str(value) for key, value in config.get("variables", {}).items()
    }
    compare = config.get("compare", {})
    report_cases: list[dict[str, Any]] = []
    for case in cases:
        case_id = str(case["id"])
        source = _root_path(root, case["source"]).resolve()
        if not source.is_file():
            raise FileNotFoundError(f"case source does not exist: {source}")
        case_root = work_root / case_id
        left_dir = case_root / "left"
        right_dir = case_root / "right"
        left_dir.mkdir(parents=True, exist_ok=True)
        right_dir.mkdir(parents=True, exist_ok=True)
        values_left = dict(shared_variables)
        values_left.update(
            {str(key): str(value) for key, value in case.get("variables", {}).items()}
        )
        values_left.update(
            {str(key): str(value) for key, value in config["left"].get("variables", {}).items()}
        )
        values_left.update({
            "root": str(root),
            "source": str(source),
            "work": str(left_dir),
            "output": str(left_dir / "output"),
            "case": case_id,
            "stage": "left",
        })
        values_right = dict(values_left)
        values_right.update(
            {str(key): str(value) for key, value in config["right"].get("variables", {}).items()}
        )
        values_right.update(
            {"work": str(right_dir), "output": str(right_dir / "output"), "stage": "right"}
        )
        left = _run_command(left_command, values_left, left_dir, timeout)
        right = _run_command(right_command, values_right, right_dir, timeout)
        differences: list[str] = []
        left_key = _result_key(left, compare)
        right_key = _result_key(right, compare)
        if left_key != right_key:
            if left["status"] != right["status"]:
                differences.append("status")
            if left["exit_code"] != right["exit_code"]:
                differences.append("exit_code")
            if compare.get("stdout", True) and left["stdout"] != right["stdout"]:
                differences.append("stdout")
            if compare.get("stderr", True) and left["stderr"] != right["stderr"]:
                differences.append("stderr")
            if compare.get("artifacts", True) and left_key["artifacts"] != right_key["artifacts"]:
                differences.append("artifacts")
        report_cases.append(
            {
                "id": case_id,
                "source": _posix(source.relative_to(root)),
                "left": left,
                "right": right,
                "differences": differences,
            }
        )
    return {
        "schema": SCHEMA_VERSION,
        "root": ".",
        "work_root": str(work_root),
        "cases": report_cases,
        "differences": [
            {"id": case["id"], "fields": case["differences"]}
            for case in report_cases
            if case["differences"]
        ],
    }


def _default_root(value: str | None) -> Path:
    if value:
        return Path(value).resolve()
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return Path(result.stdout.strip()).resolve()


def _command_inventory(args: argparse.Namespace) -> int:
    root = _default_root(args.root)
    manifest = build_manifest(root)
    errors = _manifest_errors(manifest)
    if args.output:
        _write_json(Path(args.output), manifest)
    else:
        sys.stdout.write(_canonical_json(manifest))
    for error in errors:
        print(f"manifest error: {error}", file=sys.stderr)
    return 1 if errors else 0


def _command_baseline(args: argparse.Namespace) -> int:
    root = _default_root(args.root)
    manifest = build_manifest(root)
    baseline = _baseline_from_manifest(manifest)
    errors = _manifest_errors(manifest)
    if args.output:
        _write_json(Path(args.output), baseline)
    else:
        sys.stdout.write(_canonical_json(baseline))
    for error in errors:
        print(f"manifest error: {error}", file=sys.stderr)
    return 1 if errors else 0


def _command_target_registry(args: argparse.Namespace) -> int:
    root = _default_root(args.root)
    generated, _ = _target_registry_text(root)
    output = Path(args.output) if args.output else root / "compiler" / "target-registry.red"
    _write_text(output, generated)
    print(f"target registry: {output}")
    return 0


def _command_verify(args: argparse.Namespace) -> int:
    root = _default_root(args.root)
    expected_path = Path(args.manifest)
    expected = json.loads(expected_path.read_text(encoding="utf-8"))
    manifest = build_manifest(root)
    actual = (
        _baseline_from_manifest(manifest)
        if expected.get("kind") == "rebol-migration-baseline"
        else manifest
    )
    errors = _manifest_errors(manifest)
    if expected != actual:
        print("source manifest is stale", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"manifest error: {error}", file=sys.stderr)
        return 1
    print("source manifest: OK")
    return 0


def _command_diff(args: argparse.Namespace) -> int:
    root = _default_root(args.root)
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    report = run_differential(config, root, Path(args.work_root) if args.work_root else None)
    if args.report:
        _write_json(Path(args.report), report)
    else:
        sys.stdout.write(_canonical_json(report))
    return 1 if report["differences"] else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", help="repository root (defaults to git root)")
    subparsers = parser.add_subparsers(dest="command", required=True)

    inventory = subparsers.add_parser("inventory", help="write a deterministic source manifest")
    inventory.add_argument("--output", help="JSON output path; stdout when omitted")
    inventory.set_defaults(handler=_command_inventory)

    baseline = subparsers.add_parser(
        "baseline", help="write the checked Rebol migration baseline"
    )
    baseline.add_argument("--output", help="JSON output path; stdout when omitted")
    baseline.set_defaults(handler=_command_baseline)

    target_registry = subparsers.add_parser(
        "target-registry", help="generate compiler/target-registry.red from config"
    )
    target_registry.add_argument("--output", help="Red output path")
    target_registry.set_defaults(handler=_command_target_registry)

    verify = subparsers.add_parser("verify", help="compare a checked manifest with the current tree")
    verify.add_argument("manifest", help="checked JSON manifest")
    verify.set_defaults(handler=_command_verify)

    diff = subparsers.add_parser("diff", help="run two compiler commands against a corpus")
    diff.add_argument("config", help="JSON differential configuration")
    diff.add_argument("--work-root", help="directory for preserved run artifacts")
    diff.add_argument("--report", help="JSON report path; stdout when omitted")
    diff.set_defaults(handler=_command_diff)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.handler(args))
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, KeyError, ValueError) as error:
        print(f"self-hosting tool error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
