-- Focused adapter contract test. No frame/UI emulation. Sentinels model only
-- rejection by issecretvalue/canaccessvalue, not WoW's secret-value VM.
local private = {}
local secret, inaccessible = {}, {}
local itemID, count, reads = 2512, 68, 0
local env = setmetatable({
  WeakAuras = {IsLibsOK = function() return true end,
              L = setmetatable({}, {__index = function(_, key) return key end})},
  issecretvalue = function(value) return value == secret end,
  canaccessvalue = function(value) return value ~= inaccessible end,
  GetInventoryItemID = function(unit, slot)
    assert(unit == "player" and slot == 0)
    return itemID
  end,
  C_Item = {
    GetItemCount = function(item, bank, uses, reagentBank)
      assert(item == 2512 and not bank and not uses and not reagentBank)
      reads = reads + 1
      return count
    end,
    GetItemIconByID = function() return 132382 end
  },
  C_Spell = {
    GetSpellName = function() return "Raptor Strike" end,
    GetSpellTexture = function() return 132223 end
  }
}, {__index = _G})
local chunk = assert(loadfile("WeakAuras/ForeverState.lua"))
setfenv(chunk, env)("WeakAuras", private)
local F = private.Forever
local checks = 0
local function check(value)
  assert(value, "Forever adapter assertion " .. (checks + 1))
  checks = checks + 1
end
local t = {source = "ammo", maximum = 200, lowOnly = true, threshold = 100}
local s = F.MakeState(t, false)
check(s.show and s.count == 68 and s.value == 68 and s.total == 200)
count = 101
check(not F.MakeState(t, false).show)
count = 100
check(F.MakeState(t, false).show)
count = 0
check(F.MakeState(t, false).count == 0 and F.MakeState(t, false).show)
count = secret
s = F.MakeState(t, false)
check(not s.show and not s.available and s.count == nil)
count = inaccessible
check(not F.MakeState(t, false).show)
itemID = secret
reads = 0
check(not F.MakeState(t, false).show and reads == 0)
itemID = inaccessible
check(not F.MakeState(t, false).show and reads == 0)
itemID = nil
s = F.MakeState(t, false)
check(s.show and s.available and s.count == 0 and reads == 0)
itemID, count = 2512, 999
check(F.MakeState(t, true).show and F.MakeState(t, true).count == 68)
check(not F.MakeState({source = "cooldown", spellID = "bad"}, false).show)
check(not F.MakeState({source = "buff", spellID = -1}, false).show)
s = F.MakeState({source = "cooldown", spellID = 2973}, false)
check(s.show and s.duration == nil and s.expirationTime == nil and s.stacks == nil)
s = F.MakeState({source = "buff", spellID = 13163}, false)
check(s.show and s.duration == nil and s.expirationTime == nil and s.stacks == nil)
check(not F.MakeState({source = "unsupported"}, false).show)
print(checks .. " Forever adapter checks passed")

-- Exercise the provider through the registration/lifecycle boundary called by
-- WeakAuras.lua, using an event recorder rather than an emulated frame runtime.
local system, eventCallback, addCallback, pollCallback
local states, updates = {}, {}
local paused, loginFinished = false, false
private.frames = {}
private.callbacks = {RegisterCallback = function(_, event, callback)
  assert(event == "Add")
  addCallback = callback
end}
private.AuraWarnings = {UpdateWarning = function() end}
private.UpdatedTriggerState = function(id) updates[id] = (updates[id] or 0) + 1 end
env.wipe = function(value) for key in pairs(value) do value[key] = nil end end
env.CreateFrame = function()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, name, func)
      if name == "OnEvent" then eventCallback = func
      elseif name == "OnUpdate" then pollCallback = func
      else error(name) end
    end
  }
