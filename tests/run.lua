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
GetInboxHeaderInfo = function(i)
  local m = inbox[i]; if not m then return nil end
  return nil, nil, "Auction House", m.subject, m.money or 0, 0, m.daysLeft or 29.5, m.item and 1 or 0
end
GetInboxInvoiceInfo = function(i)
  local m = inbox[i]; if not (m and m.invoice) then return nil end
  local v = m.invoice
  return v.type, v.name, nil, v.bid, v.buyout, v.deposit, v.cut, 0, 0, 0, v.count
end
GetInboxItem = function(i) local m = inbox[i]; if m and m.item then return m.item.name, nil, nil, m.item.count end end
GetInboxItemLink = function(i) local m = inbox[i]; if m and m.item then return "|Hitem:" .. m.item.id .. "::::|h[" .. m.item.name .. "]|h" end end
TakeInboxMoney = function(i) if inbox[i] then inbox[i].money = 0 end end
TakeInboxItem = function(i) if inbox[i] then inbox[i].item = nil end end
AutoLootMailItem = function(i) end
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
TakeInboxMoney(1)                       -- pending notice: nothing to record
check("pending sale ignored", #events("sale"), 0)
TakeInboxMoney(2)
local sale = events("sale")[1]
check("sale recorded", sale ~= nil, true)
check("sale item id from posting", sale[4], "3860")
check("sale quantity", sale[6], "20")
check("sale gross", sale[7], "22000")
check("sale cut", sale[9], "1100")
check("sale net of cut", sale[10], "20900")
check("sale auction id", sale[11], "555002")
fire("MAIL_INBOX_UPDATE")               -- the same mail is still listed until it is deleted
TakeInboxMoney(2)
check("sale not counted twice", #events("sale"), 1)
TakeInboxItem(3, 1)
local buy = events("purchase")[1]
check("purchase recorded", buy and buy[4], "4306")
check("purchase quantity", buy[6], "12")
check("purchase cost", buy[7], "2400")
AutoLootMailItem(4)
local exp = events("expired")[1]
check("expired recorded", exp and exp[5], "Linen Cloth")
check("expired lost deposit", exp[8], "200")
check("expired auction id", exp[11], "555003")
TakeInboxMoney(5)
TakeInboxMoney(6)
check("ordinary mail ignored", #WowfahLedgerDB.events, 6)

-- next session: same sale mail still in the inbox, a fresh addon state
local saved = WowfahLedgerDB
local ns2 = {}
for file in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile("WowfahLedger/" .. file))("WowfahLedger", ns2) end
WowfahLedgerDB = saved
ns2.frame.onOnEvent(ns2.frame, "ADDON_LOADED", "WowfahLedger")
ns2.frame.onOnEvent(ns2.frame, "PLAYER_LOGIN")
inbox = { { subject = "Auction successful: Mithril Bar", money = 21000, daysLeft = 29.5 - 3700 / 86400 + 3700 / 86400,
            invoice = { type = "seller", name = "Mithril Bar", bid = 22000, deposit = 100, cut = 1100, count = 20 } } }
ns2.frame.onOnEvent(ns2.frame, "MAIL_SHOW")
TakeInboxMoney(1)
check("same mail next session not recounted", #events("sale"), 1)

-- a cancelled auction and a second identical-looking sale at a different time
now = now + 600
inbox = {
  { subject = "Auction cancelled: Lionheart Helm", item = { id = 12640, name = "Lionheart Helm", count = 1 } },
  { subject = "Auction successful: Mithril Bar", money = 21000, invoice = { type = "seller", name = "Mithril Bar", bid = 22000, deposit = 100, cut = 1100, count = 20 } },
}
ns2.frame.onOnEvent(ns2.frame, "MAIL_INBOX_UPDATE")
TakeInboxItem(1, 1)
TakeInboxMoney(2)
check("cancelled recorded", #events("cancelled"), 1)
check("cancelled lost deposit", events("cancelled")[1][8], "150")
check("later identical sale is a new sale", #events("sale"), 2)

-- summary: 2 sales of 22000, cuts 2200, lost deposits 200 + 150, purchase 2400
local s = ns2.Summarise(0)
check("summary sales", s.sales, 44000)
check("summary fees", s.fees, 2200)
check("summary lost deposits", s.lost, 350)
check("summary bought", s.bought, 2400)
check("summary profit", s.profit, 44000 - 2200 - 350 - 2400)
check("money format", ns2.FormatMoney(1234567), "123g 45s 67c")
check("money format negative", ns2.FormatMoney(-250), "-2s 50c")

-- browsing and own auctions
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_SHOW")
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
ns2.frame.onOnEvent(ns2.frame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check("price sightings (zero price skipped, repeats skipped)", #WowfahLedgerDB.sightings, 1)
ns2.frame.onOnEvent(ns2.frame, "OWNED_AUCTIONS_UPDATED")
ns2.frame.onOnEvent(ns2.frame, "OWNED_AUCTIONS_UPDATED")
check("owned auction ids (3 posted + 2 listed, no repeats)", #WowfahLedgerDB.owned, 5)

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
