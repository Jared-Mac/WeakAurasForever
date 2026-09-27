-- Exercises the actual Cache.Load -> Cache.Build -> picker lookup path.
-- The only client fixtures are documented spellbook metadata. Arbitrary spell
-- queries are tripwires; this does not emulate a native assertion or the WoW UI.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")

local forever = true
local slots, queries = {}, {}
local lines = {{itemIndexOffset = 0, numSpellBookItems = 3},
               {itemIndexOffset = 6, numSpellBookItems = 3}}
local scheduled
local function forbidden() error("Unexpected full-database spell lookup") end
local private = {
  ExecEnv = {GetSpellName = forbidden, GetSpellIcon = forbidden, GetSpellInfo = forbidden},
  Threads = {
    Add = function(_, name, thread, priority)
      assert(not forever, "Forever scheduled the legacy spell cache worker")
      scheduled = {name, thread, priority}
    end,
    SetPriority = function() error("Forever resumed the legacy spell cache worker") end
  }
}
WeakAuras = {
  IsLibsOK = function() return true end,
  IsForever = function() return forever end,
  IsClassicEra = function() return true end,
  IsWrathOrCataOrMistsOrRetail = function() return false end,
  versionString = "5.22.0-forever.2"
}
Enum = {SpellBookSpellBank = {Player = 0}, SpellBookItemType = {Spell = 1}}
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return #lines end,
  GetSpellBookSkillLineInfo = function(index) return lines[index] end,
  GetSpellBookItemInfo = function(slot, bank)
    assert(bank == 0)
    assert(slot >= 1 and slot <= 3 or slot >= 7 and slot <= 9, "Read outside spellbook slot ranges")
    queries[#queries + 1] = slot
    return slots[slot]
  end,
  IsSpellKnownOrInSpellBook = function() return true end
}
GetBuildInfo = function() return "1.60.1", "69913" end
GetLocale = function() return "enUS" end
wipe = function(value) for key in pairs(value) do value[key] = nil end end
T.loadAddonFile("WeakAurasOptions/Cache.lua", "WeakAurasOptions", {Private = private})
local cache = WeakAuras.spellCache
local data = {spellCache = {Unrelated = {spells = "1251678=123"}}, rebuilding = true,
              needsRebuild = false, selectedTab = "trigger"}
T.section("Forever never schedules or queries the whole spell database")
cache.Load(data)
T.expect(next(cache.Get()) == nil, "drops old database entries before picker lookups")
T.expect(not data.rebuilding and data.needsRebuild, "resets interrupted build flags")
T.expect(data.selectedTab == "trigger", "preserves other editor settings")
slots[1] = {itemType = 1, spellID = 2973, name = "Raptor Strike", iconID = 132223}
slots[2] = {itemType = 4, name = "Flyout", iconID = 4}
slots[3] = {itemType = 2, spellID = 9999, name = "Unlearned", iconID = 9}
slots[7] = {itemType = 1, spellID = 14260, name = "Raptor Strike", iconID = 132224}
slots[8] = slots[1]
-- Slot 9 is absent: the documented API may return nothing.
cache.Build()
T.expect(scheduled == nil, "does not schedule the spellCache coroutine")
T.expect(table.concat(queries, ",") == "1,2,3,7,8,9", "enumerates only reported slot ranges")
T.expect(cache.Get().Flyout == nil and cache.Get().Unlearned == nil, "skips flyouts and future spells")
T.expect(cache.Get()["Raptor Strike"].spells == "2973=132223,14260=132224", "keeps ranks and deduplicates spell IDs")
local matches = cache.GetSpellsMatching("Raptor Strike")
T.expect(matches[2973] == "132223" and matches[14260] == "132224", "retains the existing picker cache format")
T.expect(cache.GetIcon("Raptor Strike") == 132224, "icon lookup works without arbitrary metadata queries")
T.expect(not data.needsRebuild and not data.rebuilding, "marks the bounded build complete")

T.section("Reopening the editor refreshes the character spellbook")
slots[1].iconID = 777
slots[7], slots[8] = nil, nil
queries = {}
cache.Build()
T.expect(cache.GetIcon("Raptor Strike") == 777, "refreshes the best-icon memo after rebuilding")
T.expect(cache.GetSpellsMatching("Raptor Strike")[14260] == nil, "removes stale spellbook entries")
T.expect(#queries == 6, "rebuilds despite the previous needsRebuild flag being false")
lines = {}
cache.Build()
T.expect(next(cache.Get()) == nil, "empty spellbooks do not fall back to a database sweep")

T.section("Other client flavors retain the existing cache builder")
forever = false
private.ExecEnv.GetSpellName = function() return "Classic spell" end
private.ExecEnv.GetSpellIcon = function() return 123 end
local legacy = {spellCache = {}}
cache.Load(legacy)
cache.Build()
T.expect(scheduled and scheduled[1] == "spellCache" and scheduled[3] == "background", "Classic still schedules the existing background worker")
local ok, _, label = coroutine.resume(scheduled[2])
T.expect(ok and label == "spells" and cache.Get()["Classic spell"].spells == "1=123", "Classic builder still reaches its normal lookup and yield")
T.finish()
