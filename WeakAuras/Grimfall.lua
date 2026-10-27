if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

-- WeakAuras Simple Remastered (Grimfall edition)
-- Grimfall & Classless compatible by Lidless
--
-- Grimfall's Conquest of Azeroth realm has custom classes and backported races,
-- and the classless realm has no real class at all. This file replaces the
-- class/spec based parts of WeakAuras with things that work everywhere:
--   * a character binding: auras are stored account wide, but every new aura
--     only loads on the character that created it (editable in the Load tab)
--   * a manual Tank / DPS / Healer role chosen per character
--   * class and race lists that accept any token the client reports

local Grimfall = {}
Private.Grimfall = Grimfall

Grimfall.roles = { "tank", "dps", "healer" }
Grimfall.defaultRole = "dps"

Grimfall.role_types = {
  tank = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t " .. (TANK or "Tank"),
  dps = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t " .. (DAMAGER or "DPS"),
  healer = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t " .. (HEALER or "Healer"),
}
Private.player_role_types = Grimfall.role_types

-- Old WeakAuras role keys, so auras made with the original role filter keep working
local legacyRoleMap = {
  tank = "tank",
  healer = "healer",
  dps = "dps",
  melee = "dps",
  caster = "dps",
  damager = "dps",
  TANK = "tank",
  HEALER = "healer",
  DAMAGER = "dps",
}

local function getDB()
  return Private.db or WeakAurasSaved
end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------

function Grimfall.CharacterKey(name, realm)
  name = name or UnitName("player")
  realm = realm or GetRealmName()
  if not name or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  return name .. "-" .. (realm or "")
end

local function characterTable()
  local db = getDB()
  if not db then return nil end
  db.characters = db.characters or {}
  return db.characters
end

function Grimfall.GetCharacterInfo(key)
  local characters = characterTable()
  key = key or Grimfall.CharacterKey()
  if not characters or not key then return nil end
  characters[key] = characters[key] or {}
  return characters[key]
end

function Grimfall.RegisterCurrentCharacter()
  local key = Grimfall.CharacterKey()
  if not key then return end
  local info = Grimfall.GetCharacterInfo(key)
  if not info then return end
  info.name = UnitName("player")
  info.realm = GetRealmName()
  local className, classToken = UnitClass("player")
  info.className = className
  info.class = classToken
  info.lastSeen = time()
  Grimfall.RegisterClass(classToken, className)
  local raceName, raceToken = UnitRace("player")
  Grimfall.RegisterRace(raceToken, raceName)
  return key
end

function WeakAuras.IsCurrentCharacter(key)
  return key ~= nil and key == Grimfall.CharacterKey()
end

--- values for the "Characters" load option
function Grimfall.GetCharacterList()
  local list = {}
  local current = Grimfall.CharacterKey()
  local characters = characterTable() or {}
  for key, info in pairs(characters) do
    local text = (info.name or key) .. " - " .. (info.realm or "")
    if key == current then
      text = "|cff00ff00" .. text .. "|r"
    end
    list[key] = text
  end
  if current and not list[current] then
    list[current] = "|cff00ff00" .. current .. "|r"
  end
  return list
end

--- Binds an aura to the current character (only for real auras, groups load through their children)
function Grimfall.BindToCurrentCharacter(data)
  if not data or data.controlledChildren then return end
  local key = Grimfall.CharacterKey()
  if not key then return end
  data.load = data.load or {}
  data.load.use_characters = false -- false = multi select mode
  data.load.characters = { multi = { [key] = true } }
end

--- On import: keep a binding that points to one of our own characters,
--- otherwise bind the aura to the importing character
function Grimfall.FixImportedBinding(data)
  if not data or data.controlledChildren then return end
  local load = data.load
  local characters = characterTable() or {}
  if load and load.use_characters ~= nil and type(load.characters) == "table" and type(load.characters.multi) == "table" then
    for key in pairs(load.characters.multi) do
      if characters[key] then
        return
      end
    end
  end
  Grimfall.BindToCurrentCharacter(data)
end

