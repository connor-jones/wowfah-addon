-- Sales, purchases, expired and cancelled auctions, read from auction house mail.
-- Mail is the only place the game states what an auction actually sold for and what the house kept.
-- A mail is recorded once, at the moment you take its money or item (or delete it), so a mail that sits
-- in the inbox across several sessions is never counted twice.

local _, ns = ...

local cache = {}   -- inbox index -> mail details, rebuilt on every inbox update

-- "Auction expired: %s" -> "^Auction expired: (.+)$"
local function subjectPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")   -- escape pattern characters, leave %s alone
  p = p:gsub("%%s", "(.+)")
  return "^" .. p .. "$"
end

local function matchSubject(subject, fmt)
  local p = subjectPattern(fmt)
  if not p or type(subject) ~= "string" then return nil end
  return subject:match(p)
end
ns.MatchSubject = matchSubject

-- find the player's own posting of this item (oldest first) to recover the item id and the deposit paid
function ns.TakePosting(itemName, consume)
  local list = ns.db.postings
  for i = 1, #list do
    local name, itemID, qty, deposit, auctionID = list[i]:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if name == itemName then
      if consume then table.remove(list, i) end
      return tonumber(itemID) or 0, tonumber(qty) or 1, tonumber(deposit) or 0, tonumber(auctionID) or 0
    end
  end
  return 0, 0, 0, 0
end

local function itemIDFromLink(link)
  if type(link) ~= "string" then return 0 end
  return tonumber(link:match("item:(%d+)")) or 0
end

local function readMail(i)
  local _, _, sender, subject, money, _, daysLeft, itemCount = ns.Try(GetInboxHeaderInfo, i)
  if subject == nil then return nil end
  if RETRIEVING_DATA and subject == RETRIEVING_DATA then return nil end   -- not loaded yet
  local invoiceType, itemName, _, bid, _, deposit, consignment, _, _, _, count = ns.Try(GetInboxInvoiceInfo, i)
  local m = {
    subject = subject, money = money or 0, itemCount = itemCount or 0,
    expires = math.floor((time() + (daysLeft or 0) * 86400) / 60 + 0.5),   -- stable to the minute
    invoiceType = invoiceType, itemName = itemName, bid = bid or 0,
    deposit = deposit or 0, consignment = consignment or 0, count = count or 0,
  }
  if (itemCount or 0) > 0 then
    local attName, _, _, attCount = ns.Try(GetInboxItem, i, 1)
    m.attName, m.attCount = attName, attCount or 1
    m.attID = itemIDFromLink(ns.Try(GetInboxItemLink, i, 1))
  end
  if invoiceType == "seller" then
    m.kind = "sale"
  elseif invoiceType == "buyer" then
    m.kind = "purchase"
  elseif invoiceType == nil then
    local expired = matchSubject(subject, AUCTION_EXPIRED_MAIL_SUBJECT)
    local removed = matchSubject(subject, AUCTION_REMOVED_MAIL_SUBJECT)
    if expired then m.kind, m.itemName = "expired", m.attName or expired
    elseif removed then m.kind, m.itemName = "cancelled", m.attName or removed end
  end
  -- "seller_temp_invoice" is the 'sale pending' notice: the real sale mail follows, so it is ignored
  return m
end

local function fingerprint(m)
  -- only details that stay the same after the money or item has been taken out of the mail
  return ns.Row(m.kind, m.subject, m.bid, m.deposit, m.consignment, m.count, m.expires)
end

local function alreadySeen(fp)
  local seen = ns.db.seen
  for i = #seen, 1, -1 do
    if seen[i] == fp then return true end
  end
  table.insert(seen, fp)
  return false
end

local function record(m)
  if not m or not m.kind or m.done then return end
  m.done = true
  if alreadySeen(fingerprint(m)) then return end
  local name = m.itemName or ""
  if m.kind == "sale" then
    local itemID, postedQty, _, auctionID = ns.TakePosting(name, true)
    local qty = (m.count and m.count > 0) and m.count or (postedQty > 0 and postedQty or 1)
    -- gross = what the buyer paid; cut = what the house kept; the deposit you paid when posting is returned
    ns.AddEvent("sale", itemID, name, qty, m.bid, m.deposit, m.consignment, m.bid - m.consignment, auctionID)
    ns.db.debug.lastInvoice = ns.Row("seller", name, m.bid, m.deposit, m.consignment, m.money, m.count)
  elseif m.kind == "purchase" then
    local qty = m.attCount or ((m.count and m.count > 0) and m.count) or 1
    ns.AddEvent("purchase", m.attID or 0, name, qty, m.bid, 0, 0, -m.bid, 0)
    ns.db.debug.lastInvoice = ns.Row("buyer", name, m.bid, m.deposit, m.consignment, m.money, m.count)
  else   -- expired or cancelled: the deposit paid when posting is lost
    local itemID, _, deposit, auctionID = ns.TakePosting(name, true)
    ns.AddEvent(m.kind, (m.attID and m.attID > 0) and m.attID or itemID, name, m.attCount or 1, 0, deposit, 0, -deposit, auctionID)
  end
end

local function scan()
  cache = {}
  local n = ns.Try(GetInboxNumItems) or 0
  for i = 1, n do cache[i] = readMail(i) end
end

local function taken(index)
  if type(index) ~= "number" then return end
  record(cache[index])
end

function ns.InstallMailHooks()
  if ns.mailHooked or not hooksecurefunc then return end
  ns.mailHooked = true
  for _, fn in ipairs({ "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem", "DeleteInboxItem" }) do
    if type(_G[fn]) == "function" then hooksecurefunc(fn, taken) end
  end
end

ns.On("MAIL_SHOW", scan)
ns.On("MAIL_INBOX_UPDATE", scan)

-- the instant "A buyer has been found for your auction" line: counted for diagnostics only,
-- the sale itself is recorded from the mail so it carries the real price and fees
ns.On("CHAT_MSG_SYSTEM", function(text)
  if matchSubject(text, ERR_AUCTION_SOLD_S) then
    ns.db.debug.soldMessages = (ns.db.debug.soldMessages or 0) + 1
  end
end)

-- exposed for tests
ns._mail = { scan = scan, taken = taken, readMail = readMail, record = record }
