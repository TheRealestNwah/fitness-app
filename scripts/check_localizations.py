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

LANGUAGES = ["es", "de"]
# Each catalog and the targets whose strings it holds. The widget folder is built into the
# iOS widgets, the watch complications and the watch app, so they share its catalog.
CATALOGS = {
    "FitnessApp/Localizable.xcstrings": ["FitnessApp.build"],
    "StrideWidgets/Localizable.xcstrings": ["StrideWidgets.build", "StrideWatch.build", "StrideWatchWidgets.build"],
}


def extracted_keys(build_dir, targets):
    keys = {}
    paths = []
    for target in targets:
        # <project>.build/<Configuration>-<platform>/<target>.build/...; the project folder shares the
        # app target's name, so match the target inside a configuration folder.
        paths += glob.glob(os.path.join(build_dir, "**", "*-*", target, "**", "*.stringsdata"), recursive=True)
    for path in paths:
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
    report, failed = {}, False
    for catalog_path, targets in CATALOGS.items():
        keys = extracted_keys(sys.argv[1], targets)
        if not keys:
            print(f"{catalog_path}: no extracted strings found; was it built with SWIFT_EMIT_LOC_STRINGS?")
            failed = True
            continue
        missing = check(catalog_path, keys)
        print(f"{catalog_path}: {len(keys)} strings extracted, {len(missing)} missing a translation")
        for key, langs in list(missing.items())[:50]:
            print(f"  {key!r}: {', '.join(langs)}")
        report[catalog_path] = {k: {"comment": keys[k], "missing": v} for k, v in missing.items()}
        failed = failed or bool(missing)
    if "--dump" in sys.argv:
        with open(sys.argv[sys.argv.index("--dump") + 1], "w", encoding="utf-8") as f:
            json.dump(report, f, indent=1, ensure_ascii=False)
    return 1 if failed else 0


def check(catalog_path, keys):
    with open(catalog_path, encoding="utf-8") as f:
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
    return missing


if __name__ == "__main__":
    sys.exit(main())
