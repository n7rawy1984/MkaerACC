"""Local Stage C Vary verification; no network or application behavior changes."""

import re

_FIELD_NAME = re.compile(r"[!#$%&'*+.^_`|~0-9A-Za-z-]+", re.ASCII)


def parse_vary(values):
    """Combine header lines into case-insensitive field-name tokens."""
    if values is None:
        return set()
    if isinstance(values, str):
        values = [values]
    names = set()
    for value in values:
        if not isinstance(value, str):
            raise AssertionError("Invalid Vary header value")
        for part in value.split(","):
            name = part.strip(" \t")
            if not name:
                continue
            if not _FIELD_NAME.fullmatch(name):
                raise AssertionError("Invalid Vary field name")
            names.add(name.lower())
    return names


def require_origin_in_vary(values):
    names = parse_vary(values)
    if "origin" not in names:
        raise AssertionError("Vary must include Origin")
    return names
