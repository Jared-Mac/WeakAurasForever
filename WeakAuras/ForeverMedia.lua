-- Forever media relocation, 2026-09-23. GPLv2; see LICENSE.
local AddonName, Private = ...

-- Deliberately split: the packager must not rewrite the source prefix itself.
local legacyPrefix = "interface/addons/" .. "weakauras/media/"
local function relocate(value)
  if type(value) ~= "string" then
    return value
  end
  local path = value:gsub("\\", "/")
  if path:sub(1, #legacyPrefix):lower() == legacyPrefix then
    return "Interface\\AddOns\\" .. AddonName .. "\\Media\\"
      .. path:sub(#legacyPrefix + 1):gsub("/", "\\")
  end
  return value
end

-- Only renderer-owned media fields. Do not walk arbitrary tables: aura names,
-- custom Lua, display text, trigger values and custom config are user content.
local fields = {
  "displayIcon", "texture", "textureInput", "sparkTexture",
  "foregroundTexture", "backgroundTexture", "textureTexture",
  "circularTextureTexture", "linearTextureTexture", "stopmotionTexture",
  "tick_texture", "font", "text_font", "border_edge", "borderEdge",
  "borderBackdrop",
}
local mediaProperties = {}
for _, field in ipairs(fields) do
  mediaProperties[field] = true
end

local function relocateFields(object)
  for _, field in ipairs(fields) do
    object[field] = relocate(object[field])
  end
end

local function relocateSound(object)
  object.sound = relocate(object.sound)
  object.sound_path = relocate(object.sound_path)
end

function Private.RelocateForeverMedia(data)
  relocateFields(data)
  for _, subregion in ipairs(data.subRegions or {}) do
    relocateFields(subregion)
  end
  for _, action in pairs(data.actions or {}) do
    if type(action) == "table" then
      relocateSound(action)
    end
  end
  for _, condition in ipairs(data.conditions or {}) do
    for _, change in ipairs(condition.changes or {}) do
      local property = change.property
      if type(property) == "string" then
        local field = property:match("^sub%.%d+%.(.+)$") or property
        if mediaProperties[field] then
          change.value = relocate(change.value)
        elseif property == "sound" and type(change.value) == "table" then
          relocateSound(change.value)
        end
      end
    end
  end
end
