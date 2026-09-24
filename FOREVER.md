# WeakAurasForever

Local experimental fork, modified 2026-09-20. Upstream WeakAuras remains credited
and licensed under GPL v2; see LICENSE. This is not an official WeakAuras release.

Base: WeakAuras/WeakAuras2 main, commit
`91c52bc92f86ae4a5232913039225a0032aca048`.
Target: WoW Forever 1.60.1, interface 16001.

AurasForever v0.17.0 was checkpointed separately at `565a78c` before this
experiment. Its addon files and saved variables are not inputs to this fork.

## Standalone distribution and logo: waf.4

Modified 2026-09-23. The installer now owns exactly four directories: WAF,
WAFOptions, WAFArchive and WAFModelPaths. The builder no longer produces legacy
WeakAuras folders, and the Forever TOCs no longer depend on them. Existing
canonical WAF saves remain authoritative, including an empty table. The runtime
aliases are retained for the engine, but no legacy global is silently adopted.

The optional `tools/migrate_legacy_saves.py` helper previews offline migration
from older Forever-fork files. With `--apply`, it copies only missing WAF files,
renaming the root assignment while leaving the rest of each file unchanged.
It never evaluates Lua or replaces a target file. See [docs/MIGRATION.md](docs/MIGRATION.md).

`Private.AddMany` and `Private.Add` both call `WeakAuras.PreAdd`, which runs
`Private.Modernize` before setting up renderers. At the end of modernization,
Forever now relocates only known media fields (including subregions, actions
and condition overrides) from the old bundled Media directory to WAF/Media.
This also covers imported current-version displays and archive restores. It
leaves aura IDs, text, triggers, custom code and arbitrary settings untouched.
There is no per-frame rewrite, global API shim or numeric protected-data access.

An original WAF infinity-aura logo is used for the Forever addon listing,
minimap launcher and editor portrait. Other clients retain upstream branding.
The generated master and 400-pixel CurseForge avatar are in assets/branding;
WoW uses a 256-pixel uncompressed TGA. Upstream media and credits are retained.

Regression checks cover the actual current-version modernization entry point,
empty/deleted save collections, unrelated legacy globals, offline source/target
races, and byte-preserved payloads. The builder asserts exactly four package
roots and validates all client load dependencies and Lua 5.1 syntax. Native
upgrade/relog behavior and the new logo in the client still need in-game review.

The sections below describe earlier builds. Their legacy-loader installation
instructions are superseded by waf.4 and the migration guide above.

## Editor hover compatibility: waf.3

