# Updating to the standalone WAF package

Starting with **5.22.0-waf.4**, the download contains only `WAF`, `WAFOptions`,
`WAFArchive`, and `WAFModelPaths`. No original WeakAuras folders are installed.
WAF still shares internal Lua API names with WeakAuras, so enable only one runtime.

## Already using WAF

Your `WAF.lua`, `WAFOptions.lua`, and `WAFArchive.lua` account SavedVariables files
remain authoritative. Install the four updated addon folders. No save conversion
is needed, and an empty WAF collection stays empty. Updates never backfill auras.

Older WAF packages included data-only legacy loaders in `WeakAuras`,
`WeakAurasOptions`, and `WeakAurasArchive`. With WoW closed, move those three
folders to a backup outside `Interface/AddOns` **only if their TOCs contain
`## X-WAF-Legacy: 1`**. These are the old WAF loaders, not ordinary WeakAuras.
Keep all SavedVariables files and backups. Do not remove another project's
folders or use an addon manager's option to delete saved settings.

## Migrating a pre-WAF Forever fork

Only use this for saves from earlier versions of this Forever fork. This does
not convert ordinary WeakAuras triggers into Forever triggers.

1. Completely exit WoW so its last edits reach disk.
2. Back up your account's `WTF/Account/<account>/SavedVariables` directory.
3. With Python 3, preview the migration from this repository:

   ```sh
   python3 tools/migrate_legacy_saves.py --saved-variables "/path/to/SavedVariables"
   ```

4. Check the proposed copies, then repeat with `--apply`:

   ```sh
   python3 tools/migrate_legacy_saves.py --saved-variables "/path/to/SavedVariables" --apply
   ```

5. Install the four WAF folders and restart WoW. Use `/waf` to check your groups,
   then reload and relog to verify persistence in your client build.

The helper copies missing saves, changing only the top-level global name. It
never executes Lua, modifies the old files, overwrites a WAF file, or combines
collections. Existing target files always win, even when empty. If you already
started WAF with an empty collection and now want old data instead, back up that
WAF file and deliberately move it aside before using the helper.

## Saved media paths

On load, import, or archive restore, the Forever modernization step changes
renderer-owned texture and sound paths under `Interface/AddOns/WeakAuras/Media`
to the bundled `WAF/Media` location. Aura names, IDs, text, custom Lua and custom
configuration are not rewritten. SharedMedia names and numeric file IDs remain
unchanged. Custom code with hard-coded old paths must be updated manually;
third-party assets must still be installed separately.
