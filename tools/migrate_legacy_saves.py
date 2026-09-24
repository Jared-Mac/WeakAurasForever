#!/usr/bin/env python3
"""Opt-in offline migration of pre-WAF fork saves; never execute saved Lua."""
import argparse
import os
from pathlib import Path
import re
import tempfile

SAVES = (
    ('WeakAuras', 'WeakAurasSaved', 'WAF', 'WAFSaved'),
    ('WeakAurasOptions', 'WeakAurasOptionsSaved', 'WAFOptions', 'WAFOptionsSaved'),
    ('WeakAurasArchive', 'WeakAurasArchive', 'WAFArchive', 'WAFArchive'),
)


def migration_plan(directory):
    """Validate every source before writing anything; any target file wins."""
    plan, messages = [], []
    for source_name, source_global, target_name, target_global in SAVES:
        source = directory / (source_name + '.lua')
        target = directory / (target_name + '.lua')
        if target.exists() or target.is_symlink():
            messages.append(f'Keep {target.name}: already exists (including empty saves).')
            continue
        if not source.is_file():
            messages.append(f'Skip {source.name}: no legacy file.')
            continue
        original = source.read_bytes()
        # WoW serializes these as a single root table assignment. Only rename
        # that first identifier. Strings, custom code and table contents stay
        # byte-for-byte intact; unfamiliar file formats are refused.
        pattern = rb'\A((?:\xef\xbb\xbf)?\s*)' + source_global.encode() + rb'(\s*=\s*\{)'
        match = re.match(pattern, original)
        if not match:
            raise ValueError(f'{source.name}: expected a root {source_global} table; no files written.')
        converted = (match[1] + target_global.encode() + match[2]
                     + original[match.end():])
        plan.append((source, target, original, converted))
        messages.append(f'Copy {source.name} -> {target.name}; retain the original.')
    return plan, messages


def apply_plan(plan):
    # Detect a save changing since the preview was prepared (e.g. WoW exiting).
    for source, target, original, _ in plan:
        if source.read_bytes() != original:
            raise ValueError(f'{source.name} changed: exit WoW and run the migration again.')
        if target.exists() or target.is_symlink():
            raise FileExistsError(f'{target.name} now exists; it will not be overwritten.')
    for _, target, _, converted in plan:
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.waf-migrate-',
                                             delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(converted)
                stream.flush()
                os.fsync(stream.fileno())
            # Publish the complete file without replacing a concurrently created
            # target. The original legacy file is itself the recovery copy.
            os.link(temporary, target)
        finally:
            if temporary is not None:
                temporary.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--saved-variables', type=Path, required=True,
                        help='Account SavedVariables directory; completely exit WoW first.')
    parser.add_argument('--apply', action='store_true',
                        help='Create missing WAF files. Default is a read-only preview.')
    args = parser.parse_args()
    if not args.saved_variables.is_dir():
        parser.error('SavedVariables directory does not exist.')
    try:
        plan, messages = migration_plan(args.saved_variables)
        for message in messages:
            print(message)
        if args.apply:
            apply_plan(plan)
            print(f'Created {len(plan)} WAF save file(s). Original files retained.')
        else:
            print('Preview only. Exit WoW, then repeat with --apply to copy missing saves.')
    except (OSError, ValueError) as error:
        parser.exit(1, f'Migration stopped: {error}\n')


if __name__ == '__main__':
    main()
