if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

-- WeakAuras Simple Remastered – learning list
-- Grimfall & Classless compatible by Lidless
--
-- Grimfall has a lot of custom spells, buffs and procs (classless builds, runes, CoA classes),
-- so nobody can be expected to know their exact names. This file quietly writes down every
-- aura it sees, per character:
--   * buffs and debuffs on the player
--   * debuffs the player put on the current target (DoTs), nothing else from the target
-- and sorts them into simple categories. The picker of the options shows this list, together
-- with the spellbook and usable items. Entries can also be added, moved or removed by hand.

local Learning = {}
Private.Learning = Learning

local UnitAura, UnitIsUnit, GetTime, GetSpellInfo, time = UnitAura, UnitIsUnit, GetTime, GetSpellInfo, time
local pairs, ipairs, tonumber, tostring, type, next = pairs, ipairs, tonumber, tostring, type, next

-- categories (kind)
--   proc        short buff on me that I did not cast directly (procs, rune effects)
--   mybuff      buff I cast on myself
--   received    buff someone else put on me
--   passive     permanent buff without duration (auras, passives, Born Hero...)
--   debuffOnMe  debuff on me
--   mydot       my debuff / DoT on my target
Learning.kinds = { "proc", "mybuff", "received", "passive", "debuffOnMe", "mydot" }
Learning.kindNames = {
  proc = L["Procs"],
  mybuff = L["My buffs"],
  received = L["Buffs from others"],
  passive = L["Passive / permanent"],
  debuffOnMe = L["Debuffs on me"],
  mydot = L["My debuffs / DoTs on target"],
}

local PROC_MAX_DURATION = 30   -- seconds; longer self buffs count as "my buff"
local CAST_WINDOW = 1.0        -- an aura appearing this soon after casting the same spell is not a proc
local MAX_ENTRIES = 600        -- per character

local recentCasts = {}         -- spell name -> GetTime() of my last cast

local function store()
  local info = Private.Grimfall and Private.Grimfall.GetCharacterInfo()
  if not info then return nil end
  info.learned = info.learned or {}
  return info.learned
end

local function classify(filter, unit, duration, caster, name)
  if unit == "target" then
    return "mydot"
  end
  if filter == "HARMFUL" then
    return "debuffOnMe"
  end
  if not duration or duration == 0 then
    return "passive"
  end
  local mine = caster == nil or caster == "player" or caster == "pet" or caster == "vehicle"
  if not mine then
    return "received"
  end
  local castAt = recentCasts[name]
  if castAt and GetTime() - castAt <= CAST_WINDOW then
    return "mybuff"
  end
  if duration <= PROC_MAX_DURATION then
    return "proc"
  end
  return "mybuff"
end

