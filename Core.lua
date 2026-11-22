-- wowfah Ledger: records your auction house sales, purchases, expired and cancelled auctions.
-- Nothing leaves your computer unless you upload the saved file or paste an export code at wowfah.com.
-- Other players' names are never stored.

local ADDON, ns = ...
ns.VERSION = "0.8.1"
ns.SEP = "|"

local MAX_SIGHTINGS, MAX_OWNED, MAX_POSTINGS, MAX_SEEN, MAX_EVENTS, MAX_GOLD = 4000, 400, 300, 400, 20000, 600

-- ---------------------------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------------------------
function ns.Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4a44cwowfah|r " .. tostring(msg))
  end
end

-- pcall wrapper: a missing or changed game function must never break the player's UI
function ns.Try(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g, h, i, j, k, l end
  return nil
end

-- fields are joined with "|"; item names never contain one, but strip it anyway
function ns.Clean(v)
  if v == nil then return "" end
  return (tostring(v):gsub("[|\r\n]", " "))
end

function ns.Row(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[i] = ns.Clean((select(i, ...))) end
  return table.concat(parts, ns.SEP)
end

function ns.Trim(list, max)
  local extra = #list - max
  if extra > 0 then
    for _ = 1, extra do table.remove(list, 1) end
  end
end

function ns.FormatMoney(copper)
  copper = math.floor((copper or 0) + 0.5)
  local sign = ""
  if copper < 0 then sign, copper = "-", -copper end
  local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
  if g > 0 then return string.format("%s%dg %ds %dc", sign, g, s, c) end
  if s > 0 then return string.format("%s%ds %dc", sign, s, c) end
  return string.format("%s%dc", sign, c)
end

-- ---------------------------------------------------------------------------------------------
-- saved data
-- ---------------------------------------------------------------------------------------------
function ns.InitDB()
  WowfahLedgerDB = WowfahLedgerDB or {}
  local db = WowfahLedgerDB
  db.v = 1
  db.addon = ns.VERSION
  if db.share == nil then db.share = true end   -- share anonymous sale prices with wowfah.com
  db.chars = db.chars or {}        -- charKey -> "region|faction|pvp|rp|hc|project|lastSeen"
  db.events = db.events or {}      -- sales, purchases, expired, cancelled, posted (one row each)
  db.postings = db.postings or {}  -- recent postings, used to find item ids and deposits for later mail
  db.owned = db.owned or {}        -- auction ids of your own auctions (confirms which house you use)
  db.sightings = db.sightings or {}-- prices seen while you browse
  db.seen = db.seen or {}          -- fingerprints of mail already recorded
  db.gold = db.gold or {}          -- your gold at login and logout: "time|character|copper"
  if db.guildReply == nil then db.guildReply = false end     -- answering price questions in guild chat is off until asked for
  if db.tips == nil then db.tips = true end     -- your own prices on item tooltips
  db.debug = db.debug or {}
  ns.db = db
  return db
end

-- ---------------------------------------------------------------------------------------------
-- who and where
-- ---------------------------------------------------------------------------------------------
local function rule(name)
  if not (C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule and Enum.GameRule[name]) then return "" end
  local v = ns.Try(C_GameRules.IsGameRuleActive, Enum.GameRule[name])
  if v == nil then return "" end
  return v and "1" or "0"
end

function ns.CharKey()
  local name, realm = ns.Try(UnitFullName, "player")
  name = name or ns.Try(UnitName, "player") or "Unknown"
  realm = realm or ns.Try(GetNormalizedRealmName) or ""
  return name .. "-" .. realm
end

function ns.UpdateCharacter()
  local key = ns.CharKey()
  ns.charKey = key
  ns.db.chars[key] = ns.Row(
    ns.Try(GetCurrentRegion) or "",
    ns.Try(UnitFactionGroup, "player") or "",
    rule("PvPRuleset"), rule("RPRuleset"), rule("HardcoreRuleset"),
    WOW_PROJECT_ID or "", time())
  return key
end

-- where the player is standing: used with the auction ids to work out which auction house this is
function ns.MapID()
  if C_Map and C_Map.GetBestMapForUnit then
    return ns.Try(C_Map.GetBestMapForUnit, "player") or 0
  end
  return 0
end

-- ---------------------------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------------------------
-- kind: sale | purchase | expired | cancelled | posted
function ns.AddEvent(kind, itemID, itemName, qty, gross, deposit, cut, net, auctionID, when)
  local row = ns.Row(kind, when or time(), ns.charKey or ns.CharKey(), itemID or 0, itemName or "", qty or 1,
    gross or 0, deposit or 0, cut or 0, net or 0, auctionID or 0, ns.MapID())
  table.insert(ns.db.events, row)
  if ns.InvalidateData then ns.InvalidateData() end
  if ns.RefreshUI then ns.RefreshUI() end
  return row
end

ns.handlers = {}
function ns.On(event, fn)
  ns.handlers[event] = ns.handlers[event] or {}
  table.insert(ns.handlers[event], fn)
  if ns.frame then ns.Try(ns.frame.RegisterEvent, ns.frame, event) end
end

ns.frame = CreateFrame("Frame")
ns.frame:SetScript("OnEvent", function(_, event, ...)
  local list = ns.handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok and ns.db then ns.db.debug.lastError = tostring(err) end
  end
end)
ns.frame:RegisterEvent("ADDON_LOADED")
ns.frame:RegisterEvent("PLAYER_LOGIN")
ns.frame:RegisterEvent("PLAYER_LOGOUT")

ns.handlers["ADDON_LOADED"] = { function(name)
  if name ~= ADDON then return end
  ns.InitDB()
  -- register everything the other files asked for before the frame existed
  for event in pairs(ns.handlers) do ns.Try(ns.frame.RegisterEvent, ns.frame, event) end
end }

ns.handlers["PLAYER_LOGIN"] = { function()
  if not ns.db then ns.InitDB() end
  ns.UpdateCharacter()
  if ns.InstallHooks then ns.InstallHooks() end
  if ns.NoteGold then ns.NoteGold() end
end }

ns.handlers["PLAYER_LOGOUT"] = { function()
  if not ns.db then return end
  if ns.NoteGold then ns.NoteGold(true) end
  ns.Trim(ns.db.gold, MAX_GOLD)
  ns.Trim(ns.db.sightings, MAX_SIGHTINGS)
  ns.Trim(ns.db.owned, MAX_OWNED)
  ns.Trim(ns.db.postings, MAX_POSTINGS)
  ns.Trim(ns.db.seen, MAX_SEEN)
  ns.Trim(ns.db.events, MAX_EVENTS)     -- the website keeps everything you have uploaded; this only stops the file growing for ever
end }

-- ---------------------------------------------------------------------------------------------
-- slash commands
-- ---------------------------------------------------------------------------------------------
function ns.Debug()
  local d = {}
  local function put(k, v) d[k] = ns.Clean(v) end
  local version, build, _, toc = ns.Try(GetBuildInfo)
  put("build", (version or "?") .. " " .. (build or "?") .. " toc " .. (toc or "?"))
  put("project", WOW_PROJECT_ID)
  local n1, r1 = ns.Try(UnitFullName, "player")
  put("UnitFullName", (n1 or "nil") .. " / " .. (r1 or "nil"))
  local n2, r2 = ns.Try(UnitName, "player")
  put("UnitName", (n2 or "nil") .. " / " .. (r2 or "nil"))
  put("GetRealmName", ns.Try(GetRealmName))
  put("GetNormalizedRealmName", ns.Try(GetNormalizedRealmName))
  put("region", ns.Try(GetCurrentRegion))
  put("faction", ns.Try(UnitFactionGroup, "player"))
  put("rules", "pvp=" .. rule("PvPRuleset") .. " rp=" .. rule("RPRuleset") .. " hc=" .. rule("HardcoreRuleset"))
  put("map", ns.MapID())
  put("zone", (ns.Try(GetRealZoneText) or "") .. " / " .. (ns.Try(GetSubZoneText) or ""))
  put("npc", (ns.Try(UnitName, "npc") or "none") .. " / " .. (ns.Try(UnitGUID, "npc") or "none"))
  local have = {}
  local function has(label, v) table.insert(have, label .. "=" .. (v and "yes" or "no")) end
  has("C_AuctionHouse", C_AuctionHouse)
  has("PostItem", C_AuctionHouse and C_AuctionHouse.PostItem)
  has("PostCommodity", C_AuctionHouse and C_AuctionHouse.PostCommodity)
  has("GetOwnedAuctionInfo", C_AuctionHouse and C_AuctionHouse.GetOwnedAuctionInfo)
  has("GetBrowseResults", C_AuctionHouse and C_AuctionHouse.GetBrowseResults)
  has("GetInboxInvoiceInfo", GetInboxInvoiceInfo)
  has("C_EncodingUtil", C_EncodingUtil)
  has("C_GameRules", C_GameRules)
  has("legacyPostAuction", PostAuction or StartAuction)
  put("apis", table.concat(have, " "))
  put("subjects", "expired=" .. tostring(AUCTION_EXPIRED_MAIL_SUBJECT) .. " removed=" .. tostring(AUCTION_REMOVED_MAIL_SUBJECT)
    .. " sold=" .. tostring(AUCTION_SOLD_MAIL_SUBJECT) .. " won=" .. tostring(AUCTION_WON_MAIL_SUBJECT))
  put("soldMessages", ns.db.debug.soldMessages or 0)
  put("events", #ns.db.events)
  put("owned", #ns.db.owned)
  put("sightings", #ns.db.sightings)
  put("loot", tostring(ns.db.lootShare) .. " install=" .. tostring(ns.db.install))
  local hasLoot = {}
  for _, name in ipairs({ "GetLootSourceInfo", "GetLootSlotLink", "GetLootSlotInfo", "GetLootSlotType", "IsFishingLoot", "GetMerchantItemID",
    "GetMerchantItemInfo", "GetQuestItemLink", "GetInstanceInfo", "UnitClassification" }) do
    hasLoot[#hasLoot + 1] = name .. "=" .. (_G[name] and "yes" or "no")
  end
  hasLoot[#hasLoot + 1] = "C_MerchantFrame=" .. ((C_MerchantFrame and C_MerchantFrame.GetItemInfo) and "yes" or "no")
  put("lootApis", table.concat(hasLoot, " "))
  put("lastInvoice", ns.db.debug.lastInvoice or "")
  put("lastError", ns.db.debug.lastError or "")
  put("time", time())
  for k, v in pairs(d) do ns.db.debug[k] = v end
  ns.Print("debug details saved. They are included the next time you upload. Summary:")
  for _, k in ipairs({ "build", "UnitFullName", "GetRealmName", "region", "faction", "rules", "map", "zone", "apis" }) do
    ns.Print("  " .. k .. ": " .. d[k])
  end
end

-- The game writes this addon's data to disk only on logout, exit or an interface reload. Reloading on request is the
-- one way to save in the middle of a session, so the wowfah Sync app (or a manual upload) has something new to send.
-- Is the wowfah Sync app set up on this computer? The app rewrites SyncApp.lua in this folder with the time it last
-- ran; the game reads that file when it loads. A mark older than three weeks means the app has gone.
function ns.HasSyncApp()
  local m = WowfahSyncApp
  return type(m) == "table" and type(m.seen) == "number" and (time() - m.seen) < 21 * 86400
end

function ns.SaveNow()
  if not ns.HasSyncApp() then
    ns.Print("Save and sync needs the free wowfah Sync app for Windows, which uploads for you: wowfah.com/sync")
    ns.Print("Without it, click Manual upload in the ledger window (or type /wowfah export). If you have just set the app up, type /reload once.")
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    ns.Print("You are in combat. Try again when the fight is over.")
    return false
  end
  ns.Print("Reloading to save your ledger. wowfah Sync uploads it a few seconds later.")
  local reload = (C_UI and C_UI.Reload) or ReloadUI
  if reload then reload() end
  return true
end

SLASH_WOWFAHSYNC1 = "/sync"
SLASH_WOWFAHSYNC2 = "/wfsync"
SlashCmdList["WOWFAHSYNC"] = function() ns.SaveNow() end

SLASH_WOWFAH1 = "/wowfah"
SLASH_WOWFAH2 = "/wfl"
SlashCmdList["WOWFAH"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if not ns.db then ns.InitDB() end
  if msg == "debug" then
    ns.Debug()
  elseif msg == "sync" or msg == "save" then
    ns.SaveNow()
  elseif msg == "export" then
    if ns.ShowExport then ns.ShowExport() end
  elseif msg == "path" then
    ns.Print("Log out or type /reload, then upload this file at wowfah.com/ledger/upload:")
    ns.Print("World of Warcraft/_forever_/WTF/Account/YOUR_ACCOUNT/SavedVariables/WowfahLedger.lua")
  elseif msg == "share on" or msg == "share off" then
    ns.db.share = (msg == "share on")
    ns.Print("Sharing anonymous sale prices with wowfah.com is now " .. (ns.db.share and "on" or "off") .. ".")
  elseif msg == "loot on" or msg == "loot off" then
    if ns.SetLoot then ns.SetLoot(msg == "loot on") end
  elseif msg == "minimap" then
    if ns.ShowMinimapButton then
      ns.ShowMinimapButton(ns.db.minimap and ns.db.minimap.hide and true or false)
      ns.Print("The minimap button is now " .. (ns.db.minimap.hide and "hidden. Type /wowfah minimap to bring it back." or "shown."))
    end
  elseif msg == "bags" then
    if ns.PrintBags then ns.PrintBags() end
  elseif msg == "crafts" or msg == "craft" then
    if ns.PrintCrafts then ns.PrintCrafts() end
  elseif msg == "guild on" or msg == "guild off" then
    ns.db.guildReply = (msg == "guild on")
    ns.Print("Answering price questions in guild chat is now " .. (ns.db.guildReply and "on. Guild members ask with a question mark and an item link." or "off."))
  elseif msg == "help" then
    ns.Print("/wowfah (open the ledger), /sync (save and upload with the wowfah Sync app), /wowfah bags (what your bags are worth), /wowfah crafts (profit for the open profession), /wowfah guild on|off (answer price questions in guild chat), /wowfah export (manual upload code), /wowfah path, /wowfah share on|off, /wowfah loot on|off, /wowfah minimap, /wowfah debug")
  else
    if ns.ToggleUI then ns.ToggleUI() end
  end
end
