#!/usr/bin/env python3
"""Writes FitnessApp/Localizable.xcstrings from the translation tables in translations_a.py and
translations_b.py, checking that each translation keeps the key's format specifiers.

Run from the repository root: python3 scripts/build_catalog.py
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import translations_a  # noqa: E402
import translations_b  # noqa: E402

CATALOG = "FitnessApp/Localizable.xcstrings"
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f|%)|\$\{\w+\}")


def specifiers(text):
    """Format specifiers with positions made explicit, sorted by position."""
    found, n = [], 0
    for m in SPEC.finditer(text):
        s = m.group(0)
        if s == "%%":
            continue
        pos = re.match(r"%(\d+)\$", s)
        if pos:
            found.append((int(pos.group(1)), re.sub(r"%\d+\$", "%", s)))
        else:
            n += 1
            found.append((n, s))
    return sorted(found)


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def main():
    strings, problems = {}, []
    for key, es, de in translations_a.T + translations_b.T:
        if key in strings:
            problems.append(f"duplicate key {key!r}")
        for lang, value in (("es", es), ("de", de)):
            if specifiers(value) != specifiers(key):
                problems.append(f"{lang} {key!r}: {specifiers(value)} != {specifiers(key)}")
        strings[key] = {"localizations": {"es": unit(es), "de": unit(de)}}
    for key in translations_b.KEEP:
        strings[key] = {"shouldTranslate": False}
    for key, forms in translations_b.PLURALS.items():
        strings[key] = {"localizations": {
            lang: {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}
            for lang, (one, other) in forms.items()}}
    for key, (arg, forms) in translations_b.SUBSTITUTIONS.items():
        strings[key] = {"localizations": {
            lang: {**unit(template), "substitutions": {"count": {
                "argNum": arg, "formatSpecifier": "lld",
                "variations": {"plural": {"one": unit(one), "other": unit(other)}}}}}
            for lang, (template, one, other) in forms.items()}}
    if problems:
        print("\n".join(problems))
        return 1
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    with open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")
    print(f"wrote {len(strings)} strings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
