if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- WeakAuras Simple Remastered – picker
-- Grimfall & Classless compatible by Lidless
--
-- A small window that lists what this character can track, so nobody has to type exact names:
--   learned auras (procs, my buffs, buffs from others, passives, debuffs on me, my DoTs on target),
--   spells from the spellbook (with or without cooldown) and items with a "Use:" effect.
-- Left click picks an entry, right click moves a learned entry to another category or removes it.
-- Anything that was not found can be added by hand at the bottom.

local AceGUI = LibStub("AceGUI-3.0")

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local pairs, ipairs, tinsert, type, tostring = pairs, ipairs, tinsert, type, tostring

local MAX_ROWS = 250

local sourceNames = {
  cooldown = L["Spells with cooldown"],
  spell = L["Other spells"],
  item = L["Usable items (trinkets, potions)"],
}

local function Learning()
  return OptionsPrivate.Private.Learning
end

local function categoryName(key)
  return Learning().kindNames[key] or sourceNames[key] or key
end

local function isLearnedKind(key)
  return Learning().kindNames[key] ~= nil
end

local picker
local menuFrame

local function entriesFor(category)
  if isLearnedKind(category) then
    return Learning().GetEntries(category)
  end
  local result = {}
  if category == "cooldown" or category == "spell" then
    for _, entry in ipairs(Learning().GetSpellbook()) do
      if entry.kind == category then tinsert(result, entry) end
    end
  elseif category == "item" then
    result = Learning().GetUsableItems()
  end
  return result
end

local function describe(entry)
  local parts = {}
  if entry.spellId then tinsert(parts, "ID " .. entry.spellId) end
  if entry.itemId then tinsert(parts, "item " .. entry.itemId) end
  if entry.duration and entry.duration > 0 then tinsert(parts, ("%ds"):format(entry.duration)) end
  if entry.seen and entry.seen > 0 then tinsert(parts, L["seen %dx"]:format(entry.seen)) end
  if entry.manual then tinsert(parts, L["added by hand"]) end
  if entry.noAuto then tinsert(parts, L["not on auto bar"]) end
  if entry.pet then tinsert(parts, L["pet"]) end
  if entry.info then tinsert(parts, entry.info) end
  return #parts > 0 and (" |cff999999(" .. table.concat(parts, ", ") .. ")|r") or ""
end

