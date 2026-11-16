-- The ledger's numbers. Saved rows are parsed once and kept; every view (the window, the minimap tooltip,
-- the bar text) asks here, so they always agree.

local _, ns = ...

local parsed, parsedCount, parsedLast

-- every recorded event, oldest first: { kind, ts, char, id, name, qty, gross, deposit, cut, auction }
function ns.Events()
  local raw = ns.db.events
  local n = #raw
  if parsed and parsedCount == n and parsedLast == raw[n] then return parsed end
  local out = {}
  for i = 1, n do
    local kind, ts, char, id, name, qty, gross, deposit, cut, _, auction = raw[i]:match(
      "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if kind then
      out[#out + 1] = { kind = kind, ts = tonumber(ts) or 0, char = char, id = tonumber(id) or 0, name = name or "",
        qty = tonumber(qty) or 1, gross = tonumber(gross) or 0, deposit = tonumber(deposit) or 0,
        cut = tonumber(cut) or 0, auction = tonumber(auction) or 0 }
    end
  end
  parsed, parsedCount, parsedLast = out, n, raw[n]
  return out
end

function ns.InvalidateData()
  parsed = nil
end

function ns.StartOfDay(ts)
  local d = date("*t", ts)
  return ts - (d.hour * 3600 + d.min * 60 + d.sec)
end

-- the periods every view offers
function ns.Periods()
  local now = time()
  return { { "Today", ns.StartOfDay(now) }, { "7 days", now - 7 * 86400 }, { "30 days", now - 30 * 86400 }, { "All time", 0 } }
end

-- which character's rows count: the one asked for, or this one when "this character only" is ticked
local function wanted(char)
  if char == nil and ns.onlyThisCharacter then char = ns.charKey end
  return char
end

local function tally(s, e)
  if e.kind == "sale" then
    s.sales, s.fees, s.nSales, s.sold = s.sales + e.gross, s.fees + e.cut, s.nSales + 1, s.sold + e.qty
  elseif e.kind == "purchase" then
    s.bought, s.nBought, s.boughtQty = s.bought + e.gross, s.nBought + 1, s.boughtQty + e.qty
  elseif e.kind == "expired" or e.kind == "cancelled" then
    s.lost, s.failed = s.lost + e.deposit, s.failed + 1
  elseif e.kind == "posted" then
    s.posted = s.posted + 1
  end
end

local function blank()
  return { sales = 0, fees = 0, lost = 0, bought = 0, nSales = 0, nBought = 0, sold = 0, boughtQty = 0, failed = 0, posted = 0 }
end

local function finish(s)
  -- profit = sales - auction house cut - deposits lost on unsold auctions - purchases
  s.profit = s.sales - s.fees - s.lost - s.bought
  return s
end

function ns.Summarise(sinceTime, char)
  char = wanted(char)
  local s = blank()
  for _, e in ipairs(ns.Events()) do
    if e.ts >= sinceTime and (not char or e.char == char) then tally(s, e) end
  end
  return finish(s)
end

-- one row per item, best profit first
function ns.ByItem(sinceTime, char)
  char = wanted(char)
  local map, list = {}, {}
  for _, e in ipairs(ns.Events()) do
    if e.ts >= sinceTime and (not char or e.char == char) then
      local key = e.id > 0 and e.id or e.name
      local s = map[key]
      if not s then
        s = blank()
        s.id, s.name = e.id, e.name
        map[key] = s
        list[#list + 1] = s
      end
      if s.name == "" then s.name = e.name end
      tally(s, e)
    end
  end
  for _, s in ipairs(list) do finish(s) end
  table.sort(list, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.name < b.name end)
  return list
end

-- the last `days` days, oldest first, each { day = midnight, profit, sales, bought }
function ns.ByDay(days, char)
  char = wanted(char)
  local today = ns.StartOfDay(time())
  local out, at = {}, {}
  for i = days - 1, 0, -1 do
    local row = blank()
    row.day = ns.StartOfDay(today - i * 86400 + 43200)      -- noon, so a clock change cannot skip a day
    out[#out + 1] = row
    at[row.day] = row
  end
  local first = out[1].day
  for _, e in ipairs(ns.Events()) do
    if e.ts >= first and (not char or e.char == char) then
      local row = at[ns.StartOfDay(e.ts)]
      if row then tally(row, e) end
    end
  end
  for _, row in ipairs(out) do finish(row) end
  return out
end

function ns.ByCharacter(sinceTime)
  local map, list = {}, {}
  for _, e in ipairs(ns.Events()) do
    if e.ts >= sinceTime then
      local s = map[e.char]
      if not s then
        s = blank()
        s.char = e.char
        map[e.char] = s
        list[#list + 1] = s
      end
      tally(s, e)
    end
  end
  for _, s in ipairs(list) do finish(s) end
  table.sort(list, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.char < b.char end)
  return list
end

-- newest first, without the "posted" rows; kind and text narrow it
function ns.Recent(limit, char, kind, search)
  char = wanted(char)
  search = search and search ~= "" and search:lower() or nil
  local out, all = {}, ns.Events()
  for i = #all, 1, -1 do
    local e = all[i]
    if e.kind ~= "posted" and (not char or e.char == char) and (not kind or e.kind == kind)
      and (not search or e.name:lower():find(search, 1, true)) then
      out[#out + 1] = e
      if limit and #out >= limit then break end
    end
  end
  return out
end

function ns.TodayLine()
  local s = ns.Summarise(ns.Periods()[1][2])
  return string.format("Today: profit %s from %d sale%s", ns.FormatMoney(s.profit), s.nSales, s.nSales == 1 and "" or "s")
end
