# WeakAurasForever

<img src="assets/branding/waf-logo-400.png" alt="WAF logo" width="200" height="200">

**Experimental WeakAuras fork for WoW Forever 1.60.1 (interface 16001).**
Build customizable displays with the familiar WeakAuras editor and a new set of
triggers designed for Forever's addon restrictions.

This is an independent community fork of
[WeakAuras](https://github.com/WeakAuras/WeakAuras2), based on commit
`91c52bc92f86ae4a5232913039225a0032aca048`. It is not an official WeakAuras release.
The WeakAuras Team and contributors retain credit for the original work.

## What works in the prototype

- The WeakAuras editor, groups, anchors, icon/bar styling, text, animations,
  and import/export for displays created with the Forever sources.
- Categorized triggers for spells, auras, items, units, player/world state,
  and timers; All/Any combinations and conditions using readable data.
- Native cooldown/recharge icons, native player/target aura icons, and a native
  player mana bar. Protected values stay in Blizzard's display APIs.
- Ammo and item counts, public spell checks, swing timers, and manual timers.
- A Hunter starter group with mana, ranged swing, learned core cooldowns,
  and learned Night Elf racials.

**This is an alpha, not full WeakAuras compatibility.** Existing upstream aura
packs are not supported. Restricted buff data cannot drive missing-buff rules;
unknown data does not count as a missing buff. Numeric protected cooldowns and
mana are unavailable to conditions. Native cooldown progress bars, legacy
combat-log triggers, and boss-mod integrations are not implemented.

The latest editor hover fix has local regression coverage; the reported missing
Hunter group in the editor still needs an in-game retest. See
[FOREVER.md](FOREVER.md) for implementation details and validation limits.

## Build and try it

Requires Python 3, Git, Lua 5.1, and the `luac5.1` compiler:

```sh
lua5.1 tests/run.lua
python3 -B tests/migrate_legacy_saves_test.py
python3 tools/build_forever.py
```

The builder downloads the official WeakAuras 5.22.0 release for its embedded
libraries and verifies a pinned SHA-256 before using them. The resulting
`.release/WeakAurasForever-5.22.0-waf.4.zip` is the installable archive.
GitHub's automatic source-code ZIP is not an installable addon.
The **WAF build** Actions workflow also produces the package as an artifact.

The current package is intended for manual testing. Back up your addon folders
and SavedVariables, exit WoW, then extract the ZIP into the Forever client's
`Interface/AddOns/` directory. It contains four uniquely named folders:

```text
WAF/    WAFOptions/    WAFArchive/    WAFModelPaths/
```

Existing WAF saves continue to load without conversion. If upgrading from an
older WAF package, move its three data-only legacy loaders out of AddOns; identify
these by `## X-WAF-Legacy: 1`, and keep all SavedVariables. If migrating from the
pre-WAF Forever fork, use the optional offline helper. Follow the
[migration guide](docs/MIGRATION.md) for both cases.

No folders belong to both projects now, but WAF and original WeakAuras still
share internal Lua API names. Enable only one runtime in a given game session.

Restart WoW and enable the included modules. Use `/waf` to open the editor.
`/waforever` and `/weakaurasforever` are aliases.

- `/waf hunter` creates **Forever Hunter** if absent; it preserves an existing pack.
- `/waf hunter validate` checks the preset structure and live spellbook IDs.
- `/waf examples` adds example displays without replacing existing names.

WAF stores its settings under `WAFSaved`, `WAFOptionsSaved`, and `WAFArchive`.
Only WAF saves are loaded, including an empty collection. Legacy migration is
explicit and never overwrites an existing WAF save or restores deleted auras.

## Development and publishing

Source directories retain upstream names to make merging easier. Use
`tools/build_forever.py` for Forever packaging; `.pkgmeta` and the upstream
release scripts target ordinary WeakAuras. Upstream workflows are restricted to
the upstream repository. WAF's workflow validates and builds without publishing
to CurseForge or sending release notifications.

Read [AGENTS.md](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md), and
[tests/README.md](tests/README.md) before contributing. Open issues and pull
requests in [this fork](https://github.com/Jared-Mac/WeakAurasForever), not in the
upstream project, for Forever-specific behavior.

[CurseForge readiness and submission draft](docs/CURSEFORGE.md) records the
remaining work. No CurseForge project has been submitted for this fork.

## License and credits

GNU General Public License version 2; see [LICENSE](LICENSE). Original copyright
and attribution notices are retained. Embedded libraries and assets retain
their respective notices. Forever modifications and their dates are recorded
in Git history and [FOREVER.md](FOREVER.md).

Thanks to the [WeakAuras Team and contributors](https://github.com/WeakAuras/WeakAuras2)
for the editor and framework on which this work is based.
