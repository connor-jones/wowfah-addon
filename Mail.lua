-- Sales, purchases, expired and cancelled auctions, read from auction house mail.
-- Mail is the only place the game states what an auction actually sold for and what the house kept.
-- A mail is recorded once, when its money or items have actually left it, so a mail that sits in the
-- inbox across several sessions, or a take that fails and is tried again, is never counted twice.

local _, ns = ...

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

-- Find the posting a mail belongs to: the same item and, when the mail states a price, the same price each
-- (an unsold return states no price, so it goes by the quantity still unsold).
-- A posting can sell in several lots, so it is used up by quantity and dropped once nothing is left.
-- Returns item id, quantity posted, the share of the deposit that goes with this quantity, auction id.
function ns.TakePosting(itemName, qty, unitPrice)
  local list, pick = ns.db.postings, nil
  for i = 1, #list do
    local name, _, posted, _, _, _, total, left = list[i]:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?([^|]*)")
    if name == itemName then
      pick = pick or i   -- oldest first unless the price, or the quantity still unsold, points at another
      posted, total = tonumber(posted) or 1, tonumber(total) or 0
      if unitPrice then
        if posted > 0 and math.abs(total / posted - unitPrice) < 1 then pick = i; break end
      elseif qty and qty > 0 and (tonumber(left) or posted) == qty then
        pick = i; break
      end
    end
  end
  if not pick then return 0, 0, 0, 0 end
  local f = {}
  for part in (list[pick] .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end
  local posted, deposit = tonumber(f[3]) or 1, tonumber(f[4]) or 0
  local left = tonumber(f[8]) or posted
  if not qty or qty <= 0 then qty = left end
  local share = posted > 0 and math.floor(deposit * math.min(qty, posted) / posted + 0.5) or deposit
  left = left - qty
  if left <= 0 then
    table.remove(list, pick)
  else
    list[pick] = ns.Row(f[1], f[2], f[3], f[4], f[5], f[6], f[7], left)
  end
  return tonumber(f[2]) or 0, posted, share, tonumber(f[5]) or 0
end

local function itemIDFromLink(link)
  if type(link) ~= "string" then return 0 end
  return tonumber(link:match("item:(%d+)")) or 0
end

local MAX_ATTACHMENTS = ATTACHMENTS_MAX_RECEIVE or 16

-- returns the mail's details, or nil and true while the game is still loading it
local function readMail(i)
  local _, _, _, subject, money, _, _, itemCount = ns.Try(GetInboxHeaderInfo, i)
  if subject == nil then return nil end
  if RETRIEVING_DATA and subject == RETRIEVING_DATA then return nil, true end
  local invoiceType, itemName, _, bid, _, deposit, consignment, _, _, _, count = ns.Try(GetInboxInvoiceInfo, i)
  local m = {
    subject = subject, money = money or 0, itemCount = itemCount or 0,
    invoiceType = invoiceType, itemName = itemName, bid = bid or 0,
    deposit = deposit or 0, consignment = consignment or 0, count = count or 0, qty = 0,
  }
  if m.itemCount > 0 then
    -- a mail can carry several stacks, and the slots are not always filled from the first
    for a = 1, MAX_ATTACHMENTS do
      local attName, _, _, attCount = ns.Try(GetInboxItem, i, a)
      if attName then
        m.qty = m.qty + (tonumber(attCount) or 1)
        if not m.attName then
          m.attName = attName
          m.attID = itemIDFromLink(ns.Try(GetInboxItemLink, i, a))
        end
      end
    end
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
  if m.kind == "sale" then m.holds = m.money > 0 else m.holds = m.itemCount > 0 end
  return m
end

-- mails that look the same are counted together, so it does not matter where in the inbox they sit
local function mailKey(m)
  return ns.Row(m.kind, m.itemName or "", m.bid, m.deposit, m.consignment, m.count)
end

-- moved = how many items left mails of this kind since the last one was recorded
local function record(m, moved)
  if not m or not m.kind then return end
  moved = moved or 0
  local name = m.itemName or ""
  if m.kind == "sale" then
    local each = (m.count > 0) and (m.bid / m.count) or nil
    local itemID, postedQty, _, auctionID = ns.TakePosting(name, m.count, each)
    local qty = (m.count > 0) and m.count or (postedQty > 0 and postedQty or 1)
    -- gross = what the buyer paid; cut = what the house kept; the deposit you paid when posting is returned
    ns.AddEvent("sale", itemID, name, qty, m.bid, m.deposit, m.consignment, m.bid - m.consignment, auctionID)
    ns.db.debug.lastInvoice = ns.Row("seller", name, m.bid, m.deposit, m.consignment, m.money, m.count)
  elseif m.kind == "purchase" then
    -- the invoice states how many were bought; the first stack in the mail is only part of a large order
    local qty = (m.count > 0 and m.count) or (moved > 0 and moved) or (m.qty > 0 and m.qty) or 1
    ns.AddEvent("purchase", m.attID or 0, name, qty, m.bid, 0, 0, -m.bid, 0)
    ns.db.debug.lastInvoice = ns.Row("buyer", name, m.bid, m.deposit, m.consignment, m.money, m.count)
  else   -- expired or cancelled: the deposit paid for the unsold part is lost
    local qty = (moved > 0 and moved) or (m.qty > 0 and m.qty) or 1
    local itemID, _, deposit, auctionID = ns.TakePosting(name, qty)
    ns.AddEvent(m.kind, (m.attID and m.attID > 0) and m.attID or itemID, name, qty, 0, deposit, 0, -deposit, auctionID)
  end
end

-- A mail is recorded once, when it stops holding its money or items. Counting the click instead would
-- count a mail twice whenever the take fails (full bags, a busy mail server) and is tried again.
local prev          -- kind of mail -> { n = mails still holding money or items, qty = items in them, m = one of them }
local prevLoading = 0
local moved = {}    -- kind of mail -> items taken so far from mails that still hold more
local armedAt       -- when the player last took or deleted something
local hooks = 0
local skipped = 0

local function armed()
  return hooks == 0 or (armedAt and time() - armedAt <= 30)
end

local function scan()
  local n = ns.Try(GetInboxNumItems) or 0
  local now, loading = {}, 0
  for i = 1, n do
    local m, wait = readMail(i)
    if wait then loading = loading + 1 end
    if m and m.kind and m.holds then
      local k = mailKey(m)
      local t = now[k]
      if not t then t = { n = 0, qty = 0, m = m }; now[k] = t end
      t.n = t.n + 1
      t.qty = t.qty + m.qty
    end
  end
  if prev and loading > prevLoading and skipped < 3 then
    skipped = skipped + 1   -- a mail went back to loading: wait for it before comparing
    return
  end
  local settle = loading > prevLoading   -- still loading after several looks: start again from here
  skipped, prevLoading = 0, loading
  if prev and armed() and not settle then
    for k, was in pairs(prev) do
      local is = now[k]
      local gone = was.n - (is and is.n or 0)
      local left = was.qty - (is and is.qty or 0)
      if left > 0 then moved[k] = (moved[k] or 0) + left end
      if gone > 0 then
        local total = moved[k] or 0
        moved[k] = nil
        local each = math.floor(total / gone)
        for j = 1, gone do
          local ok, err = pcall(record, was.m, j == 1 and (total - each * (gone - 1)) or each)
          if not ok then ns.db.debug.lastError = tostring(err) end
        end
      end
    end
  end
  prev = now
end

local function arm()
  armedAt = time()
end

function ns.InstallMailHooks()
  if ns.mailHooked or not hooksecurefunc then return end
  ns.mailHooked = true
  for _, fn in ipairs({ "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem", "DeleteInboxItem" }) do
    if type(_G[fn]) == "function" then
      hooksecurefunc(fn, arm)
      hooks = hooks + 1
    end
  end
end

local function reset()
  prev, prevLoading, skipped, moved = nil, 0, 0, {}
end

ns.On("MAIL_SHOW", function() reset(); scan() end)
ns.On("MAIL_INBOX_UPDATE", scan)
ns.On("MAIL_CLOSED", reset)   -- the inbox reads as empty once closed, so nothing is compared here

-- the instant "A buyer has been found for your auction" line: counted for diagnostics only,
-- the sale itself is recorded from the mail so it carries the real price and fees
ns.On("CHAT_MSG_SYSTEM", function(text)
  if matchSubject(text, ERR_AUCTION_SOLD_S) then
    ns.db.debug.soldMessages = (ns.db.debug.soldMessages or 0) + 1
  end
end)

-- exposed for tests
ns._mail = { scan = scan, readMail = readMail, record = record }
