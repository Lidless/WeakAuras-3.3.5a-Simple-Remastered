if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- WeakAuras Simple Remastered Quick Setup
-- Grimfall & Classless compatible by Lidless
--
-- One page, read from top to bottom:
--   1. What to track   2. Details   3. How to show it   4. Where   5. When
-- A block only becomes active after everything above it is answered.
-- Changing an answer resets the blocks that depend on it (Where and When are
-- independent and keep their values). When a new block opens, the page scrolls
-- so that the block above it stays visible at the top.

local AceGUI = LibStub("AceGUI-3.0")

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local GetSpellInfo, GetSpellLink, GetItemInfo, GetItemIcon = GetSpellInfo, GetSpellLink, GetItemInfo, GetItemIcon
local tinsert, sort, pairs, ipairs, tonumber, tostring, max, min = tinsert, table.sort, pairs, ipairs, tonumber, tostring, math.max, math.min

local quickSetup

---------------------------------------------------------------------------
-- Choices
---------------------------------------------------------------------------

local categories = {
  list = {
    buff = L["Buff / Debuff"],
    proc = L["Proc (something pops up or lights up)"],
    cooldown = L["Cooldown"],
    resource = L["Resource (health, power, combo points)"],
  },
  order = { "buff", "proc", "cooldown", "resource" },
}

local detailTypes = {
  buff = {
    list = {
      myBuff = L["A buff on me"],
      debuffOnMe = L["A debuff on me"],
      myDebuffOnTarget = L["My debuff / DoT on my target"],
      buffOnTarget = L["A buff on my target"],
      missingBuff = L["A buff missing from me"],
    },
    order = { "myBuff", "debuffOnMe", "myDebuffOnTarget", "buffOnTarget", "missingBuff" },
  },
  cooldown = {
    list = {
      spell = L["Spell cooldown"],
      item = L["Item cooldown (trinket, potion)"],
    },
    order = { "spell", "item" },
  },
  proc = {
    list = {
      proc = L["A buff pops up on me (e.g. Shooting Stars, Clearcasting, Art of War)"],
      usable = L["An ability lights up (e.g. Overpower, Revenge, Victory Rush, Kill Shot)"],
    },
    order = { "proc", "usable" },
  },
  resource = {
    list = {
      health = L["Health"],
      power = L["Power (mana, rage, energy, runic power)"],
      combo = L["Combo points"],
    },
    order = { "health", "power", "combo" },
  },
}

local cooldownShowOn = {
  list = {
    showAlways = L["Always"],
    showOnCooldown = L["Only while on cooldown"],
    showOnReady = L["Only when ready"],
  },
  order = { "showAlways", "showOnCooldown", "showOnReady" },
}

local units = {
  list = { player = L["Me"], target = L["My target"], focus = L["My focus"] },
  order = { "player", "target", "focus" },
}

local powerTypes = {
  list = { [0] = MANA or "Mana", [1] = RAGE or "Rage", [3] = ENERGY or "Energy", [6] = RUNIC_POWER or "Runic Power", [2] = FOCUS or "Focus" },
  order = { 0, 1, 3, 6, 2 },
}

local displayTypes = {
  icon = L["Icon"],
  aurabar = L["Bar"],
  text = L["Text"],
  progresstexture = L["Circle"],
}
local displayOrder = {
  buff = { "icon", "aurabar", "text" },
  cooldown = { "icon", "aurabar", "text" },
  proc = { "icon", "aurabar", "text" },
  resource = { "aurabar", "progresstexture", "text" },
}

local sizes = {
  icon = { label = L["Size"], min = 24, max = 128, step = 2, default = 48 },
  aurabar = { label = L["Width"], min = 80, max = 400, step = 10, default = 200 },
  text = { label = L["Font Size"], min = 10, max = 40, step = 1, default = 20 },
  progresstexture = { label = L["Size"], min = 48, max = 256, step = 8, default = 96 },
}

local positions = {
  list = {
    center = L["Screen center"],
    above = L["Above my character"],
    below = L["Below my character"],
    left = L["Left of my character"],
    right = L["Right of my character"],
    top = L["Top of the screen"],
  },
  order = { "center", "above", "below", "left", "right", "top" },
  offsets = {
    center = { 0, 0 },
    above = { 0, 150 },
    below = { 0, -150 },
    left = { -220, 0 },
    right = { 220, 0 },
    top = { 0, 320 },
  },
}

local combatChoices = {
  list = { always = L["Always"], combat = L["Only in combat"], noCombat = L["Only out of combat"] },
  order = { "always", "combat", "noCombat" },
}

