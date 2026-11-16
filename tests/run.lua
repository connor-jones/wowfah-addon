-- Runs the addon's logic outside the game against a fake mailbox and auction house.
--   luajit tests/run.lua      (from the addon folder)
local now = 1794750000
local realTime = os.time
time = function() return now end
date = os.date

-- ---- a minimal fake of the game ----
local function frame()
  local f = { events = {}, shown = false }
  local noop = function() end
  setmetatable(f, { __index = function(t, k)
    if k == "RegisterEvent" then return function(self, e) self.events[e] = true end end
    if k == "SetScript" then return function(self, what, fn) self["on" .. what] = fn end end
    if k == "CreateFontString" or k == "CreateTexture" then return function() return frame() end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "SetText" then return function(self, s) self.text = s end end
    if k == "GetChecked" then return function(self) return self.checked end end
    if k == "SetChecked" then return function(self, v) self.checked = v end end
    return noop
  end })
  return f
end
CreateFrame = function() return frame() end
UIParent, UISpecialFrames, SlashCmdList = frame(), {}, {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
hooksecurefunc = function(a, b, c)
  local tbl, name, fn = _G, a, b
  if type(a) == "table" then tbl, name, fn = a, b, c end
  local orig = tbl[name]
  tbl[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
end
WOW_PROJECT_ID = 18
UnitFullName = function() return "Thrall", "ForeverPvE1" end
UnitName = function() return "Thrall" end
GetNormalizedRealmName = function() return "ForeverPvE1" end
GetRealmName = function() return "Forever PvE 1" end
GetCurrentRegion = function() return 3 end
UnitFactionGroup = function() return "Horde" end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 2026", 16001 end
Enum = { GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 }, CompressionMethod = { Deflate = 0 } }
C_GameRules = { IsGameRuleActive = function(r) return r == 1 end }
C_Map = { GetBestMapForUnit = function() return 1454 end }
AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
AUCTION_REMOVED_MAIL_SUBJECT = "Auction cancelled: %s"
ERR_AUCTION_SOLD_S = "A buyer has been found for your auction of %s."
RETRIEVING_DATA = "Retrieving data"

local inbox = {}
GetInboxNumItems = function() return #inbox end
local function stacks(m)
  if m.items then return m.items end
  return m.item and { m.item } or {}
end
local function nstacks(m) local n = 0; for _ in pairs(stacks(m)) do n = n + 1 end; return n end
GetInboxHeaderInfo = function(i)
  local m = inbox[i]; if not m then return nil end
  return nil, nil, "Auction House", m.subject, m.money or 0, 0, m.daysLeft or 29.5, nstacks(m)
end
GetInboxInvoiceInfo = function(i)
  local m = inbox[i]; if not (m and m.invoice) then return nil end
  local v = m.invoice
  return v.type, v.name, nil, v.bid, v.buyout, v.deposit, v.cut, 0, 0, 0, v.count
end
GetInboxItem = function(i, a) local m = inbox[i]; local it = m and stacks(m)[a or 1]; if it then return it.name, nil, nil, it.count end end
GetInboxItemLink = function(i, a) local m = inbox[i]; local it = m and stacks(m)[a or 1]; if it then return "|Hitem:" .. it.id .. "::::|h[" .. it.name .. "]|h" end end
local bagsFull = false
TakeInboxMoney = function(i) if inbox[i] then inbox[i].money = 0 end end
TakeInboxItem = function(i, a)
  local m = inbox[i]
  if not m or bagsFull then return end
  if m.items then m.items[a or 1] = nil else m.item = nil end
end
AutoLootMailItem = function(i) if inbox[i] and not bagsFull then inbox[i].item, inbox[i].items = nil, nil end end
DeleteInboxItem = function(i) table.remove(inbox, i) end

local created
C_Item = { GetItemID = function(loc) return loc.id end, GetItemName = function(loc) return loc.name end }
C_AuctionHouse = {
  PostItem = function() end, PostCommodity = function() end,
  CalculateItemDeposit = function() return 150 end, CalculateCommodityDeposit = function(_, _, qty) return 5 * qty end,
  GetBrowseResults = function() return { { itemKey = { itemID = 3860 }, minPrice = 1085, totalQuantity = 4652 }, { itemKey = { itemID = 4306 }, minPrice = 0, totalQuantity = 3 } } end,
  GetNumOwnedAuctions = function() return 2 end,
  GetOwnedAuctionInfo = function(i) return { auctionID = 9000 + i, itemKey = { itemID = 3860 }, status = 0 } end,
  QueryOwnedAuctions = function() end,
}

-- ---- loot windows, merchants and quest rewards ----
local lootWindow, fishingLoot, targetGUID, units = {}, false, nil, {}
GetNumLootItems = function() return #lootWindow end
GetLootSlotType = function(i) return lootWindow[i].money and 2 or 1 end
GetLootSlotLink = function(i) local s = lootWindow[i]; if s.id then return "|Hitem:" .. s.id .. "::::|h[x]|h" end end
GetLootSlotInfo = function(i) local s = lootWindow[i]; return nil, s.name, s.qty or 1, nil, 1, false, s.quest or false end
GetLootSourceInfo = function(i) return unpack(lootWindow[i].src or {}) end
IsFishingLoot = function() return fishingLoot end
UnitGUID = function(u) if u == "target" then return targetGUID end; return units[u] and units[u].guid end
UnitLevel = function(u) return units[u] and units[u].level or 10 end
UnitClassification = function(u) return units[u] and units[u].class or "normal" end
GetRealZoneText = function() return "The Barrens" end
GetSubZoneText = function() return "The Crossroads" end
GetInstanceInfo = function() return "Kalimdor", "none" end
GetTime = function() return 1234.567 end
local merchant = {}
GetMerchantNumItems = function() return #merchant end
GetMerchantItemID = function(i) return merchant[i].id end
GetMerchantItemInfo = function(i) local m = merchant[i]; return m.name, nil, m.price, m.stack or 1, m.avail or -1, true, true, false end
local quest = { id = 0, rewards = {}, choices = {} }
GetQuestID = function() return quest.id end
GetTitleText = function() return quest.title end
GetNumQuestRewards = function() return #quest.rewards end
GetNumQuestChoices = function() return #quest.choices end
GetQuestItemLink = function(kind, i) local l = kind == "reward" and quest.rewards or quest.choices; return "|Hitem:" .. l[i].id .. "::::|h[x]|h" end
GetQuestItemInfo = function(kind, i) local l = kind == "reward" and quest.rewards or quest.choices; return "x", nil, l[i].qty or 1 end
local popup
StaticPopupDialogs = {}
StaticPopup_Show = function(name) popup = StaticPopupDialogs[name] end
local bagItems = {}
C_Container = { UseContainerItem = function() end, GetContainerItemID = function(bag, slot) return bagItems[bag .. ":" .. slot] end }

-- ---- load the addon the way the game does ----
local ns = {}
local toc = io.open("WowfahLedger/WowfahLedger.toc"):read("*a")
for file in toc:gmatch("\n([%w_]+%.lua)") do
  local chunk = assert(loadfile("WowfahLedger/" .. file))
  chunk("WowfahLedger", ns)
end
local function fire(event, ...) ns.frame.onOnEvent(ns.frame, event, ...) end

local failed, passed = 0, 0
local function check(label, got, want)
  if got == want then passed = passed + 1 else
    failed = failed + 1
    print(("FAIL %s: got %s, wanted %s"):format(label, tostring(got), tostring(want)))
  end
end
local function events(kind)
  local out = {}
  for _, row in ipairs(WowfahLedgerDB.events) do
    local f = {}
    for part in (row .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end
    if f[1] == kind then out[#out + 1] = f end
  end
  return out
end

fire("ADDON_LOADED", "WowfahLedger")
fire("PLAYER_LOGIN")
check("character key", ns.charKey, "Thrall-ForeverPvE1")
check("character row", WowfahLedgerDB.chars["Thrall-ForeverPvE1"]:match("^3|Horde|1|0|0|18|"), "3|Horde|1|0|0|18|")
check("share defaults on", WowfahLedgerDB.share, true)
check("subject match", ns.MatchSubject("Auction expired: Linen Cloth", AUCTION_EXPIRED_MAIL_SUBJECT), "Linen Cloth")
check("subject no match", ns.MatchSubject("Hello there", AUCTION_EXPIRED_MAIL_SUBJECT), nil)

-- post two things; the game then reports each auction's id
C_AuctionHouse.PostItem({ id = 12640, name = "Lionheart Helm" }, 2, 1, 4000000, 4500000)
fire("AUCTION_HOUSE_AUCTION_CREATED", 555001)
C_AuctionHouse.PostCommodity({ id = 3860, name = "Mithril Bar" }, 2, 20, 1100)
fire("AUCTION_HOUSE_AUCTION_CREATED", 555002)
C_AuctionHouse.PostCommodity({ id = 2589, name = "Linen Cloth" }, 2, 40, 25)
fire("AUCTION_HOUSE_AUCTION_CREATED", 555003)
check("posted events", #events("posted"), 3)
check("posting keeps auction id", WowfahLedgerDB.postings[2]:match("^Mithril Bar|3860|20|100|555002|") ~= nil, true)
check("commodity total", events("posted")[2][7], "22000")

-- the mailbox an hour later
now = now + 3700
inbox = {
  { subject = "Sale Pending: Mithril Bar", invoice = { type = "seller_temp_invoice", name = "Mithril Bar", bid = 22000, deposit = 100, cut = 1100, count = 20 } },
  { subject = "Auction successful: Mithril Bar", money = 21000, invoice = { type = "seller", name = "Mithril Bar", bid = 22000, deposit = 100, cut = 1100, count = 20 } },
  { subject = "Auction won: Silk Cloth", item = { id = 4306, name = "Silk Cloth", count = 12 }, invoice = { type = "buyer", name = "Silk Cloth", bid = 2400, deposit = 0, cut = 0, count = 12 } },
  { subject = "Auction expired: Linen Cloth", item = { id = 2589, name = "Linen Cloth", count = 40 } },
  { subject = "Hello from a friend", money = 500 },
  { subject = "Retrieving data" },
}
fire("MAIL_SHOW")
local function update() fire("MAIL_INBOX_UPDATE") end
TakeInboxMoney(1); update()             -- pending notice: nothing to record
check("pending sale ignored", #events("sale"), 0)
TakeInboxMoney(2)
check("nothing recorded until the money has left the mail", #events("sale"), 0)
update()
local sale = events("sale")[1]
check("sale recorded", sale ~= nil, true)
check("sale item id from posting", sale[4], "3860")
check("sale quantity", sale[6], "20")
check("sale gross", sale[7], "22000")
check("sale cut", sale[9], "1100")
check("sale net of cut", sale[10], "20900")
check("sale auction id", sale[11], "555002")
update()                                -- the emptied mail is still listed until it is deleted
TakeInboxMoney(2); update()
check("sale not counted twice", #events("sale"), 1)
bagsFull = true
TakeInboxItem(3, 1); update()           -- bags full: the item stays in the mail
check("failed take records nothing", #events("purchase"), 0)
now = now + 80
bagsFull = false
TakeInboxItem(3, 1); update()
check("retry after a failed take counts once", #events("purchase"), 1)
local buy = events("purchase")[1]
check("purchase recorded", buy and buy[4], "4306")
check("purchase quantity", buy[6], "12")
check("purchase cost", buy[7], "2400")
AutoLootMailItem(4); update()
local exp = events("expired")[1]
check("expired recorded", exp and exp[5], "Linen Cloth")
check("expired lost deposit", exp[8], "200")
check("expired auction id", exp[11], "555003")
TakeInboxMoney(5); update()
TakeInboxMoney(6); update()
check("ordinary mail ignored", #WowfahLedgerDB.events, 6)
DeleteInboxItem(2); update()
check("deleting an emptied mail records nothing", #events("sale"), 1)

-- next session: the emptied sale mail is still in the inbox, a fresh addon state
local saved = WowfahLedgerDB
local ns2 = {}
for file in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile("WowfahLedger/" .. file))("WowfahLedger", ns2) end
WowfahLedgerDB = saved
ns2.frame.onOnEvent(ns2.frame, "ADDON_LOADED", "WowfahLedger")
ns2.frame.onOnEvent(ns2.frame, "PLAYER_LOGIN")
local function update2() ns2.frame.onOnEvent(ns2.frame, "MAIL_INBOX_UPDATE") end
inbox = { { subject = "Auction successful: Mithril Bar", money = 0,
            invoice = { type = "seller", name = "Mithril Bar", bid = 22000, deposit = 100, cut = 1100, count = 20 } } }
ns2.frame.onOnEvent(ns2.frame, "MAIL_SHOW")
TakeInboxMoney(1); update2()
DeleteInboxItem(1); update2()
check("same mail next session not recounted", #events("sale"), 1)

-- a cancelled auction and a second identical-looking sale at a different time
now = now + 600
ns2.frame.onOnEvent(ns2.frame, "MAIL_CLOSED")
inbox = {
  { subject = "Auction cancelled: Lionheart Helm", item = { id = 12640, name = "Lionheart Helm", count = 1 } },
  { subject = "Auction successful: Mithril Bar", money = 21000, invoice = { type = "seller", name = "Mithril Bar", bid = 22000, deposit = 100, cut = 1100, count = 20 } },
}
ns2.frame.onOnEvent(ns2.frame, "MAIL_SHOW")
TakeInboxItem(1, 1); update2()
TakeInboxMoney(2); update2()
check("cancelled recorded", #events("cancelled"), 1)
check("cancelled lost deposit", events("cancelled")[1][8], "150")
check("later identical sale is a new sale", #events("sale"), 2)

-- a posting that sells in two lots, then the rest comes back in several stacks
ns2.frame.onOnEvent(ns2.frame, "MAIL_CLOSED")
ns2._posting.onPostCommodity({ id = 10940, name = "Strange Dust" }, 2, 20, 169)
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_AUCTION_CREATED", 777001)
ns2._posting.onPostCommodity({ id = 10940, name = "Strange Dust" }, 2, 83, 137)
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_AUCTION_CREATED", 777002)
local posted = events("posted")
check("posted row carries the auction id", posted[#posted][11], "777002")
check("two events of one kind are still two rows", #posted, 5)
local two = { id = 1470, name = "Murloc Skin Bag", count = 1 }
inbox = {
  { subject = "Auction successful: Strange Dust", money = 6400, invoice = { type = "seller", name = "Strange Dust", bid = 6713, deposit = 245, cut = 335, count = 49 } },
  { subject = "Auction expired: Strange Dust", items = { { id = 10940, name = "Strange Dust", count = 20 }, { id = 10940, name = "Strange Dust", count = 14 } } },
  { subject = "Auction won: Linen Cloth", invoice = { type = "buyer", name = "Linen Cloth", bid = 6715, deposit = 0, cut = 0, count = 60 },
    items = { { id = 2589, name = "Linen Cloth", count = 20 }, { id = 2589, name = "Linen Cloth", count = 20 }, { id = 2589, name = "Linen Cloth", count = 20 } } },
  { subject = "Auction won: Murloc Skin Bag", item = { id = 1470, name = "Murloc Skin Bag", count = 1 }, invoice = { type = "buyer", name = "Murloc Skin Bag", bid = 1998, deposit = 0, cut = 0, count = 1 } },
  { subject = "Auction won: Murloc Skin Bag", item = { id = 1470, name = "Murloc Skin Bag", count = 1 }, invoice = { type = "buyer", name = "Murloc Skin Bag", bid = 1998, deposit = 0, cut = 0, count = 1 } },
}
ns2.frame.onOnEvent(ns2.frame, "MAIL_SHOW")
local before = #events("purchase")
TakeInboxMoney(1); update2()
local lot = events("sale"); lot = lot[#lot]
check("part sale matched to the posting at that price", lot[11], "777002")
check("part sale quantity", lot[6], "49")
TakeInboxItem(2, 1); update2()
check("a mail with stacks left is not recorded yet", #events("expired"), 1)
TakeInboxItem(2, 2); update2()
local back = events("expired"); back = back[#back]
check("expired quantity adds up the stacks", back[6], "34")
check("expired auction id", back[11], "777002")
check("deposit lost is the unsold share", back[8], tostring(math.floor(415 * 34 / 83 + 0.5)))
TakeInboxItem(3, 1); TakeInboxItem(3, 2); TakeInboxItem(3, 3); update2()
local big = events("purchase"); big = big[#big]
check("large purchase uses the invoice quantity", big[6], "60")
bagsFull = true
TakeInboxItem(4, 1); update2()
bagsFull = false
now = now + 80
TakeInboxItem(4, 1); table.remove(inbox, 4); update2()   -- the game removes an emptied purchase mail
TakeInboxItem(4, 1); table.remove(inbox, 4); update2()
check("two identical purchases, one failed take: two rows", #events("purchase") - before, 3)
inbox[#inbox + 1] = { subject = "Retrieving data" }
update2(); update2()
check("a loading mail records nothing", #events("purchase") - before, 3)

-- summary: 2 sales of 22000, cuts 2200, lost deposits 200 + 150, purchase 2400
local s = ns2.Summarise(0)
check("summary sales", s.sales, 44000 + 6713)
check("summary fees", s.fees, 2200 + 335)
check("summary lost deposits", s.lost, 350 + 170)
check("summary bought", s.bought, 2400 + 6715 + 1998 * 2)
check("summary profit", s.profit, s.sales - s.fees - s.lost - s.bought)
check("money format", ns2.FormatMoney(1234567), "123g 45s 67c")
check("money format negative", ns2.FormatMoney(-250), "-2s 50c")

-- browsing and own auctions
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_SHOW")
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check("price sightings (zero price skipped, repeats skipped)", #WowfahLedgerDB.sightings, 1)
ns2.frame.onOnEvent(ns2.frame, "OWNED_AUCTIONS_UPDATED")
ns2.frame.onOnEvent(ns2.frame, "OWNED_AUCTIONS_UPDATED")
check("owned auction ids (5 posted + 2 listed, no repeats)", #WowfahLedgerDB.owned, 7)

-- chat line, slash commands, export
ns2.frame.onOnEvent(ns2.frame, "CHAT_MSG_SYSTEM", "A buyer has been found for your auction of Mithril Bar.")
check("sold message counted", WowfahLedgerDB.debug.soldMessages, 1)
SlashCmdList["WOWFAH"]("debug")
check("debug stored", WowfahLedgerDB.debug.UnitFullName, "Thrall / ForeverPvE1")
SlashCmdList["WOWFAH"]("share off")
check("share off", WowfahLedgerDB.share, false)
SlashCmdList["WOWFAH"]("")
SlashCmdList["WOWFAH"]("export")
local code = ns2.BuildExport()
check("plain export prefix when no compressor", code:sub(1, 5), "WFL0:")
check("export has events", select(2, code:gsub("\nE|", "")), #WowfahLedgerDB.events)
check("export header carries share flag", code:match("^WFL0:V|1|[%d%.]+|(%d)|"), "0")
ns2.frame.onOnEvent(ns2.frame, "PLAYER_LOGOUT")

-- ---- loot: nothing is recorded until the player says yes ----
local db = WowfahLedgerDB
local function creature(id, n) return ("Creature-0-4444-1-12-%d-%010X"):format(id, n) end
local function row(t, key) local f = {}; for part in ((t[key] or "") .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end; return f end
check("loot question asked once at login", popup ~= nil, true)
check("loot undecided at first", db.lootShare, nil)
check("install label made", #db.install, 12)
units.target = { guid = creature(3273, 1), level = 12, class = "normal" }; targetGUID = units.target.guid
UnitName = function(u) if u == "target" then return "Kolkar Stormer" end; if u == "npc" then return "Wrahk" end; return "Thrall" end
fire("PLAYER_TARGET_CHANGED")
lootWindow = { { id = 2589, name = "Linen Cloth", qty = 2, src = { creature(3273, 1), 2 } } }
fire("LOOT_READY"); fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("nothing recorded before consent", next(db.lootSrc), nil)
popup.OnAccept()
check("consent stored", db.lootShare, true)

fire("LOOT_READY"); fire("LOOT_OPENED"); fire("LOOT_CLOSED")
local key = "c:3273:1454:0"
check("creature source row", db.lootSrc[key], "Kolkar Stormer|The Barrens|The Crossroads||12|normal||1")
check("drop counted once for ready and opened", db.lootItems[key .. ":2589"], "1|2|0")
fire("LOOT_READY"); fire("LOOT_CLOSED")
check("same corpse opened again is not counted twice", row(db.lootSrc, key)[8], "1")
-- area loot: two corpses in one window, one of them a creature never targeted, plus coin
lootWindow = {
  { money = true, src = { creature(3273, 2), 1, creature(3274, 3), 1 } },
  { id = 2589, name = "Linen Cloth", qty = 3, src = { creature(3273, 2), 1, creature(3274, 3), 2 } },
  { id = 4306, name = "Silk Cloth", qty = 1, quest = true, src = { creature(3274, 3), 1 } },
}
fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("second kill of the same creature", row(db.lootSrc, key)[8], "2")
check("drops and quantity add up", db.lootItems[key .. ":2589"], "2|3|0")
check("unseen creature still recorded by id", row(db.lootSrc, "c:3274:1454:0")[8], "1")
check("quest item flagged", db.lootItems["c:3274:1454:0:4306"], "1|1|1")
-- a corpse with only coin still counts as looted
lootWindow = { { money = true, src = { creature(3273, 9), 1 } } }
fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("coin only corpse counts towards the total", row(db.lootSrc, key)[8], "3")
-- mining a node: the cast names the node and the spell
fire("UNIT_SPELLCAST_SENT", "player", "Copper Vein", "cast-1", 2575)
lootWindow = { { id = 2770, name = "Copper Ore", qty = 3, src = { "GameObject-0-4444-1-12-1731-0000000001", 3 } } }
fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("node source", db.lootSrc["o:1731:1454:2575"]:match("^Copper Vein|The Barrens|"), "Copper Vein|The Barrens|")
check("node drop", db.lootItems["o:1731:1454:2575:2770"], "1|3|0")
-- skinning: the same creature id with a spell is a different source from killing it
now = now + 60
fire("UNIT_SPELLCAST_SENT", "player", "Kolkar Stormer", "cast-2", 8613)
lootWindow = { { id = 2318, name = "Light Leather", qty = 1, src = { creature(3273, 77), 1 } } }
fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("skinning kept apart from kill loot", db.lootItems["c:3273:1454:8613:2318"], "1|1|0")
-- fishing: no source id, keyed by map; two catches are two casts
now = now + 60
fishingLoot = true
lootWindow = { { id = 6291, name = "Raw Brilliant Smallfish", qty = 1, src = {} } }
fire("LOOT_OPENED"); fire("LOOT_CLOSED"); fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("fishing counted per catch", db.lootItems["f:0:1454:0:6291"], "2|2|0")
check("fishing casts", row(db.lootSrc, "f:0:1454:0")[8], "2")
fishingLoot = false
-- opening a container from the bags
bagItems["0:3"] = 5523
C_Container.UseContainerItem(0, 3)
lootWindow = { { id = 5498, name = "Small Lustrous Pearl", qty = 1, src = { "Item-4444-0-4000000A1B2C3D4E", 1 } } }
fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("container loot credited to the item opened", db.lootItems["i:5523:1454:0:5498"], "1|1|0")
-- a vendor
units.npc = { guid = creature(3489, 5) }
merchant = { { id = 2320, name = "Coarse Thread", price = 10 }, { id = 6270, name = "Pattern: Blue Linen Vest", price = 200, avail = 1 } }
fire("MERCHANT_SHOW")
check("vendor row", db.vendors["3489:1454"]:match("^Wrahk|The Barrens|The Crossroads|"), "Wrahk|The Barrens|The Crossroads|")
check("vendor price", db.vendorItems["3489:2320"], "10|1|-1|0")
check("vendor limited stock", db.vendorItems["3489:6270"], "200|1|1|0")
-- a quest reward window
quest = { id = 870, title = "The Forgotten Pools", rewards = { { id = 4306, qty = 2 } }, choices = { { id = 2589 }, { id = 2770 } } }
fire("QUEST_COMPLETE")
check("quest rewards", db.quests["870"], "The Forgotten Pools|10|The Barrens|4306:2|2589:1,2770:1")
-- export carries the loot only while sharing is on
local lines = table.concat(ns.BuildLines(), "\n")
check("export header has loot flag and install", lines:match("^V|1|[%d%.]+|%d|%d+|1|(%x+)"), db.install)
check("export loot line", lines:find("L|c|3273|1454|0|Kolkar Stormer|The Barrens|The Crossroads||12|normal||3", 1, true) ~= nil, true)
check("export item line", lines:find("I|c|3273|1454|0|2589|2|3|0", 1, true) ~= nil, true)
check("export vendor item line", lines:find("N|3489|2320|10|1|-1|0", 1, true) ~= nil, true)
check("export quest line", lines:find("Q|870|The Forgotten Pools|", 1, true) ~= nil, true)
SlashCmdList["WOWFAH"]("loot off")
check("loot off stops the export", table.concat(ns.BuildLines(), "\n"):find("\nL|", 1, true), nil)
lootWindow = { { id = 2589, name = "Linen Cloth", qty = 1, src = { creature(3273, 500), 1 } } }
fire("LOOT_OPENED"); fire("LOOT_CLOSED")
check("loot off stops recording", row(db.lootSrc, key)[8], "3")
SlashCmdList["WOWFAH"]("loot on")

-- ---- opening the ledger without commands ----
check("minimap button setting exists", type(db.minimap), "table")
check("welcome shown once", db.welcomed, true)
check("addon list entry opens the ledger", type(WowfahLedger_OnAddonCompartmentClick), "function")
WowfahLedger_OnAddonCompartmentClick("WowfahLedger", "LeftButton")
WowfahLedger_OnAddonCompartmentClick("WowfahLedger", "RightButton")
SlashCmdList["WOWFAH"]("minimap")
check("minimap button can be hidden", db.minimap.hide, true)
SlashCmdList["WOWFAH"]("minimap")
check("and shown again", db.minimap.hide, false)
check("today line", ns.TodayLine():match("^Today: profit ") ~= nil, true)
fire("AUCTION_HOUSE_SHOW"); fire("MAIL_SHOW")

-- write the saved file the way the game would, for the website's parser tests
local function dump(v, indent)
  if type(v) == "table" then
    local out = { "{\n" }
    local n = #v
    for i = 1, n do out[#out + 1] = indent .. "\t" .. dump(v[i], indent .. "\t") .. ", -- [" .. i .. "]\n" end
    local keys = {}
    for k in pairs(v) do if not (type(k) == "number" and k >= 1 and k <= n) then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do out[#out + 1] = indent .. '\t["' .. tostring(k) .. '"] = ' .. dump(v[k], indent .. "\t") .. ",\n" end
    out[#out + 1] = indent .. "}"
    return table.concat(out)
  elseif type(v) == "string" then return string.format("%q", v)
  else return tostring(v) end
end
local f = io.open("tests/fixture_WowfahLedger.lua", "w")
f:write("\nWowfahLedgerDB = " .. dump(WowfahLedgerDB, "") .. "\n")
f:close()
local c = io.open("tests/fixture_export.txt", "w"); c:write(code); c:close()

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
