#!/usr/bin/env python3
"""Structural YAML validation for the Factory Assistant overlay templates.

The shipped Core templates under
buildroot-external/rootfs-overlay/usr/share/factory-assistant/ use Home
Assistant's custom YAML tags (!include, !include_dir_*, !secret, !env_var).
Stock SafeLoader rejects those, so this validator registers them as no-ops and
then parses each file, reporting the first structural error with its location.

This checks that the YAML *parses* (no tabs/indent/duplicate-key errors); it
does not check Lovelace/Core schema — that is the job of a running Core, and
the templates are intentionally full of example entity ids.

Usage: lint_yaml.py FILE [FILE ...]   (exits non-zero on any parse error)
"""
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("lint_yaml.py: PyYAML not installed\n")
    sys.exit(2)


class FALoader(yaml.SafeLoader):
    """SafeLoader that tolerates Home Assistant's custom tags."""


def _ha_tag(loader, node):
    # We only care that the document parses; the tag's payload is irrelevant.
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    return loader.construct_mapping(node)


for _tag in (
    "!include",
    "!include_dir_named",
    "!include_dir_merge_named",
    "!include_dir_list",
    "!include_dir_merge_list",
    "!secret",
    "!env_var",
    "!input",
):
    FALoader.add_constructor(_tag, _ha_tag)


def main(paths):
    errors = 0
    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                # load (not safe_load) so our custom-tag loader is used.
                yaml.load(fh, Loader=FALoader)
        except yaml.YAMLError as exc:
            mark = getattr(exc, "problem_mark", None)
            where = f":{mark.line + 1}:{mark.column + 1}" if mark else ""
            problem = getattr(exc, "problem", str(exc))
            print(f"YAML ERROR {path}{where}: {problem}", file=sys.stderr)
            errors += 1
        except OSError as exc:
            print(f"YAML ERROR {path}: {exc}", file=sys.stderr)
            errors += 1
        else:
            print(f"ok  {path}")
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stderr.write("usage: lint_yaml.py FILE [FILE ...]\n")
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
