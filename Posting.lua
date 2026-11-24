-- Records what you post: item, quantity, price and the deposit you paid.
-- Sale and expiry mail only names the item, so these records supply the item id and the deposit later.

local _, ns = ...

local pending   -- the posting waiting for its auction id from AUCTION_HOUSE_AUCTION_CREATED

local function remember(itemID, name, qty, total, deposit, duration)
  if not name or name == "" then return end
  -- name|itemID|qty|deposit|auctionID|time|total
  local row = ns.Row(name, itemID or 0, qty or 1, deposit or 0, 0, time(), total or 0)
  table.insert(ns.db.postings, row)
  pending = { index = #ns.db.postings, name = name, itemID = itemID or 0, qty = qty or 1, total = total or 0, deposit = deposit or 0 }
  -- the auction length goes on the end of the row, so the website can tell which length pays which deposit
  ns.AddEvent("posted", itemID, name, qty, total, deposit, 0, 0, 0, nil, tonumber(duration) or 0)
  pending.event = #ns.db.events
end

local function itemInfo(location)
  if not (C_Item and location) then return nil end
  local itemID = ns.Try(C_Item.GetItemID, location)
  local name = ns.Try(C_Item.GetItemName, location)
  if (not name) and itemID then name = ns.Try(C_Item.GetItemNameByID, itemID) end
  return itemID, name
end

local function onPostItem(location, duration, quantity, bid, buyout)
  local itemID, name = itemInfo(location)
  local deposit = C_AuctionHouse.CalculateItemDeposit and ns.Try(C_AuctionHouse.CalculateItemDeposit, location, duration, quantity) or 0
  remember(itemID, name, quantity or 1, (buyout or bid or 0), deposit, duration)
end

local function onPostCommodity(location, duration, quantity, unitPrice)
  local itemID, name = itemInfo(location)
  local deposit = 0
  if itemID and C_AuctionHouse.CalculateCommodityDeposit then
    deposit = ns.Try(C_AuctionHouse.CalculateCommodityDeposit, itemID, duration, quantity) or 0
  end
  remember(itemID, name, quantity or 1, (unitPrice or 0) * (quantity or 1), deposit, duration)
end

function ns.InstallHooks()
  if ns.InstallMailHooks then ns.InstallMailHooks() end
  if ns.postHooked or not (hooksecurefunc and C_AuctionHouse) then return end
  ns.postHooked = true
  if C_AuctionHouse.PostItem then hooksecurefunc(C_AuctionHouse, "PostItem", function(...) pcall(onPostItem, ...) end) end
  if C_AuctionHouse.PostCommodity then hooksecurefunc(C_AuctionHouse, "PostCommodity", function(...) pcall(onPostCommodity, ...) end) end
end

-- the game reports the new auction's id just after posting: attach it to the posting we just stored
ns.On("AUCTION_HOUSE_AUCTION_CREATED", function(auctionID)
  if not (pending and auctionID) then return end
  local list = ns.db.postings
  if list[pending.index] then
    list[pending.index] = ns.Row(pending.name, pending.itemID, pending.qty, pending.deposit, auctionID, time(), pending.total)
  end
  -- and to the "posted" row, so the website can tell which of your auctions are still up
  local ev = ns.db.events[pending.event]
  if ev and ev:match("^posted|") then
    local f = {}
    for part in (ev .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end
    if f[11] == "0" then f[11] = tostring(auctionID); ns.db.events[pending.event] = table.concat(f, ns.SEP) end
  end
  table.insert(ns.db.owned, ns.Row(auctionID, pending.itemID, time(), ns.charKey or "", ns.MapID()))
  pending = nil
end)

ns._posting = { onPostItem = onPostItem, onPostCommodity = onPostCommodity, remember = remember }
