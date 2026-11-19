-- While the auction house is open, note the ids of your own auctions and the prices you browse past.
-- Your auction ids let wowfah.com work out which auction house (ruleset and faction) you are using.
-- Prices seen are only what the game already showed you; no extra searches are made on your behalf.

local _, ns = ...

local lastSeen = {}   -- itemID -> time, so the same item is noted at most every 10 minutes
local ownedSeen = {}

local function sight(itemID, minPrice, qty)
  if not itemID or not minPrice or minPrice <= 0 then return end
  local now = time()
  if lastSeen[itemID] and now - lastSeen[itemID] < 600 then return end
  lastSeen[itemID] = now
  -- time|character|map|itemID|minPrice|quantity
  table.insert(ns.db.sightings, ns.Row(now, ns.charKey or "", ns.MapID(), itemID, minPrice, qty or 0))
  if ns.NoteSighting then ns.NoteSighting(itemID, minPrice, now) end
end

ns.On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
  local results = C_AuctionHouse and C_AuctionHouse.GetBrowseResults and ns.Try(C_AuctionHouse.GetBrowseResults)
  if type(results) ~= "table" then return end
  for i = 1, #results do
    local r = results[i]
    if r and r.itemKey then sight(r.itemKey.itemID, r.minPrice, r.totalQuantity) end
  end
end)

ns.On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if not (itemID and C_AuctionHouse and C_AuctionHouse.GetCommoditySearchResultInfo) then return end
  local r = ns.Try(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, 1)
  local total = C_AuctionHouse.GetCommoditySearchResultsQuantity and ns.Try(C_AuctionHouse.GetCommoditySearchResultsQuantity, itemID)
  if type(r) == "table" then sight(itemID, r.unitPrice, total or r.quantity) end
end)

local function readOwned()
  if not (C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetOwnedAuctionInfo) then return end
  local n = ns.Try(C_AuctionHouse.GetNumOwnedAuctions) or 0
  local now = {}
  for i = 1, n do
    local info = ns.Try(C_AuctionHouse.GetOwnedAuctionInfo, i)
    if type(info) == "table" and info.auctionID then
      local itemID = info.itemKey and info.itemKey.itemID or 0
      local qty = tonumber(info.quantity) or 1
      local each = tonumber(info.buyoutAmount) or 0          -- the game gives the buyout for one
      local name = info.itemLink and tostring(info.itemLink):match("%[(.-)%]")
      if not name and itemID > 0 then name = (C_Item and C_Item.GetItemInfo and ns.Try(C_Item.GetItemInfo, itemID)) or (GetItemInfo and ns.Try(GetItemInfo, itemID)) end
      now[info.auctionID] = { id = itemID, name = name or ("item " .. itemID), qty = qty, each = each,
        left = tonumber(info.timeLeftSeconds), sold = info.status == 1 }
      if not ownedSeen[info.auctionID] then
        ownedSeen[info.auctionID] = true
        -- auctionID|itemID|time|character|map|price each|quantity
        table.insert(ns.db.owned, ns.Row(info.auctionID, itemID, time(), ns.charKey or "", ns.MapID(), each, qty))
      end
    end
  end
  ns.ownedNow = now          -- the whole list as the game has it now, so sold and cancelled auctions drop out
  if ns.RefreshUI then ns.RefreshUI() end
end

ns.On("OWNED_AUCTIONS_UPDATED", readOwned)

ns.On("AUCTION_HOUSE_SHOW", function()
  ns.UpdateCharacter()
  ns.db.debug.lastAH = ns.Row(time(), ns.MapID(), ns.Try(GetRealZoneText) or "", ns.Try(GetSubZoneText) or "",
    ns.Try(UnitName, "npc") or "", ns.Try(UnitGUID, "npc") or "")
  -- ask once for your own auctions so their ids are known (the game does this itself on the Auctions tab)
  if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then ns.Try(C_AuctionHouse.QueryOwnedAuctions, {}) end
end)

ns._prices = { sight = sight, readOwned = readOwned }
