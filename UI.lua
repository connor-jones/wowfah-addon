-- The in-game ledger window: your profit for today, 7 days, 30 days and all time, then one list with seven views:
-- recent activity, items, days, characters, what you are still holding and your own auctions.

local _, ns = ...

local window
local ROWS = 10
local W, H = 664, 486
local LIST_Y = -186

local VIEWS
local KIND = { sale = { "Sold", "up" }, purchase = { "Bought", "down" }, expired = { "Expired", "dim" }, cancelled = { "Cancelled", "dim" } }


local function left(seconds)
  if not seconds then return "" end
  if seconds < 3600 then return math.floor(seconds / 60) .. " min left" end
  return math.floor(seconds / 3600) .. " h left"
end

local function signed(profit)
  return ns.FormatMoney(profit), nil, profit >= 0 and ns.C.up or ns.C.down
end

-- each view: its tab label, the four column headings, the rows for a period and how one row reads.
-- line(e) -> first, second, third, fourth column, colour of the second, colour of the fourth
VIEWS = {
  { tab = "Recent", heads = { "WHEN", "WHAT", "ITEM", "AMOUNT" }, empty = "Nothing recorded yet. Collect auction house mail and it will appear here.",
    rows = function() return ns.Recent(200) end,
    line = function(e)
      local k = KIND[e.kind] or { e.kind, "dim" }
      local amount = ""
      if e.kind == "sale" or e.kind == "purchase" then amount = ns.FormatMoney(e.gross)
      elseif e.deposit > 0 then amount = ns.FormatMoney(e.deposit) .. " lost" end
      return date("%d %b %H:%M", e.ts), k[1], e.qty .. " x " .. e.name, amount, ns.C[k[2]]
    end },
  { tab = "Items", period = true, heads = { "SOLD", "BOUGHT", "ITEM", "PROFIT" }, empty = "No sales or purchases in this period.",
    rows = function(since) return ns.ByItem(since) end,
    line = function(s)
      local text, _, colour = signed(s.profit)
      return s.sold > 0 and (s.sold .. " sold") or "", s.boughtQty > 0 and (s.boughtQty .. " in") or "", s.name, text, nil, colour
    end },
  { tab = "Days", heads = { "DAY", "SALES", "SOLD AND BOUGHT", "PROFIT" }, empty = "Nothing recorded in the last 30 days.",
    rows = function()
      local out, days = {}, ns.ByDay(30)
      for i = #days, 1, -1 do
        local d = days[i]
        if d.nSales + d.nBought + d.failed > 0 then out[#out + 1] = d end
      end
      return out
    end,
    line = function(d)
      local text, _, colour = signed(d.profit)
      return date("%a %d %b", d.day), d.nSales .. (d.nSales == 1 and " sale" or " sales"),
        "Sold " .. ns.FormatMoney(d.sales) .. "   Bought " .. ns.FormatMoney(d.bought), text, nil, colour
    end },
  { tab = "Characters", period = true, heads = { "", "SALES", "CHARACTER", "PROFIT" }, empty = "No sales or purchases in this period.",
    rows = function(since) return ns.ByCharacter(since) end,
    line = function(s)
      local text, _, colour = signed(s.profit)
      return "", s.nSales .. (s.nSales == 1 and " sale" or " sales"), s.char, text, nil, colour
    end },
  { tab = "Holding", heads = { "LEFT", "", "ITEM", "COST" }, empty = "Nothing bought that you have not sold again.",
    rows = function() return ns.Holding() end,
    line = function(h) return h.qty .. " left", "", h.name .. "   paid " .. ns.FormatMoney(h.each) .. " each", ns.FormatMoney(h.cost) end },
  { tab = "My auctions", heads = { "TIME LEFT", "", "AUCTION", "LOWEST YOU SAW" }, empty = "Open the auction house to list your auctions here.",
    rows = function() return ns.MyAuctions() end,
    line = function(a)
      local low = a.low and (ns.FormatMoney(a.low) .. ", " .. ns.Ago(a.lowAt)) or "not browsed"
      return left(a.left), a.beaten and "Beaten" or (a.low and "Lowest" or ""),
        a.qty .. " x " .. a.name .. "   " .. ns.FormatMoney(a.each) .. " each", low, a.beaten and ns.C.down or ns.C.up,
        a.beaten and ns.C.down or ns.C.text
    end },
  { tab = "Deals", heads = { "BELOW", "", "ITEM", "PROFIT EACH" }, empty = "No deals in the price list. It comes from the wowfah Sync app; /reload loads the newest.",
    rows = function() return ns.Deals() end,
    line = function(d)
      return d.off .. "%", "", d.name .. "   lowest " .. ns.FormatMoney(d.low) .. ", market " .. ns.FormatMoney(d.market) .. ", " .. d.sold .. " sold a day",
        ns.FormatMoney(d.profit), ns.C.up, ns.C.up
    end },
}

function ns.RefreshUI()
  if ns.UpdateBroker then ns.UpdateBroker() end
  if not (window and window:IsShown()) then return end
  local C = ns.C
  for i, p in ipairs(ns.Periods()) do
    local s = ns.Summarise(p[2])
    local card = window.cards[i]
    card.value:SetText(ns.Coins(s.profit))
    ns.Colour(card.value, s.profit >= 0 and C.up or C.down)
    card.sold:SetText(string.format("Sold %s (%d)", ns.FormatMoney(s.sales), s.nSales))
    card.bought:SetText(string.format("Bought %s (%d)", ns.FormatMoney(s.bought), s.nBought))
    card.fees:SetText("Fees " .. ns.FormatMoney(s.fees + s.lost))
  end
  for i, card in ipairs(window.cards) do ns.SetBorder(card, i == window.period and C.brass or C.line) end
  local view = VIEWS[window.tab] or VIEWS[1]
  local rows = view.rows(ns.Periods()[window.period][2])
  local top = math.max(0, math.min(window.offset[window.tab] or 0, #rows - ROWS))
  window.offset[window.tab] = top
  for i = 1, 4 do window.heads[i]:SetText(view.heads[i]) end
  for i, b in ipairs(window.tabs) do
    local on = i == window.tab
    ns.SetBorder(b, on and C.brass or C.line)
    b.on = on
    ns.Colour(b.label, on and C.brass or C.text)
  end
  for i = 1, ROWS do
    local line, e = window.rows[i], rows[top + i]
    if e then
      local a, b, c, d, bc, dc = view.line(e)
      line.when:SetText(a); line.kind:SetText(b); line.item:SetText(c); line.amount:SetText(d)
      ns.Colour(line.kind, bc or C.text)
      ns.Colour(line.amount, dc or C.text)
    else
      line.when:SetText(""); line.kind:SetText(""); line.item:SetText(""); line.amount:SetText("")
    end
  end
  if #rows == 0 then window.rows[1].item:SetText(view.empty) end
  if #rows > ROWS then
    window.count:SetText(string.format("%d to %d of %d. Scroll for more", top + 1, math.min(top + ROWS, #rows), #rows))
  else
    window.count:SetText(view.period and ns.Periods()[window.period][1] or "")
  end
  local fresh, last = ns.NotUploaded()
  if fresh > 0 then
    window.hint:SetText(string.format("%d new record%s not on wowfah.com yet%s", fresh, fresh == 1 and "" or "s",
      last and (". Last upload " .. ns.Ago(last)) or ""))
    ns.Colour(window.hint, C.brass)
  else
    window.hint:SetText(last and ("Everything is uploaded. More at wowfah.com/ledger") or "More at wowfah.com/ledger")
    ns.Colour(window.hint, C.dim)
  end
  if window.tips then window.tips:SetChecked(ns.db.tips and true or false) end
  if window.guild then window.guild:SetChecked(ns.db.guildReply and true or false) end
  window.share:SetChecked(ns.db.share and true or false)
  if window.loot then window.loot:SetChecked(ns.db.lootShare == true) end
  if window.mini then window.mini:SetChecked(not (ns.db.minimap and ns.db.minimap.hide)) end
  if window.scope then window.scope:SetChecked(ns.onlyThisCharacter and true or false) end
end

local function build()
  local C = ns.C
  local f = CreateFrame("Frame", "WowfahLedgerWindow", UIParent)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  ns.Flat(f, C.bg, C.line)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "WowfahLedgerWindow") end   -- Escape closes it

  -- header
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(22, 22)
  icon:SetPoint("TOPLEFT", 14, -11)
  icon:SetTexture(ns.ICON)
  local title = ns.Text(f, "title")
  title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  title:SetText("wowfah Ledger")
  local sub = ns.Text(f, "small", C.dim)
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
  sub:SetText("your auction house profit")
  local x = ns.Button(f, "x", 24, function() f:Hide() end)
  x:SetPoint("TOPRIGHT", -10, -10)
  ns.Rule(f, -44)

  -- four cards: today, 7 days, 30 days, all time
  f.cards = {}
  local cw = (W - 28 - 3 * 8) / 4
  for i, p in ipairs(ns.Periods()) do
    local c = CreateFrame("Frame", nil, f)
    c:SetSize(cw, 92)
    c:SetPoint("TOPLEFT", 14 + (i - 1) * (cw + 8), -56)
    ns.Flat(c)
    c:EnableMouse(true)          -- click a card to make it the period for the Items and Characters views
    c:SetScript("OnMouseUp", function() f.period = i; ns.RefreshUI() end)
    local label = ns.Text(c, "label")
    label:SetPoint("TOPLEFT", 10, -9)
    label:SetText(string.upper(p[1]))
    c.value = ns.Text(c, "big")
    c.value:SetPoint("TOPLEFT", 10, -26)
    c.sold = ns.Text(c, "small")
    c.sold:SetPoint("TOPLEFT", 10, -48)
    c.bought = ns.Text(c, "small")
    c.bought:SetPoint("TOPLEFT", 10, -61)
    c.fees = ns.Text(c, "small", C.dim)
    c.fees:SetPoint("TOPLEFT", 10, -74)
    f.cards[i] = c
  end

  -- one tab per view
  f.period, f.tab, f.offset, f.tabs = 3, 1, {}, {}
  local tw = (W - 28 - (#VIEWS - 1) * 4) / #VIEWS
  for i, v in ipairs(VIEWS) do
    local b = ns.Button(f, v.tab, tw, function() f.tab = i; ns.RefreshUI() end)
    b:SetPoint("TOPLEFT", 14 + (i - 1) * (tw + 4), -156)
    b:SetScript("OnLeave", function(self) ns.SetBorder(self, self.on and C.brass or C.line); ns.Colour(self.label, self.on and C.brass or C.text) end)
    f.tabs[i] = b
  end

  -- the list
  local list = CreateFrame("Frame", nil, f)
  list:SetSize(W - 28, 28 + ROWS * 18 + 6)
  list:SetPoint("TOPLEFT", 14, LIST_Y)
  ns.Flat(list)
  f.heads = {}
  for i, x in ipairs({ 10, 106, 178 }) do
    f.heads[i] = ns.Text(list, "label")
    f.heads[i]:SetPoint("TOPLEFT", x, -9)
  end
  f.heads[4] = ns.Text(list, "label")
  f.heads[4]:SetPoint("TOPRIGHT", -12, -9)
  f.count = ns.Text(list, "small", C.dim)
  f.count:SetPoint("TOPRIGHT", -150, -9)
  ns.Rule(list, -26)
  if list.EnableMouseWheel then
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
      f.offset[f.tab] = math.max(0, (f.offset[f.tab] or 0) - delta * 3)
      ns.RefreshUI()
    end)
  end
  f.rows = {}
  for i = 1, ROWS do
    local y = -13 - i * 18
    if i % 2 == 0 then
      local stripe = list:CreateTexture(nil, "BACKGROUND", nil, 1)
      stripe:SetColorTexture(1, 1, 1, 0.025)
      stripe:SetPoint("TOPLEFT", 1, y + 3)
      stripe:SetSize(W - 30, 18)
    end
    local row = {}
    row.when = ns.Text(list, "small", C.dim)
    row.when:SetPoint("TOPLEFT", 10, y)
    row.when:SetWidth(92)
    row.kind = ns.Text(list, "small")
    row.kind:SetPoint("TOPLEFT", 106, y)
    row.kind:SetWidth(70)
    row.item = ns.Text(list, "small")
    row.item:SetPoint("TOPLEFT", 178, y)
    row.item:SetWidth(330)
    row.item:SetWordWrap(false)
    row.amount = ns.Text(list, "small")
    row.amount:SetPoint("TOPRIGHT", -12, y)
    row.amount:SetWidth(120)
    row.amount:SetJustifyH("RIGHT")
    f.rows[i] = row
  end

  -- footer: what to do next, without typing anything
  f.scope = ns.Check(f, "This character only", function(on) ns.onlyThisCharacter = on; ns.RefreshUI() end)
  f.scope:SetPoint("BOTTOMLEFT", 12, 38)
  local hint = ns.Text(f, "small", C.dim)
  hint:SetPoint("BOTTOMLEFT", 16, 16)
  hint:SetText("More at wowfah.com/ledger")
  f.hint = hint
  local settings
  -- two ways to get the ledger onto the site: by hand (always there), or with the wowfah Sync app when it is set up
  local hasApp = ns.HasSyncApp and ns.HasSyncApp()
  local function tip(button, title, text)
    if not (button.HookScript and GameTooltip) then return end
    button:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(title)
      GameTooltip:AddLine(text, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local up = ns.Button(f, "Manual upload", 120, function() if ns.ShowExport then ns.ShowExport() end end, not hasApp)
  up:SetPoint("BOTTOMRIGHT", -14, 14)
  tip(up, "Manual upload", "Shows a code to copy and paste at wowfah.com/ledger/upload. Works on any computer, with nothing else installed.")
  local save = ns.Button(f, "Save and sync", 120, function() if ns.SaveNow then ns.SaveNow() end end, hasApp)
  save:SetPoint("RIGHT", up, "LEFT", -6, 0)
  if hasApp then
    tip(save, "Save and sync", "Reloads the interface so the game saves your ledger. The wowfah Sync app uploads it a few seconds later. Typing /sync does the same.")
  else
    if save.SetAlpha then save:SetAlpha(0.4) end
    tip(save, "Save and sync (needs wowfah Sync)", "Uploads for you, with no copying and pasting. It needs the free wowfah Sync app for Windows: wowfah.com/sync. If you have just set the app up, type /reload once. Until then, use Manual upload.")
  end
  f.save = save
  local set = ns.Button(f, "Settings", 90, function() if settings:IsShown() then settings:Hide() else settings:Show() end end)
  set:SetPoint("RIGHT", save, "LEFT", -6, 0)

  -- settings: a small panel over the list, so nobody needs a slash command
  settings = CreateFrame("Frame", nil, f)
  settings:SetSize(W - 28, 28 + ROWS * 18 + 6)
  settings:SetPoint("TOPLEFT", 14, LIST_Y)
  settings:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  ns.Flat(settings, C.bg, C.brass)
  settings:EnableMouse(true)
  settings:Hide()
  local sh = ns.Text(settings, "label")
  sh:SetPoint("TOPLEFT", 10, -9)
  sh:SetText("SETTINGS")
  ns.Rule(settings, -26)
  f.share = ns.Check(settings, "Share anonymous sale prices with wowfah.com when I upload", function(on) ns.db.share = on end)
  f.share:SetPoint("TOPLEFT", 8, -34)
  f.loot = ns.Check(settings, "Share what drops where (creatures, nodes, vendors, quests). No character names",
    function(on) if ns.SetLoot then ns.SetLoot(on, true) end end)
  f.loot:SetPoint("TOPLEFT", 8, -60)
  f.mini = ns.Check(settings, "Show the wowfah button on the minimap", function(on) if ns.ShowMinimapButton then ns.ShowMinimapButton(on) end end)
  f.mini:SetPoint("TOPLEFT", 8, -86)
  f.tips = ns.Check(settings, "Show prices on item tooltips and when I post an auction", function(on) ns.db.tips = on end)
  f.tips:SetPoint("TOPLEFT", 8, -112)
  f.guild = ns.Check(settings, "Answer price questions in guild chat (a question mark and an item link)", function(on) ns.db.guildReply = on end)
  f.guild:SetPoint("TOPLEFT", 8, -138)
  local note = ns.Text(settings, "small", C.dim)
  note:SetPoint("TOPLEFT", 14, -170)
  note:SetWidth(W - 150)
  note:SetText("Nothing leaves your computer until you upload. Manual upload gives a code to paste on the site and needs nothing else. Save and sync needs the wowfah Sync app.")
  local done = ns.Button(settings, "Done", 80, function() settings:Hide() end)
  done:SetPoint("BOTTOMRIGHT", -10, 10)
  f.settings = settings
  return f
end

-- open the window on one of its views (1 recent .. 6 my auctions)
function ns.ShowTab(tab)
  if not window then return end
  window.tab = tab
  local ok, err = pcall(ns.RefreshUI)
  if not ok then ns.Print("could not show that view (" .. tostring(err) .. ")") end
end

function ns.ToggleUI()
  if not window then
    local ok, made = pcall(build)
    if not ok then
      ns.Print("could not open the window (" .. tostring(made) .. "). Your data is still being recorded.")
      local s = ns.Summarise(0)
      ns.Print("All time profit " .. ns.FormatMoney(s.profit) .. " from " .. s.nSales .. " sales.")
      return
    end
    window = made
    window:Hide()
  end
  if window:IsShown() then window:Hide() else window:Show(); ns.RefreshUI() end
end
