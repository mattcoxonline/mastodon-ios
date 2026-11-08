#!/usr/bin/env python3
"""Prune localization catalogs and resources to an allowlist of languages.

Removes every non-allowlist locale from:
  - all *.xcstrings string catalogs (format-preserving: the serializer
    reproduces the catalogs' hand-maintained style exactly, verified by a
    byte-identical round-trip before any pruning is applied)
  - *.lproj resource folders inside app/extension targets
  - pbxproj: knownRegions, lproj file references, variant-group children

Re-run this after merging upstream to re-assert the allowlist.
Usage: python3 scripts/prune_localizations.py [--dry-run]
"""

import json
import os
import re
import subprocess
import sys

ALLOWLIST = {"en", "en-US", "Base", "nb", "pl", "uk", "ar"}
# "Base" applies to resource folders only, never to catalog locale entries.
LOCALE_ALLOWLIST = {l for l in ALLOWLIST if l != "Base"}

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY_RUN = "--dry-run" in sys.argv


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, cwd=REPO).stdout


# MARK: - xcstrings


def serialize(obj, indent=0):
    """Reproduce the xcstrings hand-maintained formatting exactly."""
    pad = "  " * indent
    if isinstance(obj, dict):
        if not obj:
            return "{}"
        items = [pad + "  " + json.dumps(k, ensure_ascii=False) + " : " + serialize(v, indent + 1)
                 for k, v in obj.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(obj, list):
        if not obj:
            return "[]"
        items = [pad + "  " + serialize(v, indent + 1) for v in obj]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    if isinstance(obj, bool):
        return "true" if obj else "false"
    if obj is None:
        return "null"
    if isinstance(obj, str):
        return json.dumps(obj, ensure_ascii=False)
    return str(obj)


def prune_catalog(path):
    with open(path, encoding="utf-8") as f:
        original = f.read()
    data = json.loads(original)

    # Safety: only prune when the serializer reproduces the current bytes exactly,
    # so the diff stays surgical and merges with upstream stay easy.
    if serialize(data) != original:
        print(f"SKIP {os.path.basename(path)}: serializer round-trip mismatch")
        return 0

    removed = 0
    for entry in data.get("strings", {}).values():
        locs = entry.get("localizations", {})
        for lang in list(locs):
            if lang not in LOCALE_ALLOWLIST:
                del locs[lang]
                removed += 1
    if not DRY_RUN and removed:
        with open(path, "w", encoding="utf-8") as f:
            f.write(serialize(data))
    return removed


# MARK: - lproj folders


def pruned_lproj_files():
    tracked = [l for l in git("ls-files").splitlines() if ".lproj/" in l]
    resource_files = [l for l in tracked if not l.startswith("Localization/")]
    return [f for f in resource_files
            if f.split(".lproj/")[0].rsplit("/", 1)[-1] not in ALLOWLIST], resource_files


# MARK: - pbxproj

UUID = r"[0-9A-F]{24,32}"


def prune_pbxproj(stats):
    path = os.path.join(REPO, "Mastodon.xcodeproj/project.pbxproj")
    with open(path) as f:
        lines = f.readlines()

    removed_uuids = set()

    # 1. PBXFileReference lines for pruned locales: `UUID /* xx */ = {isa = PBXFileReference; ... name = xx; path = xx.lproj/...`
    kept = []
    fileref = re.compile(UUID + r' /\* ([^*]+) \*/ = \{isa = PBXFileReference;.*?(?:name|path) = "?([a-zA-Z-]+)"?\.lproj')
    for ln in lines:
        m = fileref.search(ln)
        if m and m.group(2) not in ALLOWLIST:
            removed_uuids.add(ln.split(" ", 1)[0])
            stats["pbxproj filerefs"] += 1
            continue
        kept.append(ln)
    lines = kept

    # 2. variant-group child lines pointing at removed file refs
    kept = []
    for ln in lines:
        m = re.match(r"\t+" + UUID + r" /\* ", ln)
        if m and ln.split(" ", 1)[0] in removed_uuids and ln.rstrip().endswith(","):
            stats["pbxproj variant children"] += 1
            continue
        kept.append(ln)
    lines = kept

    # 3. knownRegions
    out, in_kr = [], False
    for ln in lines:
        if re.match(r"\t*knownRegions = \($", ln):
            in_kr = True
            out.append(ln)
            for locale in ["en", "Base", "nb", "pl", "uk", "ar"]:
                out.append(f"\t\t\t\t{locale},\n")
            stats["knownRegions"] = "rewritten"
            continue
        if in_kr:
            if ln.strip().startswith(");"):
                in_kr = False
                out.append(ln)
            continue
        out.append(ln)
    lines = out

    if not DRY_RUN:
        with open(path, "w") as f:
            f.writelines(lines)
    return len(removed_uuids)


def main():
    print(f"allowlist: {sorted(LOCALE_ALLOWLIST)} (+ Base resources)   dry-run: {DRY_RUN}\n")

    for catalog in sorted(git("ls-files", "*.xcstrings").splitlines()):
        removed = prune_catalog(os.path.join(REPO, catalog))
        if removed:
            print(f"catalog {catalog}: -{removed} locale entries")
    for catalog in sorted(git("ls-files", "*.xcstrings").splitlines()):
        if DRY_RUN:
            pass

    deleted, resource_files = prune_catalogs_final = (None, None)
    deleted, resource_files = pruned_lproj_files()
    print(f"lproj resource files to delete: {len(deleted)} / {len(resource_files)}")
    if not DRY_RUN and deleted:
        dirs = sorted({os.path.dirname(os.path.join(REPO, f)) for f in deleted})
        for d in dirs:
            subprocess.run(["git", "rm", "-rq", os.path.relpath(d, REPO)], cwd=REPO)

    stats = {"pbxproj filerefs": 0, "pbxproj variant children": 0, "knownRegions": ""}
    prune_pbxproj(stats)
    print("pbxproj:", {k: v for k, v in stats.items() if v})


if __name__ == "__main__":
    main()
