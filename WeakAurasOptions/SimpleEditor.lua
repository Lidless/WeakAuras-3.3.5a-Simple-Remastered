if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- WeakAuras Simple Remastered simple editor
-- Grimfall & Classless compatible by Lidless
--
-- When "Advanced options" is off (the default) a single aura is edited on five short tabs:
--   Look, Trigger, Effects, Rules, When
-- They write into the normal WeakAuras data, so switching to the advanced tabs
-- always shows the same aura with everything that was set here.

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local pairs, ipairs, type, tostring, tonumber, tinsert, sort = pairs, ipairs, type, tostring, tonumber, tinsert, table.sort

---------------------------------------------------------------------------
-- Shared lists
---------------------------------------------------------------------------

-- 10 easy colors (8 basic + pink and grey)
local colors = {
  { key = "yellow", name = L["Yellow"], value = { 1, 0.9, 0, 1 } },
  { key = "green", name = L["Green"], value = { 0.1, 0.9, 0.1, 1 } },
  { key = "lightblue", name = L["Light blue"], value = { 0.4, 0.8, 1, 1 } },
  { key = "darkblue", name = L["Dark blue"], value = { 0.1, 0.3, 1, 1 } },
  { key = "red", name = L["Red"], value = { 1, 0.15, 0.15, 1 } },
  { key = "orange", name = L["Orange"], value = { 1, 0.55, 0, 1 } },
  { key = "purple", name = L["Purple"], value = { 0.7, 0.3, 1, 1 } },
  { key = "white", name = L["White"], value = { 1, 1, 1, 1 } },
  { key = "pink", name = L["Pink"], value = { 1, 0.4, 0.8, 1 } },
  { key = "grey", name = L["Grey"], value = { 0.5, 0.5, 0.5, 1 } },
}
local colorByKey, colorValues, colorOrder = {}, {}, {}
for _, c in ipairs(colors) do
  colorByKey[c.key] = c
  colorValues[c.key] = ("|cff%02x%02x%02x%s|r"):format(c.value[1] * 255, c.value[2] * 255, c.value[3] * 255, c.name)
  tinsert(colorOrder, c.key)
end
OptionsPrivate.SimpleColors = { list = colorValues, order = colorOrder, byKey = colorByKey }

local function colorKeyOf(value)
  if type(value) ~= "table" then return nil end
  for _, c in ipairs(colors) do
    local v = c.value
    if math.abs((value[1] or 0) - v[1]) < 0.02 and math.abs((value[2] or 0) - v[2]) < 0.02 and math.abs((value[3] or 0) - v[3]) < 0.02 then
      return c.key
    end
  end
  return "custom"
end

local function colorChoices()
  local list = {}
  for k, v in pairs(colorValues) do list[k] = v end
  list.custom = L["Custom (set in Advanced options)"]
  return list
end
local colorSorting = {}
for _, k in ipairs(colorOrder) do tinsert(colorSorting, k) end
tinsert(colorSorting, "custom")

local regionColorProperty = {
  icon = "color",
  aurabar = "barColor",
  progresstexture = "foregroundColor",
  text = "color",
  texture = "color",
}

local function copyColor(c)
  return { c[1], c[2], c[3], c[4] or 1 }
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function commit(data, rebuild)
  WeakAuras.Add(data)
  WeakAuras.UpdateThumbnail(data)
  OptionsPrivate.ResetMoverSizer()
  OptionsPrivate.Private.ScanForLoads({ [data.id] = true })
  if rebuild then
    WeakAuras.ClearAndUpdateOptions(data.id)
  end
end

local function soundChoices()
  local list = { none = L["No sound"] }
  for path, name in pairs(OptionsPrivate.Private.sound_file_types or {}) do
    list[path] = name
  end
  return list
end

local function soundSorting()
  local list = soundChoices()
  local order = {}
  for k in pairs(list) do
    if k ~= "none" then tinsert(order, k) end
  end
  sort(order, function(a, b) return list[a] < list[b] end)
  tinsert(order, 1, "none")
  return order
end

local function glowIndex(data)
  for index, sub in ipairs(data.subRegions or {}) do
    if sub.type == "subglow" then
      return index
    end
  end
end

local function ensureGlow(data)
  local index = glowIndex(data)
  if index then return index end
  data.subRegions = data.subRegions or {}
  local glow = { type = "subglow" }
  local glowType = OptionsPrivate.Private.subRegionTypes and OptionsPrivate.Private.subRegionTypes.subglow
  local defaults = glowType and glowType.default
  if type(defaults) == "function" then defaults = defaults(data.regionType) end
  if type(defaults) == "table" then
    for k, v in pairs(defaults) do
      glow[k] = type(v) == "table" and CopyTable(v) or v
    end
  end
  glow.glow = false
  tinsert(data.subRegions, glow)
  return #data.subRegions
end

--- what kind of trigger the simple tabs can handle
local function triggerKind(data)
  local triggers = data.triggers
  if not triggers or #triggers ~= 1 or not triggers[1].trigger then
    return nil
  end
  local t = triggers[1].trigger
  if t.type == "aura2" then
    if t.unit == "player" or t.unit == "target" or t.unit == "focus" or t.unit == "pet" then
      return "aura"
    end
    return nil
  elseif t.event == "Cooldown Progress (Spell)" then
    return "spellcd"
  elseif t.event == "Cooldown Progress (Item)" then
    return "itemcd"
  elseif t.event == "Action Usable" then
    return "usable"
  elseif t.event == "Health" then
    return "health"
  elseif t.event == "Power" then
    return "power"
  end
  return nil
end
OptionsPrivate.SimpleTriggerKind = triggerKind

local function supported(data)
  return not data.controlledChildren and type(data.id) == "string"
end

