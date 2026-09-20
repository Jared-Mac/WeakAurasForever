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
local system, eventCallback, addCallback
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
    SetScript = function(_, name, func) assert(name == "OnEvent") eventCallback = func end
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
