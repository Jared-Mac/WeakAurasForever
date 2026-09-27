# CurseForge readiness

Researched 2026-09-23. This is a submission plan, not an approved listing.

## Platform support

CurseForge already lists **Forever** files for **1.60.1**. We can target the
existing flavor; no new game integration is needed. For example, the
[ForeverUI files page](https://www.curseforge.com/wow/addons/foreverui/files/all)
shows both tags. Select them explicitly when uploading; interface `16001` is
the WoW TOC value, not a CurseForge upload API version ID.

## Work before public distribution

- **Done: standalone packaging.** Since waf.4, the ZIP contains only WAF,
  WAFOptions, WAFArchive and WAFModelPaths. Legacy TOC dependencies are removed.
  Existing WAF saves win; migration is an optional offline copy. Typed media
  paths are modernized on load/import. See [MIGRATION.md](MIGRATION.md).
  Local regression and package checks cover this boundary; native client and
  CurseForge-manager installation checks remain part of release validation.
- **Complete an in-game release pass.** Retest the Hunter group's editor
  visibility after the hover fix; check fresh installation, source switching,
  combat transitions, import/export, reload, and relog. Local checks do not
  establish native UI correctness. Start with an Alpha file while this is pending.
- **Done: distinct project logo.** The [400 x 400 PNG](../assets/branding/waf-logo-400.png)
  is ready for the avatar field and also has an in-game TGA export. Add actual
  in-game screenshots. The [submission guide](https://support.curseforge.com/support/solutions/articles/9000199552)
  specifies logo and metadata requirements.
- **Finish the distribution attribution audit.** Keep GPLv2, original notices,
  and bundled-library/asset licenses. Verify modified-file notices and dates
  in the distributed files, not just Git history. Upstream also declares
  [GPLv2 on CurseForge](https://www.curseforge.com/wow/addons/weakauras-2).
  Fork descriptions must explain the changes and credit/link the original;
  see the [moderation policy](https://support.curseforge.com/support/solutions/articles/9000197279).

## Project fields

| Field | Proposed value |
| --- | --- |
| Name | WeakAurasForever |
| Slug | weakaurasforever (subject to availability) |
| Game / class | World of Warcraft / Addons |
| Main category | Buffs & Debuffs |
| Additional categories | HUDs, Combat |
| License | GNU General Public License version 2 (GPLv2) |
| Source | https://github.com/Jared-Mac/WeakAurasForever |
| Issues | https://github.com/Jared-Mac/WeakAurasForever/issues |
| File tags | Forever; 1.60.1 |
| Initial file type | Alpha |
| Relationship | WeakAuras (`weakauras-2`) is incompatible, not a required dependency |

Suggested summary: **Customizable icons, bars, and reminders using
restriction-aware triggers for WoW Forever.**

Create the project through the
[author dashboard](https://authors.curseforge.com/#/projects/create/choose-game),
add the description, logo and license, then upload the built addon ZIP with a
changelog and matching game tags. New files undergo moderation. Use the
manual-release option if approval should not immediately publish the file.
CurseForge's [submission instructions](https://support.curseforge.com/support/solutions/articles/9000197241)
say a project needs at least one Release file before syncing to the app; an
Alpha-only launch does not provide ordinary one-click app discovery. Their
separate Experimental project setting also disables ecosystem syncing, so do
not confuse that setting with an honest alpha label in the description.

## Description draft

WeakAurasForever brings the WeakAuras display editor to WoW Forever, with a new
trigger system designed around the information the client allows addons to use.
Create groups of icons, bars, text, and animations, then combine supported
triggers and style them with conditions.

The prototype includes native cooldown and aura icons, a native player mana
bar, ammo and item counts, public spell and unit checks, swing timers, and
manual timers. `/waf` opens the editor. Hunters can use `/waf hunter` to create
a starter group with mana, ranged swing, and learned core and Night Elf cooldowns.

This is an independent alpha fork, not an official WeakAuras release or full
compatibility port. Existing upstream aura packs are unsupported. Protected
combat data cannot be used for conditions, and a restricted buff lookup cannot
show that a buff is missing. Another WeakAuras runtime cannot be enabled alongside
WeakAurasForever. See the file changelog for known issues and supported builds.

Based on [WeakAuras by the WeakAuras Team and contributors](https://github.com/WeakAuras/WeakAuras2).
Distributed under GPLv2 with upstream credits retained. Report Forever-specific
issues to [this fork's issue tracker](https://github.com/Jared-Mac/WeakAurasForever/issues).

## Build and future upload automation

Use `python3 tools/build_forever.py`, not GitHub's source ZIP or the upstream
`.pkgmeta` packager. Current Actions builds run checks and produce a ZIP only;
upstream publishing, issue automation, and notification jobs are guarded to
run only in `WeakAuras/WeakAuras2`.

After a CurseForge project exists, its numeric project ID and an author upload
token can support a separate release workflow. Keep the token in a GitHub
Actions secret. The [official upload API](https://support.curseforge.com/support/solutions/articles/9000197321)
accepts a ZIP plus metadata, release type, game versions, changelog and relations.
Resolve the correct Forever game-version entry using the versions API; do not
guess IDs or reuse WeakAuras's project ID `65387`. This automation has not been
configured and no CurseForge credentials are needed for the GitHub push.