local function prune(list)
  local count = 0
  for _ in pairs(list) do count = count + 1 end
  if count <= MAX_ENTRIES then return end
  -- drop the least seen, oldest automatic entries
  local candidates = {}
  for id, entry in pairs(list) do
    if not entry.manual and not entry.userKind then
      candidates[#candidates + 1] = id
    end
  end
  table.sort(candidates, function(a, b)
    local ea, eb = list[a], list[b]
    if (ea.seen or 0) ~= (eb.seen or 0) then return (ea.seen or 0) < (eb.seen or 0) end
    return (ea.lastSeen or 0) < (eb.lastSeen or 0)
  end)
  for i = 1, count - MAX_ENTRIES do
    if candidates[i] then list[candidates[i]] = nil end
  end
end

local seenThisSession = {}

local function record(unit, filter, index)
  local name, _, icon, _, _, duration, _, caster, _, _, spellId = UnitAura(unit, index, filter)
  if not name then return false end
  if unit == "target" and caster ~= "player" and caster ~= "pet" then
    return true -- only my own debuffs on the target
  end
  local list = store()
  if not list then return true end
  local key = spellId or name
  local entry = list[key]
  local now = time()
  if not entry then
    entry = { name = name, icon = icon, spellId = spellId, seen = 0 }
    list[key] = entry
  end
  entry.icon = icon or entry.icon
  entry.name = name
  -- the first sighting decides the category; casting the spell yourself later moves it to "my buffs"
  local castAt = recentCasts[name]
  if not entry.kind then
    entry.kind = classify(filter, unit, duration, caster, name)
  elseif filter == "HELPFUL" and unit == "player" and castAt and GetTime() - castAt <= CAST_WINDOW and entry.kind == "proc" then
    entry.kind = "mybuff"
  end
  if duration and duration > 0 then entry.duration = duration end
  -- count each aura once per appearance, not on every UNIT_AURA
  local sessionKey = unit .. ":" .. tostring(key)
  if not seenThisSession[sessionKey] then
    seenThisSession[sessionKey] = true
    entry.seen = (entry.seen or 0) + 1
    entry.lastSeen = now
  end
  return true
end

local function scan(unit)
  if unit == "target" and (not UnitExists("target") or UnitIsUnit("target", "player")) then
    return
  end
  local present = {}
  local filters = unit == "target" and { "HARMFUL" } or { "HELPFUL", "HARMFUL" }
  for _, filter in ipairs(filters) do
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
      if not name then break end
      present[unit .. ":" .. tostring(spellId or name)] = true
      record(unit, filter, i)
    end
  end
  -- auras that went away can be counted again when they come back
  local prefix = unit .. ":"
  for k in pairs(seenThisSession) do
    if k:sub(1, #prefix) == prefix and not present[k] then
      seenThisSession[k] = nil
    end
  end
  if unit == "player" then
    prune(store() or {})
  end
end

local function forgetTarget()
  for k in pairs(seenThisSession) do
    if k:sub(1, 7) == "target:" then seenThisSession[k] = nil end
  end
end

---------------------------------------------------------------------------
-- API for the options
---------------------------------------------------------------------------

--- learned + manual entries of this character, as a list
function Learning.GetEntries(kind)
  local list = store() or {}
  local result = {}
  for key, entry in pairs(list) do
    local k = entry.userKind or entry.kind
    if not kind or k == kind then
      result[#result + 1] = {
        key = key,
        name = entry.name,
        icon = entry.icon,
        spellId = entry.spellId,
        kind = k,
        duration = entry.duration,
        seen = entry.seen or 0,
        manual = entry.manual,
      }
    end
  end
  table.sort(result, function(a, b)
    if a.seen ~= b.seen then return a.seen > b.seen end
    return (a.name or "") < (b.name or "")
  end)
  return result
end

function Learning.SetKind(key, kind)
  local list = store()
  if list and list[key] then
    list[key].userKind = kind
  end
end

function Learning.Remove(key)
  local list = store()
  if list then list[key] = nil end
end

--- add by name or spell id; returns the entry or nil, error text
function Learning.AddManual(text, kind)
  if not text or text == "" then return nil, L["Type a name or a spell ID."] end
  text = text:match("^%s*(.-)%s*$")
  local spellId = tonumber(text)
  local name, icon
  if spellId then
    local n, _, i = GetSpellInfo(spellId)
    if not n then return nil, L["Unknown spell ID."] end
    name, icon = n, i
  else
    name = text
    local link = GetSpellLink and GetSpellLink(text)
    spellId = link and tonumber(link:match("spell:(%d+)"))
    if spellId then
      local _, _, i = GetSpellInfo(spellId)
      icon = i
    end
    icon = icon or (WeakAuras.spellCache and WeakAuras.spellCache.GetIcon and WeakAuras.spellCache.GetIcon(text))
  end
  local list = store()
  if not list then return nil, L["Not logged in yet."] end
  local key = spellId or name
  local entry = list[key] or { seen = 0 }
  entry.name = name
  entry.icon = icon or entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  entry.spellId = spellId
  entry.kind = entry.kind or kind
  entry.userKind = kind
  entry.manual = true
  list[key] = entry
  return entry
end

---------------------------------------------------------------------------
-- Spellbook and items
---------------------------------------------------------------------------

local scanTip
local function tooltipHasCooldown(index, bookType)
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "WeakAurasSimpleScanTooltip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
  scanTip:ClearLines()
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:SetSpell(index, bookType)
  for line = 1, scanTip:NumLines() do
    for _, side in ipairs({ "Left", "Right" }) do
      local fontString = _G["WeakAurasSimpleScanTooltipText" .. side .. line]
      local text = fontString and fontString:GetText()
      if text and text:lower():find("cooldown") then
        return true, text
      end
    end
  end
  return false
end

--- every active (not passive) spell in the spellbook and pet spellbook
function Learning.GetSpellbook()
  local result, seen = {}, {}
  local books = { { BOOKTYPE_SPELL or "spell", nil } }
  if HasPetSpells and HasPetSpells() then
    tinsert(books, { BOOKTYPE_PET or "pet", HasPetSpells() })
  end
  local total = 0
  for t = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
    local _, _, offset, numSpells = GetSpellTabInfo(t)
    total = max(total, (offset or 0) + (numSpells or 0))
  end
  for _, book in ipairs(books) do
    local bookType = book[1]
    local count = bookType == (BOOKTYPE_PET or "pet") and (book[2] or 0) or total
    for i = 1, count do
      local name = GetSpellName(i, bookType)
      if not name then break end
      if not IsPassiveSpell(i, bookType) then
        local link = GetSpellLink(i, bookType)
        local spellId = link and tonumber(link:match("spell:(%d+)"))
        local key = spellId or name
        if not seen[key] then
          seen[key] = true
          local hasCooldown, cooldownText = tooltipHasCooldown(i, bookType)
          result[#result + 1] = {
            key = key,
            name = name,
            spellId = spellId,
            icon = GetSpellTexture(i, bookType),
            kind = hasCooldown and "cooldown" or "spell",
            info = cooldownText,
            pet = bookType ~= (BOOKTYPE_SPELL or "spell"),
          }
        end
      end
    end
  end
  table.sort(result, function(a, b) return (a.name or "") < (b.name or "") end)
  return result
end

--- items with a "Use:" effect in the bags and equipped
function Learning.GetUsableItems()
  local result, seen = {}, {}
  local function add(link)
    if not link then return end
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId or seen[itemId] then return end
    if GetItemSpell(link) then
      seen[itemId] = true
      local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(link)
      result[#result + 1] = { key = itemId, itemId = itemId, name = name or tostring(itemId), icon = icon or GetItemIcon(itemId), kind = "item" }
    end
  end
  for slot = 1, 19 do
    add(GetInventoryItemLink("player", slot))
  end
  for bag = 0, 4 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      add(GetContainerItemLink(bag, slot))
    end
  end
  table.sort(result, function(a, b) return (a.name or "") < (b.name or "") end)
  return result
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:SetScript("OnEvent", function(self, event, unit, spellName)
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit == "player" and spellName then
      recentCasts[spellName] = GetTime()
    end
  elseif event == "UNIT_AURA" then
    if unit == "player" or unit == "target" then
      scan(unit)
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    forgetTarget()
    scan("target")
  else
    scan("player")
  end
end)
