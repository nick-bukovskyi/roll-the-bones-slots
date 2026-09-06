-- Build-specific game boundary and native-only live aura rendering
local _, ns = ...
local Game = {}
ns.Game = Game

local TARGET_VERSION, TARGET_BUILD = "12.1.0", "69587"
Game.ClientLabel = "Retail " .. TARGET_VERSION .. "." .. TARGET_BUILD
local OUTLAW_SPEC_ID = 260
local ROLL_THE_BONES = 1214909

-- Authored artwork definitions, not a model of the player's active result
-- Symbol IDs are dice, coin, crossed swords, rum bottle, and Jackpot chest
-- Zero marks a non-winning position filled by a cosmetic variant
Game.Results = {
  { spellID = 1214933, label = "One of a Kind", symbols = { 1, 0, 0 } },
  { spellID = 1214934, label = "Double Trouble", symbols = { 1, 1, 0 } },
  { spellID = 1214935, label = "Triple Threat", symbols = { 1, 1, 1 } },
  { spellID = 1214937, label = "Jackpot", symbols = { 5, 5, 5 } },
}

function Game.IsSupportedClient()
  local version, build = GetBuildInfo()
  return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and version == TARGET_VERSION and build == TARGET_BUILD
end

function Game.IsRogue()
  local _, classToken = UnitClass("player")
  if issecretvalue(classToken) or classToken == nil then
    return nil
  end
  return classToken == "ROGUE"
end

function Game.IsOutlaw()
  if not Game.IsRogue() then
    return false
  end
  local index = C_SpecializationInfo.GetSpecialization()
  if issecretvalue(index) or not index or index == 0 then
    return false
  end
  local specID = C_SpecializationInfo.GetSpecializationInfo(index)
  if issecretvalue(specID) or specID ~= OUTLAW_SPEC_ID then
    return false
  end
  local known = C_SpellBook.IsSpellKnown(ROLL_THE_BONES)
  return not issecretvalue(known) and known == true
end

function Game.IsRollCast(unit, spellID)
  return not issecretvalue(unit) and unit == "player" and not issecretvalue(spellID) and spellID == ROLL_THE_BONES
end

function Game.CanConfigure()
  return not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret()
end

local function CreateContainer(parent)
  local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  -- Native slot-only flow layout may shrink this container to zero size
  -- A corner anchor keeps artwork stable without reading secret dimensions
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  container:SetUnit("player")
  return container
end

local function InitializeButton(button, container)
  -- Called only before native access restrictions and aura assignment
  button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  button:SetCancelAuraButtons(nil)
  button:SetHideTooltipInCombat(true)
end

function Game.CreateReelDisplay(parent, reelIndex, initializeResult)
  assert(reelIndex == 1 or reelIndex == 2 or reelIndex == 3, "Reel index must be 1, 2 or 3")
  assert(type(initializeResult) == "function", "Result artwork initializer is required")
  local container = CreateContainer(parent)
  for index, definition in ipairs(Game.Results) do
    container:AddAuraSlot("result" .. index, "HELPFUL", {
      candidateFilters = { includeSpellIDs = { [definition.spellID] = true } },
      initializeFrame = function(button)
        InitializeButton(button, container)
        button:EnableMouse(false)
        initializeResult(button, definition, reelIndex)
        -- Never retain or inspect this button or its regions after setup
      end,
    })
  end
  container:SetEnabled(true)
  return container
end

function Game.CreateBuffDisplay(parent, initializeArtwork)
  assert(type(initializeArtwork) == "function", "Buff artwork initializer is required")
  local container = CreateContainer(parent)
  local spellIDs = {}
  for _, definition in ipairs(Game.Results) do
    spellIDs[definition.spellID] = true
  end
  container:AddAuraSlot("footer", "HELPFUL", {
    candidateFilters = { includeSpellIDs = spellIDs },
    initializeFrame = function(button)
      InitializeButton(button, container)
      initializeArtwork(button)
    end,
  })
  container:SetEnabled(true)
  return container
end

function Game.CreateWinDisplay(parent, definition, reelIndex, initializeWin)
  local container = CreateContainer(parent)
  container:AddAuraSlot("win", "HELPFUL", {
    candidateFilters = { includeSpellIDs = { [definition.spellID] = true } },
    initializeFrame = function(button)
      InitializeButton(button, container)
      button:EnableMouse(false)
      initializeWin(button, definition, reelIndex)
    end,
  })
  container:SetEnabled(true)
  return container
end