---------------------------------------------------------------------------
-- Mode
---------------------------------------------------------------------------

function OptionsPrivate.IsAdvancedMode()
  return WeakAurasOptionsSaved and WeakAurasOptionsSaved.simpleAdvanced and true or false
end

function OptionsPrivate.SetAdvancedMode(on)
  if WeakAurasOptionsSaved then
    WeakAurasOptionsSaved.simpleAdvanced = on and true or nil
  end
end

--- tabs for the editor of this aura
function OptionsPrivate.GetEditorTabs(data)
  if OptionsPrivate.IsAdvancedMode() or not supported(data) then
    local tabs = {
      { value = "region", text = L["Display"] },
      { value = "trigger", text = L["Trigger"] },
      { value = "conditions", text = L["Conditions"] },
      { value = "action", text = L["Actions"] },
      { value = "animation", text = L["Animations"] },
      { value = "load", text = L["Load"] },
      { value = "authorOptions", text = L["Custom Options"] },
      { value = "information", text = L["Information"] },
    }
    if data.controlledChildren and type(data.id) == "string" then
      tinsert(tabs, 1, { value = "group", text = L["Group"] })
    end
    return tabs
  end
  return {
    { value = "simpleLook", text = L["Look"] },
    { value = "simpleTrigger", text = L["Trigger"] },
    { value = "simpleEffects", text = L["Effects"] },
    { value = "simpleRules", text = L["Rules"] },
    { value = "simpleWhen", text = L["When"] },
  }
end

function OptionsPrivate.IsValidEditorTab(data, tab)
  for _, t in ipairs(OptionsPrivate.GetEditorTabs(data)) do
    if t.value == tab then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------

local textChoices = {
  aura = { ["%n"] = L["Name"], ["%p"] = L["Time left"], ["%s"] = L["Stacks"], ["%n %p"] = L["Name and time left"] },
  resource = { ["%p"] = L["Value"], ["%p / %t"] = L["Value / maximum"] },
}

