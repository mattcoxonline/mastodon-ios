#!/usr/bin/env python3
"""Apply Norwegian Bokmål translation batches to the string catalogs.

Usage: python3 scripts/add_nb.py <batch.json>

Batch format:
{
  "<catalog-filename>": {
    "<key>": "plain translation"
    or {"plural": {"one": "...", "other": "..."}}
  }
}

Insertions are format-preserving (same serializer as prune_localizations,
with a byte-identical round-trip guard). Keys missing from the catalog are
reported; existing nb entries are overwritten.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prune_localizations import serialize, REPO, git  # noqa: E402

CATALOGS = {
    name: os.path.join(REPO, "MastodonSDK/Sources/MastodonLocalization/Resources", name)
    for name in [
        "Localizable.xcstrings",
        "Localizable-Collections.xcstrings",
        "Localizable-CommonAlerts.xcstrings",
        "Localizable-CommonControls.xcstrings",
        "Localizable-ConfirmationDialogs.xcstrings",
        "Localizable-Lists.xcstrings",
        "Localizable-MastodonMenuAction.xcstrings",
        "Localizable-Notifications.xcstrings",
        "Localizable-Onboarding.xcstrings",
        "Localizable-Profile.xcstrings",
        "Localizable-Settings.xcstrings",
        "Localizable-Timeline.xcstrings",
    ]
}


def string_unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural_unit(variants):
    return {"variations": {"plural": {cat: string_unit(text)
                                      for cat, text in variants.items()}}}


def main():
    batch_path = sys.argv[1]
    with open(batch_path) as f:
        batch = json.load(f)

    applied, missing = 0, []
    for catalog_name, keys in batch.items():
        path = CATALOGS[catalog_name]
        with open(path) as f:
            original = f.read()
        data = json.loads(original)
        if serialize(data) != original:
            sys.exit(f"refusing: {catalog_name} does not round-trip; fix formatting first")

        catalog = data["strings"]
        for key, value in keys.items():
            if key not in catalog:
                missing.append(f"{catalog_name}:{key}")
                continue
            loc = string_unit(value) if isinstance(value, str) else plural_unit(value["plural"])
            catalog[key]["localizations"]["nb"] = loc
            applied += 1

        with open(path, "w") as f:
            f.write(serialize(data))

    print(f"applied {applied} keys")
    if missing:
        print("MISSING KEYS:")
        for m in missing:
            print("  " + m)

    # coverage report
    out = git("ls-files", "*.xcstrings").splitlines()
    for name in sorted(out):
        data = json.load(open(os.path.join(REPO, name)))
        keys = data.get("strings", {})
        nb = sum(1 for v in keys.values() if "nb" in v.get("localizations", {}))
        if nb:
            print(f"coverage {os.path.basename(name)}: {nb}/{len(keys)} nb")


if __name__ == "__main__":
    main()
