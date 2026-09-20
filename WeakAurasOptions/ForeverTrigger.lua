-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local OptionsPrivate = select(2, ...)
local L = WeakAuras.L
local F = OptionsPrivate.Private.Forever

local function options(data, index)
  local trigger = data.triggers[index].trigger
  local function source() return trigger.source or "ammo" end
  local function definition() return F.Source(trigger) or {} end
  local function commit()
    WeakAuras.Add(data)
    WeakAuras.UpdateThumbnail(data)
    WeakAuras.ClearAndUpdateOptions(data.id)
  end
  local function selectSource(value)
    trigger.source = value
    trigger.showWhen, trigger.compare, trigger.lowOnly, trigger.unit = nil, nil, nil, nil
    commit()
  end
  local function only(value) return function() return source() ~= value end end
  local function numeric() return definition().kind == "number" end
  local function comparison() return trigger.compare or (trigger.lowOnly and "<=") or "always" end
  local function spellInput()
    return definition().spell or source() == "timer" and trigger.timerStart == "cast"
  end
  local result = {
    __title = L["Forever source"], __order = index, __collapsed = false,
    category = {
      type = "select", name = L["Category"] .. (WeakAuras.newFeatureString or ""), order = 1,
      values = F.categories, sorting = F.categoryOrder,
      get = function() return definition().category or "item" end,
      set = function(_, value) selectSource(F.defaults[value]) end
    },
    source = {
      type = "select", name = L["Track"], order = 2,
      values = function()
        local values = {}
        for key, entry in pairs(F.sources) do
          if entry.category == definition().category then values[key] = entry.name end
        end
        return values
      end,
      get = source, set = function(_, value) selectSource(value) end
    },
    spellbook = {
      type = "select", name = L["Choose from spellbook"], order = 2.8, width = "full",
      hidden = function() return not spellInput() and source() ~= "aura_presence" end,
      values = function()
        local values = {}
        -- This cache contains only reported spellbook slots in Forever. Do not
        -- bring back the full spell-database scan when populating this picker.
        for name, entry in pairs(WeakAuras.spellCache.Get()) do
          for id in entry.spells:gmatch("(%d+)=") do
            values[tonumber(id)] = name .. " (" .. id .. ")"
          end
        end
        return values
      end,
      get = function() return source() ~= "aura_presence" and F.SpellID(trigger) or nil end,
      set = function(_, value)
        if source() == "aura_presence" then
          local ids = F.ParseSpellIDs(trigger.spellIDs or trigger.spellID) or {}
          for _, id in ipairs(ids) do if id == value then return end end
          if #ids >= 32 then return end
          ids[#ids + 1] = value
          trigger.spellIDs = table.concat(ids, ", ")
        else
          trigger.spellID = value
        end
        commit()
      end
    },
    spellID = {
      type = "input", name = L["Spell ID"], order = 3,
      hidden = function() return not spellInput() end,
      get = function() return tostring(trigger.spellID or "") end,
      validate = function(_, value) return F.PositiveID(value) ~= nil or L["Enter a positive spell ID."] end
    },
    spellName = {
      type = "description", order = 3.1,
      hidden = function() return not spellInput() end,
      name = function()
        local id = F.SpellID(trigger)
        if not id then return L["Choose a spell from your spellbook or enter its exact ID."] end
        return F.Read(C_Spell.GetSpellName, "string", id) or L["Spell name unavailable."]
      end
    },
    itemID = {
      type = "input", name = L["Item ID"], order = 3,
      hidden = function() return not definition().item end,
      get = function() return tostring(trigger.itemID or "") end,
      validate = function(_, value) return F.PositiveID(value) ~= nil or L["Enter a positive item ID."] end
    },
    spellIDs = {
      type = "input", name = L["Effect spell IDs"], order = 3, width = "full",
      desc = L["Enter up to 32 exact spell IDs, separated by spaces or commas. Include each rank you want to check."],
      hidden = only("aura_presence"),
      get = function() return tostring(trigger.spellIDs or trigger.spellID or "") end,
      validate = function(_, value) return F.ParseSpellIDs(value) ~= nil or L["Enter 1 to 32 positive spell IDs, separated by spaces or commas."] end
    },
    auraMatch = {
      type = "select", name = L["Match effects"], order = 4,
      values = {any = L["Any listed effect"], all = L["All listed effects"]},
      hidden = only("aura_presence"), get = function() return trigger.auraMatch or "any" end
    },
    unit = {
      type = "select", name = L["Unit"], order = 4.1,
      hidden = function()
        return source() ~= "buff" and source() ~= "aura_presence" and source() ~= "unit_state" and source() ~= "spell_range"
      end,
      values = function()
        if source() == "buff" or source() == "aura_presence" then
          return {player = L["Player"], target = L["Target"]}
        end
        return F.units
      end,
      get = function() return trigger.unit or ((source() == "buff" or source() == "aura_presence") and "player" or "target") end
    },
    auraFilter = {
      type = "select", name = L["Effect type"], order = 4.2,
      values = {HELPFUL = L["Buff"], HARMFUL = L["Debuff"]},
      hidden = only("buff"), get = function() return trigger.auraFilter or "HELPFUL" end
    },
    nativeTimer = {
      type = "select", name = L["Timer"], order = 4,
      values = {cooldown = L["Spell cooldown"], charges = L["Charge recharge"]},
      hidden = only("cooldown"), get = function() return trigger.nativeTimer or "cooldown" end
    },
    cooldownState = {
      type = "select", name = L["Check"], order = 4, width = "full", values = F.cooldownStates,
      hidden = only("cooldown_state"), get = function() return trigger.cooldownState or "active" end
    },
    playerState = {
      type = "select", name = L["Check"], order = 4, values = F.playerStates,
      hidden = only("player_state"), get = function() return trigger.playerState or "combat" end
    },
    classToken = {
      type = "select", name = L["Class"], order = 4,
      values = function() return WeakAuras.class_types end,
      hidden = only("class"), get = function() return trigger.classToken or F.ClassToken() end
    },
    unitState = {
      type = "select", name = L["Check"], order = 4, values = F.unitStates,
      hidden = only("unit_state"), get = function() return trigger.unitState or "exists" end
    },
    zoneName = {
      type = "input", name = L["Zone name"], order = 4, width = "full",
      hidden = only("zone"), desc = L["Exact zone name in your game language. Capitalization does not matter."]
    },
    currentZone = {
      type = "execute", name = L["Use current zone"], order = 4.1, hidden = only("zone"),
      func = function()
        local zone = F.Read(GetRealZoneText, "string")
        if zone then trigger.zoneName = zone commit() end
      end
    },
    instanceType = {
      type = "select", name = L["Instance type"], order = 4, values = F.instanceTypes,
      hidden = only("instance"), get = function() return trigger.instanceType or "party" end
    },
    swingType = {
      type = "select", name = L["Weapon"], order = 4,
      values = {[0] = L["Main hand"], [1] = L["Off hand"], [2] = L["Ranged"]},
      hidden = only("swing"), get = function() return trigger.swingType or 2 end
    },
    timerStart = {
      type = "select", name = L["Start timer on"], order = 2.5,
      values = {manual = L["Slash command"], combat = L["Entering combat"], cast = L["Successful player cast (when readable)"]},
      hidden = only("timer"), get = function() return trigger.timerStart or "manual" end
    },
    timerKey = {
      type = "input", name = L["Timer key"], order = 4,
      hidden = function() return source() ~= "timer" or (trigger.timerStart or "manual") ~= "manual" end,
      get = function() return trigger.timerKey or "timer" end,
      validate = function(_, value) return value:match("^[%w_-]+$") ~= nil or L["Use letters, numbers, underscores or hyphens."] end
    },
    timerDuration = {
      type = "range", name = L["Duration (seconds)"], order = 4.1, min = 0.1, max = 3600, softMax = 120, step = 0.1,
      hidden = only("timer"), get = function() return trigger.timerDuration or 10 end
    },
    showWhen = {
      type = "select", name = L["Show when"], order = 5, width = "full",
      hidden = function() return definition().kind ~= "bool" end,
      values = function()
        if source() == "aura_presence" then
          if (trigger.auraMatch or "any") == "any" then
            return {["true"] = L["At least one effect is present"], ["false"] = L["None of the effects are present"], always = L["Always, while data is available"]}
          end
          return {["true"] = L["Every effect is present"], ["false"] = L["At least one effect is missing"], always = L["Always, while data is available"]}
        end
        return {["true"] = L["Condition is true"], ["false"] = L["Condition is false"], always = L["Always, while data is available"]}
      end,
      get = function() return trigger.showWhen or "true" end
    },
    compare = {
      type = "select", name = L["Show when value is"], order = 5,
      values = {always = L["Always"], ["<"] = L["Below"], ["<="] = L["At or below"],
        [">"] = L["Above"], [">="] = L["At or above"], ["=="] = L["Equal to"], ["~="] = L["Not equal to"]},
      hidden = function() return not numeric() end,
      get = comparison, set = function(_, value) trigger.compare, trigger.lowOnly = value, nil commit() end
    },
    threshold = {
      type = "input", name = L["Threshold"], order = 5.1,
      hidden = function() return not numeric() or comparison() == "always" end,
      get = function() return tostring(trigger.threshold or 100) end,
      validate = function(_, value)
        local number = tonumber(value)
        return number and number >= 0 and number < math.huge or L["Enter a non-negative number."]
      end,
      set = function(_, value) trigger.threshold = tonumber(value) commit() end
    },
    usePercent = {
      type = "toggle", name = L["Compare percentage"], order = 5.2,
      desc = L["Compare against a percentage of the bar maximum. Experience uses the current level's XP requirement."],
      hidden = function() return not numeric() or comparison() == "always" end
    },
    maximum = {
      type = "range", name = L["Bar maximum"], order = 6, min = 1, max = 1000000, softMax = 1000, step = 1,
      hidden = function() return not numeric() or source() == "experience" end,
      get = function() return trigger.maximum or 200 end
    },
    help = {
      type = "description", order = 8, width = "full",
      name = function()
        local kind = source()
        if kind == "buff" then
          return L["Display only · Icon required. Blizzard controls this effect's visibility and timer. Extra WA text and borders do not follow buff visibility. For present/missing conditions, choose the separate presence source; restricted data cannot drive those conditions."]
        elseif kind == "cooldown" then
          return L["Native timer · Icon required. Keep Display > Cooldown enabled. Conditions can use cooldown-active, enabled and recharging flags. Numeric remaining time and current charge counts are not exposed. Use one native display source per icon."]
        elseif kind == "aura_presence" then
          return L["Checks exact effect IDs from any caster. For a missing-aspect reminder, list your aspect IDs, match Any, and show when None are present. Restricted data is unknown and cannot prove an effect is missing; the reminder hides until a readable check is possible."]
        elseif kind == "cooldown_state" then
          return L["Uses public on/off flags. Active includes the global cooldown. Inactive excludes cooldowns on hold and does not guarantee castability. Recharging describes charge recovery, not the number of charges available."]
        elseif kind == "spell_range" then
          return L["Checks this spell against the selected unit. An invalid check (no target, wrong target type or unsupported spell) is unknown, never out of range."]
        elseif kind == "spell_usable" then
          return L["Checks the game's usability flag and insufficient-resource flag. This is not a combined cooldown, range and valid-target check; add those as separate triggers if needed."]
        elseif kind == "proc" then
          return L["Tracks the spell highlights supplied by Blizzard. This does not detect every buff or proc."]
        elseif kind == "timer" then
          if (trigger.timerStart or "manual") == "manual" then
            return L["Start: /waf timer %s\nStop: /waf stop %s\nMatching timers restart on each command. Timers reset on unload, edit or reload."]:format(trigger.timerKey or "timer", trigger.timerKey or "timer")
          end
          return L["A fixed timer started by the selected event. Cast events start it only when the player's spell ID is readable. This does not reconstruct a protected cooldown or buff duration. Timers reset on unload, edit or reload."]
        elseif kind == "swing" then
          return L["Uses Forever's public swing event and duration. Starts after the next matching swing. Supports icons, bars and remaining-time text; weapon changes and interrupted swings need in-game testing."]
        elseif kind == "form" then
          return L["Uses the stance bar's form number. Zero means no form. This is not a hunter-aspect buff check."]
        elseif kind == "experience" then
          return L["Tracks current XP and the XP required for this level. Percent conditions use that requirement. No display is shown when the XP requirement is unavailable or zero."]
        elseif kind == "group_size" then
          return L["Counts your group including yourself. Solo counts as one."]
        elseif kind == "ammo" then
          return L["Counts equipped ammunition in your bags. No ammunition equipped counts as zero. The previous low-ammo setting is preserved. Use Conditions to change color, text or glow at other thresholds."]
        elseif kind == "item_count" then
          return L["Counts this item in your bags and equipment, excluding bank storage. Zero is a valid count. Use Conditions for additional color, text and glow thresholds."]
        end
        return L["Use Add Trigger and Required for Activation: All / Any to combine checks. Choose Condition is false to invert this check. Unavailable data never becomes a matching inverse condition."]
      end
    },
    nativeWarning = {
      type = "description", order = 2.1, width = "full",
      hidden = function() return not F.IsNative(trigger) or data.regionType == "icon" end,
      name = L["This source needs an Icon display. For a bar or text display, choose a public state or timer source."]
    }
  }
  -- Category replaces the single-entry legacy Type dropdown. Persisted trigger
  -- type stays 'forever', so existing auras/imports retain their provider.
  OptionsPrivate.commonOptions.AddTriggerGetterSetter(result, data, index)
  OptionsPrivate.AddTriggerMetaFunctions(result, data, index)
  return {["trigger." .. index .. ".forever"] = result}
end
WeakAuras.RegisterTriggerSystemOptions({"forever"}, options)
