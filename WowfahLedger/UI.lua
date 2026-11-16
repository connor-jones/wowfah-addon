-- The in-game ledger window: your profit for today, 7 days, 30 days and all time, and recent activity.

local _, ns = ...

local window
local ROWS = 10

-- profit = sales - auction house cut - deposits lost on unsold auctions - purchases
function ns.Summarise(sinceTime)
  local s = { sales = 0, fees = 0, lost = 0, bought = 0, nSales = 0, nBought = 0 }
  local me = ns.charKey
  for i = 1, #ns.db.events do
    local kind, ts, char, _, _, _, gross, deposit, cut = ns.db.events[i]:match(
      "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    ts = tonumber(ts) or 0
    if ts >= sinceTime and (not ns.onlyThisCharacter or char == me) then
      gross, deposit, cut = tonumber(gross) or 0, tonumber(deposit) or 0, tonumber(cut) or 0
      if kind == "sale" then
        s.sales, s.fees, s.nSales = s.sales + gross, s.fees + cut, s.nSales + 1
      elseif kind == "purchase" then
        s.bought, s.nBought = s.bought + gross, s.nBought + 1
      elseif kind == "expired" or kind == "cancelled" then
        s.lost = s.lost + deposit
      end
    end
  end
  s.profit = s.sales - s.fees - s.lost - s.bought
  return s
end

local KIND = {
  sale = { "Sold", 0.50, 0.77, 0.42 }, purchase = { "Bought", 0.87, 0.39, 0.31 },
  expired = { "Expired", 0.53, 0.57, 0.53 }, cancelled = { "Cancelled", 0.53, 0.57, 0.53 },
}
local BRASS = { 0.83, 0.64, 0.30 }
local W, H = 664, 456

-- the newest rows, newest first: { when, kind, item text, amount text }
local function recentRows()
  local out = {}
  for i = #ns.db.events, 1, -1 do
    local kind, ts, char, _, name, qty, gross, deposit = ns.db.events[i]:match(
      "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if KIND[kind] and (not ns.onlyThisCharacter or char == ns.charKey) then
      local amount
      if kind == "sale" or kind == "purchase" then
        amount = ns.FormatMoney(tonumber(gross))
      else
        amount = (tonumber(deposit) or 0) > 0 and (ns.FormatMoney(tonumber(deposit)) .. " lost") or ""
      end
      out[#out + 1] = { date("%d %b %H:%M", tonumber(ts) or 0), kind, (qty or "1") .. " x " .. (name or ""), amount }
      if #out >= ROWS then break end
    end
  end
  return out
end

local function periods()
  local now = time()
  local d = date("*t", now)
  local midnight = now - (d.hour * 3600 + d.min * 60 + d.sec)
  return { { "Today", midnight }, { "7 days", now - 7 * 86400 }, { "30 days", now - 30 * 86400 }, { "All time", 0 } }
end

-- one line for tooltips and chat: "Today: profit 1g 20s from 3 sales"
function ns.TodayLine()
  local s = ns.Summarise(periods()[1][2])
  return string.format("Today: profit %s from %d sale%s", ns.FormatMoney(s.profit), s.nSales, s.nSales == 1 and "" or "s")
end

function ns.RefreshUI()
  if not (window and window:IsShown()) then return end
  for i, r in ipairs(periods()) do
    local s = ns.Summarise(r[2])
    local card = window.cards[i]
    card.value:SetText(ns.FormatMoney(s.profit))
    if s.profit >= 0 then card.value:SetTextColor(0.50, 0.77, 0.42) else card.value:SetTextColor(0.87, 0.39, 0.31) end
    card.sold:SetText(string.format("Sold %s (%d)", ns.FormatMoney(s.sales), s.nSales))
    card.bought:SetText(string.format("Bought %s (%d)", ns.FormatMoney(s.bought), s.nBought))
    card.fees:SetText("Fees " .. ns.FormatMoney(s.fees + s.lost))
  end
  local rows = recentRows()
  for i = 1, ROWS do
    local line, r = window.rows[i], rows[i]
    if r then
      local k = KIND[r[2]]
      line.when:SetText(r[1]); line.kind:SetText(k[1]); line.kind:SetTextColor(k[2], k[3], k[4])
      line.item:SetText(r[3]); line.amount:SetText(r[4])
    else
      line.when:SetText(""); line.kind:SetText(""); line.item:SetText(""); line.amount:SetText("")
    end
  end
  if #rows == 0 then
    window.rows[1].item:SetText("Nothing recorded yet. Collect auction house mail and it will appear here.")
  end
  window.share:SetChecked(ns.db.share and true or false)
  if window.loot then window.loot:SetChecked(ns.db.lootShare == true) end
  if window.mini then window.mini:SetChecked(not (ns.db.minimap and ns.db.minimap.hide)) end
  if window.scope then window.scope:SetChecked(ns.onlyThisCharacter and true or false) end
end

local function skin(f, r, g, b, a, border)
  if not f.SetBackdrop then return end
  f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  f:SetBackdropColor(r, g, b, a)
  local c = border or { 0.20, 0.26, 0.22 }
  f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

local function box(parent, name)
  return CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
end

local function text(parent, font, r, g, b)
  local t = parent:CreateFontString(nil, "OVERLAY", font)
  if r then t:SetTextColor(r, g, b) end
  t:SetJustifyH("LEFT")
  return t
end

local function check(parent, label, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
  local t = text(parent, "GameFontHighlightSmall")
  t:SetPoint("LEFT", c, "RIGHT", 2, 0)
  t:SetText(label)
  return c
end

local function button(parent, label, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local function build()
  local f = box(UIParent, "WowfahLedgerWindow")
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  skin(f, 0.04, 0.06, 0.05, 0.97, BRASS)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "WowfahLedgerWindow") end   -- Escape closes it

  -- header
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26)
  icon:SetPoint("TOPLEFT", 14, -12)
  icon:SetTexture(ns.ICON)
  local title = text(f, "GameFontNormalLarge", BRASS[1], BRASS[2], BRASS[3])
  title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  title:SetText("wowfah Ledger")
  local sub = text(f, "GameFontDisableSmall")
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
  sub:SetText("your auction house profit")
  local x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  x:SetPoint("TOPRIGHT", -2, -2)
  x:SetScript("OnClick", function() f:Hide() end)

  -- four cards: today, 7 days, 30 days, all time
  f.cards = {}
  local cw = (W - 28 - 3 * 8) / 4
  for i, p in ipairs(periods()) do
    local c = box(f)
    c:SetSize(cw, 92)
    c:SetPoint("TOPLEFT", 14 + (i - 1) * (cw + 8), -48)
    skin(c, 0.07, 0.10, 0.08, 1)
    local label = text(c, "GameFontNormalSmall", BRASS[1], BRASS[2], BRASS[3])
    label:SetPoint("TOPLEFT", 10, -9)
    label:SetText(string.upper(p[1]))
    c.value = text(c, "GameFontNormalLarge")
    c.value:SetPoint("TOPLEFT", 10, -25)
    c.sold = text(c, "GameFontHighlightSmall")
    c.sold:SetPoint("TOPLEFT", 10, -47)
    c.bought = text(c, "GameFontHighlightSmall")
    c.bought:SetPoint("TOPLEFT", 10, -60)
    c.fees = text(c, "GameFontDisableSmall")
    c.fees:SetPoint("TOPLEFT", 10, -73)
    f.cards[i] = c
  end

  -- recent activity
  local list = box(f)
  list:SetSize(W - 28, 28 + ROWS * 17 + 8)
  list:SetPoint("TOPLEFT", 14, -148)
  skin(list, 0.07, 0.10, 0.08, 1)
  local head = text(list, "GameFontNormalSmall", BRASS[1], BRASS[2], BRASS[3])
  head:SetPoint("TOPLEFT", 10, -9)
  head:SetText("RECENT ACTIVITY")
  f.rows = {}
  for i = 1, ROWS do
    local y = -12 - i * 17
    if i % 2 == 0 then
      local stripe = list:CreateTexture(nil, "BACKGROUND")
      stripe:SetColorTexture(1, 1, 1, 0.03)
      stripe:SetPoint("TOPLEFT", 4, y + 2)
      stripe:SetSize(W - 36, 17)
    end
    local row = {}
    row.when = text(list, "GameFontDisableSmall")
    row.when:SetPoint("TOPLEFT", 10, y)
    row.when:SetWidth(92)
    row.kind = text(list, "GameFontHighlightSmall")
    row.kind:SetPoint("TOPLEFT", 106, y)
    row.kind:SetWidth(70)
    row.item = text(list, "GameFontHighlightSmall")
    row.item:SetPoint("TOPLEFT", 178, y)
    row.item:SetWidth(330)
    row.item:SetWordWrap(false)
    row.amount = text(list, "GameFontHighlightSmall")
    row.amount:SetPoint("TOPRIGHT", -12, y)
    row.amount:SetWidth(120)
    row.amount:SetJustifyH("RIGHT")
    f.rows[i] = row
  end

  -- footer: what to do next, without typing anything
  f.scope = check(f, "This character only", function(on) ns.onlyThisCharacter = on; ns.RefreshUI() end)
  f.scope:SetPoint("BOTTOMLEFT", 12, 40)
  local hint = text(f, "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 16, 16)
  hint:SetText("Charts, flips and undercut checks are at wowfah.com/ledger")
  local settings
  local up = button(f, "Upload to wowfah.com", 170, function() if ns.ShowExport then ns.ShowExport() end end)
  up:SetPoint("BOTTOMRIGHT", -14, 14)
  local set = button(f, "Settings", 90, function() if settings:IsShown() then settings:Hide() else settings:Show() end end)
  set:SetPoint("RIGHT", up, "LEFT", -6, 0)

  -- settings: a small panel over the list, so nobody needs a slash command
  settings = box(f)
  settings:SetSize(W - 28, 190)
  settings:SetPoint("TOPLEFT", 14, -148)
  settings:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  skin(settings, 0.05, 0.07, 0.06, 1, BRASS)
  settings:EnableMouse(true)
  settings:Hide()
  local sh = text(settings, "GameFontNormalSmall", BRASS[1], BRASS[2], BRASS[3])
  sh:SetPoint("TOPLEFT", 10, -9)
  sh:SetText("SETTINGS")
  f.share = check(settings, "Share anonymous sale prices with wowfah.com when I upload", function(on) ns.db.share = on end)
  f.share:SetPoint("TOPLEFT", 8, -28)
  f.loot = check(settings, "Share what drops where (creatures, nodes, vendors, quests). No character names",
    function(on) if ns.SetLoot then ns.SetLoot(on, true) end end)
  f.loot:SetPoint("TOPLEFT", 8, -54)
  f.mini = check(settings, "Show the wowfah button on the minimap", function(on) if ns.ShowMinimapButton then ns.ShowMinimapButton(on) end end)
  f.mini:SetPoint("TOPLEFT", 8, -80)
  local note = text(settings, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 14, -114)
  note:SetWidth(W - 60)
  note:SetText("Nothing leaves your computer until you upload. The game saves this addon's data when you log out or reload, so do one of those before uploading the saved file. The Upload button gives you a code to paste instead.")
  local done = button(settings, "Done", 80, function() settings:Hide() end)
  done:SetPoint("BOTTOMRIGHT", -10, 10)
  f.settings = settings
  return f
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