local function CreatePicker()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle(L["Choose"])
  frame:SetWidth(460)
  frame:SetHeight(560)
  frame:SetLayout("Flow")
  frame:EnableResize(false)
  frame:SetCallback("OnClose", function() end) -- keep the window, it is reused
  frame.frame:SetFrameStrata("FULLSCREEN_DIALOG")

  local view = { frame = frame, categories = {}, category = nil, search = "", onPick = nil }

  local categoryBox = AceGUI:Create("Dropdown")
  categoryBox:SetLabel(L["Show"])
  categoryBox:SetRelativeWidth(0.5)
  frame:AddChild(categoryBox)

  local searchBox = AceGUI:Create("EditBox")
  searchBox:SetLabel(L["Search"])
  searchBox:DisableButton(true)
  searchBox:SetRelativeWidth(0.5)
  frame:AddChild(searchBox)

  local listGroup = AceGUI:Create("SimpleGroup")
  listGroup:SetFullWidth(true)
  listGroup:SetHeight(330)
  listGroup:SetLayout("Fill")
  frame:AddChild(listGroup)

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("List")
  listGroup:AddChild(scroll)

  -- manual add
  local addHeader = AceGUI:Create("Heading")
  addHeader:SetText(L["Not in the list? Add it by hand"])
  addHeader:SetFullWidth(true)
  frame:AddChild(addHeader)

  local addName = AceGUI:Create("EditBox")
  addName:SetLabel(L["Name or spell ID"])
  addName:DisableButton(true)
  addName:SetRelativeWidth(0.45)
  frame:AddChild(addName)

  local addKind = AceGUI:Create("Dropdown")
  addKind:SetLabel(L["Category"])
  addKind:SetRelativeWidth(0.33)
  frame:AddChild(addKind)

  local addButton = AceGUI:Create("Button")
  addButton:SetText(L["Add"])
  addButton:SetRelativeWidth(0.2)
  frame:AddChild(addButton)

  local addInfo = AceGUI:Create("Label")
  addInfo:SetFullWidth(true)
  addInfo:SetText("")
  frame:AddChild(addInfo)

  local function pick(entry)
    local callback = view.onPick
    frame.frame:Hide()
    if callback then callback(entry) end
  end

  local fillList

  local function showMenu(entry)
    if not menuFrame then
      menuFrame = CreateFrame("Frame", "WeakAurasSimplePickerMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = {
      { text = entry.name, isTitle = true, notCheckable = true },
    }
    for _, kind in ipairs(Learning().kinds) do
      tinsert(menu, {
        text = L["Move to: %s"]:format(Learning().kindNames[kind]),
        notCheckable = true,
        disabled = kind == entry.kind,
        func = function()
          Learning().SetKind(entry.key, kind)
          fillList()
        end,
      })
    end
    if entry.kind == "proc" and entry.spellId then
      tinsert(menu, {
        text = entry.noAuto and L["Show on the automatic proc bar"] or L["Hide from the automatic proc bar"],
        notCheckable = true,
        func = function()
          Learning().SetNoAuto(entry.key, not entry.noAuto)
          fillList()
        end,
      })
    end
    tinsert(menu, {
      text = "|cffff4040" .. L["Remove from the list"] .. "|r",
      notCheckable = true,
      func = function()
        Learning().Remove(entry.key)
        fillList()
      end,
    })
    tinsert(menu, { text = CANCEL or "Cancel", notCheckable = true })
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
  end

  fillList = function()
    scroll:PauseLayout()
    scroll:ReleaseChildren()
    local category = view.category
    local entries = category and entriesFor(category) or {}
    local search = view.search:lower()
    local shown = 0
    for _, entry in ipairs(entries) do
      if search == "" or (entry.name or ""):lower():find(search, 1, true) or tostring(entry.spellId or ""):find(search, 1, true) then
        shown = shown + 1
        if shown <= MAX_ROWS then
          local row = AceGUI:Create("InteractiveLabel")
          row:SetFullWidth(true)
          row:SetImage(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
          row:SetImageSize(20, 20)
          row:SetText((entry.name or "?") .. describe(entry))
          row:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
          row:SetCallback("OnClick", function(_, _, button)
            if button == "RightButton" and isLearnedKind(category) then
              showMenu(entry)
            else
              pick(entry)
            end
          end)
          scroll:AddChild(row)
        end
      end
    end
    if shown == 0 then
      local empty = AceGUI:Create("Label")
      empty:SetFullWidth(true)
      if isLearnedKind(category) and search == "" then
        empty:SetText(L["Nothing here yet. Play a little with this character (fight, use your abilities): procs, buffs and debuffs are noted automatically. Or add one by hand below."])
      else
        empty:SetText(L["Nothing found."])
      end
      scroll:AddChild(empty)
    elseif shown > MAX_ROWS then
      local more = AceGUI:Create("Label")
      more:SetFullWidth(true)
      more:SetText("|cff999999" .. L["%d more, use the search box."]:format(shown - MAX_ROWS) .. "|r")
      scroll:AddChild(more)
    end
    scroll:ResumeLayout()
    scroll:DoLayout()
    if isLearnedKind(category) then
      frame:SetStatusText(L["Left click: choose.  Right click: move to another category or remove."])
    else
      frame:SetStatusText(L["Left click: choose."])
    end
  end

  categoryBox:SetCallback("OnValueChanged", function(_, _, key)
    view.category = key
    if isLearnedKind(key) then addKind:SetValue(key) end
    fillList()
  end)

  searchBox:SetCallback("OnTextChanged", function(_, _, text)
    view.search = text or ""
    fillList()
  end)

  local kindList, kindOrder = {}, {}
  for _, kind in ipairs(Learning().kinds) do
    kindList[kind] = Learning().kindNames[kind]
    tinsert(kindOrder, kind)
  end
  addKind:SetList(kindList, kindOrder)
  addKind:SetValue("proc")

  addName:SetCallback("OnTextChanged", function(_, _, text)
    local id = tonumber(text or "")
    local name, _, icon = id and GetSpellInfo(id)
    if name then
      addInfo:SetText("|T" .. (icon or "") .. ":16|t |cff00ff00" .. name .. "|r")
    else
      addInfo:SetText("")
    end
  end)

  addButton:SetCallback("OnClick", function()
    local kind = addKind:GetValue() or "proc"
    local entry, err = Learning().AddManual(addName:GetText(), kind)
    if not entry then
      addInfo:SetText("|cffff4040" .. (err or "") .. "|r")
      return
    end
    addName:SetText("")
    addInfo:SetText("|cff00ff00" .. L["Added: %s"]:format(entry.name) .. "|r")
    if isLearnedKind(view.category) then
      if view.category ~= kind and view.categories[kind] then
        view.category = kind
        categoryBox:SetValue(kind)
      end
      fillList()
    end
  end)

  --- categories: list of category keys this caller accepts; first one is shown first
  function view:Open(categories, onPick, title)
    self.onPick = onPick
    self.categories = {}
    local list, order = {}, {}
    for _, key in ipairs(categories) do
      list[key] = categoryName(key)
      tinsert(order, key)
      self.categories[key] = true
    end
    categoryBox:SetList(list, order)
    self.category = order[1]
    categoryBox:SetValue(self.category)
    self.search = ""
    searchBox:SetText("")
    addName:SetText("")
    addInfo:SetText("")
    local anyLearned = false
    for _, key in ipairs(order) do
      if isLearnedKind(key) then anyLearned = true end
    end
    for _, widget in ipairs({ addHeader, addName, addKind, addButton, addInfo }) do
      if anyLearned then widget.frame:Show() else widget.frame:Hide() end
    end
    if isLearnedKind(self.category) then addKind:SetValue(self.category) end
    frame:SetTitle(title or L["Choose"])
    frame.frame:Show()
    fillList()
  end

  return view
end

--- opens the picker; onPick(entry) gets {name, icon, spellId?, itemId?, kind}
function OptionsPrivate.OpenPicker(categories, onPick, title)
  picker = picker or CreatePicker()
  picker:Open(categories, onPick, title)
end

--- category sets used by the Quick Setup and the simple Trigger tab
OptionsPrivate.PickerCategories = {
  anyBuff = { "proc", "mybuff", "received", "passive" },
  myBuff = { "mybuff", "proc", "received", "passive" },
  proc = { "proc", "mybuff", "received", "passive" },
  missing = { "mybuff", "received", "passive", "proc" },
  debuffOnMe = { "debuffOnMe" },
  myDot = { "mydot" },
  buffOnTarget = { "received", "mybuff" },
  allAuras = { "proc", "mybuff", "received", "passive", "debuffOnMe", "mydot" },
  spells = { "cooldown", "spell" },
  usable = { "spell", "cooldown" },
  items = { "item" },
}
