#!/usr/bin/env python3
"""Audit, annotate, and locate terminal hybrid codegen failures.

    python tools/codegen/sync-codegen-sites.py --check
    python tools/codegen/sync-codegen-sites.py --write
    python tools/codegen/sync-codegen-sites.py --locate arm64:283

IDs are backend-local. --write retains existing unique IDs and names, assigns
new ones, and repairs duplicates after their first occurrence. Site 0 with name
"auto" requests a new annotation. Comments and literals are not scanned as code.
"""

import argparse
import bisect
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGETS = [(name, ROOT / ("system/codegen/%s" % file)) for name, file in [
    ("x64", "x64-codegen.reds"), ("arm64", "arm64-codegen.reds"),
    ("reader", "codegen-rsir-reader.reds")]]
KINDS = {"INVALID_IR": "fail-invalid", "UNSUPPORTED": "fail-unsupported",
         "INTERNAL_ERROR": "fail-internal", "RESOURCE_LIMIT": "fail-limit",
         "OUT_OF_MEMORY": "fail-memory"}
HELPERS = dict.fromkeys(KINDS.values(), 0)
HELPERS.update({"fail-code": 1, "fail-output": 2, "fail-mismatch": 2})


@dataclass
class Token:
    value: str
    start: int
    end: int
    kind: str = "word"


def tokens(source):
    """Lex source anchors, not Red/System semantics; preserve source positions."""
    pos = 0
    while pos < len(source):
        char = source[pos]
        if char.isspace():
            pos += 1
            continue
        if char == ";":
            end = source.find("\n", pos)
            pos = len(source) if end < 0 else end + 1
            continue
        start = pos
        if source[pos:pos + 2] in ('#"', '#{'):
            pos += 1
            char = source[pos]
        if char in '"{':
            quoted, depth = char == '"', 1
            pos += 1
            while pos < len(source) and depth:
                char = source[pos]
                if char == "^":
                    pos += 2
                    continue
                if quoted and char == '"':
                    depth = 0
                elif not quoted:
                    if char == "{":
                        depth += 1
                    elif char == "}":
                        depth -= 1
                pos += 1
            if depth:
                raise ValueError("unterminated literal at offset %d" % start)
            kind = "string" if source[start] == '"' else "literal"
            yield Token(source[start:pos], start, pos, kind)
            continue
        if char in "[]()":
            pos += 1
            yield Token(char, start, pos, "delimiter")
            continue
        while pos < len(source) and not source[pos].isspace() and source[pos] not in '[]();"{}':
            pos += 1
        if pos == start:
            pos += 1
        yield Token(source[start:pos], start, pos)


class FileSites:
    def __init__(self, label, path):
        self.label, self.path = label, path
        self.source, self.encoding = "", "utf-8"

    def load(self):
        raw = self.path.read_bytes()
        try:
            self.source = raw.decode("utf-8")
        except UnicodeDecodeError:
            self.encoding = "latin-1"
            self.source = raw.decode(self.encoding)

    def scan(self):
        stream = list(tokens(self.source))
        lines = [m.end() for m in re.finditer("\n", self.source)]
        annotated, bare, function = [], [], None
        for index, token in enumerate(stream):
            value = token.value
            if value == "func" and index and stream[index - 1].value.endswith(":"):
                function = stream[index - 1].value[:-1]
            if not function or function.startswith("fail-") or token.kind != "word":
                continue
            base = {"number": bisect.bisect_right(lines, token.start),
                    "function": function, "start": token.start, "end": token.end}
            if value in HELPERS:
                site_pos = index + 1 + HELPERS[value]
                if site_pos + 1 < len(stream):
                    site, name = stream[site_pos:site_pos + 2]
                    if site.value.isdigit() and name.kind == "string":
                        annotated.append(dict(base, kind=value, id=int(site.value),
                                              name=name.value[1:-1],
                                              id_start=site.start, id_end=site.end,
                                              name_start=name.start, name_end=name.end))
                        continue
                bare.append(dict(base, kind=value, malformed=True))
            elif value in KINDS or value == "OUTPUT_FULL":
                bare.append(dict(base, kind=KINDS.get(value, "fail-output"), malformed=False))
        return annotated, bare

    def annotate(self):
        annotated, bare = self.scan()
        next_id = max((s["id"] for s in annotated), default=0) + 1
        used_names = {s["name"] for s in annotated if s["name"] != "auto"}
        seen_ids, seen_names, replacements, ordinal = set(), set(), [], {}

        def new_id():
            nonlocal next_id
            result = next_id
            next_id += 1
            return result

        def new_name(site):
            function = site["function"]
            ordinal[function] = ordinal.get(function, 0) + 1
            stem = "%s/%s#%d" % (function, site["kind"][5:], ordinal[function])
            name, suffix = stem, 2
            while name in used_names:
                name = "%s~%d" % (stem, suffix)
                suffix += 1
            used_names.add(name)
            return name

        for site in annotated:
            if site["id"] <= 0 or site["id"] in seen_ids:
                replacements.append((site["id_start"], site["id_end"], str(new_id())))
            seen_ids.add(site["id"])
            if site["name"] == "auto" or site["name"] in seen_names:
                replacements.append((site["name_start"], site["name_end"], '"%s"' % new_name(site)))
            seen_names.add(site["name"])
        for site in bare:
            # Capacity requires explicit required/available values at the source.
            if site["malformed"] or site["kind"] == "fail-output":
                continue
            replacements.append((site["start"], site["end"], '%s %d "%s"' % (
                site["kind"], new_id(), new_name(site))))
        for start, end, text in sorted(replacements, reverse=True):
            self.source = self.source[:start] + text + self.source[end:]
        if replacements:
            self.path.write_bytes(self.source.encode(self.encoding))
        return len(replacements)

    def problems(self):
        annotated, bare = self.scan()
        issues = ["%s:%d: unannotated or malformed %s" % (
            self.path.name, s["number"] + 1, s["kind"]) for s in bare]
        ids, names = {}, {}
        for site in annotated:
            for value, seen, label in [(site["id"], ids, "id"), (site["name"], names, "name")]:
                if value in seen or value in (0, "auto"):
                    issues.append("%s:%d: duplicate or unassigned site %s %r" % (
                        self.path.name, site["number"] + 1, label, value))
                seen[value] = site["number"]
        return issues, len(annotated)

    def locate(self, query):
        if ":" in query:
            backend, query = query.split(":", 1)
            if backend != self.label:
                return 0
        sites, _ = self.scan()
        hits = [s for s in sites if str(s["id"]) == query or s["name"] == query]
        if not hits:
            hits = [s for s in sites if query in s["name"]]
        for site in hits:
            print("%s:%d: %s:%d (%s) %s" % (
                self.path, site["number"] + 1, self.label, site["id"], site["name"], site["kind"]))
        return len(hits)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    group.add_argument("--locate", metavar="BACKEND:ID_OR_NAME")
    args = parser.parse_args()
    issues, total, hits = [], 0, 0
    for label, path in TARGETS:
        sites = FileSites(label, path)
        sites.load()
        if args.locate:
            hits += sites.locate(args.locate)
            continue
        if args.write:
            print("%s: %d annotation edits" % (label, sites.annotate()))
        found, count = sites.problems()
        issues.extend(found)
        total += count
        print("%-8s %4d annotated site(s)" % (label, count))
    if args.locate:
        return 0 if hits else 1
    for issue in issues:
        print("ERROR " + issue)
    print("%d sites, %d problem(s)" % (total, len(issues)))
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