--- One time conversion of the old class load option into character bindings.
--- Runs once per character, at login, before the auras are added.
--- An aura that used the class (or class and spec) load option gets bound to
--- every character of that class, as each of them logs in for the first time.
local function classMatches(load, classToken)
  if load.use_class == true then
    return type(load.class) == "table" and load.class.single == classToken
  elseif load.use_class == false then
    return type(load.class) == "table" and type(load.class.multi) == "table" and load.class.multi[classToken] == true
  end
  return false
end

local function specMatches(load, classToken)
  local specInfoByID = Private.specInfoByID or {}
  local spec = load.class_and_spec
  if type(spec) ~= "table" then return false end
  if load.use_class_and_spec == true then
    local info = specInfoByID[spec.single]
    return info ~= nil and info.class == classToken
  elseif load.use_class_and_spec == false and type(spec.multi) == "table" then
    for specId, enabled in pairs(spec.multi) do
      local info = specInfoByID[specId]
      if enabled and info and info.class == classToken then
        return true
      end
    end
  end
  return false
end

function Grimfall.MigrateClassBindings(db)
  local key = Grimfall.RegisterCurrentCharacter()
  local info = key and Grimfall.GetCharacterInfo(key)
  if not info or info.classMigrated or not db or not db.displays then return end
  local _, classToken = UnitClass("player")
  for _, data in pairs(db.displays) do
    local load = data.load
    if not data.controlledChildren and type(load) == "table" then
      local usesClass = load.use_class ~= nil or load.use_class_and_spec ~= nil
      if load.grimfallClassBinding or (usesClass and load.use_characters == nil) then
        if not load.grimfallClassBinding then
          load.grimfallClassBinding = true
          load.use_characters = false
          load.characters = { multi = {} }
        end
        load.characters = type(load.characters) == "table" and load.characters or { multi = {} }
        load.characters.multi = load.characters.multi or {}
        if classToken and (classMatches(load, classToken) or specMatches(load, classToken)) then
          load.characters.multi[key] = true
        end
      end
    end
  end
  info.classMigrated = true
end

---------------------------------------------------------------------------
-- Role
---------------------------------------------------------------------------

function Grimfall.HasChosenRole()
  local info = Grimfall.GetCharacterInfo()
  return info and info.role ~= nil
end

function Grimfall.GetPlayerRole()
  local info = Grimfall.GetCharacterInfo()
  return info and info.role or Grimfall.defaultRole
end
WeakAuras.GetPlayerRole = Grimfall.GetPlayerRole

---------------------------------------------------------------------------
-- Role sync with Tidy Plates: Threat Plates (Grimfall edition by Lidless)
-- Both addons use the same Tank / DPS / Healer choice. Nothing has to be changed in
-- Threat Plates: we use its TidyPlatesThreat:GetRole() / :SetRole(role, silent) and
-- db.char.roleChosen, and hook :SetRole to follow changes made there.
---------------------------------------------------------------------------

local toThreatPlates = { tank = "TANK", dps = "DPS", healer = "HEALER" }
local fromThreatPlates = { TANK = "tank", DPS = "dps", HEALER = "healer" }
local syncing = false

local function threatPlates()
  local tp = _G.TidyPlatesThreat
  if type(tp) == "table" and type(tp.SetRole) == "function" and type(tp.GetRole) == "function"
     and tp.db and tp.db.char then
    return tp
  end
end

function Grimfall.IsRoleSyncEnabled()
  local db = getDB()
  return not (db and db.roleSync == false)
end

function Grimfall.SetRoleSync(enabled)
  local db = getDB()
  if db then db.roleSync = enabled and true or false end
  if enabled then Grimfall.SyncRoleNow() end
end

function Grimfall.HasThreatPlates()
  return threatPlates() ~= nil
end

local function setRole(role, fromThreatPlates)
  local info = Grimfall.GetCharacterInfo()
  if not info then return false end
  local changed = info.role ~= role
  info.role = role
  if changed then
    Private.ScanForLoads(nil, "WA_ROLE_CHANGED")
  end
  if Private.callbacks then
    Private.callbacks:Fire("RoleChanged", role)
  end
  local tp = not fromThreatPlates and Grimfall.IsRoleSyncEnabled() and threatPlates()
  if tp and not syncing and (tp:GetRole() ~= toThreatPlates[role] or not tp.db.char.roleChosen) then
    syncing = true
    pcall(tp.SetRole, tp, toThreatPlates[role], true)
    syncing = false
  end
  return true