local groupChoices = {
  list = {
    any = L["Anywhere"],
    solo = L["Only when solo"],
    group = L["Only in a party"],
    raid = L["Only in a raid"],
    grouped = L["In a party or raid"],
  },
  order = { "any", "solo", "group", "raid", "grouped" },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function resolveSpell(text)
  if not text or text == "" then return nil end
  local id = tonumber(text)
  if not id then
    local link = text:sub(1, 1) == "\124" and text or GetSpellLink(text)
    id = link and tonumber(link:match("spell:(%d+)"))
  end
  if not id then return nil end
  local name, _, icon = GetSpellInfo(id)
  if not name then return nil end
  return id, name, icon
end

local function resolveItem(text)
  if not text or text == "" then return nil end
  local id = tonumber(text)
  if not id then
    local _, link = GetItemInfo(text)
    id = link and tonumber(link:match("item:(%d+)"))
  end
  if not id then return nil end
  local name = GetItemInfo(id)
  return id, name or tostring(id), GetItemIcon(id)
end

local function auraIcon(name)
  local id = tonumber(name)
  if id then
    local _, _, icon = GetSpellInfo(id)
    return icon
  end
  return WeakAuras.spellCache and WeakAuras.spellCache.GetIcon and WeakAuras.spellCache.GetIcon(name)
end

--- cooldowns and procs share the spell / item name handling
local function isCooldownLike(state)
  return state.category == "cooldown" or state.category == "proc"
end

local function needsName(state)
  if state.category == "buff" then return true end
  if isCooldownLike(state) then return true end
  return false
end

local function soundList()
  local list, order = { none = L["No sound"] }, {}
  for path, name in pairs(OptionsPrivate.Private.sound_file_types or {}) do
    list[path] = name
    tinsert(order, path)
  end
  sort(order, function(a, b) return list[a] < list[b] end)
  tinsert(order, 1, "none")
  return list, order
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function newState()
  return {
    -- block 1
    category = nil,
    -- block 2
    detail = nil,
    name = "",
    showOn = "showAlways",
    unit = "player",
    powerType = nil,
    below = 0,
    -- block 3
    display = nil,
    size = nil,
    color = nil,
    glow = false,
    sound = "none",
    -- block 4
    position = nil,
    -- block 5
    combat = "always",
    group = "any",
    roles = {},
    allCharacters = false,
    auraName = "",
    auraNameEdited = false,
  }
end

local function resetBlock2(state)
  state.detail = nil
  state.name = ""
  state.pickedId, state.pickedName = nil, nil
  state.showOn = "showAlways"
  state.unit = "player"
  state.powerType = UnitPowerType and UnitPowerType("player") or 0
  if not powerTypes.list[state.powerType] then state.powerType = 0 end
  state.below = 0
end

local function resetBlock2Details(state)
  state.name = ""
  state.pickedId, state.pickedName = nil, nil
  state.showOn = "showAlways"
  state.unit = "player"
  state.below = 0
end

local function resetBlock3(state)
  state.display = nil
  state.size = nil
  state.color = nil
  state.tooltipNumber, state.tooltipPercent = nil, nil
  state.glow = false
  state.sound = "none"
end

--- which blocks are answered
local function blockComplete(state, block)
  if block == 1 then
    return state.category ~= nil
  elseif block == 2 then
    if not state.detail then return false end
    if isCooldownLike(state) then
      if state.detail == "item" then
        return resolveItem(state.name) ~= nil
      elseif state.detail == "proc" then
        return state.name ~= ""
      else
        return resolveSpell(state.name) ~= nil
      end
    elseif state.category == "buff" then
      return state.name ~= ""
    end
    return true
  elseif block == 3 then
    return state.display ~= nil
  elseif block == 4 then
    return state.position ~= nil
  end
  return true
end

--- number of the last active block (1..5)
local function activeBlocks(state)
  local active = 1
  for block = 1, 4 do
    if blockComplete(state, block) then
      active = block + 1
    else
      break
    end
  end
  return active
end

local function defaultAuraName(state)
  local base
  if state.category == "resource" then
    if state.detail == "power" then
      base = powerTypes.list[state.powerType] or L["Power"]
    else
      base = detailTypes.resource.list[state.detail] or L["Resource"]
    end
    if state.detail ~= "combo" and state.unit ~= "player" then
      base = base .. " (" .. (units.list[state.unit] or state.unit) .. ")"
    end
  else
    local display = state.name
    if isCooldownLike(state) then
      if state.detail == "item" then
        local _, itemName = resolveItem(state.name)
        display = itemName or display
      elseif state.detail ~= "proc" then
        local _, spellName = resolveSpell(state.name)
        display = spellName or display
      end
    end
    base = display ~= "" and display or L["New Aura"]
    if state.detail == "missingBuff" then
      base = base .. " " .. L["(missing)"]
    elseif state.category == "proc" then
      base = base .. " " .. L["(proc)"]
    elseif isCooldownLike(state) and (state.detail == "spell" or state.detail == "item") then
      base = base .. " " .. L["(cooldown)"]
    end
  end
  return base
end

---------------------------------------------------------------------------
-- Aura data
---------------------------------------------------------------------------

local regionColorProperty = { icon = "color", aurabar = "barColor", text = "color", progresstexture = "foregroundColor" }
local powerColors = { [0] = "darkblue", [1] = "red", [2] = "orange", [3] = "yellow", [6] = "lightblue" }

local function defaultColor(state)
  if state.display == "icon" then
    return "white" -- no tint
  end
  if state.category == "resource" then
    if state.detail == "health" then return "green" end
    if state.detail == "combo" then return "orange" end
    return powerColors[state.powerType] or "darkblue"
  end
  return "yellow"
end

local function buildTrigger(state)
  local c, d = state.category, state.detail
  if c == "buff" or (c == "proc" and d == "proc") then
    local trigger = {
      type = "aura2",
      useName = true,
      auranames = {},
      unitExists = false,
    }
    for name in tostring(state.name):gmatch("[^,]+") do
      name = name:match("^%s*(.-)%s*$")
      if name ~= "" then tinsert(trigger.auranames, name) end
    end
    -- picked from the list: match the exact spell ID (custom Grimfall auras can share names)
    if state.pickedId and state.pickedName == state.name then
      trigger.useName = false
      trigger.useExactSpellId = true
      trigger.auraspellids = { tostring(state.pickedId) }
    end
    if c == "proc" or d == "myBuff" then
      trigger.unit, trigger.debuffType, trigger.matchesShowOn = "player", "HELPFUL", "showOnActive"
    elseif d == "debuffOnMe" then
      trigger.unit, trigger.debuffType, trigger.matchesShowOn = "player", "HARMFUL", "showOnActive"
    elseif d == "myDebuffOnTarget" then
      trigger.unit, trigger.debuffType, trigger.matchesShowOn, trigger.ownOnly = "target", "HARMFUL", "showOnActive", true
    elseif d == "buffOnTarget" then
      trigger.unit, trigger.debuffType, trigger.matchesShowOn = "target", "HELPFUL", "showOnActive"
    elseif d == "missingBuff" then
      trigger.unit, trigger.debuffType, trigger.matchesShowOn = "player", "HELPFUL", "showOnMissing"
    end
    return trigger
  elseif c == "cooldown" or c == "proc" then
    if d == "item" then
      local itemId = resolveItem(state.name)
      return {
        type = WeakAuras.GetTriggerCategoryFor("Cooldown Progress (Item)"),
        event = "Cooldown Progress (Item)",
        itemName = itemId,
        use_genericShowOn = true,
        genericShowOn = state.showOn,
      }
    elseif d == "usable" then
      local spellId = resolveSpell(state.name)
      return {
        type = WeakAuras.GetTriggerCategoryFor("Action Usable"),
        event = "Action Usable",
        spellName = spellId,
      }
    else
      local spellId = resolveSpell(state.name)
      local trigger = {
        type = WeakAuras.GetTriggerCategoryFor("Cooldown Progress (Spell)"),
        event = "Cooldown Progress (Spell)",
        spellName = spellId,
        use_genericShowOn = true,
        genericShowOn = state.showOn,
      }
      if state.showOn == "showOnReady" then
        trigger.use_track = true
        trigger.track = "cooldown"
      end
      return trigger
    end
  elseif c == "resource" then
    if d == "health" then
      local trigger = {
        type = WeakAuras.GetTriggerCategoryFor("Health"),
        event = "Health",
        use_unit = true,
        unit = state.unit,
      }
      if state.below and state.below > 0 then
        trigger.use_percenthealth = true
        trigger.percenthealth = { tostring(state.below) }
        trigger.percenthealth_operator = { "<=" }
      end
      return trigger
    else
      local trigger = {
        type = WeakAuras.GetTriggerCategoryFor("Power"),
        event = "Power",
        use_unit = true,
        unit = d == "combo" and "player" or state.unit,
        use_powertype = true,
        powertype = d == "combo" and 4 or state.powerType,
      }
      if d ~= "combo" and state.below and state.below > 0 then
        trigger.use_percentpower = true
        trigger.percentpower = { tostring(state.below) }
        trigger.percentpower_operator = { "<=" }
      end
      return trigger
    end
  end
end

local function buildAuraData(state)
  local data = {
    id = OptionsPrivate.Private.FindUnusedId(state.auraName ~= "" and state.auraName or defaultAuraName(state)),
    regionType = state.display,
    triggers = {
      { trigger = buildTrigger(state), untrigger = {} },
    },
    load = {},
    actions = { init = {}, start = {}, finish = {} },
  }

  -- size
  local size = state.size or sizes[state.display].default
  if state.display == "icon" or state.display == "progresstexture" then
    data.width, data.height = size, size
  elseif state.display == "aurabar" then
    data.width, data.height = size, 18
    data.icon = state.category ~= "resource"
  elseif state.display == "text" then
    data.fontSize = size
    data.selfPoint = "CENTER"
    if state.category == "resource" then
      data.displayText = state.detail == "combo" and "%p" or "%p / %t"
    else
      data.displayText = "%n %p"
    end
  end

  -- position (you can drag it afterwards)
  local offset = positions.offsets[state.position] or { 0, 0 }
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = data.selfPoint or "CENTER"
  data.xOffset, data.yOffset = offset[1], offset[2]

  -- color
  local colors = OptionsPrivate.SimpleColors
  local colorKey = state.color or defaultColor(state)
  local property = regionColorProperty[state.display]
  if property and colors and colors.byKey[colorKey] then
    local c = colors.byKey[colorKey].value
    data[property] = { c[1], c[2], c[3], c[4] or 1 }
  end

  -- every new aura fades in and out (most people want this anyway)
  data.animation = {
    start = { type = "preset", preset = "fade", duration_type = "seconds", easeType = "none", easeStrength = 3 },
    main = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
    finish = { type = "preset", preset = "fade", duration_type = "seconds", easeType = "none", easeStrength = 3 },
  }

  -- glow
  if state.glow and (state.display == "icon" or state.display == "aurabar") then
    local glow = { type = "subglow" }
    local glowType = OptionsPrivate.Private.subRegionTypes and OptionsPrivate.Private.subRegionTypes.subglow
    local defaults = glowType and glowType.default
    if type(defaults) == "function" then defaults = defaults(state.display) end
    if type(defaults) == "table" then
      for k, v in pairs(defaults) do glow[k] = v end
    end
    glow.glow = true
    data.subRegions = { glow }
  end

  -- number from the tooltip (shield left), as text and / or as the fill of the bar
  if state.tooltipNumber or state.tooltipPercent then
    local trigger = data.triggers[1].trigger
    if trigger.type == "aura2" then
      trigger.fetchTooltip = true
      if state.tooltipPercent and state.display ~= "text" then
        data.progressSource = { 1, "tooltip1Left" }
      end
      if state.tooltipNumber then
        if state.display == "text" then
          data.displayText = "%n %tooltip1"
        else
          data.subRegions = data.subRegions or {}
          tinsert(data.subRegions, OptionsPrivate.SimpleTooltipText(state.display))
        end
      end
    end
  end

  -- sound
  if state.sound and state.sound ~= "none" then
    data.actions.start.do_sound = true
    data.actions.start.sound = state.sound
    data.actions.start.sound_channel = "Master"
  end

  -- when
  if state.combat == "combat" then
    data.load.use_combat = true
  elseif state.combat == "noCombat" then
    data.load.use_combat = false
  end
  if state.group ~= "any" then
    data.load.use_ingroup = false
    data.load.ingroup = { multi = {} }
    if state.group == "grouped" then
      data.load.ingroup.multi.group = true
      data.load.ingroup.multi.raid = true
    else
      data.load.ingroup.multi[state.group] = true
    end
  end
  local anyRole = false
  for _, chosen in pairs(state.roles) do
    if chosen then anyRole = true end
  end
  if anyRole then
    data.load.use_role = false
    data.load.role = { multi = {} }
    for role, chosen in pairs(state.roles) do
      if chosen then data.load.role.multi[role] = true end
    end
  end
  if state.allCharacters then
    data.grimfallSkipBinding = true
  end

  return data
end

---------------------------------------------------------------------------
-- View
---------------------------------------------------------------------------

local function CreateQuickSetup(frame)
  local view = AceGUI:Create("InlineGroup")
  view.frame:SetParent(frame)
  view.frame:SetFrameLevel(frame:GetFrameLevel() + 1)
  view.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 42)
  view.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -50)
  view.frame:Hide()
  view:SetLayout("fill")

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("flow")
  local scrollStatus = { scrollvalue = 0 }
  scroll:SetStatusTable(scrollStatus)
  view:AddChild(scroll)

  view.state = newState()
  view.blocks = {}
  view.widgets = {}
  view.lastActive = 1

  -- one frame delay helper (no C_Timer in 3.3.5)
  local delayFrame = CreateFrame("Frame")
  delayFrame:Hide()
  delayFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    if self.func then
      local func = self.func
      self.func = nil
      func()
    end
  end)
  local function nextFrame(func)
    delayFrame.func = func
    delayFrame:Show()
  end

  --- scroll so that the block above the newly opened one is at the top,
  --- never all the way to the new block itself, and never backwards
  local function scrollToBlock(index)
    nextFrame(function()
      local block = view.blocks[index]
      local previous = view.blocks[index - 1]
      if not block or not previous or not scroll.scrollBarShown then return end
      local contentTop = scroll.content:GetTop()
      local viewHeight = scroll.scrollframe:GetHeight()
      local contentHeight = scroll.content:GetHeight()
      if not contentTop or not viewHeight or not contentHeight then return end
      local maxOffset = contentHeight - viewHeight
      if maxOffset <= 0 then return end
      local previousOffset = contentTop - (previous.frame:GetTop() or contentTop)
      local blockOffset = contentTop - (block.frame:GetTop() or contentTop)
      local blockBottom = blockOffset + (block.frame:GetHeight() or 0)
      local current = scrollStatus.offset or 0
      -- already fully visible: leave the page alone
      if blockOffset >= current and blockBottom <= current + viewHeight then return end
      -- keep the block above visible, but don't let the new block start below the middle
      local target = max(previousOffset - 4, blockOffset - viewHeight * 0.5)
      target = min(target, maxOffset)
      if target <= current then return end
      scroll.scrollbar:SetValue(target / maxOffset * 1000)
    end)
  end

  local function setBlockEnabled(index, enabled)
    local block = view.blocks[index]
    if not block then return end
    if block.titletext then
      if enabled then
        block.titletext:SetTextColor(1, 0.82, 0)
      else
        block.titletext:SetTextColor(0.5, 0.5, 0.5)
      end
    end
    for _, widget in ipairs(block.quickWidgets or {}) do
      if widget.SetDisabled then
        widget:SetDisabled(not enabled)
      end
      if widget.type == "Label" and widget.SetColor then
        if enabled then
          widget:SetColor(1, 1, 1)
        else
          widget:SetColor(0.5, 0.5, 0.5)
        end
      end
    end
  end

  --- updates enabled states and hint texts without rebuilding (keeps the edit box focus)
  local function refresh()
    local state = view.state
    local active = activeBlocks(state)
    for index = 1, 5 do
      setBlockEnabled(index, index <= active)
    end
    if view.nameHint then
      view.nameHint:SetText(view.nameHintText and view.nameHintText() or "")
    end
    if view.auraNameBox and not state.auraNameEdited then
      state.auraName = defaultAuraName(state)
      view.auraNameBox:SetText(state.auraName)
    end
    if view.createButton then
      view.createButton:SetDisabled(active < 5)
    end
    if active > view.lastActive then
      scrollToBlock(active)
    end
    view.lastActive = active
  end

  local rebuild

  -- widget factories
  local function addBlock(index, title)
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(title)
    group:SetFullWidth(true)
    group:SetLayout("flow")
    group.quickWidgets = {}
    view.blocks[index] = group
    scroll:AddChild(group)
    return group
  end

  local function track(block, widget)
    tinsert(block.quickWidgets, widget)
    block:AddChild(widget)
    return widget
  end

  local function dropdown(block, label, choices, value, onChange, width)
    local widget = AceGUI:Create("Dropdown")
    widget:SetLabel(label)
    widget:SetList(choices.list, choices.order)
    if value ~= nil then
      widget:SetValue(value)
    else
      widget:SetText(L["Choose..."])
    end
    widget:SetRelativeWidth(width or 0.48)
    widget:SetCallback("OnValueChanged", function(_, _, key)
      onChange(key)
    end)
    return track(block, widget)
  end

  local function editbox(block, label, text, onChange, width)
    local widget = AceGUI:Create("EditBox")
    widget:SetLabel(label)
    widget:SetText(text or "")
    widget:DisableButton(true)
    widget:SetRelativeWidth(width or 0.48)
    widget:SetCallback("OnTextChanged", function(_, _, value)
      onChange(value)
      refresh()
    end)
    widget:SetCallback("OnEnterPressed", function(self, _, value)
      onChange(value)
      self:ClearFocus()
      refresh()
    end)
    return track(block, widget)
  end

  local function checkbox(block, label, value, onChange, width)
    local widget = AceGUI:Create("CheckBox")
    widget:SetLabel(label)
    widget:SetValue(value and true or false)
    widget:SetRelativeWidth(width or 0.32)
    widget:SetCallback("OnValueChanged", function(_, _, checked)
      onChange(checked)
      refresh()
    end)
    return track(block, widget)
  end

  local function slider(block, label, minValue, maxValue, step, value, onChange, width)
    local widget = AceGUI:Create("Slider")
    widget:SetLabel(label)
    widget:SetSliderValues(minValue, maxValue, step)
    widget:SetValue(value)
    widget:SetRelativeWidth(width or 0.48)
    widget:SetCallback("OnValueChanged", function(_, _, v)
      onChange(v)
    end)
    return track(block, widget)
  end

  local function label(block, text, width)
    local widget = AceGUI:Create("Label")
    widget:SetText(text)
    widget:SetRelativeWidth(width or 1)
    return track(block, widget)
  end

  -- page
  rebuild = function()
    local state = view.state
    scroll:PauseLayout()
    scroll:ReleaseChildren()
    view.blocks = {}
    view.nameHint, view.nameHintText, view.auraNameBox, view.createButton = nil, nil, nil, nil

    -- 1. What to track
    local block1 = addBlock(1, L["1. What should be tracked?"])
    dropdown(block1, L["Category"], categories, state.category, function(key)
      if key == state.category then return end
      state.category = key
      resetBlock2(state)
      resetBlock3(state)
      state.auraNameEdited = false
      rebuild()
    end, 1)

    -- 2. Details
    local block2 = addBlock(2, L["2. Details"])
    if not state.category then
      label(block2, L["Choose a category first."])
    else
      local types = detailTypes[state.category]
      dropdown(block2, L["Type"], types, state.detail, function(key)
        if key == state.detail then return end
        state.detail = key
        resetBlock2Details(state)
        resetBlock3(state)
        state.auraNameEdited = false
        rebuild()
      end, 1)

      if state.detail then
        if needsName(state) then
          local nameLabel
          if state.category == "buff" or state.detail == "proc" then
            nameLabel = L["Aura name or spell ID (more names: separate with commas)"]
          elseif state.detail == "item" then
            nameLabel = L["Item name or item ID"]
          else
            nameLabel = L["Spell name or spell ID"]
          end
          editbox(block2, nameLabel, state.name, function(value)
            state.name = value or ""
          end, 0.7)
          -- picker: choose from what this character has (learned auras, spellbook, items)
          local pickerCategories
          local cats = OptionsPrivate.PickerCategories or {}
          if state.detail == "item" then
            pickerCategories = cats.items
          elseif state.detail == "spell" then
            pickerCategories = cats.spells
          elseif state.detail == "usable" then
            pickerCategories = cats.usable
          elseif state.detail == "proc" then
            pickerCategories = cats.proc
          elseif state.detail == "debuffOnMe" then
            pickerCategories = cats.debuffOnMe
          elseif state.detail == "myDebuffOnTarget" then
            pickerCategories = cats.myDot
          elseif state.detail == "buffOnTarget" then
            pickerCategories = cats.buffOnTarget
          elseif state.detail == "missingBuff" then
            pickerCategories = cats.missing
          else
            pickerCategories = cats.myBuff
          end
          if pickerCategories and OptionsPrivate.OpenPicker then
            local chooseButton = AceGUI:Create("Button")
            chooseButton:SetText(L["Choose..."])
            chooseButton:SetRelativeWidth(0.28)
            chooseButton:SetCallback("OnClick", function()
              OptionsPrivate.OpenPicker(pickerCategories, function(entry)
                if entry.itemId then
                  state.name = tostring(entry.itemId)
                  state.pickedId, state.pickedName = nil, nil
                elseif isCooldownLike(state) and state.detail ~= "proc" then
                  state.name = tostring(entry.spellId or entry.name)
                  state.pickedId, state.pickedName = nil, nil
                else
                  state.name = entry.name or ""
                  state.pickedId, state.pickedName = entry.spellId, entry.name
                end
                state.auraNameEdited = false
                rebuild()
              end)
            end)
            track(block2, chooseButton)
          end
          view.nameHintText = function()
            if state.name == "" then
              return "|cff999999" .. L["Type the name, then press Enter."] .. "|r"
            end
            if state.detail == "item" then
              local _, itemName, icon = resolveItem(state.name)
              if itemName then
                return "|T" .. (icon or "") .. ":16|t |cff00ff00" .. itemName .. "|r"
              end
              return "|cffff4040" .. L["Unknown item. Use the item ID, or put the item in your bags first."] .. "|r"
            elseif isCooldownLike(state) and state.detail ~= "proc" then
              local _, spellName, icon = resolveSpell(state.name)
              if spellName then
                return "|T" .. (icon or "") .. ":16|t |cff00ff00" .. spellName .. "|r"
              end
              return "|cffff4040" .. L["Unknown spell. It has to be in your spellbook, or use the spell ID."] .. "|r"
            else
              if state.pickedId and state.pickedName == state.name then
                local _, _, pickedIcon = GetSpellInfo(state.pickedId)
                return "|T" .. (pickedIcon or "") .. ":16|t |cff00ff00" .. L["OK, exact match by spell ID %d"]:format(state.pickedId) .. "|r"
              end
              local icon = auraIcon(state.name:match("^%s*([^,]-)%s*,") or state.name)
              if icon then
                return "|T" .. icon .. ":16|t |cff00ff00" .. L["OK"] .. "|r"
              end
              return "|cffffd100" .. L["OK (not seen yet, the name has to match exactly)"] .. "|r"
            end
          end
          view.nameHint = label(block2, view.nameHintText())
        end

        if isCooldownLike(state) and (state.detail == "spell" or state.detail == "item") then
          dropdown(block2, L["Show it"], cooldownShowOn, state.showOn, function(key)
            state.showOn = key
            refresh()
          end, 1)
        end

        if state.category == "resource" then
          if state.detail == "power" then
            dropdown(block2, L["Power type"], powerTypes, state.powerType, function(key)
              state.powerType = key
              refresh()
            end)
          end
          if state.detail ~= "combo" then
            dropdown(block2, L["Whose"], units, state.unit, function(key)
              state.unit = key
              refresh()
            end)
            slider(block2, L["Only show below this % (0 = always)"], 0, 100, 5, state.below, function(v)
              state.below = v
            end, 1)
          end
        end
      end
    end

    -- 3. How to show it
    local block3 = addBlock(3, L["3. How should it look?"])
    local displayChoices = { list = {}, order = {} }
    for _, key in ipairs(displayOrder[state.category or "buff"]) do
      displayChoices.list[key] = displayTypes[key]
      tinsert(displayChoices.order, key)
    end
    dropdown(block3, L["Display"], displayChoices, state.display, function(key)
      if key == state.display then return end
      state.display = key
      state.size = sizes[key].default
      state.color = nil
      -- procs glow by default, that is what makes them easy to notice
      state.glow = state.category == "proc" and (key == "icon" or key == "aurabar")
      rebuild()
    end, 1)
    if state.display then
      local s = sizes[state.display]
      slider(block3, s.label, s.min, s.max, s.step, state.size or s.default, function(v)
        state.size = v
      end)
      local colors = OptionsPrivate.SimpleColors
      if colors then
        dropdown(block3, state.display == "icon" and L["Icon tint"] or L["Color"], colors, state.color or defaultColor(state), function(key)
          state.color = key
        end)
      end
      local sounds, soundOrder = soundList()
      dropdown(block3, L["Sound when it appears"], { list = sounds, order = soundOrder }, state.sound, function(key)
        state.sound = key
        if key ~= "none" and PlaySoundFile then
          PlaySoundFile(key, "Master")
        end
      end)
      if state.display == "icon" or state.display == "aurabar" then
        checkbox(block3, L["Glow while shown"], state.glow, function(v)
          state.glow = v
        end, 1)
      end
      -- shields and other buffs with a number in their tooltip (e.g. "Absorbing 241 damage")
      local isAura = state.category == "buff" or (state.category == "proc" and state.detail == "proc")
      if isAura and state.detail ~= "missingBuff" then
        checkbox(block3, L["Show the number from its tooltip (e.g. shield left)"], state.tooltipNumber, function(v)
          state.tooltipNumber = v
        end, 1)
        if state.display ~= "text" then
          checkbox(block3, L["Fill it by that number (% of its starting value)"], state.tooltipPercent, function(v)
            state.tooltipPercent = v
          end, 1)
        end
      end
    end

    -- 4. Where
    local block4 = addBlock(4, L["4. Where should it be?"])
    dropdown(block4, L["Position"], positions, state.position, function(key)
      state.position = key
      refresh()
    end, 1)
    label(block4, "|cff999999" .. L["After creating it you can drag it anywhere with the mouse."] .. "|r")

    -- 5. When
    local block5 = addBlock(5, L["5. When should it be active?"])
    dropdown(block5, L["Combat"], combatChoices, state.combat, function(key)
      state.combat = key
    end)
    dropdown(block5, L["Group"], groupChoices, state.group, function(key)
      state.group = key
    end)
    label(block5, L["Only for these roles (none checked = any role):"])
    for _, role in ipairs(OptionsPrivate.Private.Grimfall.roles) do
      checkbox(block5, OptionsPrivate.Private.Grimfall.role_types[role], state.roles[role], function(v)
        state.roles[role] = v and true or nil
      end, 0.32)
    end
    checkbox(block5, L["On all my characters (default: only this character)"], state.allCharacters, function(v)
      state.allCharacters = v
    end, 1)
    view.auraNameBox = editbox(block5, L["Aura name"], state.auraName, function(value)
      state.auraName = value or ""
      state.auraNameEdited = state.auraName ~= ""
    end, 1)
    local createButton = AceGUI:Create("Button")
    createButton:SetText(L["Create"])
    createButton:SetRelativeWidth(0.5)
    createButton:SetCallback("OnClick", function()
      view:Create()
    end)
    track(block5, createButton)
    view.createButton = createButton

    scroll:ResumeLayout()
    scroll:DoLayout()
    refresh()
  end

  -- buttons at the bottom
  local cancel = CreateFrame("Button", nil, view.frame, "UIPanelButtonTemplate")
  cancel:SetFrameLevel(view.frame:GetFrameLevel() + 1)
  cancel:SetScript("OnClick", function() view:CancelClose() end)
  cancel:SetPoint("BOTTOMRIGHT", -27, -23)
  cancel:SetHeight(20)
  cancel:SetWidth(100)
  cancel:SetText(L["Cancel"])

  local restart = CreateFrame("Button", nil, view.frame, "UIPanelButtonTemplate")
  restart:SetFrameLevel(view.frame:GetFrameLevel() + 1)
  restart:SetScript("OnClick", function()
    view.state = newState()
    view.lastActive = 1
    scrollStatus.scrollvalue = 0
    scrollStatus.offset = 0
    rebuild()
    scroll:SetScroll(0)
  end)
  restart:SetPoint("BOTTOMRIGHT", -147, -23)
  restart:SetHeight(20)
  restart:SetWidth(100)
  restart:SetText(L["Start Over"])

  function view.Open(self, targetId)
    frame.window = "quickSetup"
    self.targetId = targetId
    self.state = newState()
    self.lastActive = 1
    scrollStatus.scrollvalue = 0
    scrollStatus.offset = 0
    frame:UpdateFrameVisible()
    rebuild()
    scroll:SetScroll(0)
  end

  function view.CancelClose(self)
    frame.window = "default"
    frame:UpdateFrameVisible()
    frame:NewAura()
  end

  function view.Create(self)
    local state = self.state
    if activeBlocks(state) < 5 then return end
    local data = buildAuraData(state)
    local targetId = self.targetId
    frame.window = "default"
    frame:UpdateFrameVisible()
    WeakAuras.NewAura(data, data.regionType, targetId)
    -- bars with a shield number: number left, time right, no name on top of them
    if state.tooltipNumber and data.regionType == "aurabar" and OptionsPrivate.SimpleArrangeShieldTexts then
      local created = WeakAuras.GetData(data.id)
      if created then
        OptionsPrivate.SimpleArrangeShieldTexts(created, true)
        WeakAuras.Add(created)
        WeakAuras.ClearAndUpdateOptions(created.id)
      end
    end
    WeakAuras.prettyPrint(L["Aura created. Drag it to its place with the mouse, then fine tune it here if you like."])
  end

  return view
