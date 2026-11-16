-- The in-game ledger window: your profit for today, 7 days, 30 days and all time, and recent activity.

local _, ns = ...

local window
local ROWS = 10
local W, H = 664, 456

local KIND = { sale = { "Sold", "up" }, purchase = { "Bought", "down" }, expired = { "Expired", "dim" }, cancelled = { "Cancelled", "dim" } }

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
  local rows = ns.Recent(ROWS)
  for i = 1, ROWS do
    local line, e = window.rows[i], rows[i]
    if e then
      local k = KIND[e.kind] or { e.kind, "dim" }
      line.when:SetText(date("%d %b %H:%M", e.ts))
      line.kind:SetText(k[1])
      ns.Colour(line.kind, C[k[2]])
      line.item:SetText(e.qty .. " x " .. e.name)
      if e.kind == "sale" or e.kind == "purchase" then
        line.amount:SetText(ns.FormatMoney(e.gross))
      else
        line.amount:SetText(e.deposit > 0 and (ns.FormatMoney(e.deposit) .. " lost") or "")
      end
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

  -- recent activity
  local list = CreateFrame("Frame", nil, f)
  list:SetSize(W - 28, 28 + ROWS * 18 + 6)
  list:SetPoint("TOPLEFT", 14, -156)
  ns.Flat(list)
  local head = ns.Text(list, "label")
  head:SetPoint("TOPLEFT", 10, -9)
  head:SetText("RECENT ACTIVITY")
  ns.Rule(list, -26)
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
  hint:SetText("Charts, flips and undercut checks are at wowfah.com/ledger")
  local settings
  local up = ns.Button(f, "Upload to wowfah.com", 170, function() if ns.ShowExport then ns.ShowExport() end end, true)
  up:SetPoint("BOTTOMRIGHT", -14, 14)
  local set = ns.Button(f, "Settings", 90, function() if settings:IsShown() then settings:Hide() else settings:Show() end end)
  set:SetPoint("RIGHT", up, "LEFT", -6, 0)

  -- settings: a small panel over the list, so nobody needs a slash command
  settings = CreateFrame("Frame", nil, f)
  settings:SetSize(W - 28, 28 + ROWS * 18 + 6)
  settings:SetPoint("TOPLEFT", 14, -156)
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
  local note = ns.Text(settings, "small", C.dim)
  note:SetPoint("TOPLEFT", 14, -120)
  note:SetWidth(W - 60)
  note:SetText("Nothing leaves your computer until you upload. The game saves this addon's data when you log out or reload, so do one of those before uploading the saved file. The Upload button gives you a code to paste instead.")
  local done = ns.Button(settings, "Done", 80, function() settings:Hide() end)
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
