-- Your own numbers where you need them: on item tooltips and beside the price box when you post an auction.
-- Read only. The addon never sets a price, posts, buys or cancels anything.

local _, ns = ...

local function each(copper, when, count)
  local s = ns.Coins(copper)
  if count then s = s .. " each (" .. count .. ")" end
  if when then s = s .. ", " .. ns.Ago(when) end
  return s
end

-- the lines for one item: { { label, text }, ... }. Empty when there is nothing of yours to say about it.
function ns.ItemLines(itemID)
  local out = {}
  if not (ns.db and itemID and itemID > 0) then return out end
  local s = ns.ItemStats(itemID)
  if s and s.soldQty > 0 then out[#out + 1] = { "You sold", each(s.soldGross / s.soldQty, nil, s.soldQty .. " sold") } end
  if s and s.boughtQty > 0 then out[#out + 1] = { "You paid", each(s.boughtGross / s.boughtQty, nil, s.boughtQty .. " bought") } end
  local low, at = ns.LastSeen(itemID)
  if low then out[#out + 1] = { "Lowest you saw", each(low, at) } end
  local site, siteAt = ns.SitePrice(itemID)
  if site then out[#out + 1] = { "wowfah market", each(site, siteAt) } end
  return out
end

local function idFromLink(link)
  return link and tonumber(tostring(link):match("item:(%d+)"))
end

local function add(tooltip, itemID)
  if not (ns.db and ns.db.tips and tooltip and tooltip.AddDoubleLine and itemID) then return end
  local lines = ns.ItemLines(itemID)
  if #lines == 0 then return end
  local C = ns.C
  for i = 1, #lines do
    tooltip:AddDoubleLine(lines[i][1], lines[i][2], C.brass[1], C.brass[2], C.brass[3], 1, 1, 1)
  end
  if tooltip.Show then tooltip:Show() end
end
ns._tooltip = { add = add }

function ns.InstallTooltips()
  if ns.tooltipsOn then return end
  ns.tooltipsOn = true
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    ns.Try(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tooltip, data)
      if tooltip == GameTooltip or tooltip == ItemRefTooltip then pcall(add, tooltip, data and tonumber(data.id)) end
    end)
    return
  end
  for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tooltip and tooltip.HookScript then
      ns.Try(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self)
        local _, link = self:GetItem()
        pcall(add, self, idFromLink(link))
      end)
    end
  end
end

-- ---- beside the price box when you put something up for sale ----
local helpText = {}

function ns.PostingLine(itemID)
  local parts = {}
  if not (itemID and itemID > 0) then return "" end
  local s = ns.ItemStats(itemID)
  if s and s.lastSale then parts[#parts + 1] = "Your last sale " .. ns.Coins(s.lastSale) .. " each" end
  if s and s.nSales > 1 then parts[#parts + 1] = "your average " .. ns.Coins(s.soldGross / s.soldQty) end
  if s and s.boughtQty > 0 then parts[#parts + 1] = "you paid " .. ns.Coins(s.boughtGross / s.boughtQty) end
  local low, at = ns.LastSeen(itemID)
  if low then parts[#parts + 1] = "lowest you saw " .. ns.Coins(low) .. " (" .. ns.Ago(at) .. ")" end
  local site = ns.SitePrice(itemID)
  if site then parts[#parts + 1] = "wowfah market " .. ns.Coins(site) end
  return table.concat(parts, "  |cff7d8a80/|r  ")
end

local function showFor(sellFrame, location)
  local t = helpText[sellFrame]
  if not t then
    t = sellFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("BOTTOMLEFT", sellFrame, "BOTTOMLEFT", 12, 10)
    t:SetPoint("BOTTOMRIGHT", sellFrame, "BOTTOMRIGHT", -12, 10)
    t:SetJustifyH("LEFT")
    helpText[sellFrame] = t
  end
  local itemID = location and C_Item and C_Item.GetItemID and ns.Try(C_Item.GetItemID, location)
  t:SetText(ns.db and ns.db.tips and ns.PostingLine(itemID) or "")
end

local hooked = {}
ns.On("AUCTION_HOUSE_SHOW", function()
  local ah = AuctionHouseFrame
  if type(ah) ~= "table" then return end
  for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
    local f = ah[key]
    if type(f) == "table" and type(f.SetItem) == "function" and not hooked[f] then
      hooked[f] = true
      hooksecurefunc(f, "SetItem", function(self, location) pcall(showFor, self, location) end)
    end
  end
end)

ns.On("PLAYER_LOGIN", function() ns.InstallTooltips() end)

-- ---- once per visit to the auction house: say when browsing has shown a lower price than one of your auctions ----
local told
ns.On("AUCTION_HOUSE_SHOW", function() told = nil end)
ns.On("OWNED_AUCTIONS_UPDATED", function()
  local n = ns.BeatenCount()
  if n > 0 and told ~= n then
    told = n
    ns.Print(string.format("%d of your auctions %s no longer the cheapest you have seen. Open the ledger, My auctions, to see which.",
      n, n == 1 and "is" or "are"))
  end
end)