end

function OptionsPrivate.QuickSetup(frame, noConstruct)
  quickSetup = quickSetup or (not noConstruct and CreateQuickSetup(frame))
  return quickSetup
end

---------------------------------------------------------------------------
-- Automatic proc bar: one bar that shows every proc of the learned list
---------------------------------------------------------------------------

local function boundToCurrent(data)
  local load = data.load
  if not load or load.use_characters == nil then return true end
  local key = OptionsPrivate.Private.Grimfall.CharacterKey()
  return key and load.characters and load.characters.multi and load.characters.multi[key] or false
end

function OptionsPrivate.CreateAutoProcBar()
  local Learning = OptionsPrivate.Private.Learning
  -- one bar per character is enough
  for id, data in pairs(WeakAurasSaved.displays or {}) do
    if data.simpleAuto == "procs" and boundToCurrent(data) then
      OptionsPrivate.PickAndEditDisplay(data.parent or id)
      WeakAuras.prettyPrint(L["This character already has an automatic proc bar: %s"]:format(id))
      return
    end
  end

  local ids = Learning and Learning.GetAutoProcIds() or {}
  local group = {
    id = OptionsPrivate.Private.FindUnusedId(L["Auto procs"]),
    regionType = "dynamicgroup",
    grow = "HORIZONTAL",
    align = "CENTER",
    centerType = "LR",
    space = 4,
    selfPoint = "CENTER",
    anchorPoint = "CENTER",
    anchorFrameType = "SCREEN",
    xOffset = 0,
    yOffset = 150,
  }
  WeakAuras.NewAura(group, "dynamicgroup")

  local glow = { type = "subglow" }
  local glowType = OptionsPrivate.Private.subRegionTypes and OptionsPrivate.Private.subRegionTypes.subglow
  local defaults = glowType and glowType.default
  if type(defaults) == "function" then defaults = defaults("icon") end
  if type(defaults) == "table" then
    for k, v in pairs(defaults) do glow[k] = v end
  end
  glow.glow = true

  local icons = {
    id = OptionsPrivate.Private.FindUnusedId(L["Auto procs (icons)"]),
    regionType = "icon",
    simpleAuto = "procs",
    width = 44,
    height = 44,
    triggers = {
      {
        trigger = {
          type = "aura2",
          unit = "player",
          debuffType = "HELPFUL",
          useName = false,
          useExactSpellId = true,
          auraspellids = #ids > 0 and ids or { "0" }, -- never empty: an empty list would match every buff
          matchesShowOn = "showOnActive",
          showClones = true,
          unitExists = false,
        },
        untrigger = {},
      },
    },
    subRegions = { glow },
    animation = {
      start = { type = "preset", preset = "fade", duration_type = "seconds", easeType = "none", easeStrength = 3 },
      main = { type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3 },
      finish = { type = "preset", preset = "fade", duration_type = "seconds", easeType = "none", easeStrength = 3 },
    },
  }
  WeakAuras.NewAura(icons, "icon", group.id)
  if #ids == 0 then
    WeakAuras.prettyPrint(L["Automatic proc bar created. No procs learned yet: play a little, procs are added to the bar by themselves."])
  else
    WeakAuras.prettyPrint(L["Automatic proc bar created with %d procs. New procs are added by themselves; hide one with right click in the Choose... list."]:format(#ids))
  end
end