The reported `AceGUIWidget-WeakAurasSpinBox.lua:66` error occurs when entering
a number control: `Frame_OnEnter` calls `UpdateHandleVisibility`, which called
the missing global `MouseIsOver`. The handle's hover-color callback used the
same global. Both now call the region's `IsMouseOver` method, as does Blizzard's
[InputUtil helper](https://github.com/Gethe/wow-ui-source/blob/4d5d706b8e01c5ebe01c8dd9b7a07151d8d37069/Interface/AddOns/Blizzard_SharedXML/InputUtil.lua#L213).
The frame picker and both pending-install/update button animations had the
same obsolete call and use the method too. Widget registration versions are
incremented; no Blizzard global or embedded library is modified.

The focused callback test reproduced the exact line-66 error before the fix
and passes afterward with `MouseIsOver` absent. It checks handle visibility,
hover/drag colors and a single value commit on mouse release. This validates
the callback logic, not native hit testing or the entire editor. The earlier
missing Hunter-list entry still needs confirmation in WoW: the supplied stack
shows a mouse-enter callback, not the aura-list construction coroutine.
Reload, open `/waf`, and check both the Hunter group and number-control hovering.
Saved auras, package names and save paths are unchanged.

## Naming: waf.2

Use **WeakAurasForever** as the full name in the editor title, launcher,
main addon listing, documentation and distribution ZIP. Use **WAForever**
in chat prefixes and module labels. **WAF** remains the package identity and
short command (`/waf`); `/waforever` and `/weakaurasforever` also open the editor.

This update changes branding only. Package folders, SavedVariables names,
legacy migration, aura IDs and layouts remain stable. The separately reported
missing Hunter entry in the editor is still under investigation.

## WAF identity: waf.1

The installed runtime is now **WAF**, with **WAFOptions**, **WAFArchive** and
**WAFModelPaths** supporting addons. `/waf` and `/weakaurasforever` open the
editor; `/wa` remains an alias. Existing `/waf hunter`, `hunter validate`,
`examples`, `timer` and `stop` commands still work. Standard commands such as
`/waf minimap` pass through to the original dispatcher. The visible naming is
updated in waf.2 above.

The builder retains upstream directory names in this repository for merging,
maps installed folders and media paths to WAF, and leaves embedded libraries
unchanged. Package lookups derive from the actual addon name. Named frames,
the public `WeakAuras` API, aura IDs/UIDs and the import/export format remain
compatible. This is a renamed fork, not namespace isolation for running another
copy of WeakAuras alongside it. Upstream credits and GPL v2 remain intact.

### Saved data during the rename

The package includes three small **WAForever - Legacy saves** addons under the old
`WeakAuras`, `WeakAurasOptions` and `WeakAurasArchive` directory names. These
contain TOC declarations only; the main one also retains legacy media paths
for saved/imported textures and fonts. They contain no old addon runtime.
Keep these compatibility loaders enabled. They are required dependencies, so
their saved data loads before the corresponding WAF addon initializes.

New files are `SavedVariables/WAF.lua`, `WAFOptions.lua` and `WAFArchive.lua`,
declaring `WAFSaved`, `WAFOptionsSaved` and `WAFArchive`. At the runtime's
`ADDON_LOADED`, the options addon's own `ADDON_LOADED`, and archive initialization,
respectively, the new table is adopted if it exists. Only a nil new variable
falls back to the complete legacy table. An empty new table or empty collection
never restores old auras. Legacy runtime globals alias the selected tables,
so the compatibility files also continue to receive the current data on save.
Custom aura code cannot access the new save globals or the migration helper
through the sandbox.

No external rewrite of SavedVariables is necessary: a still-running old client
can flush its last edits on exit, and WAF reads that final save next login.
Installation backs up the old packages and saved files. It does not create,
rename, merge or backfill individual auras, including the Hunter preset.
Completely exit and restart WoW to discover the new addon folders, then use
`/waf`. First-login migration and a subsequent reload/relog still need native
client confirmation; local checks exercise save selection, command routing,
sandbox boundaries, packaged dependencies and Lua 5.1 syntax.

## Mana texture orientation: forever.7

The first Hunter-group screenshot shows full mana (376 / 376) with bands of
different blue brightness. `ForeverMana.lua` unconditionally enabled the native
StatusBar's texture rotation. The selected Blizzard texture is a shaded 64x8
image; rotating it on a horizontal bar stretches its short-axis shading across
the bar's width. WA's Lua bar has different rotation semantics: its true flag
selects orientation-aware UV mapping, including normal UVs for horizontal bars.

The native renderer now enables rotation only for vertical orientations. Reverse
fill remains independent. This matches the native StatusBar convention used by
[TellMeWhen's bar view](https://github.com/ascott18/TellMeWhen/blob/master/Components/IconViews/Bar/Bar.lua)
and [ElvUI's aura bars](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Modules/Auras/Auras.lua).
The source texture was inspected from
[the extracted Classic UI assets](https://github.com/Gethe/wow-ui-textures/blob/classic/TARGETINGFRAME/UI-StatusBar.PNG).

No preset or saved aura fields change. Reload applies the renderer correction
to existing mana bars. Local tests, Lua 5.1 parsing and the complete package
load-graph check pass; native visual confirmation after reload remains pending.
The Blizzard texture retains its intended shading across the bar's thickness.
For completely flat color, choose Display > Bar Texture > Solid.

## Hunter group and native mana: forever.6

After reload, run `/waf hunter` out of combat. This explicitly creates one
movable **Forever Hunter** group with a blue mana bar (current / maximum text),
a thin gold ranged-swing bar, and an unlabeled row of native cooldown icons.
Hunter abilities precede the Night Elf racials, with a wider gap between them.
The group is anchored to screen center at Y -160; children follow the group.

The character's saved, bounded spellbook cache from build 69913 confirms:

| Ability | Learned IDs | Selected from current cache |
| --- | --- | --- |
| Arcane Shot | 3044, 14281 | 14281 |
| Concussive Shot | 5116 | 5116 |
| Distracting Shot | 20736 | 20736 |
| Raptor Strike | 2973, 14260 | 14260 |
| Elune's Light | 1259799 | 1259799 |
| Shadowmeld | 20580 | 20580 |

Creation enumerates only the current player's documented skill-line slot
ranges, ignores passive/off-spec/future-spell entries, selects the highest
learned rank, and skips unlearned abilities. It never scans arbitrary spell IDs.
These are the core cooldowns available to this character now, not an endgame
Hunter package. Each icon requires Hunter class and that spell being learned.
No numeric cooldowns are inferred; the existing native duration-object binding
provides the swipe and Blizzard countdown.

`/waf hunter` preserves an existing group, including deleted children and edited
positions. It does not backfill on login, reload, or another command invocation.
Unrelated child-name collisions receive a numeric suffix. Creation uses the
normal `WeakAuras.Add` lifecycle; no SavedVariables files are edited externally.
Use `/waf hunter validate` for a read-only check of the current group membership,
trigger support, native display types, and cooldown IDs against the live
spellbook. This structural check does not prove combat rendering or persistence.

### Why mana needs a separate renderer

`RegionTypes/AuraBar.lua` implements its fill using Lua arithmetic and texture
masks, so protected mana cannot be passed to that bar's `SetValue`. The new
Unit > Player mana (native bar) source binds an actual Blizzard StatusBar,
passing `UnitPowerPercent("player", 0, false)` directly to the native setter.
`UnitPower` and `UnitPowerMax` go directly to `FontString:SetFormattedText`.
The target client's generated API declares both setters as accepting secret
arguments when tainted. No current/max/percent mana enters WA states, conditions,
dynamic text formatters, frame-size calculations or comparisons.

Binding happens after normal aurabar modification and subregion setup. Before
the next modify, all wrapped writers are restored and the native bar is hidden,
covering source edits and pooled region reuse. Mana updates follow power events
through the existing Forever provider. They do not add per-frame polling.
The bar retains size, anchors, texture, color/gradient, orientation, inversion
(using Blizzard's curve evaluator), native smoothing, and ordinary text labels.
Spark, progress overlays and foreground-relative anchors are unsupported for
this native source. Its built-in mana text toggle and size are in Trigger.
Editor preview uses explicit samples; closing the editor resumes real values.

Validation: local tests cover bounded spellbook selection/ranks, parent/child
membership, non-overlapping layout, no-overwrite behavior, unavailable spells,
opaque-value forwarding, writer restoration, native-source event routing and
the actual Trigger-tab builders. The eight definitions also round-tripped
field-for-field through the packaged LibSerialize/LibDeflate import format,
using the actual saved character spellbook cache. A backup import string is
available at `.release/Forever-Hunter.txt`; `/waf hunter` is preferred because
it selects spells from the live spellbook at creation time.
These fixtures do not emulate the secret VM,
native frames, combat, or AceGUI. Build validation parses the complete Forever
load graph with Lua 5.1. Native-client acceptance still needs:

1. `/reload`, `/waf hunter`; check eight children and six correct spell icons.
2. Close `/wa`. Spend/regenerate mana out of combat and while shooting; compare
   the mana number and fill to the player frame. The gold bar starts after a
   ranged swing and hides when its public timer expires.
3. Use the six abilities when applicable; compare swipes/countdowns with the
   action bar, especially both racial cooldowns. The native binding ignores GCD.
4. Move the group, edit colors/sizes, switch mana to a public source and back,
   reopen/close the editor, and run `/waf hunter validate`.
5. Export the group, then test reload/relog. The beta's existing persistence
   issue is not claimed fixed by this change.

## Options initialization fix: forever.5

The first native run of forever.4 reported
`WeakAurasOptions/ForeverTrigger.lua:5: attempt to index field 'Private' (a nil value)`.
`Private.LoadOptions` calls `C_AddOns.LoadAddOn("WeakAurasOptions")`, which executes
all options files. Only after loading returns does `WeakAuras.OpenOptions` call
`WeakAuras.ToggleOptions(msg, Private)`, assigning `OptionsPrivate.Private`.
The new file-scope alias read that table too early and aborted registration.

The alias now lives inside the options builder, which runs after the runtime is
connected. No nil fallback or early return masks the missing registration. The
options regression fixture previously injected Private before loading files;
it now loads the real provider with Private absent, verifies registration, then
connects Private before building and exercising all source panels. It reproduced
the exact line-5 error before the fix and passes afterward.

The fix affects only the Forever options provider. Runtime triggers, aura data,
and the TOC load sequence are unchanged in that fix. Reload, open `/wa`, select an example,
and open Trigger to verify the six categories in the native client. The existing
examples can be used directly; recreating them is unnecessary.

## General trigger expansion: forever.4

The Trigger tab now has six categories (Spell, Aura, Item, Unit, Player & World,
Timer) and 23 sources. The single-entry Type dropdown is replaced by Category;
persisted trigger type remains `forever`. Track lists only the chosen category.
Spell inputs include a picker backed by the bounded player spellbook cache,
plus an exact ID field. The effect-list picker appends IDs without duplicates.

- Spell: native cooldown/charge-recharge icons; public cooldown-active,
  cooldown-inactive, cooldown-on-hold and recharging checks; learned spells,
  usability/insufficient-resource, range, and Blizzard proc highlights.
- Aura: native player/target buff or debuff icons; separately, public exact-ID
  presence checks over up to 32 IDs with Any/All and present/missing choices.
  Presence checks accept any caster; no owner-specific inference is made.
- Item: equipped ammo, general carried/equipped item counts (not banks), and
  whether an item is equipped. Numeric sources support comparisons and percent
  thresholds. Previous ammo `lowOnly` settings remain effective until edited.
- Unit: player/target/focus/pet existence, dead/ghost, attackability, friendship,
  and connectivity. Non-existence does not prove another unit predicate false.
- Player & World: combat, mounted, resting, swimming, dead/ghost, pet, group/raid;
  class, level, XP, money in gold, form/stance index, group size, zone and instance type.
  Form means stance-bar index, not hunter-aspect presence. Solo group size is one.
- Timer: main/off-hand/ranged swings, and configurable fixed timers started by
  entering combat, a readable successful player cast, or `/waf timer KEY`.
  `/waf stop KEY` cancels matching manual timers. These are not cooldown inference.

Use **Add Trigger → Required for Activation: All / Any** to combine checks.
**Show when: Condition is false** inverts a readable check. **Always, while data
is available** retains a boolean source for styling through Conditions.
Native sources remain display bindings: their slot eligibility is not buff
presence. Their Active/Since Active conditions remain hidden. Cooldown flags
are separately exposed; active includes GCD, inactive excludes held cooldowns,
and neither implies that all cast requirements are met. No numeric protected
cooldown times or current charge counts enter WA state.

Unknown is not false. Protected effect policies, inaccessible fields, missing
APIs, invalid range checks and invisible targets cannot activate an inverse
check. Restriction-transition events invalidate presence observations before
restrictions activate; a subsequent poll performs a fresh check. Active=false
and Source-is-true=false conditions also require a known observation. Custom
Lua combinations remain user-authored code over WA's boolean activation array;
use the built-in per-source inversion for unknown-aware behavior.

The existing runtime entry point is `system.Add` -> load/unload hooks -> event
updates -> `Private.UpdatedTriggerState`. Per-trigger contexts own parsed IDs,
metadata and public timers; contexts are not serialized. Event subscriptions
come from source definitions. Only range/presence/state/timer sources poll (5 Hz),
only while such sources are loaded, and unchanged observations do not republish
states. Inventory and cooldown sources are event-driven. Unload/delete clear
observations and timers; rename moves them. Edit/reload resets event timers.
Core Resume forces a fresh publication after editor fake states. Live fallback
states now use real readable values instead of the old fixed editor samples.

`Private.GetTriggerConditions` preserves upstream behavior outside Forever,
uses the provider's unknown-aware Active check for ordinary Forever sources,
and keeps Active/Since Active hidden for native sources. The Condition tab,
All/Any combination UI, progress sources and text fields remain the upstream
systems. Ordinary boolean sources use WA's zero-duration status representation,
so icons do not acquire a fabricated one-second cooldown.

### Try it

1. `/reload`, then `/wa`. In Trigger, choose Category, Track, and the relevant
   item/spell/state. Use Conditions for extra color/text/glow rules.
2. Optional: `/waf examples` creates the original three examples plus low ammo
   AND combat, ranged swing, a manual timer, and a missing-aspect reminder.
   Existing names are kept. Nothing is created automatically during installation.
3. Close the editor, then `/waf timer demo`; the example should count down for
   ten seconds. `/waf stop demo` cancels it. Test the swing bar by shooting.
4. Set the low-ammo example threshold above the current count, enter/leave
   combat, and verify All gating. Then change All to Any to check the difference.
5. The aspect example lists Monkey 13163 and Hawk 13165; edit IDs for your ranks.
   Toggle an aspect out of combat, then enter combat. Restricted checks must
   hide the reminder rather than incorrectly report that the aspect is missing.
6. Check a native target debuff, cooldown/recharge icon, range, usability and
   proc source with the relevant spell/class. Test source switching, duplicate,
   rename, delete, export/import, reload and relog.

Source contracts: Blizzard's pinned Forever UI at
`4d5d706b8e01c5ebe01c8dd9b7a07151d8d37069`, generated Spell/SpellShared,
SpellBook, Item, Unit, PlayerScript, Instance, SecretPredicateAPI,
RestrictedActions, SwingTimer and SpellActivationOverlay documentation, plus
`Blizzard_CustomAuraContainer.lua` (`SetUnit`, `SetAuraSlotFilterString`,
`SetAuraSlotCandidateFilters`). Wiki API pages returned HTTP 403; the local
exact-build source is the primary evidence. These contracts support the
implementation, but the newly added sources still require native-client tests.
Previously confirmed ammo/native cooldown behavior is not proof of every source.

## Trigger-tab follow-up: forever.3

The next native run opened the editor and showed the examples, then selecting
Triggers raised `TriggerOptions.lua:307`, indexing a nil `event_prototype`.
`GetTriggerOptions` invokes the registered Forever provider, which calls
`AddTriggerMetaFunctions`; that calls the shared `GetTriggerTitle` helper.
The helper assumed every non-aura/non-custom trigger belonged to the legacy
event-prototype registry. Forever sources deliberately use a separate provider
and have no such prototype.

`GetTriggerTitle` now resolves Forever headings from its source-name table,
including ammunition as the default for newly added triggers. Legacy trigger
headings retain their previous behavior. Conditions and dynamic-text headings
use the same helper and receive the correction too. No aura migration or
saved-variable edit is needed.

The focused regression test loads the actual shared option builders and Forever
provider. It reproduced the screenshot's line-307 failure before the patch and
passes 17 checks after it, including changing source through the real setter,
adding a trigger through the actual button callback, and reordering. This tests
option construction, not native AceGUI rendering. Retest with `/reload`, `/wa`,
and the Trigger tab on each example; also check Conditions on Ammunition.

## Crash follow-up: forever.2

The first native run reached the options spell-cache worker and then WoW build
69913 crashed (2026-09-20 22:47:59 UTC). The report names ERROR #110 in
`PlayerConditions_C.cpp:763`: aura 1251678 referenced by player condition 144600
was unknown to the client. Its Lua stack shows the WeakAuras coroutine scheduler
resuming `spellCache`, with the last yield label `spells`. The exact spell ID
being queried is not present in the report; the referenced aura ID need not be
that queried ID. There was no systemd core or kernel OOM/GPU error in that window.

The inherited `WeakAurasOptions/Cache.lua` builder queried successive spell IDs
through its entire database range. `WeakAuras.ShowOptions` starts that worker on
first open. Forever now takes an early branch that reads only the player's
reported `C_SpellBook` skill-line slot ranges and uses each entry's existing
name, spell ID and icon metadata. It does not call general spell metadata APIs
or schedule the legacy worker. Names/ranks keep the upstream cache format.

Opening the editor rebuilds this small cache so learned/removed abilities are
reflected. Loading options discards any partial or previous full-database search
cache; aura definitions and other settings are untouched. Name searches now
cover the character's spellbook. Explicit spell-ID lookups remain available;
this change does not guarantee that all IDs in the beta database are valid.

This removes the automatic lookup path present at the crash. Confirmation that
`/wa` now opens without a native assertion still requires a client retest. Start
with `/wa`, then use `/waf test` if the editor opens successfully.

## Install and test

Build with `python3 tools/build_forever.py`. The script uses the official
WeakAuras 5.22.0 ZIP only for unmodified embedded libraries, verifies its pinned
SHA256, copies the fork source, and validates all TOC/XML load dependencies and
Lua 5.1 syntax. Output is `.release/WeakAurasForever-5.22.0-waf.3.zip`.

Install all seven directories into Forever's Interface/AddOns, replacing the
old fork directories completely (do not leave old Lua files in the compatibility
loaders). Do not install another WeakAuras runtime alongside WAF. AurasForever
can remain installed. Restart WoW once to discover new addons.

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
   trigger is Item > Equipped ammunition. Choose a native source only for an
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
  no numeric game cooldown duration, current charge count or expiration time.
  Recharge icons and public status flags are supported; native cooldown progress
  bars are not implemented yet.
- Buff icons use `CustomAuraContainerTemplate`, an exact player/target buff or debuff spell-ID
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
- `tests/forever_spell_cache_test.lua` (included in `tests/run.lua`): real cache
  load/build/picker-lookup path, with metadata fixtures and tripwires against
  full-database queries or worker scheduling; also checks the Classic branch.
- `tests/forever_trigger_options_test.lua` (included in `tests/run.lua`): builds
  actual Trigger-tab options through the Forever provider and shared helpers.
- `git diff --check` and Lua 5.1 parsing of modified source files.

The forever.5 local runs passed: 92 upstream assertions, 16 spell-cache
regression checks, 78 trigger-options checks and 110 Forever source/lifecycle/
slash-command checks (296 total). Packaging verifies 234 load dependencies and
Lua 5.1 syntax. Luacheck is not installed.

The forever.2 screenshot confirms that the editor opens. The subsequent
forever.3 screenshot shows the repaired Trigger tab. Native verification of the
new forever.4 sources and broader display behavior is pending. Capture the first Lua error or crash
report if another compatibility issue occurs.
