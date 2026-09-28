#!/usr/bin/env python3
"""Checks that every string the compiler extracted from the app is in Localizable.xcstrings
and translated into each required language.

Xcode writes the extracted keys to .stringsdata files during the build (SWIFT_EMIT_LOC_STRINGS).
Usage: check_localizations.py <derived-data-dir> [--dump missing.json]
"""
import glob
import json
import os
import sys

CATALOG = "FitnessApp/Localizable.xcstrings"
LANGUAGES = ["es", "de"]


def extracted_keys(build_dir):
    keys = {}
    pattern = os.path.join(build_dir, "**", "FitnessApp.build", "**", "*.stringsdata")
    for path in glob.glob(pattern, recursive=True):
        if "Tests" in path:
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for entry in data.get("tables", {}).get("Localizable", []):
            keys.setdefault(entry["key"], entry.get("comment"))
    return keys


def translated(entry, lang):
    loc = entry.get("localizations", {}).get(lang)
    if not loc:
        return False
    if "stringUnit" in loc:
        return loc["stringUnit"].get("state") == "translated" and loc["stringUnit"].get("value", "") != ""
    return "variations" in loc


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    keys = extracted_keys(sys.argv[1])
    if not keys:
        print("No extracted strings found; was the app built with SWIFT_EMIT_LOC_STRINGS?")
        return 1
    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f).get("strings", {})
    missing = {}
    for key in sorted(keys):
        # Keys with nothing to translate (numbers, symbols, format-only) don't need entries.
        if not any(c.isalpha() for c in key.replace("%lld", "").replace("%@", "").replace("%lf", "")):
            continue
        entry = catalog.get(key)
        if entry is None:
            missing[key] = LANGUAGES
        elif entry.get("shouldTranslate") is False:
            continue
        else:
            langs = [lang for lang in LANGUAGES if not translated(entry, lang)]
            if langs:
                missing[key] = langs
    print(f"{len(keys)} strings extracted, {len(missing)} missing a translation")
    for key, langs in list(missing.items())[:50]:
        print(f"  {key!r}: {', '.join(langs)}")
    if "--dump" in sys.argv:
        with open(sys.argv[sys.argv.index("--dump") + 1], "w", encoding="utf-8") as f:
            json.dump({k: {"comment": keys[k], "missing": v} for k, v in missing.items()}, f, indent=1, ensure_ascii=False)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
