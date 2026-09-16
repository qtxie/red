#!/usr/bin/env python3
"""Keep code generator failure sites annotated with a stable id and a searchable name.

Every `return INVALID_IR` / `return UNSUPPORTED` in the hybrid code generators has
to return through `fail-invalid` / `fail-unsupported` instead, carrying a site
number that never changes and a short name that is written verbatim in the source:

    return fail-invalid 137 "layout-module-globals/global-flags#4"

The name is the locating anchor: grepping the printed name jumps straight to the
failing line, so no generated map is needed and nothing can point at a stale line.

`OUTPUT_FULL` is deliberately not annotated: the Red layer already grows the output
buffer and retries (system/compiler-rsir-core.red `finish-code`), so those returns
are a capacity signal, not a failure.

usage:
    python tools/codegen/sync-codegen-sites.py --check
    python tools/codegen/sync-codegen-sites.py --write
    python tools/codegen/sync-codegen-sites.py --locate 137
    python tools/codegen/sync-codegen-sites.py --locate global-flags
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TARGETS = [
    ("x64", ROOT / "system/codegen/x64-codegen.reds"),
    ("arm64", ROOT / "system/codegen/arm64-codegen.reds"),
    ("reader", ROOT / "system/codegen/codegen-rsir-reader.reds"),
]

FUNC_RE = re.compile(r"^(\t*)([A-Za-z][\w?!.-]*):\s*func\s*\[")
GUARD_RE = re.compile(r"^\t*(if|unless|either|case|all|any|while|until|switch)\b")
ANNOTATED_RE = re.compile(
    r"\breturn (fail-invalid|fail-unsupported) (\d+) \"([^\"]+)\""
)
BARE_RE = re.compile(r"\breturn (INVALID_IR|UNSUPPORTED)\b")
LEGACY_RE = re.compile(r"\breturn report-invalid \d+\b")
TOKEN_RE = re.compile(r"[a-z][a-z0-9-]*(?:/[a-z][a-z0-9-]*)?")

# Words that carry no information about what a guard actually rejected.
STOPWORDS = {
    "if", "unless", "either", "case", "all", "any", "not", "true", "false",
    "return", "while", "until", "null", "func", "as", "with", "local", "do",
    "and", "or", "xor", "index", "id", "count", "size", "width", "kind",
    "type", "value", "target", "first", "last", "next", "offset", "slot",
    "step", "steps", "row", "limit", "used", "total", "base", "end",
    "system",
}

KIND_OF_TOKEN = {"INVALID_IR": "fail-invalid", "UNSUPPORTED": "fail-unsupported"}


def decode(raw):
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("latin-1"), "latin-1"


def function_name_at(lines, index):
    """Nearest enclosing `name: func [` declaration above `index`."""
    for i in range(index, -1, -1):
        match = FUNC_RE.match(lines[i])
        if match:
            return match.group(2)
    return "toplevel"


def guard_candidates(lines, index, head_end):
    """Guard text for a failure, innermost first.

    The text in front of the return comes first so the hint names the condition
    that actually rejected the value; the enclosing guard lines follow.
    """
    texts = [lines[index][:head_end]]
    start = index
    while start > 0 and index - start < 6:
        start -= 1
        texts.append(lines[start])
        if GUARD_RE.match(lines[start]):
            break
    return texts


def hint_for(texts, excluded):
    """First identifier that says what the guard was looking at."""
    for text in texts:
        tokens = TOKEN_RE.findall(text)
        for token in tokens:
            if "/" in token:
                head, tail = token.split("/", 1)
                if head in STOPWORDS or head in excluded:
                    continue
                if tail in STOPWORDS:
                    continue
                return token
        for token in tokens:
            if "/" in token:
                continue
            if token in STOPWORDS or token in excluded:
                continue
            return token
    return None


class FileSites:
    def __init__(self, label, path):
        self.label = label
        self.path = path
        self.lines = []
        self.encoding = "utf-8"

    def load(self):
        raw = self.path.read_bytes()
        text, self.encoding = decode(raw)
        self.lines = text.splitlines(keepends=True)

    def save(self):
        self.path.write_bytes("".join(self.lines).encode(self.encoding))

    def scan(self):
        """Return the annotated sites plus the bare ones that still need an id."""
        annotated = []
        bare = []
        for number, line in enumerate(self.lines):
            match = ANNOTATED_RE.search(line)
            if match:
                annotated.append({
                    "number": number,
                    "kind": match.group(1),
                    "id": int(match.group(2)),
                    "name": match.group(3),
                })
                continue
            match = BARE_RE.search(line)
            if match:
                bare.append({
                    "number": number,
                    "kind": KIND_OF_TOKEN[match.group(1)],
                    "span": match.span(),
                    "legacy": False,
                })
                continue
            match = LEGACY_RE.search(line)
            if match:
                bare.append({
                    "number": number,
                    "kind": "fail-invalid",
                    "span": match.span(),
                    "legacy": True,
                })
        return annotated, bare

    def function_names(self):
        names = set()
        for line in self.lines:
            match = FUNC_RE.match(line)
            if match:
                names.add(match.group(2))
        return names

    def annotate(self):
        annotated, bare = self.scan()
        if not bare:
            return 0

        used_names = {site["name"] for site in annotated}
        used_ids = {site["id"] for site in annotated}
        next_id = max(used_ids) + 1 if used_ids else 1
        per_function = {}
        declared = self.function_names()

        for site in bare:
            number = site["number"]
            function = function_name_at(self.lines, number)
            ordinal = per_function.get(function, 0) + 1
            per_function[function] = ordinal

            hint = hint_for(
                guard_candidates(self.lines, number, site["span"][0]),
                declared | {function},
            )
            stem = "%s/%s#%d" % (function, hint, ordinal) if hint else "%s#%d" % (
                function, ordinal
            )
            name = stem
            suffix = 2
            while name in used_names:
                name = "%s~%d" % (stem, suffix)
                suffix += 1
            used_names.add(name)

            site_id = next_id
            next_id += 1

            line = self.lines[number]
            start, end = site["span"]
            replacement = 'return %s %d "%s"' % (site["kind"], site_id, name)
            self.lines[number] = line[:start] + replacement + line[end:]

        return len(bare)

    def problems(self):
        annotated, bare = self.scan()
        issues = []
        for site in bare:
            issues.append(
                "%s:%d: unannotated %s return"
                % (self.path.name, site["number"] + 1, site["kind"])
            )
        by_id = {}
        by_name = {}
        for site in annotated:
            if site["id"] in by_id:
                issues.append(
                    "%s:%d: duplicate site id %d (also on line %d)"
                    % (self.path.name, site["number"] + 1, site["id"],
                       by_id[site["id"]] + 1)
                )
            by_id[site["id"]] = site["number"]
            if site["name"] in by_name:
                issues.append(
                    "%s:%d: duplicate site name %r (also on line %d)"
                    % (self.path.name, site["number"] + 1, site["name"],
                       by_name[site["name"]] + 1)
                )
            by_name[site["name"]] = site["number"]
        return issues, len(annotated)

    def locate(self, token):
        annotated, bare = self.scan()
        hits = []
        if token.isdigit():
            hits = [s for s in annotated if s["id"] == int(token)]
        if not hits:
            hits = [s for s in annotated if s["name"] == token]
        if not hits:
            hits = [s for s in annotated if token in s["name"]]
        for site in hits:
            print("%s:%d: site %d (%s) %s" % (
                self.path, site["number"] + 1, site["id"], site["name"],
                site["kind"]
            ))
        return len(hits)


def run_write():
    changed = 0
    for label, path in TARGETS:
        sites = FileSites(label, path)
        sites.load()
        count = sites.annotate()
        if count:
            sites.save()
            changed += count
        print("%-8s %4d site(s) annotated  %s" % (label, count, path.name))
    print("total: %d" % changed)
    return 0


def run_check():
    issues = []
    total = 0
    for label, path in TARGETS:
        sites = FileSites(label, path)
        sites.load()
        found, count = sites.problems()
        total += count
        issues.extend(found)
        print("%-8s %4d annotated site(s)  %s" % (label, count, path.name))
    for issue in issues:
        print("ERROR %s" % issue)
    if issues:
        print("%d problem(s) found" % len(issues))
        return 1
    print("ok: %d annotated sites" % total)
    return 0


def run_locate(token):
    hits = 0
    for _label, path in TARGETS:
        sites = FileSites(_label, path)
        sites.load()
        hits += sites.locate(token)
    if not hits:
        print("no site matches %r" % token)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true", help="annotate bare sites")
    group.add_argument("--check", action="store_true", help="verify annotations")
    group.add_argument("--locate", metavar="ID_OR_NAME", help="print file:line")
    args = parser.parse_args()

    if args.write:
        return run_write()
    if args.check:
        return run_check()
    return run_locate(args.locate)


if __name__ == "__main__":
    sys.exit(main())
