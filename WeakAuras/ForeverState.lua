-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local L = WeakAuras.L
local F = {}
Private.Forever = F

function F.Readable(value)
  return not issecretvalue(value) and canaccessvalue(value)
end

function F.ReadAmmo()
  local itemID = GetInventoryItemID("player", 0)
  if not F.Readable(itemID) then return nil end
  if itemID == nil then return 0 end
  local count = C_Item.GetItemCount(itemID, false, false, false)
  if not F.Readable(count) or type(count) ~= "number" then return nil end
  return count, itemID
end

local sourceNames = {
  ammo = L["Equipped ammunition"],
  cooldown = L["Spell cooldown (native)"],
  buff = L["Player buff (native)"]
}
F.sourceNames = sourceNames

function F.SpellID(trigger)
  local id = tonumber(trigger.spellID)
  if id and id > 0 and id == math.floor(id) then return id end
end

function F.NameAndIcon(trigger)
  if trigger.source == "cooldown" or trigger.source == "buff" then
    local id = F.SpellID(trigger)
    if id then return C_Spell.GetSpellName(id), C_Spell.GetSpellTexture(id) end
  else
    local _, item = F.ReadAmmo()
    return sourceNames.ammo, item and C_Item.GetItemIconByID(item) or 132382
  end
  return sourceNames[trigger.source] or L["Forever"], 134400
end

-- All state passed to WA is public. Native timers and aura occupancy never
-- enter its state tables, generated conditions, text formatters or sorting.
function F.MakeState(trigger, preview)
  local name, icon = F.NameAndIcon(trigger)
  local state = {changed = true, show = true, name = name, icon = icon,
                 progressType = "static", value = 0, total = 1}
  local source = trigger.source or "ammo"
  if source == "ammo" then
    local count = preview and 68 or F.ReadAmmo()
    state.available = count ~= nil
    state.count = count
    state.value = count or 0
    state.total = math.max(1, tonumber(trigger.maximum) or 200)
    state.stacks = count
    state.show = preview or (state.available and
      (not trigger.lowOnly or count <= (tonumber(trigger.threshold) or 100)))
  elseif source == "cooldown" or source == "buff" then
    state.show = preview or F.SpellID(trigger) ~= nil
  else
    state.show = false
  end
  return state
end