end

function Grimfall.SetPlayerRole(role)
  if type(role) ~= "string" then
    return false
  end
  role = legacyRoleMap[role] or legacyRoleMap[role:lower()]
  if not role then
    return false
  end
  return setRole(role, false)
end
WeakAuras.SetPlayerRole = Grimfall.SetPlayerRole

local hooked = false
--- hook Threat Plates once and bring both addons to the same role
function Grimfall.SyncRoleNow()
  local tp = threatPlates()
  if not tp then return end
  if not hooked then
    hooked = true
    hooksecurefunc(tp, "SetRole", function(self)
      if syncing or not Grimfall.IsRoleSyncEnabled() then return end
      local role = fromThreatPlates[self:GetRole()]
      if role then
        syncing = true
        setRole(role, true)
        syncing = false
      end
    end)
  end
  if not Grimfall.IsRoleSyncEnabled() then return end
  local tpChosen = tp.db.char.roleChosen
  local tpRole = fromThreatPlates[tp:GetRole()]
  if tpChosen and tpRole then
    -- Threat Plates wins at login
    if Grimfall.GetPlayerRole() ~= tpRole or not Grimfall.HasChosenRole() then
      setRole(tpRole, true)
    end
  elseif Grimfall.HasChosenRole() then
    setRole(Grimfall.GetPlayerRole(), false)
  end
end

--- used by the role load test, accepts old WeakAuras role keys as well
function WeakAuras.RoleMatches(current, wanted)
  return current ~= nil and legacyRoleMap[wanted] == current
end

function Grimfall.PrintRole()
  local role = Grimfall.GetPlayerRole()
  WeakAuras.prettyPrint(L["Your role: %s"]:format(Grimfall.role_types[role] or role))
  if Grimfall.HasThreatPlates() then
    if Grimfall.IsRoleSyncEnabled() then
      WeakAuras.prettyPrint(L["Role is synced with Threat Plates (turn off: /wa role sync off)."])
    else
      WeakAuras.prettyPrint(L["Role is NOT synced with Threat Plates (turn on: /wa role sync on)."])
    end
  end
  if not Grimfall.HasChosenRole() then
    WeakAuras.prettyPrint(L["No role chosen for this character yet, DPS is used. Choose with: /wa role tank | dps | healer"])
  end
end

---------------------------------------------------------------------------
-- Class and race lists that accept unknown (custom) tokens
---------------------------------------------------------------------------

function Grimfall.RegisterClass(token, localizedName)
  if not token or token == "" or not WeakAuras.class_types then return end
  if WeakAuras.class_types[token] then return end
  local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[token]
  local text = localizedName or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
  if color and color.colorStr then
    text = "|c" .. color.colorStr .. text .. "|r"
  end
  WeakAuras.class_types[token] = text
end

function Grimfall.RegisterRace(token, localizedName)
  if not token or token == "" or not WeakAuras.race_types then return end
  if WeakAuras.race_types[token] then return end
  WeakAuras.race_types[token] = localizedName or token
end

local function registerGroupClasses()
  local prefix, count
  if GetNumRaidMembers() > 0 then
    prefix, count = "raid", GetNumRaidMembers()
  else
    prefix, count = "party", GetNumPartyMembers()
  end
  for i = 1, count do
    local unit = prefix .. i
    if UnitExists(unit) then
      local className, classToken = UnitClass(unit)
      Grimfall.RegisterClass(classToken, className)
      local raceName, raceToken = UnitRace(unit)
      Grimfall.RegisterRace(raceToken, raceName)
    end
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
local reminded = false
frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    Grimfall.RegisterCurrentCharacter()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Grimfall.RegisterCurrentCharacter()
    registerGroupClasses()
    Grimfall.SyncRoleNow()
    -- Threat Plates already reminds about the role, one reminder is enough
    local threatPlatesReminds = Grimfall.HasThreatPlates() and Grimfall.IsRoleSyncEnabled()
    if not reminded and not Grimfall.HasChosenRole() and not threatPlatesReminds then
      reminded = true
      WeakAuras.prettyPrint(L["No role chosen for this character yet, DPS is used. Choose with: /wa role tank | dps | healer"])
    end
  else
    registerGroupClasses()
  end
end)
