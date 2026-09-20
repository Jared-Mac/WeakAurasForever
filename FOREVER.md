# WeakAuras Forever experiment

Local experimental fork, modified 2026-09-20. Upstream WeakAuras remains credited
and licensed under GPL v2; see LICENSE. This is not an official WeakAuras release.

Base: WeakAuras/WeakAuras2 main, commit
`91c52bc92f86ae4a5232913039225a0032aca048`.
Target: WoW Forever 1.60.1, interface 16001.

AurasForever v0.17.0 was checkpointed separately at `565a78c` before this
experiment. Its addon files and saved variables are not inputs to this fork.

## Install and test

Build with `python3 tools/build_forever.py`. The script uses the official
WeakAuras 5.22.0 ZIP only for unmodified embedded libraries, verifies its pinned
SHA256, copies the fork source, and validates all TOC/XML load dependencies and
Lua 5.1 syntax. Output is `.release/WeakAurasForever-5.22.0-forever.1.zip`.

Install the four directories into Forever's Interface/AddOns. They use the
standard WeakAuras names and cannot coexist with a different WeakAuras install.
AurasForever can remain installed. Restart WoW once to discover new addons.

1. Run `/waf test` out of combat after login. This creates three separate test
   auras, without replacing existing examples, and opens `/wa`.
2. Select **Forever test - Raptor Strike**. Change its size, position, border,
   color and cooldown options. Close the editor, use Raptor Strike, and compare
   the native swipe/countdown with the normal action bar, including in combat.
3. Select **Forever test - Aspect of the Monkey**. Close the editor and toggle
   Aspect of the Monkey. The native icon should follow the buff, including in
   combat. In the editor a native sample is shown for placement.
4. Select **Forever test - Ammunition**. It shows the equipped ammo bag count,
   with a bar maximum of 200 and a red color condition at 100 or fewer arrows.
   Shoot, change stacks, and unequip/re-equip ammo. In Trigger, enable **Only
   show when ammunition is low** and change **Show at or below** to test hiding.
5. Create another Icon or Progress Bar through the normal New menu. The default
   trigger is Forever > Equipped ammunition. Choose a native source only for an
   Icon. Try Conditions > Ammo count, multiple public ammo conditions, rename,
   duplicate, delete, reload and a full relog. Export the examples before relog
   if retaining edits matters; the beta's earlier persistence issue is not
   considered resolved by this experiment.

Do not install upstream updates over this experiment. To revert the experiment,
disable the four WeakAuras addons. `/af` continues to use AurasForever separately.

## Scope and data boundary

- Retains the WeakAuras editor, icon/bar styling, subregions, groups, anchors,
  animations, public trigger combinations, conditions, serialization and history.
- Replaces the runtime trigger registry with a small Forever source adapter.
  Legacy aura scanning, combat-log/generic triggers, boss-mod integration and
  range scanners are absent from the Forever load graph. Old aura imports are
  not supported by this prototype. No conversion to full WeakAuras parity is
  implied by retaining the editor.
- Equipped ammunition is public data, guarded before any comparison or lookup.
  No equipped item is a known zero; inaccessible item/count is unknown and hides
  the live display. Conditions expose count and availability.
- Cooldown icons use `C_Spell.GetSpellCooldownDuration(id, true)` and
  `Cooldown:SetCooldownFromDurationObject`, with GCD ignored. The engine receives
  no numeric cooldown duration, readiness, stacks or expiration time. Charge
  rendering and cooldown progress bars are not implemented yet.
- Buff icons use `CustomAuraContainerTemplate`, an exact player buff spell-ID
  filter, and native icon/cooldown bindings. The engine does not read native
  occupancy, texture, visibility, stacks or timer values to reconstruct state.
  This does not provide missing-buff conditions during restrictions. There is
  one native source per icon. WA-added text/borders are separate from native buff
  visibility; native buff styling is limited to basic display settings for now.
- Native-source "Active" and "Since Active" conditions are deliberately absent:
  a loaded native slot does not establish buff presence or cooldown activity.
  Load conditions are limited to combat and never; global conditions to combat
  and always true. Range-based and GCD text formatters are unavailable.
- The inherited custom-code editor and sandbox still exist. Custom scripts are
  not a compatibility layer for old triggers or a bypass for protected APIs.
- Uses separate `WeakAurasSaved`, `WeakAurasOptionsSaved`, and `WeakAurasArchive`
  storage. Uses the Forever early-saved-variables TOC flag, but native reload and
  relog persistence remain part of the test, not a claimed fix.

## Source reasoning

`Init.lua` uses a dedicated Forever flavor while retaining Classic game data.
`Types.lua` and `WeakAuras.lua` skip obsolete talent-cache APIs. A separate branch
in `scanForLoadsImpl` retains the existing core load/unload/group lifecycle, but
supplies only `InCombatLockdown()` to the matching minimal load prototype.
It does not evaluate the old health, PvP, vehicle or raid context expressions.

The Forever TOCs omit `BuffTrigger2.lua`, `GenericTrigger.lua`, `BossMods.lua`
and their options providers. The range libraries are omitted from the dedicated
embed XML and their initialization in Prototypes is guarded. Other client TOCs
and trigger registrations retain their original behavior.

`ForeverState.lua` owns the public adapter; `ForeverTrigger.lua` owns registration,
events and lifecycle, including unload, rename, deletion and editor fake states.
The icon region's modify hook replaces numeric progress writers with native
rendering. Duration objects never enter WeakAuras' state, conditions or formatter
tables. Native aura children are created/configured during normal out-of-combat
editor work; normal runtime changes come from Blizzard's container.

API evidence: the locally captured Forever Blizzard UI source at commit
`4d5d706b8e01c5ebe01c8dd9b7a07151d8d37069`, specifically
`Blizzard_APIDocumentationGenerated/SpellDocumentation.lua`,
`FrameAPICooldownDocumentation.lua`,
`ItemDocumentation.lua`, and `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua`.
The same native API contracts are used in the separately tested AurasForever
prototype. The user's ammo query succeeded both out of and in combat. Those
observations support the API choices; they do not establish this fork's native
startup, editor or rendering behavior.

## Local validation

- `lua5.1 tests/run.lua`: upstream sandbox/options regressions.
- `lua5.1 tests/forever_state_test.lua`: isolated public adapter tests, including
  no-ammo versus inaccessible data, threshold boundaries, and absence of numeric
  native timing data. Its access-check sentinels do not emulate WoW's secret VM.
- `python3 tools/build_forever.py`: recursive packaged load-file existence and
  Lua 5.1 syntax; includes embedded libraries without modifying them.
- `git diff --check` and Lua 5.1 parsing of modified source files.

The local runs passed: 92 upstream assertions, 25 Forever adapter/lifecycle checks,
and 234 packaged load dependencies. Luacheck is not installed.

Native client testing is pending. In particular, this experiment has not yet
proved that the full upstream AceGUI editor and all shared display code run
unchanged on this beta. Capture the first Lua error if startup or `/wa` fails;
that is the next compatibility boundary to address.
