-- Actual modernization entry point with current-version data. No WoW UI stub.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local forever = true
WeakAuras = {
  IsLibsOK = function() return true end,
  IsForever = function() return forever end,
  InternalVersion = function() return 90 end,
  L = {},
}
max = math.max
local Private = {}
T.loadAddonFile("WeakAuras/ForeverMedia.lua", "WAF", Private)
T.loadAddonFile("WeakAuras/Modernize.lua", "WAF", Private)

local old = [[Interface\AddOns\WeakAuras\Media\Textures\Square_FullWhite]]
local new = [[Interface\AddOns\WAF\Media\Textures\Square_FullWhite]]
local sound = [[Interface\AddOns\WeakAuras\Media\Sounds\HeartbeatSingle.ogg]]
local newSound = [[Interface\AddOns\WAF\Media\Sounds\HeartbeatSingle.ogg]]
local data = {
  internalVersion = 90,
  id = old, uid = "unchanged", parent = old, xOffset = 123,
  texture = old, textureInput = old, sparkTexture = old, displayIcon = 12345,
  font = "Fira Sans Medium", displayText = old,
  config = {texture = old},
  triggers = {{trigger = {custom = old, texture = old}}},
  actions = {start = {sound = sound, sound_path = sound, custom = old}},
  subRegions = {
    {type = "subtexture", textureTexture = old},
    {type = "subtext", text_text = old, text_font = "Friz Quadrata TT"},
    {type = "subtick", tick_texture = old},
  },
  conditions = {{changes = {
    {property = "texture", value = old},
    {property = "sub.1.textureTexture", value = old},
    {property = "sub.2.text_text", value = old},
    {property = "sound", value = {sound = sound, sound_path = sound}},
    {property = "chat", value = {message = old}},
  }}},
}
Private.Modernize(data)
T.expect(data.texture == new and data.sparkTexture == new and data.textureInput == new,
         "current-version displays relocate at the real modernization boundary")
T.expect(data.id == old and data.parent == old and data.uid == "unchanged" and data.xOffset == 123,
         "names, grouping, IDs and layout remain unchanged")
T.expect(data.displayText == old and data.config.texture == old
         and data.triggers[1].trigger.custom == old and data.actions.start.custom == old,
         "text, custom settings and custom code are not rewritten")
T.expect(data.actions.start.sound == newSound and data.actions.start.sound_path == newSound,
         "action sound paths relocate")
T.expect(data.subRegions[1].textureTexture == new and data.subRegions[3].tick_texture == new,
         "subregion textures relocate")
T.expect(data.subRegions[2].text_text == old and data.subRegions[2].text_font == "Friz Quadrata TT",
         "subregion text and SharedMedia names stay intact")
T.expect(data.conditions[1].changes[1].value == new and data.conditions[1].changes[2].value == new,
         "media condition overrides relocate")
T.expect(data.conditions[1].changes[3].value == old
         and data.conditions[1].changes[5].value.message == old,
         "condition text and chat messages stay intact")
T.expect(data.conditions[1].changes[4].value.sound == newSound
         and data.conditions[1].changes[4].value.sound_path == newSound,
         "sound condition overrides relocate")
T.expect(data.displayIcon == 12345 and data.font == "Fira Sans Medium",
         "numeric file IDs and SharedMedia keys stay intact")
Private.Modernize(data)
T.expect(data.texture == new and data.actions.start.sound == newSound,
         "repeated load and import modernization is idempotent")

data.texture = "INTERFACE/AddOns/wEaKaUrAs/MeDiA/Textures/Square_FullWhite"
Private.Modernize(data)
T.expect(data.texture == new, "mixed case and slash paths relocate")
for _, value in ipairs({
  [[Interface\AddOns\WeakAurasExtra\Media\Textures\test]],
  [[Interface\AddOns\OtherAddon\texture]],
  [[Interface\Icons\INV_Misc_QuestionMark]],
  "Square_FullWhite",
}) do
  data.texture = value
  Private.Modernize(data)
  T.expect(data.texture == value, "unrelated path or atlas is not rewritten: " .. value)
end
forever = false
data.texture = old
Private.Modernize(data)
T.expect(data.texture == old, "other client flavors retain upstream paths")
T.finish()
