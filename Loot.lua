-- What drops where: creature loot, gathering nodes, fishing, opened containers, vendor stock and quest rewards.
-- Off until the player says yes to the one-time question. Nothing here records a character name.
-- Rows are counters, not one line per kill, so the saved file stays small.

local _, ns = ...

local RECENT = 6           -- seconds a cast or container use stays linked to the loot window that follows
local MAX_SOURCES = 6000   -- distinct creatures, nodes and zones kept
local MAX_KNOWN = 400      -- names of creatures seen recently

local known, knownOrder = {}, {}      -- guid -> { name, level, classification }
local looted, lootedOrder = {}, {}    -- guids already counted, so a corpse opened twice is counted once
local lastCast                        -- { spell, name, target, at }
local lastUse                         -- { item, at }
local windowDone = false              -- this loot window has been read
local windowCount = 0                 -- labels loot that reports no source, one label per window

function ns.LootOn()
  return ns.db and ns.db.lootShare == true
end

local function fields(row)
  local out = {}
  for part in ((row or "") .. "|"):gmatch("([^|]*)|") do out[#out + 1] = part end
  return out
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- "Creature-0-4444-0-12-3054-00001A2B3C" -> "Creature", 3054
function ns.ParseGUID(guid)
  if type(guid) ~= "string" then return nil end
  local kind = guid:match("^(%a+)%-")
  if not kind then return nil end
  if kind == "Creature" or kind == "Vehicle" or kind == "GameObject" or kind == "Pet" then
    local id = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return kind, tonumber(id)
  end
  return kind, nil
end

local function remember(unit)
  local guid = ns.Try(UnitGUID, unit)
  if not guid then return end
  local kind = ns.ParseGUID(guid)
  if kind ~= "Creature" and kind ~= "Vehicle" then return end
  if not known[guid] then
    knownOrder[#knownOrder + 1] = guid
    if #knownOrder > MAX_KNOWN then known[table.remove(knownOrder, 1)] = nil end
  end
  known[guid] = { ns.Try(UnitName, unit) or "", ns.Try(UnitLevel, unit) or 0, ns.Try(UnitClassification, unit) or "" }
end

local function place()
  local zone = ns.Try(GetRealZoneText) or ""
  local sub = ns.Try(GetSubZoneText) or ""
  local instance = ""
  local name, kind = ns.Try(GetInstanceInfo)
  if kind and kind ~= "none" then instance = name or "" end
  return zone, sub, instance
end

local function itemID(link)
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("item:(%d+)"))
end

local function spellName(id)
  if not id then return "" end
  if C_Spell and C_Spell.GetSpellName then return ns.Try(C_Spell.GetSpellName, id) or "" end
  return ns.Try(GetSpellInfo, id) or ""
end

-- one source (a creature, a node, a fishing zone, a container) on one map
local function source(kind, id, spell, name, level, class, castName)
  local db = ns.db
  local map = ns.MapID()
  local key = table.concat({ kind, id or 0, map, spell or 0 }, ":")
  local old = db.lootSrc[key]
  if not old and count(db.lootSrc) >= MAX_SOURCES then return nil end
  local f = fields(old)
  local zone, sub, instance = place()
  db.lootSrc[key] = ns.Row(
    (name and name ~= "") and name or f[1] or "", zone, sub, instance,
    (level and level ~= 0) and level or f[5] or 0, (class and class ~= "") and class or f[6] or "",
    castName or f[7] or "", (tonumber(f[8]) or 0) + 1)
  return key
end

local function drop(key, item, qty, quest)
  local k = key .. ":" .. item
  local f = fields(ns.db.lootItems[k])
  ns.db.lootItems[k] = ns.Row((tonumber(f[1]) or 0) + 1, (tonumber(f[2]) or 0) + (qty or 1), (quest or f[3] == "1") and 1 or 0)
end

local function markLooted(guid)
  looted[guid] = true
  lootedOrder[#lootedOrder + 1] = guid
  if #lootedOrder > 300 then looted[table.remove(lootedOrder, 1)] = nil end
end

-- Read the open loot window once. Each corpse or node in it is a source; each item slot is a drop from its sources.
local function readLoot()
  if not ns.LootOn() or windowDone then return end
  local n = ns.Try(GetNumLootItems) or 0
  if n == 0 then return end
  windowDone = true
  windowCount = windowCount + 1
  local now = time()
  local cast = lastCast and (now - lastCast.at) <= RECENT and lastCast or nil
  local used = lastUse and (now - lastUse.at) <= RECENT and lastUse or nil
  local fishing = ns.Try(IsFishingLoot) and true or false
  local keys = {}          -- guid -> source key, for sources counted in this window

  local function keyFor(guid)
    if keys[guid] ~= nil then return keys[guid] end
    keys[guid] = false
    if looted[guid] then return false end      -- already counted: the leftovers of an earlier look
    local kind, id = ns.ParseGUID(guid)
    local key
    if fishing then
      key = source("f", 0, 0, "", 0, "", cast and cast.name or "")
    elseif kind == "Creature" or kind == "Vehicle" then
      if not id then return false end
      local who = known[guid] or {}
      if ns.Try(UnitGUID, "target") == guid then
        who = { ns.Try(UnitName, "target") or who[1], ns.Try(UnitLevel, "target") or who[2], ns.Try(UnitClassification, "target") or who[3] }
      end
      key = source("c", id, cast and cast.spell or 0, who[1], who[2], who[3], cast and cast.name or "")
    elseif kind == "GameObject" then
      if not id then return false end
      key = source("o", id, cast and cast.spell or 0, cast and cast.target or "", 0, "", cast and cast.name or "")
    elseif kind == "Item" then
      if not used then return false end
      key = source("i", used.item, 0, "", 0, "", "")
    end
    if key then
      markLooted(guid)
      keys[guid] = key
    end
    return keys[guid]
  end

  for slot = 1, n do
    local slotType = ns.Try(GetLootSlotType, slot)
    local id = itemID(ns.Try(GetLootSlotLink, slot))
    if id and (slotType == nil or slotType == 1) then
      local _, _, quantity, _, _, _, isQuest = ns.Try(GetLootSlotInfo, slot)
      local src = { ns.Try(GetLootSourceInfo, slot) }
      if #src == 0 then
        -- no source reported: fishing and some containers
        local guid = fishing and ("fishing-" .. windowCount) or (used and ("Item-use-" .. windowCount)) or nil
        if guid then
          local key = keyFor(guid)
          if key then drop(key, id, quantity or 1, isQuest) end
        end
      end
      for i = 1, #src, 2 do
        local guid, qty = src[i], src[i + 1]
        if type(guid) == "string" then
          local key = keyFor(guid)
          if key then drop(key, id, tonumber(qty) or quantity or 1, isQuest) end
        end
      end
    else
      -- money and currency still tell us the corpse was looted, so it counts towards the total
      local src = { ns.Try(GetLootSourceInfo, slot) }
      for i = 1, #src, 2 do
        if type(src[i]) == "string" then keyFor(src[i]) end
      end
    end
  end
end

-- vendors: what they sell and for how much
local function readMerchant()
  if not ns.LootOn() then return end
  local guid = ns.Try(UnitGUID, "npc")
  local kind, npc = ns.ParseGUID(guid)
  if kind ~= "Creature" or not npc then return end
  local n = ns.Try(GetMerchantNumItems) or 0
  if n == 0 then return end
  local zone, sub = place()
  ns.db.vendors[npc .. ":" .. ns.MapID()] = ns.Row(ns.Try(UnitName, "npc") or "", zone, sub, time())
  for i = 1, n do
    local id = ns.Try(GetMerchantItemID, i) or itemID(ns.Try(GetMerchantItemLink, i))
    local price, stack, available, extended
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
      local info = ns.Try(C_MerchantFrame.GetItemInfo, i)
      if type(info) == "table" then
        price, stack, available, extended = info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
      end
    end
    if price == nil and GetMerchantItemInfo then
      local _, _, p, s, a, _, _, e = ns.Try(GetMerchantItemInfo, i)
      price, stack, available, extended = p, s, a, e
    end
    if id and price then
      ns.db.vendorItems[npc .. ":" .. id] = ns.Row(price, stack or 1, available or -1, extended and 1 or 0)
    end
  end
end

-- quest rewards, read when the reward window is shown
local function readQuest()
  if not ns.LootOn() then return end
  local id = ns.Try(GetQuestID)
  if not id or id == 0 then return end
  local function list(kind, n)
    local out = {}
    for i = 1, n or 0 do
      local item = itemID(ns.Try(GetQuestItemLink, kind, i))
      local _, _, qty = ns.Try(GetQuestItemInfo, kind, i)
      if item then out[#out + 1] = item .. ":" .. (qty or 1) end
    end
    return table.concat(out, ",")
  end
  local rewards = list("reward", ns.Try(GetNumQuestRewards))
  local choices = list("choice", ns.Try(GetNumQuestChoices))
  if rewards == "" and choices == "" then return end
  if not ns.db.quests[tostring(id)] and count(ns.db.quests) >= 3000 then return end
  local zone = place()
  ns.db.quests[tostring(id)] = ns.Row(ns.Try(GetTitleText) or "", ns.Try(UnitLevel, "player") or 0, zone, rewards, choices)
end

-- ---------------------------------------------------------------------------------------------
-- the one-time question
-- ---------------------------------------------------------------------------------------------
function ns.SetLoot(on, quiet)
  ns.db.lootShare = on and true or false
  if not quiet then
    ns.Print(on and "Thank you. What drops where will be included when you upload. No character names are recorded. Turn it off with /wowfah loot off."
      or "Loot is not recorded. You can turn it on later with /wowfah loot on.")
  end
  if ns.RefreshUI then ns.RefreshUI() end
end

function ns.AskLoot()
  if not ns.db or ns.db.lootShare ~= nil then return end
  if not (StaticPopupDialogs and StaticPopup_Show) then
    ns.Print("Help map WoW Forever? Type /wowfah loot on to share what drops where. No character names are recorded.")
    return
  end
  StaticPopupDialogs["WOWFAH_LOOT"] = {
    text = "wowfah Ledger\n\nHelp map WoW Forever? If you say yes, the addon notes what drops from which creature, node, vendor and quest, and includes it when you upload.\n\nNo character names are recorded.",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() ns.SetLoot(true) end,
    OnCancel = function(_, _, reason)
      if reason == "timeout" or reason == "override" then return end     -- not an answer: ask again next time
      ns.SetLoot(false)
    end,
    timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
  }
  ns.Try(StaticPopup_Show, "WOWFAH_LOOT")
end

function ns.InitLoot()
  local db = ns.db
  db.lootSrc = db.lootSrc or {}         -- "kind:id:map:spell" -> "name|zone|subzone|instance|level|class|castName|timesLooted"
  db.lootItems = db.lootItems or {}     -- "kind:id:map:spell:item" -> "drops|quantity|quest"
  db.vendors = db.vendors or {}         -- "npc:map" -> "name|zone|subzone|seen"
  db.vendorItems = db.vendorItems or {} -- "npc:item" -> "price|stack|available|extendedCost"
  db.quests = db.quests or {}           -- questID -> "title|playerLevel|zone|rewards|choices"
  if not db.install then
    -- a random label for this copy of the saved file, so repeat uploads replace its counters instead of adding to them
    local seed = (time() % 100000) * 1000 + math.floor(((ns.Try(GetTime) or 0) * 1000) % 1000)
    local parts = {}
    for i = 1, 3 do
      seed = (seed * 1103515245 + 12345) % 2147483648
      parts[i] = string.format("%04x", seed % 65536)
    end
    db.install = table.concat(parts)
  end
end

ns.On("PLAYER_LOGIN", function()
  ns.InitLoot()
  ns.InstallLootHooks()
  if ns.db.lootShare == nil then
    if C_Timer and C_Timer.After then ns.Try(C_Timer.After, 8, ns.AskLoot) else ns.AskLoot() end
  end
end)
ns.On("LOOT_READY", readLoot)
ns.On("LOOT_OPENED", readLoot)
ns.On("LOOT_CLOSED", function() windowDone = false end)
ns.On("MERCHANT_SHOW", readMerchant)
ns.On("QUEST_COMPLETE", readQuest)
ns.On("PLAYER_TARGET_CHANGED", function() remember("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() remember("mouseover") end)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit) if unit then remember(unit) end end)
ns.On("UNIT_SPELLCAST_SENT", function(unit, target, _, spell)
  if unit ~= "player" then return end
  lastCast = { spell = spell or 0, name = spellName(spell), target = target or "", at = time() }
end)

function ns.InstallLootHooks()
  -- which bag item was just opened, so loot from a container can be credited to it
  local function used(bag, slot)
    local id
    if C_Container and C_Container.GetContainerItemID then id = ns.Try(C_Container.GetContainerItemID, bag, slot) end
    if not id and GetContainerItemID then id = ns.Try(GetContainerItemID, bag, slot) end
    if id then lastUse = { item = id, at = time() } end
  end
  if C_Container and C_Container.UseContainerItem then ns.Try(hooksecurefunc, C_Container, "UseContainerItem", used) end
  if UseContainerItem then ns.Try(hooksecurefunc, "UseContainerItem", used) end
end

-- lines for the export code and for anyone reading the format: L source, I item, M vendor, N vendor item, Q quest
function ns.LootLines(out)
  local db = ns.db
  if not ns.LootOn() then return out end
  local function keyed(prefix, key, row) out[#out + 1] = prefix .. "|" .. ns.Clean(key):gsub(":", "|") .. "|" .. row end
  for key, row in pairs(db.lootSrc or {}) do keyed("L", key, row) end
  for key, row in pairs(db.lootItems or {}) do keyed("I", key, row) end
  for key, row in pairs(db.vendors or {}) do keyed("M", key, row) end
  for key, row in pairs(db.vendorItems or {}) do keyed("N", key, row) end
  for key, row in pairs(db.quests or {}) do keyed("Q", key, row) end
  return out
end