function OptionsPrivate.GetSimpleLookOptions(data)
  local rt = data.regionType
  local args = {}
  local order = 0
  local function nextOrder() order = order + 1 return order end

  args.name = {
    type = "input",
    name = L["Aura name"],
    width = WeakAuras.doubleWidth,
    order = nextOrder(),
    get = function() return data.id end,
    set = function(_, newid)
      if newid and newid ~= "" and data.id ~= newid and not WeakAuras.GetData(newid) then
        WeakAuras.Rename(data, newid)
      end
    end,
  }

  -- size
  if rt == "icon" or rt == "progresstexture" then
    args.size = {
      type = "range", name = L["Size"], order = nextOrder(), width = WeakAuras.doubleWidth,
      min = 16, softMax = 256, max = 512, step = 1, bigStep = 2,
      get = function() return data.width end,
      set = function(_, v) data.width, data.height = v, v; commit(data) end,
    }
  elseif rt == "aurabar" then
    args.width = {
      type = "range", name = L["Width"], order = nextOrder(), width = WeakAuras.normalWidth,
      min = 20, softMax = 600, max = 2000, step = 1, bigStep = 5,
      get = function() return data.width end,
      set = function(_, v) data.width = v; commit(data) end,
    }
    args.height = {
      type = "range", name = L["Height"], order = nextOrder(), width = WeakAuras.normalWidth,
      min = 4, softMax = 80, max = 300, step = 1,
      get = function() return data.height end,
      set = function(_, v) data.height = v; commit(data) end,
    }
  elseif rt == "text" then
    args.fontSize = {
      type = "range", name = L["Font Size"], order = nextOrder(), width = WeakAuras.doubleWidth,
      min = 6, softMax = 72, max = 200, step = 1,
      get = function() return data.fontSize end,
      set = function(_, v) data.fontSize = v; commit(data) end,
    }
    local kind = triggerKind(data)
    local choices = (kind == "health" or kind == "power") and textChoices.resource or textChoices.aura
    args.displayText = {
      type = "select", name = L["The text shows"], order = nextOrder(), width = WeakAuras.doubleWidth,
      values = function()
        local list = {}
        for k, v in pairs(choices) do list[k] = v end
        if not choices[data.displayText] then list[data.displayText or ""] = L["Custom (set in Advanced options)"] end
        return list
      end,
      get = function() return data.displayText end,
      set = function(_, v) data.displayText = v; commit(data) end,
    }
  end

  -- color
  local colorProperty = regionColorProperty[rt]
  if colorProperty then
    args.color = {
      type = "select", name = rt == "icon" and L["Icon tint"] or L["Color"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = colorChoices, sorting = colorSorting,
      get = function() return colorKeyOf(data[colorProperty]) end,
      set = function(_, key)
        if colorByKey[key] then
          data[colorProperty] = copyColor(colorByKey[key].value)
          commit(data)
        end
      end,
    }
  end

  args.alpha = {
    type = "range", name = L["Visibility (%)"], order = nextOrder(), width = WeakAuras.normalWidth,
    min = 10, max = 100, step = 5,
    get = function() return math.floor((data.alpha or 1) * 100 + 0.5) end,
    set = function(_, v) data.alpha = v / 100; commit(data) end,
  }

  if rt == "icon" then
    args.cooldown = {
      type = "toggle", name = L["Show the clock swipe"], order = nextOrder(), width = WeakAuras.normalWidth,
      get = function() return data.cooldown end,
      set = function(_, v) data.cooldown = v; commit(data) end,
    }
    args.cooldownText = {
      type = "toggle", name = L["Show time numbers"], order = nextOrder(), width = WeakAuras.normalWidth,
      get = function() return not data.cooldownTextDisabled end,
      set = function(_, v) data.cooldownTextDisabled = not v; commit(data) end,
    }
  end

  -- glow
  if rt == "icon" or rt == "aurabar" then
    args.glowHeader = { type = "header", name = L["Glow"], order = nextOrder() }
    args.glow = {
      type = "toggle", name = L["Glow while shown"], order = nextOrder(), width = WeakAuras.normalWidth,
      desc = L["A glowing frame around it, good for procs."],
      get = function()
        local index = glowIndex(data)
        return index and data.subRegions[index].glow or false
      end,
      set = function(_, v)
        local index = ensureGlow(data)
        data.subRegions[index].glow = v
        commit(data, true)
      end,
    }
    args.glowColor = {
      type = "select", name = L["Glow color"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = function()
        local list = colorChoices()
        list.custom = nil
        list.default = L["Default"]
        return list
      end,
      sorting = function()
        local result = { "default" }
        for _, k in ipairs(colorOrder) do tinsert(result, k) end
        return result
      end,
      hidden = function()
        local index = glowIndex(data)
        return not (index and data.subRegions[index].glow)
      end,
      get = function()
        local index = glowIndex(data)
        local sub = index and data.subRegions[index]
        if not sub or not sub.useGlowColor then return "default" end
        local key = colorKeyOf(sub.glowColor)
        return key ~= "custom" and key or "default"
      end,
      set = function(_, key)
        local index = ensureGlow(data)
        local sub = data.subRegions[index]
        if colorByKey[key] then
          sub.useGlowColor = true
          sub.glowColor = copyColor(colorByKey[key].value)
        else
          sub.useGlowColor = false
        end
        commit(data)
      end,
    }
  end

  -- position
  args.positionHeader = { type = "header", name = L["Position"], order = nextOrder() }
  args.positionHint = {
    type = "description", order = nextOrder(), width = WeakAuras.doubleWidth, fontSize = "medium",
    name = L["You can also drag it with the mouse."],
  }
  args.xOffset = {
    type = "range", name = L["Left / right"], order = nextOrder(), width = WeakAuras.normalWidth,
    softMin = -1000, softMax = 1000, min = -4000, max = 4000, step = 1, bigStep = 10,
    get = function() return data.xOffset or 0 end,
    set = function(_, v) data.xOffset = v; commit(data) end,
  }
  args.yOffset = {
    type = "range", name = L["Down / up"], order = nextOrder(), width = WeakAuras.normalWidth,
    softMin = -600, softMax = 600, min = -4000, max = 4000, step = 1, bigStep = 10,
    get = function() return data.yOffset or 0 end,
    set = function(_, v) data.yOffset = v; commit(data) end,
  }
  args.center = {
    type = "execute", name = L["Move to screen center"], order = nextOrder(), width = WeakAuras.normalWidth,
    func = function()
      data.anchorFrameType = "SCREEN"
      data.anchorPoint = "CENTER"
      data.selfPoint = "CENTER"
      data.xOffset, data.yOffset = 0, 0
      commit(data)
    end,
  }

  return { type = "group", name = L["Look"], order = 1, args = args }
end

---------------------------------------------------------------------------
-- Trigger
---------------------------------------------------------------------------

local unitChoices = { player = L["Me"], target = L["My target"], focus = L["My focus"], pet = L["My pet"] }
local powerChoices = { [0] = MANA or "Mana", [1] = RAGE or "Rage", [2] = FOCUS or "Focus", [3] = ENERGY or "Energy", [4] = L["Combo points"], [6] = RUNIC_POWER or "Runic Power" }
local cooldownShow = { showAlways = L["Always"], showOnCooldown = L["Only while on cooldown"], showOnReady = L["Only when ready"] }

local function resolveSpellId(text)
  if not text or text == "" then return nil end
  local id = tonumber(text)
  if not id then
    local link = text:sub(1, 1) == "\124" and text or GetSpellLink(text)
    id = link and tonumber(link:match("spell:(%d+)"))
  end
  return id and GetSpellInfo(id) and id or nil
end

local function resolveItemId(text)
  if not text or text == "" then return nil end
  local id = tonumber(text)
  if not id then
    local _, link = GetItemInfo(text)
    id = link and tonumber(link:match("item:(%d+)"))
  end
  return id
end

local function percentGet(t, field)
  if t["use_" .. field] and type(t[field]) == "table" then
    return tonumber(t[field][1]) or 0
  end
  return 0
end

local function percentSet(t, field, v)
  if v and v > 0 then
    t["use_" .. field] = true
    t[field] = { tostring(v) }
    t[field .. "_operator"] = { "<=" }
  else
    t["use_" .. field] = nil
    t[field] = nil
    t[field .. "_operator"] = nil
  end
end

function OptionsPrivate.GetSimpleTriggerOptions(data)
  local args = {}
  local order = 0
  local function nextOrder() order = order + 1 return order end
  local kind = triggerKind(data)
  local t = kind and data.triggers[1].trigger

  if data.simpleAuto == "procs" then
    args.info = {
      type = "description", order = 1, width = WeakAuras.doubleWidth, fontSize = "medium",
      name = function()
        local Learning = OptionsPrivate.Private.Learning
        local count = Learning and #Learning.GetAutoProcIds() or 0
        return L["This is the automatic proc bar: it shows every proc in your learned list (%d now). New procs are added by themselves. To leave one out, right click it in the Choose... list and pick \"Hide from the automatic proc bar\"."]:format(count)
      end,
    }
    args.open = {
      type = "execute", name = L["Open the list"], order = 2, width = WeakAuras.normalWidth,
      func = function()
        OptionsPrivate.OpenPicker(OptionsPrivate.PickerCategories.proc, function() end, L["Your procs"])
      end,
    }
    return { type = "group", name = L["Trigger"], order = 1, args = args }
  end

  if not kind then
    args.info = {
      type = "description", order = 1, width = WeakAuras.doubleWidth, fontSize = "medium",
      name = L["This aura uses an advanced trigger. Turn on \"Advanced options\" at the top to edit it."],
    }
    return { type = "group", name = L["Trigger"], order = 1, args = args }
  end

  if kind == "aura" then
    args.debuffType = {
      type = "select", name = L["Buff or debuff"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = { HELPFUL = L["Buff"], HARMFUL = L["Debuff"] },
      get = function() return t.debuffType end,
      set = function(_, v) t.debuffType = v; commit(data) end,
    }
    args.unit = {
      type = "select", name = L["On whom"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = unitChoices,
      get = function() return t.unit end,
      set = function(_, v) t.unit = v; commit(data) end,
    }
    args.names = {
      type = "input", name = L["Aura name or spell ID (more names: separate with commas)"],
      order = nextOrder(), width = WeakAuras.normalWidth * 1.4,
      get = function()
        if t.useExactSpellId and t.auraspellids then
          local names = {}
          for _, id in ipairs(t.auraspellids) do
            tinsert(names, (GetSpellInfo(tonumber(id) or 0)) or tostring(id))
          end
          return table.concat(names, ", ")
        end
        return table.concat(t.auranames or {}, ", ")
      end,
      set = function(_, v)
        t.auranames = {}
        for name in tostring(v or ""):gmatch("[^,]+") do
          name = name:match("^%s*(.-)%s*$")
          if name ~= "" then tinsert(t.auranames, name) end
        end
        t.useName = true
        t.useExactSpellId = nil
        t.auraspellids = nil
        commit(data, true)
      end,
    }
    args.choose = {
      type = "execute", name = L["Choose..."], order = nextOrder(), width = WeakAuras.normalWidth * 0.6,
      desc = L["Pick from the buffs, debuffs and procs this character has had."],
      func = function()
        local cats = OptionsPrivate.PickerCategories
        local categories = t.unit == "target" and t.debuffType == "HARMFUL" and cats.myDot
                           or t.debuffType == "HARMFUL" and cats.debuffOnMe
                           or cats.anyBuff
        OptionsPrivate.OpenPicker(categories, function(entry)
          if entry.spellId then
            t.useName = false
            t.useExactSpellId = true
            t.auraspellids = { tostring(entry.spellId) }
            t.auranames = { entry.name }
          else
            t.useName = true
            t.useExactSpellId = nil
            t.auraspellids = nil
            t.auranames = { entry.name }
          end
          commit(data, true)
        end)
      end,
    }
    args.exactInfo = {
      type = "description", order = nextOrder(), width = WeakAuras.doubleWidth, fontSize = "medium",
      name = function()
        return "|cff00ff00" .. L["Exact match by spell ID: %s"]:format(table.concat(t.auraspellids or {}, ", ")) .. "|r"
      end,
      hidden = function() return not (t.useExactSpellId and t.auraspellids and #t.auraspellids > 0) end,
    }
    args.namesWarning = {
      type = "description", order = nextOrder(), width = WeakAuras.doubleWidth, fontSize = "medium",
      name = "|cffff4040" .. L["No name given: it would show ANY buff or debuff. Type a name or use Choose."] .. "|r",
      hidden = function()
        return (t.useName and t.auranames and #t.auranames > 0)
            or (t.useExactSpellId and t.auraspellids and #t.auraspellids > 0)
      end,
    }
    args.ownOnly = {
      type = "toggle", name = L["Only mine (cast by me)"], order = nextOrder(), width = WeakAuras.normalWidth,
      get = function() return t.ownOnly == true end,
      set = function(_, v) t.ownOnly = v and true or nil; commit(data) end,
    }
    args.showOn = {
      type = "select", name = L["Show it when the aura is"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = { showOnActive = L["There"], showOnMissing = L["Missing"], showAlways = L["Always (both)"] },
      get = function() return t.matchesShowOn or "showOnActive" end,
      set = function(_, v) t.matchesShowOn = v; commit(data) end,
    }
    args.stacks = {
      type = "range", name = L["Only from this many stacks (0 = any)"], order = nextOrder(), width = WeakAuras.doubleWidth,
      min = 0, softMax = 20, max = 100, step = 1,
      get = function() return t.useStacks and tonumber(t.stacks) or 0 end,
      set = function(_, v)
        if v > 0 then
          t.useStacks, t.stacksOperator, t.stacks = true, ">=", tostring(v)
        else
          t.useStacks, t.stacksOperator, t.stacks = nil, nil, nil
        end
        commit(data)
      end,
    }
  elseif kind == "spellcd" or kind == "usable" then
    args.spell = {
      type = "input", name = L["Spell name or spell ID"], order = nextOrder(), width = WeakAuras.normalWidth * 1.4,
      get = function()
        local name = t.spellName and GetSpellInfo(t.spellName)
        return name or (t.spellName and tostring(t.spellName)) or ""
      end,
      set = function(_, v)
        local id = resolveSpellId(v)
        if id then
          t.spellName = id
          commit(data, true)
        end
      end,
    }
    args.chooseSpell = {
      type = "execute", name = L["Choose..."], order = nextOrder(), width = WeakAuras.normalWidth * 0.6,
      func = function()
        OptionsPrivate.OpenPicker(kind == "usable" and OptionsPrivate.PickerCategories.usable or OptionsPrivate.PickerCategories.spells, function(entry)
          if entry.spellId then
            t.spellName = entry.spellId
            commit(data, true)
          end
        end)
      end,
    }
    args.spellCheck = {
      type = "description", order = nextOrder(), width = WeakAuras.doubleWidth, fontSize = "medium",
      name = function()
        local name, _, icon = t.spellName and GetSpellInfo(t.spellName)
        if name then
          return "|T" .. (icon or "") .. ":16|t |cff00ff00" .. name .. "|r"
        end
        return "|cffff4040" .. L["Unknown spell. It has to be in your spellbook, or use the spell ID."] .. "|r"
      end,
    }
    if kind == "spellcd" then
      args.showOn = {
        type = "select", name = L["Show it"], order = nextOrder(), width = WeakAuras.doubleWidth,
        values = cooldownShow,
        get = function() return t.genericShowOn or "showAlways" end,
        set = function(_, v)
          t.use_genericShowOn = true
          t.genericShowOn = v
          if v == "showOnReady" then
            t.use_track, t.track = true, "cooldown"
          end
          commit(data)
        end,
      }
    end
  elseif kind == "itemcd" then
    args.item = {
      type = "input", name = L["Item name or item ID"], order = nextOrder(), width = WeakAuras.normalWidth * 1.4,
      get = function()
        local name = t.itemName and GetItemInfo(t.itemName)
        return name or (t.itemName and tostring(t.itemName)) or ""
      end,
      set = function(_, v)
        local id = resolveItemId(v)
        if id then
          t.itemName = id
          commit(data, true)
        end
      end,
    }
    args.chooseItem = {
      type = "execute", name = L["Choose..."], order = nextOrder(), width = WeakAuras.normalWidth * 0.6,
      func = function()
        OptionsPrivate.OpenPicker(OptionsPrivate.PickerCategories.items, function(entry)
          if entry.itemId then
            t.itemName = entry.itemId
            commit(data, true)
          end
        end)
      end,
    }
    args.showOn = {
      type = "select", name = L["Show it"], order = nextOrder(), width = WeakAuras.doubleWidth,
      values = cooldownShow,
      get = function() return t.genericShowOn or "showAlways" end,
      set = function(_, v) t.use_genericShowOn = true; t.genericShowOn = v; commit(data) end,
    }
  elseif kind == "health" or kind == "power" then
    if kind == "power" then
      args.powertype = {
        type = "select", name = L["Power type"], order = nextOrder(), width = WeakAuras.normalWidth,
        values = powerChoices,
        get = function() return t.powertype end,
        set = function(_, v) t.use_powertype = true; t.powertype = v; commit(data) end,
      }
    end
    args.unit = {
      type = "select", name = L["Whose"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = { player = L["Me"], target = L["My target"], focus = L["My focus"], pet = L["My pet"] },
      get = function() return t.unit end,
      set = function(_, v) t.use_unit = true; t.unit = v; commit(data) end,
    }
    local field = kind == "health" and "percenthealth" or "percentpower"
    args.below = {
      type = "range", name = L["Only show below this % (0 = always)"], order = nextOrder(), width = WeakAuras.doubleWidth,
      min = 0, max = 100, step = 5,
      get = function() return percentGet(t, field) end,
      set = function(_, v) percentSet(t, field, v); commit(data) end,
    }
  end

  return { type = "group", name = L["Trigger"], order = 1, args = args }
end

---------------------------------------------------------------------------
-- Effects (animations + sound + chat message)
---------------------------------------------------------------------------

local appearChoices = {
  none = L["Nothing"], fade = L["Fade in"], shrink = L["Grow"], bounceDecay = L["Bounce"],
  slidetop = L["Slide from top"], slidebottom = L["Slide from bottom"], slideleft = L["Slide from left"], slideright = L["Slide from right"],
}
local appearSorting = { "none", "fade", "shrink", "bounceDecay", "slidetop", "slidebottom", "slideleft", "slideright" }
local mainChoices = {
  none = L["Nothing"], pulse = L["Pulse"], alphaPulse = L["Flash"], shake = L["Shake"], bounce = L["Bounce"], spin = L["Spin"],
}
local mainSorting = { "none", "pulse", "alphaPulse", "shake", "bounce", "spin" }
local disappearChoices = {
  none = L["Nothing"], fade = L["Fade out"], shrink = L["Shrink"],
  slidetop = L["Slide to top"], slidebottom = L["Slide to bottom"], slideleft = L["Slide to left"], slideright = L["Slide to right"],
}
local disappearSorting = { "none", "fade", "shrink", "slidetop", "slidebottom", "slideleft", "slideright" }
local chatChoices = {
  none = L["No message"], PRINT = L["Only for me (chat window)"], SAY = L["Say"], PARTY = L["Party"], RAID = L["Raid"],
  SMARTRAID = L["Raid, party or say (automatic)"],
}
local chatSorting = { "none", "PRINT", "SAY", "PARTY", "RAID", "SMARTRAID" }

local function animGet(data, phase)
  local anim = data.animation and data.animation[phase]
  if anim and anim.type == "preset" and anim.preset then
    return anim.preset
  elseif anim and anim.type == "custom" then
    return "custom"
  end
  return "none"
end

local function animSet(data, phase, preset)
  data.animation = data.animation or {}
  data.animation[phase] = data.animation[phase] or {}
  local anim = data.animation[phase]
  if preset == "none" then
    anim.type = "none"
  else
    anim.type = "preset"
    anim.preset = preset
  end
  anim.duration_type = anim.duration_type or "seconds"
  anim.easeType = anim.easeType or "none"
  anim.easeStrength = anim.easeStrength or 3
end

--- values/sorting for an animation select; "custom" only appears when the aura already has a custom animation
local function animValues(data, phase, list)
  return function()
    local result = {}
    for k, v in pairs(list) do result[k] = v end
    if animGet(data, phase) == "custom" then
      result.custom = L["Custom (set in Advanced options)"]
    end
    return result
  end
end

local function animSorting(data, phase, sorting)
  return function()
    local result = {}
    for _, k in ipairs(sorting) do tinsert(result, k) end
    if animGet(data, phase) == "custom" then
      tinsert(result, "custom")
    end
    return result
  end
end

function OptionsPrivate.GetSimpleEffectsOptions(data)
  local args = {}
  local order = 0
  local function nextOrder() order = order + 1 return order end
  data.actions = data.actions or {}
  data.actions.start = data.actions.start or {}
  data.actions.finish = data.actions.finish or {}
  local start, finish = data.actions.start, data.actions.finish

  args.animHeader = { type = "header", name = L["Animation"], order = nextOrder() }
  args.appear = {
    type = "select", name = L["When it appears"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = animValues(data, "start", appearChoices), sorting = animSorting(data, "start", appearSorting),
    get = function() return animGet(data, "start") end,
    set = function(_, v) if v ~= "custom" then animSet(data, "start", v); commit(data) end end,
  }
  args.main = {
    type = "select", name = L["While it is shown"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = animValues(data, "main", mainChoices), sorting = animSorting(data, "main", mainSorting),
    get = function() return animGet(data, "main") end,
    set = function(_, v) if v ~= "custom" then animSet(data, "main", v); commit(data) end end,
  }
  args.disappear = {
    type = "select", name = L["When it disappears"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = animValues(data, "finish", disappearChoices), sorting = animSorting(data, "finish", disappearSorting),
    get = function() return animGet(data, "finish") end,
    set = function(_, v) if v ~= "custom" then animSet(data, "finish", v); commit(data) end end,
  }

  args.soundHeader = { type = "header", name = L["Sound"], order = nextOrder() }
  args.startSound = {
    type = "select", name = L["Sound when it appears"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = soundChoices, sorting = soundSorting,
    get = function() return start.do_sound and start.sound or "none" end,
    set = function(_, v)
      if v == "none" then
        start.do_sound = false
      else
        start.do_sound, start.sound = true, v
        start.sound_channel = start.sound_channel or "Master"
        PlaySoundFile(v, "Master")
      end
      commit(data)
    end,
  }
  args.finishSound = {
    type = "select", name = L["Sound when it disappears"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = soundChoices, sorting = soundSorting,
    get = function() return finish.do_sound and finish.sound or "none" end,
    set = function(_, v)
      if v == "none" then
        finish.do_sound = false
      else
        finish.do_sound, finish.sound = true, v
        finish.sound_channel = finish.sound_channel or "Master"
        PlaySoundFile(v, "Master")
      end
      commit(data)
    end,
  }

  args.chatHeader = { type = "header", name = L["Chat message"], order = nextOrder() }
  args.chatType = {
    type = "select", name = L["Message when it appears"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = function()
      local list = {}
      for k, v in pairs(chatChoices) do list[k] = v end
      if start.do_message and start.message_type and not chatChoices[start.message_type] then
        list[start.message_type] = L["Custom (set in Advanced options)"]
      end
      return list
    end,
    sorting = function()
      local s = {}
      for _, k in ipairs(chatSorting) do tinsert(s, k) end
      if start.do_message and start.message_type and not chatChoices[start.message_type] then
        tinsert(s, start.message_type)
      end
      return s
    end,
    get = function() return start.do_message and start.message_type or "none" end,
    set = function(_, v)
      if v == "none" then
        start.do_message = false
      else
        start.do_message, start.message_type = true, v
      end
      commit(data, true)
    end,
  }
  args.chatText = {
    type = "input", name = L["Message text (%n = aura name)"], order = nextOrder(), width = WeakAuras.normalWidth,
    hidden = function() return not start.do_message end,
    get = function() return start.message or "" end,
    set = function(_, v) start.message = v; commit(data) end,
  }

  return { type = "group", name = L["Effects"], order = 1, args = args }
end

---------------------------------------------------------------------------
-- Rules (ready made conditions)
---------------------------------------------------------------------------

local actionChoices = {
  color = L["Change color"],
  grey = L["Grey it out"],
  fadeOut = L["Fade out (transparent)"],
  fadeIn = L["Fade in (fully visible)"],
  glow = L["Glow"],
}
local actionSorting = { "color", "grey", "fadeOut", "fadeIn", "glow" }

--- rule definitions per trigger kind
--- check(value) returns the WeakAuras condition check
local ruleSets = {
  aura = {
    { key = "remaining", name = L["Less than X seconds left"], unit = L["Seconds"], min = 1, max = 60, default = 3, action = "color", color = "red",
      check = function(v) return { trigger = 1, variable = "expirationTime", op = "<=", value = tostring(v) } end },
    { key = "stacks", name = L["At least X stacks"], unit = L["Stacks"], min = 1, max = 50, default = 3, action = "glow",
      check = function(v) return { trigger = 1, variable = "stacks", op = ">=", value = tostring(v) } end },
    { key = "missing", name = L["When the aura is missing"], action = "grey",
      check = function() return { trigger = 1, variable = "buffed", value = 0 } end },
  },
  spellcd = {
    { key = "onCooldown", name = L["While on cooldown"], action = "grey",
      check = function() return { trigger = 1, variable = "onCooldown", value = 1 } end },
    { key = "ready", name = L["When ready"], action = "glow",
      check = function() return { trigger = 1, variable = "onCooldown", value = 0 } end },
    { key = "noPower", name = L["Not enough power"], action = "color", color = "darkblue",
      check = function() return { trigger = 1, variable = "insufficientResources", value = 1 } end },
    { key = "range", name = L["Target out of range"], action = "color", color = "red",
      check = function() return { trigger = 1, variable = "spellInRange", value = 0 } end },
  },
  itemcd = {
    { key = "onCooldown", name = L["While on cooldown"], action = "grey",
      check = function() return { trigger = 1, variable = "onCooldown", value = 1 } end },
    { key = "ready", name = L["When ready"], action = "glow",
      check = function() return { trigger = 1, variable = "onCooldown", value = 0 } end },
  },
  usable = {
    { key = "range", name = L["Target out of range"], action = "color", color = "red",
      check = function() return { trigger = 1, variable = "spellInRange", value = 0 } end },
  },
  health = {
    { key = "below", name = L["Below X percent"], unit = "%", min = 5, max = 95, default = 35, action = "color", color = "red",
      check = function(v) return { trigger = 1, variable = "percenthealth", op = "<=", value = tostring(v) } end },
  },
  power = {
    { key = "below", name = L["Below X percent"], unit = "%", min = 5, max = 95, default = 30, action = "color", color = "red",
      check = function(v) return { trigger = 1, variable = "percentpower", op = "<=", value = tostring(v) } end },
  },
}

local function signature(t)
  if type(t) ~= "table" then return tostring(t) end
  local keys = {}
  for k in pairs(t) do tinsert(keys, k) end
  sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    tinsert(parts, tostring(k) .. "=" .. signature(t[k]))
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function conditionsAreOurs(data)
  if not data.conditions or #data.conditions == 0 then return true end
  return data.simpleRulesSig ~= nil and data.simpleRulesSig == signature(data.conditions)
end

local function buildChanges(data, rule, state)
  local rt = data.regionType
  local action = state.action or rule.action
  if action == "color" then
    local property = regionColorProperty[rt]
    local c = colorByKey[state.color or rule.color or "red"]
    if property and c then
      return { { property = property, value = copyColor(c.value) } }
    end
  elseif action == "grey" then
    if rt == "icon" then
      return { { property = "desaturate", value = true } }
    end
    local property = regionColorProperty[rt]
    if property then
      return { { property = property, value = copyColor(colorByKey.grey.value) } }
    end
  elseif action == "fadeOut" then
    return { { property = "alpha", value = 0.35 } }
  elseif action == "fadeIn" then
    return { { property = "alpha", value = 1 } }
  elseif action == "glow" then
    if rt == "icon" or rt == "aurabar" then
      local index = ensureGlow(data)
      return { { property = "sub." .. index .. ".glow", value = true } }
    end
    local property = regionColorProperty[rt]
    if property then
      return { { property = property, value = copyColor(colorByKey.yellow.value) } }
    end
  end
  return nil
end

local function rebuildConditions(data)
  local kind = triggerKind(data)
  local rules = kind and ruleSets[kind] or {}
  data.simpleRules = data.simpleRules or {}
  local conditions = {}
  for _, rule in ipairs(rules) do
    local state = data.simpleRules[rule.key]
    if state and state.enabled then
      local changes = buildChanges(data, rule, state)
      if changes then
        tinsert(conditions, { check = rule.check(state.value or rule.default), changes = changes })
      end
    end
  end
  data.conditions = conditions
  data.simpleRulesSig = signature(conditions)
end

function OptionsPrivate.GetSimpleRulesOptions(data)
  local args = {}
  local order = 0
  local function nextOrder() order = order + 1 return order end
  local kind = triggerKind(data)
  local rules = kind and ruleSets[kind]

  if not rules then
    args.info = {
      type = "description", order = 1, width = WeakAuras.doubleWidth, fontSize = "medium",
      name = L["There are no ready made rules for this kind of aura. Turn on \"Advanced options\" to use conditions."],
    }
    return { type = "group", name = L["Rules"], order = 1, args = args }
  end

  args.intro = {
    type = "description", order = nextOrder(), width = WeakAuras.doubleWidth, fontSize = "medium",
    name = L["Tick a rule to change how the aura looks in that situation."],
  }
  args.custom = {
    type = "description", order = nextOrder(), width = WeakAuras.doubleWidth, fontSize = "medium",
    name = "|cffffd100" .. L["This aura has its own conditions from the advanced editor. Changing a rule here replaces them."] .. "|r",
    hidden = function() return conditionsAreOurs(data) end,
  }

  data.simpleRules = data.simpleRules or {}
  for _, rule in ipairs(rules) do
    local function state()
      data.simpleRules[rule.key] = data.simpleRules[rule.key] or { enabled = false, value = rule.default, action = rule.action, color = rule.color }
      return data.simpleRules[rule.key]
    end
    local function changed()
      rebuildConditions(data)
      commit(data, true)
    end
    args[rule.key .. "Header"] = { type = "header", name = rule.name, order = nextOrder() }
    args[rule.key .. "Enabled"] = {
      type = "toggle", name = L["On"], order = nextOrder(), width = WeakAuras.halfWidth,
      get = function() return state().enabled end,
      set = function(_, v) state().enabled = v; changed() end,
    }
    if rule.min then
      args[rule.key .. "Value"] = {
        type = "range", name = rule.unit, order = nextOrder(), width = WeakAuras.normalWidth,
        min = rule.min, max = rule.max, step = 1,
        disabled = function() return not state().enabled end,
        get = function() return state().value or rule.default end,
        set = function(_, v) state().value = v; changed() end,
      }
    end
    args[rule.key .. "Action"] = {
      type = "select", name = L["Then"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = actionChoices, sorting = actionSorting,
      disabled = function() return not state().enabled end,
      get = function() return state().action or rule.action end,
      set = function(_, v) state().action = v; changed() end,
    }
    args[rule.key .. "Color"] = {
      type = "select", name = L["Color"], order = nextOrder(), width = WeakAuras.normalWidth,
      values = colorValues, sorting = colorOrder,
      hidden = function() return (state().action or rule.action) ~= "color" end,
      disabled = function() return not state().enabled end,
      get = function() return state().color or rule.color or "red" end,
      set = function(_, v) state().color = v; changed() end,
    }
  end

  return { type = "group", name = L["Rules"], order = 1, args = args }
end

---------------------------------------------------------------------------
-- When (load)
---------------------------------------------------------------------------

local whereChoices = {
  any = L["Anywhere"], world = L["Open world"], party = L["Dungeon"], raid = L["Raid"], pvp = L["Battleground"], arena = L["Arena"],
}
local whereSorting = { "any", "world", "party", "raid", "pvp", "arena" }
local whereSizes = {
  world = { none = true },
  party = { party = true },
  raid = { ten = true, twenty = true, twentyfive = true, fortyman = true },
  pvp = { pvp = true },
  arena = { arena = true },
}
local groupChoices = {
  any = L["Anywhere"], solo = L["Only when solo"], group = L["Only in a party"], raid = L["Only in a raid"], grouped = L["In a party or raid"],
}
local groupSorting = { "any", "solo", "group", "raid", "grouped" }

local function multiEquals(multi, wanted)
  if type(multi) ~= "table" then return false end
  for k, v in pairs(multi) do
    if v and not wanted[k] then return false end
  end
  for k in pairs(wanted) do
    if not multi[k] then return false end
  end
  return true
end

function OptionsPrivate.GetSimpleWhenOptions(data)
  local args = {}
  local order = 0
  local function nextOrder() order = order + 1 return order end
  data.load = data.load or {}
  local load = data.load
  local Grimfall = OptionsPrivate.Private.Grimfall

  args.combat = {
    type = "select", name = L["Combat"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = { always = L["Always"], combat = L["Only in combat"], noCombat = L["Only out of combat"] },
    sorting = { "always", "combat", "noCombat" },
    get = function()
      if load.use_combat == true then return "combat" elseif load.use_combat == false then return "noCombat" end
      return "always"
    end,
    set = function(_, v)
      load.use_combat = (v == "combat" and true) or (v == "noCombat" and false) or nil
      commit(data)
    end,
  }
  args.group = {
    type = "select", name = L["Group"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = function()
      local list = {}
      for k, v in pairs(groupChoices) do list[k] = v end
      return list
    end,
    sorting = groupSorting,
    get = function()
      if load.use_ingroup == nil then return "any" end
      local multi = load.ingroup and load.ingroup.multi
      if load.use_ingroup == true then
        return load.ingroup and load.ingroup.single or "any"
      end
      if multiEquals(multi, { group = true, raid = true }) then return "grouped" end
      for _, key in ipairs({ "solo", "group", "raid" }) do
        if multiEquals(multi, { [key] = true }) then return key end
      end
      return "any"
    end,
    set = function(_, v)
      if v == "any" then
        load.use_ingroup = nil
      else
        load.use_ingroup = false
        load.ingroup = { multi = {} }
        if v == "grouped" then
          load.ingroup.multi.group, load.ingroup.multi.raid = true, true
        else
          load.ingroup.multi[v] = true
        end
      end
      commit(data)
    end,
  }
  args.where = {
    type = "select", name = L["Where"], order = nextOrder(), width = WeakAuras.normalWidth,
    values = whereChoices, sorting = whereSorting,
    get = function()
      if load.use_size == nil then return "any" end
      local multi = load.size and load.size.multi
      for key, wanted in pairs(whereSizes) do
        if load.use_size == false and multiEquals(multi, wanted) then return key end
      end
      return "any"
    end,
    set = function(_, v)
      if v == "any" then
        load.use_size = nil
      else
        load.use_size = false
        load.size = { multi = CopyTable(whereSizes[v]) }
      end
      commit(data)
    end,
  }
  args.notMounted = {
    type = "toggle", name = L["Hide while mounted"], order = nextOrder(), width = WeakAuras.normalWidth,
    get = function() return load.use_mounted == false end,
    set = function(_, v) load.use_mounted = v and false or nil; commit(data) end,
  }
  args.notVehicle = {
    type = "toggle", name = L["Hide in vehicles"], order = nextOrder(), width = WeakAuras.normalWidth,
    get = function() return load.use_vehicle == false end,
    set = function(_, v) load.use_vehicle = v and false or nil; commit(data) end,
  }

  args.rolesHeader = { type = "header", name = L["Roles (none ticked = any role)"], order = nextOrder() }
  for _, role in ipairs(Grimfall.roles) do
    args["role_" .. role] = {
      type = "toggle", name = Grimfall.role_types[role], order = nextOrder(), width = WeakAuras.halfWidth * 1.3,
      get = function()
        return load.use_role == false and load.role and load.role.multi and load.role.multi[role] or false
      end,
      set = function(_, v)
        load.role = type(load.role) == "table" and load.role or {}
        load.role.multi = load.role.multi or {}
        load.role.multi[role] = v and true or nil
        load.use_role = next(load.role.multi) and false or nil
        commit(data)
      end,
    }
  end

  args.charHeader = { type = "header", name = L["Characters"], order = nextOrder() }
  args.allCharacters = {
    type = "toggle", name = L["On all my characters"], order = nextOrder(), width = WeakAuras.doubleWidth,
    get = function() return load.use_characters == nil end,
    set = function(_, v)
      if v then
        load.use_characters = nil
      else
        Grimfall.BindToCurrentCharacter(data)
      end
      commit(data, true)
    end,
  }
  args.characters = {
    type = "multiselect", name = L["Only on these characters"], order = nextOrder(), width = WeakAuras.doubleWidth,
    hidden = function() return load.use_characters == nil end,
    values = function() return Grimfall.GetCharacterList() end,
    get = function(_, key)
      return load.characters and load.characters.multi and load.characters.multi[key] or false
    end,
    set = function(_, key, v)
      load.characters = load.characters or { multi = {} }
      load.characters.multi = load.characters.multi or {}
      load.characters.multi[key] = v and true or nil
      load.use_characters = false
      commit(data)
    end,
  }

  return { type = "group", name = L["When"], order = 1, args = args }
end
