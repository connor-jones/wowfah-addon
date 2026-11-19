-- What your own records say about an item: what you sold it for, what you paid, the lowest price you last saw at the
-- auction house, what you are still holding and how your own auctions compare. Everything here comes from this
-- computer. The one exception is ns.SitePrice, which reads the short list of prices the wowfah Sync app leaves for the
-- items on your wowfah.com watchlist and in your ledger.

local _, ns = ...

-- ---- per item, from the ledger ----
local stats, statsFor

-- itemID -> { soldQty, soldGross, nSales, lastSale (each), lastSaleAt, boughtQty, boughtGross, lastBuy (each), lastBuyAt, name }
local function build()
  local all = ns.Events()
  if stats and statsFor == all then return stats end
  local map = {}
  for i = 1, #all do
    local e = all[i]
    if e.id > 0 and e.qty > 0 and (e.kind == "sale" or e.kind == "purchase") and e.gross > 0 then
      local s = map[e.id]
      if not s then
        s = { soldQty = 0, soldGross = 0, nSales = 0, boughtQty = 0, boughtGross = 0, name = e.name }
        map[e.id] = s
      end
      if s.name == "" then s.name = e.name end
      if e.kind == "sale" then
        s.soldQty, s.soldGross, s.nSales = s.soldQty + e.qty, s.soldGross + e.gross, s.nSales + 1
        s.lastSale, s.lastSaleAt = e.gross / e.qty, e.ts
      else
        s.boughtQty, s.boughtGross = s.boughtQty + e.qty, s.boughtGross + e.gross
        s.lastBuy, s.lastBuyAt = e.gross / e.qty, e.ts
      end
    end
  end
  stats, statsFor = map, all
  return map
end

function ns.ItemStats(itemID)
  if not (ns.db and itemID) then return nil end
  return build()[itemID]
end

-- ---- the lowest price you last saw for an item, from your own browsing ----
local seen

local function seenIndex()
  if seen then return seen end
  seen = {}
  local rows = ns.db and ns.db.sightings or {}
  for i = 1, #rows do
    local ts, _, _, id, price = rows[i]:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    id, price, ts = tonumber(id), tonumber(price), tonumber(ts)
    if id and price and ts and (not seen[id] or ts >= seen[id][2]) then seen[id] = { price, ts } end
  end
  return seen
end

function ns.NoteSighting(itemID, price, when)
  if ns.db then seenIndex()[itemID] = { price, when } end
end

-- -> price each, time seen (or nil)
function ns.LastSeen(itemID)
  if not (ns.db and itemID) then return nil end
  local s = seenIndex()[itemID]
  if s then return s[1], s[2] end
  return nil
end

-- ---- prices from wowfah.com for your own watchlist and ledger items (only with the wowfah Sync app) ----
-- -> price each, time of the snapshot (or nil). A list older than a day and a half is not shown as current.
function ns.SitePrice(itemID)
  local t = WowfahPrices
  if type(t) ~= "table" or type(t.p) ~= "table" or type(t.at) ~= "number" then return nil end
  if time() - t.at > 36 * 3600 then return nil end
  local p = t.p[itemID]
  if type(p) == "number" and p > 0 then return p, t.at end
  return nil
end

-- ---- how long ago, in a few characters ----
function ns.Ago(ts)
  local s = math.max(0, time() - (ts or 0))
  if s < 90 then return "just now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 2 * 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " days ago"
end

-- ---- bought and not sold again: { id, name, qty, cost (what the unsold part cost), each } best first ----
function ns.Holding(char)
  if char == nil and ns.onlyThisCharacter then char = ns.charKey end
  local map, list = {}, {}
  for _, e in ipairs(ns.Events()) do
    if (e.kind == "purchase" or e.kind == "sale") and (not char or e.char == char) then
      local key = e.id > 0 and e.id or e.name
      local s = map[key]
      if not s then
        s = { id = e.id, name = e.name, bought = 0, paid = 0, sold = 0 }
        map[key] = s
      end
      if e.kind == "purchase" then s.bought, s.paid = s.bought + e.qty, s.paid + e.gross else s.sold = s.sold + e.qty end
    end
  end
  for _, s in pairs(map) do
    local left = s.bought - s.sold
    if left > 0 and s.bought > 0 then
      local each = s.paid / s.bought
      list[#list + 1] = { id = s.id, name = s.name, qty = left, each = each, cost = each * left }
    end
  end
  table.sort(list, function(a, b) if a.cost ~= b.cost then return a.cost > b.cost end return a.name < b.name end)
  return list
end

-- ---- your own auctions as the game last listed them, against the lowest price you last saw ----
ns.ownedNow = {}      -- auctionID -> { id, name, qty, each, left (seconds), sold }

-- rows { id, name, qty, each, left, low, lowAt, beaten }: beaten ones first, then by time left
function ns.MyAuctions()
  local out = {}
  for _, a in pairs(ns.ownedNow) do
    if not a.sold then
      local low, lowAt = ns.LastSeen(a.id)
      local beaten = (low and a.each and a.each > 0 and low < a.each) and true or false
      out[#out + 1] = { id = a.id, name = a.name, qty = a.qty, each = a.each, left = a.left, low = low, lowAt = lowAt, beaten = beaten }
    end
  end
  table.sort(out, function(a, b)
    if a.beaten ~= b.beaten then return a.beaten end
    if (a.left or 0) ~= (b.left or 0) then return (a.left or 0) < (b.left or 0) end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

function ns.BeatenCount()
  local n, total = 0, 0
  for _, a in ipairs(ns.MyAuctions()) do
    total = total + 1
    if a.beaten then n = n + 1 end
  end
  return n, total
end

-- ---- what has been recorded since the ledger last went to the site ----
-- -> number of new records, time of the last upload we know of (or nil when nothing has gone up from this computer)
function ns.NotUploaded()
  local mark = ns.db and ns.db.exportedAt or 0
  local app = WowfahSyncApp
  if type(app) == "table" and type(app.uploaded) == "number" and app.uploaded > mark then mark = app.uploaded end
  local n, all = 0, ns.Events()
  for i = #all, 1, -1 do
    if all[i].ts <= mark then break end
    n = n + 1
  end
  return n, mark > 0 and mark or nil
end

-- ---- gold: a reading at login and logout, so the site can chart it. At most one an hour while playing. ----
function ns.NoteGold(force)
  if not (ns.db and GetMoney) then return end
  local copper = ns.Try(GetMoney)
  if type(copper) ~= "number" then return end
  local list, now = ns.db.gold, time()
  local last = list[#list]
  if last and not force then
    local ts, char, was = last:match("^([^|]*)|([^|]*)|([^|]*)")
    if char == (ns.charKey or "") and (tonumber(was) == copper or now - (tonumber(ts) or 0) < 3600) then return end
  end
  -- time|character|copper
  list[#list + 1] = ns.Row(now, ns.charKey or "", copper)
end

function ns.InvalidateInsight()
  stats, seen = nil, nil
end