end
env.SlashCmdList = {}
env.WeakAuras.IsPaused = function() return paused end
env.WeakAuras.IsLoginFinished = function() return loginFinished end
env.WeakAuras.RegisterTriggerSystem = function(types, provider)
  assert(#types == 1 and types[1] == "forever")
  system = provider
end
env.WeakAuras.GetTriggerStateForTrigger = function(id, index)
  states[id] = states[id] or {}
  states[id][index] = states[id][index] or {}
  return states[id][index]
end
chunk = assert(loadfile("WeakAuras/ForeverTrigger.lua"))
setfenv(chunk, env)("WeakAuras", private)
local aura = {id = "A", uid = "test", regionType = "aurabar",
              triggers = {{trigger = {type = "forever", source = "ammo"}}}}
itemID, count = 2512, 42
system.Add(aura)
system.LoadDisplays({A = true})
system.FinishLoadUnload()
check(states.A[1][""].count == 42) -- Resume happens before loginFinished is set.
loginFinished = true
count = 41
eventCallback()
check(states.A[1][""].count == 41)
aura.triggers[1].trigger.lowOnly = true
aura.triggers[1].trigger.threshold = 10
system.Add(aura)
addCallback("Add", aura.uid, "A")
check(not states.A[1][""].show)
aura.triggers[1].trigger.lowOnly = false

count = secret
eventCallback()
check(not states.A[1][""].show and states.A[1][""].count == nil) -- no stale public data
system.Rename("A", "B")
count = 40
eventCallback()
check(states.B[1][""].count == 40)
local before = updates.B
system.UnloadDisplays({B = true})
eventCallback()
check(updates.B == before)
system.LoadDisplays({B = true})
system.Delete("B")
eventCallback()
check(updates.B == before)
system.Add(aura)
system.LoadDisplays({A = true})
before = updates.A
paused = true
eventCallback()
check(updates.A == before)
paused = false
system.CreateFakeStates("A", 1)
check(states.A[1][""].count == 68)
system.UnloadAll()
eventCallback()
check(updates.A == before)
print(checks .. " total Forever adapter/lifecycle checks passed")

-- New public-source inputs use small API fixtures. They exercise access checks,
-- event routing and real provider lifecycle, not Blizzard's renderer or secret VM.
local now, combat, inRange, usable, insufficient = 100, false, true, true, false
local equipped, known, proc, exists, visible = false, true, false, true, true
local policy, auras = {}, {}
local cooldown = {isActive = false, isEnabled = true, startTime = secret, duration = secret}
local charges = {isActive = true, currentCharges = secret}
env.GetTime = function() return now end
env.InCombatLockdown = function() return combat end
env.IsMounted = function() return false end
env.UnitExists = function() return exists end
env.UnitIsVisible = function() return visible end
env.UnitIsDeadOrGhost = function() return false end
env.GetNumGroupMembers = function() return 0 end
env.GetMoney = function() return 123450 end
env.UnitLevel = function() return 11 end
env.UnitClass = function() return "Hunter", "HUNTER" end
env.GetShapeshiftForm = function() return 0 end
local xp, xpMax = 250, 1000
env.UnitXP = function() return xp end
env.UnitXPMax = function() return xpMax end
env.GetRealZoneText = function() return "Teldrassil" end
env.GetInstanceInfo = function() return "Teldrassil", "none" end
env.C_Spell.GetSpellCooldown = function() return cooldown end
env.C_Spell.GetSpellCharges = function() return charges end
env.C_Spell.IsSpellInRange = function() return inRange end
env.C_Spell.IsSpellUsable = function() return usable, insufficient end
env.C_SpellBook = {IsSpellKnown = function() return known end}
env.C_SpellActivationOverlay = {IsSpellOverlayed = function() return proc end}
env.C_Item.IsEquippedItem = function() return equipped end
env.C_Secrets = {ShouldSpellAuraBeSecret = function(id) return policy[id] or false end}
env.C_UnitAuras = {
  GetPlayerAuraBySpellID = function(id) return auras[id] end,
  GetUnitAuraBySpellID = function(unit, id) assert(unit == "target") return auras[id] end
}
env.WeakAuras.IsOptionsOpen = function() return paused end
local function state(source, extra)
  extra = extra or {}
  extra.source = source
  return F.MakeState(extra, false)
end
itemID, count = 2512, 68
check(state("item_count", {itemID = 2512, compare = "<", threshold = 70}).show)
check(not state("item_count", {itemID = 2512, compare = "<", threshold = 68}).show)
check(state("item_count", {itemID = 2512, compare = "==", threshold = 68}).show)
check(state("item_count", {itemID = 2512, maximum = 200, usePercent = true, compare = "<=", threshold = 34}).show)
count = secret
s = state("item_count", {itemID = 2512, compare = "~=", threshold = 0})
check(not s.show and s.count == nil and s.percent == nil)
check(not state("equipped", {itemID = 2512}).show)
check(state("equipped", {itemID = 2512, showWhen = "false"}).show)
equipped = secret
check(not state("equipped", {itemID = 2512, showWhen = "false"}).show)
check(state("spell_known", {spellID = 2973}).result == true)
known = inaccessible
check(not state("spell_known", {spellID = 2973, showWhen = "false"}).show)
check(state("spell_usable", {spellID = 2973}).show)
usable, insufficient = false, true
s = state("spell_usable", {spellID = 2973, showWhen = "always"})
check(s.show and s.result == false and s.insufficientPower == true)
usable, insufficient = secret, secret
s = state("spell_usable", {spellID = 2973, showWhen = "false"})
check(not s.show and s.result == nil and s.insufficientPower == nil)
inRange = false
check(state("spell_range", {spellID = 2973, showWhen = "false"}).show)
inRange = nil
check(not state("spell_range", {spellID = 2973, showWhen = "false"}).show)
inRange = secret
check(not state("spell_range", {spellID = 2973, showWhen = "false"}).show)
proc = true
check(state("proc", {spellID = 2973}).show)
check(state("cooldown_state", {spellID = 2973, cooldownState = "inactive"}).show)
cooldown.isEnabled = false
check(not state("cooldown_state", {spellID = 2973, cooldownState = "inactive"}).show)
check(state("cooldown_state", {spellID = 2973, cooldownState = "held"}).show)
s = state("cooldown_state", {spellID = 2973, cooldownState = "recharging"})
check(s.show and s.recharging and s.duration == 0 and s.expirationTime == math.huge and s.stacks == nil)
cooldown.isActive = secret
check(not state("cooldown_state", {spellID = 2973, showWhen = "false"}).show)
check(state("player_state", {playerState = "combat", showWhen = "false"}).show)
check(state("unit_state", {unitState = "exists"}).show)
exists = false
check(state("unit_state", {unitState = "exists", showWhen = "false"}).show)
check(not state("unit_state", {unitState = "dead", showWhen = "false"}).show)
exists = true
check(state("level").count == 11 and state("form").count == 0)
check(state("class", {classToken = "HUNTER"}).show and not state("class", {classToken = "MAGE"}).show)
check(state("group_size").count == 1)
check(state("money").count == 12.345)
s = state("experience", {compare = "<=", threshold = 25, usePercent = true})
check(s.show and s.percent == 25 and s.total == 1000)
xp = secret
check(not state("experience").show)
xp, xpMax = 0, 0
check(not state("experience").show)
check(state("zone", {zoneName = "teldrassil"}).show)
check(state("instance", {instanceType = "none"}).show)

local auraCheck = {spellIDs = "13163, 13165", showWhen = "false"}
check(state("aura_presence", auraCheck).show)
auras[13163] = {spellId = 13163}
check(not state("aura_presence", auraCheck).show)
auraCheck.auraMatch = "all"
check(state("aura_presence", auraCheck).show) -- Hawk missing even with Monkey present
policy[13165] = true
s = state("aura_presence", auraCheck)
check(not s.show and not s.available and s.result == nil)
auraCheck.auraMatch = "any"
s = state("aura_presence", auraCheck)
check(s.available and s.result == true and not s.show) -- one public presence decides ANY
policy[13163] = true
check(not state("aura_presence", auraCheck).show)
auras, policy = {}, {}
auraCheck.unit = "target"
visible = false
check(not state("aura_presence", auraCheck).show) -- invisible is not absent
visible = true
check(state("aura_presence", auraCheck).show)
check(not F.MakeState(auraCheck, false, {invalidate = true}).show)
check(F.ParseSpellIDs("13163,13163 13165")[2] == 13165)
check(F.ParseSpellIDs("13163 typo") == nil and F.ParseSpellIDs("-1") == nil)

local timerTrigger = {source = "timer", timerKey = "test", timerDuration = 10}
local context = {}
F.Event(timerTrigger, context, "FOREVER_TIMER", "other")
check(not F.MakeState(timerTrigger, false, context).show)
F.Event(timerTrigger, context, "FOREVER_TIMER", "test")
s = F.MakeState(timerTrigger, false, context)
check(s.show and s.progressType == "timed" and s.duration == 10 and s.expirationTime == 110)
now = 110
check(not F.MakeState(timerTrigger, false, context).show)
F.Event(timerTrigger, context, "FOREVER_TIMER", "test")
check(context.expirationTime == 120)
F.Event(timerTrigger, context, "FOREVER_TIMER_STOP", "test")
check(not F.MakeState(timerTrigger, false, context).show)
timerTrigger.timerStart, timerTrigger.spellID = "cast", 2973
F.Event(timerTrigger, context, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, secret)
check(context.expirationTime == nil)
F.Event(timerTrigger, context, "UNIT_SPELLCAST_SUCCEEDED", "target", nil, 2973)
check(context.expirationTime == nil)
F.Event(timerTrigger, context, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 2973)
check(context.expirationTime == 120)
F.Event(timerTrigger, context, "PLAYER_ENTERING_WORLD")
check(context.expirationTime == nil)
local swing = {source = "swing", swingType = 2}
F.Event(swing, context, "PLAYER_SWING", secret, 2)
check(context.expirationTime == nil)
F.Event(swing, context, "PLAYER_SWING", 2, 0)
check(context.expirationTime == nil)
F.Event(swing, context, "PLAYER_SWING", 2, 2)
s = F.MakeState(swing, false, context)
check(s.show and s.duration == 2 and s.expirationTime == 112)

-- Exercise event routing on a real multi-trigger definition. Conditions must
-- distinguish an inactive readable input from an unavailable one after updates.
local multi = {id = "Multi", uid = "multi", regionType = "icon", triggers = {
  {trigger = {type = "forever", source = "ammo", compare = "<=", threshold = 100}},
  {trigger = {type = "forever", source = "player_state", playerState = "combat"}},
  {trigger = {type = "forever", source = "aura_presence", spellIDs = "13163", showWhen = "false"}}
}}
count, combat, now = 50, true, 200
system.Add(multi)
system.LoadDisplays({Multi = true})
system.FinishLoadUnload()
check(states.Multi[1][""].show and states.Multi[2][""].show and states.Multi[3][""].show)
check(type(pollCallback) == "function")
local active = F.ActiveCondition(multi, 3)
local conditions = system.GetTriggerConditions(multi, 3)
check(active(nil, 1) and conditions.result.test(nil, 0))
eventCallback(nil, "ADDON_RESTRICTION_STATE_CHANGED")
check(not states.Multi[3][""].show and not active(nil, 0) and not active(nil, 1))
check(not conditions.result.test(nil, 0) and conditions.available.test(nil, 0))
policy[13163] = true
pollCallback(nil, 0.2)
check(not states.Multi[3][""].show)
policy[13163] = false
pollCallback(nil, 0.2)
check(states.Multi[3][""].show)
local countReads, updateCount = reads, updates.Multi
pollCallback(nil, 0.2)
check(reads == countReads and updates.Multi == updateCount) -- no inventory polling or unchanged updates
combat = false
eventCallback(nil, "PLAYER_REGEN_ENABLED")
check(not states.Multi[2][""].show and states.Multi[1][""].show)
-- Rename preserves observations; unload erases them and stops polling.
system.Rename("Multi", "Renamed")
multi.id = "Renamed"
check(F.ActiveCondition(multi, 1)(nil, 1))
system.UnloadDisplays({Renamed = true})
check(F.observations.Renamed == nil and pollCallback == nil)
check(not F.ActiveCondition(multi, 1)(nil, 0))
system.Delete("Renamed")
-- Runtime fallback data is not the editor's sample value.
count = 17
local fallback = {}
system.CreateFallbackState(aura, 1, fallback)
check(fallback.count == 17)
print(checks .. " total Forever source/lifecycle checks passed")

local timerAura = {id = "Timer", uid = "timer", regionType = "aurabar", triggers = {
  {trigger = {type = "forever", source = "timer", timerKey = "demo", timerDuration = 10}}
}}
system.Add(timerAura)
system.LoadDisplays({Timer = true})
system.FinishLoadUnload()
env.SlashCmdList.WEAKAURASFOREVER("timer demo")
check(states.Timer[1][""].show and states.Timer[1][""].expirationTime == now + 10)
env.SlashCmdList.WEAKAURASFOREVER("stop demo")
check(not states.Timer[1][""].show)
env.SlashCmdList.WEAKAURASFOREVER("timer demo")
system.UnloadDisplays({Timer = true})
system.LoadDisplays({Timer = true})
system.FinishLoadUnload()
check(not states.Timer[1][""].show) -- unloading does not resume an old event timer
local progress = {}
system.GetProgressSources(timerAura, 1, progress)
check(progress[1].property == "expirationTime" and progress[1].total == "duration")
timerAura.triggers[1].trigger = {type = "forever", source = "ammo"}
system.Add(timerAura)
addCallback("Add", timerAura.uid, "Timer")
check(states.Timer[1][""].count == 17 and states.Timer[1][""].expirationTime == nil and pollCallback == nil)
system.Delete("Timer")

-- The optional example command must leave an existing aura with that name alone.
local existing = {id = "Forever example - Manual timer", sentinel = "user edits"}
local examples, additions = {[existing.id] = existing}, 0
env.WeakAuras.GetData = function(id) return examples[id] end
env.WeakAuras.GenerateUniqueID = function() return "example" .. additions end
env.WeakAuras.InternalVersion = function() return 1 end
env.WeakAuras.Add = function(data) examples[data.id], additions = data, additions + 1 end
env.WeakAuras.OpenOptions = function() end
env.WeakAuras.prettyPrint = function() end
private.ScanForLoads = function() end
env.SlashCmdList.WEAKAURASFOREVER("examples")
check(additions == 6 and examples[existing.id] == existing)
env.SlashCmdList.WEAKAURASFOREVER("examples")
check(additions == 6 and existing.sentinel == "user edits")
for _, example in pairs(examples) do
  if example ~= existing then
    for _, entry in ipairs(example.triggers) do
      check(entry.untrigger ~= nil and F.MakeState(entry.trigger, true).show)
    end
  end
end
print(checks .. " total Forever checks including slash commands and example preservation passed")
