"""Validate shipped ARBs without requiring a translation service or extra packages."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("en", "vi", "es", "pt_BR", "fr", "de", "id", "ja", "ko", "zh_Hans", "hi", "ar")


def validate(directory: Path) -> list[str]:
    errors = []
    source = json.loads((directory / "app_en.arb").read_text(encoding="utf8"))
    keys = {key for key in source if not key.startswith("@")}
    for key in keys:
        if not re.fullmatch(r"[a-z][A-Za-z0-9]*", key):
            errors.append(f"Invalid key: {key}")
        if not source.get("@" + key, {}).get("description"):
            errors.append(f"Missing description: {key}")
    for locale in LOCALES:
        path = directory / f"app_{locale}.arb"
        if not path.exists():
            errors.append(f"Missing locale: {locale}")
            continue
        data = json.loads(path.read_text(encoding="utf8"))
        actual = {key for key in data if not key.startswith("@")}
        if actual != keys:
            errors.append(f"{locale}: missing={sorted(keys-actual)}, extra={sorted(actual-keys)}")
        if data.get("@@locale") != locale:
            errors.append(f"{locale}: wrong locale identifier")
        for key in keys & actual:
            value = data[key]
            if not isinstance(value, str) or not value.strip() or "\ufffd" in value:
                errors.append(f"{locale}/{key}: empty or invalid Unicode")
                continue
            expected = set(source.get("@" + key, {}).get("placeholders", {}))
            found = set(re.findall(r"\{([a-zA-Z][a-zA-Z0-9]*)\s*[,}]", value))
            if found != expected:
                errors.append(f"{locale}/{key}: placeholders expected={expected}, found={found}")
    # gen_l10n requires these parents for region/script-specific resources.
    for base, child in (("pt", "pt_BR"), ("zh", "zh_Hans")):
        parent = json.loads((directory / f"app_{base}.arb").read_text(encoding="utf8"))
        variant = json.loads((directory / f"app_{child}.arb").read_text(encoding="utf8"))
        if {k: v for k, v in parent.items() if not k.startswith("@")} != {
            k: v for k, v in variant.items() if not k.startswith("@")
        }:
            errors.append(f"{base}: fallback differs from its shipped {child} resource")
    return errors


if __name__ == "__main__":
    failures = validate(ROOT / "lib/l10n")
    for failure in failures:
        print(failure)
    if failures:
        raise SystemExit(1)
    print("PASS: 12 locale key sets, descriptions, Unicode and placeholders; human translation review remains pending.")
