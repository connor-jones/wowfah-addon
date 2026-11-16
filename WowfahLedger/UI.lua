-- The in-game ledger window: your profit for today, 7 days, 30 days and all time, and recent activity.

local _, ns = ...

local window
local LINES = 11

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

local LABEL = { sale = "|cff7fc46cSold|r", purchase = "|cffde6450Bought|r", expired = "|cff869186Expired|r",
  cancelled = "|cff869186Cancelled|r", posted = "|cffd4a44cPosted|r" }

local function recentLines()
  local out = {}
  for i = #ns.db.events, 1, -1 do
    local kind, ts, _, _, name, qty, gross, deposit = ns.db.events[i]:match(
      "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if kind ~= "posted" then
      local amount = (kind == "sale" or kind == "purchase") and ns.FormatMoney(tonumber(gross)) or
        ((tonumber(deposit) or 0) > 0 and ("deposit lost " .. ns.FormatMoney(tonumber(deposit))) or "")
      out[#out + 1] = string.format("%s  %s  %s x%s  %s", date("%d %b %H:%M", tonumber(ts) or 0), LABEL[kind] or kind, name, qty, amount)
      if #out >= LINES then break end
    end
  end
  return out
end

function ns.RefreshUI()
  if not (window and window:IsShown()) then return end
  local now = time()
  local d = date("*t", now)
  local midnight = now - (d.hour * 3600 + d.min * 60 + d.sec)
  local rows = { { "Today", midnight }, { "7 days", now - 7 * 86400 }, { "30 days", now - 30 * 86400 }, { "All time", 0 } }
  for i, r in ipairs(rows) do
    local s = ns.Summarise(r[2])
    local colour = s.profit >= 0 and "|cff7fc46c" or "|cffde6450"
    window.sum[i]:SetText(string.format("|cffd4a44c%s|r   profit %s%s|r   sold %s (%d)   fees %s   bought %s (%d)",
      r[1], colour, ns.FormatMoney(s.profit), ns.FormatMoney(s.sales), s.nSales, ns.FormatMoney(s.fees + s.lost),
      ns.FormatMoney(s.bought), s.nBought))
  end
  local lines = recentLines()
  for i = 1, LINES do window.recent[i]:SetText(lines[i] or "") end
  if #lines == 0 then window.recent[1]:SetText("Nothing recorded yet. Collect auction house mail and it will appear here.") end
  window.share:SetChecked(ns.db.share and true or false)
  if window.loot then window.loot:SetChecked(ns.db.lootShare == true) end
end

local function build()
  local f = CreateFrame("Frame", "WowfahLedgerWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(620, 400)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.04, 0.06, 0.05, 0.96)
    f:SetBackdropBorderColor(0.83, 0.64, 0.30, 1)
  end
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "WowfahLedgerWindow") end   -- Escape closes it

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("wowfah Ledger")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPRIGHT", -16, -18)
  sub:SetText("Full history and charts at wowfah.com/ledger")

  f.sum = {}
  for i = 1, 4 do
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 16, -30 - i * 20)
    t:SetJustifyH("LEFT")
    f.sum[i] = t
  end
  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 16, -142)
  head:SetText("Recent activity")
  f.recent = {}
  for i = 1, LINES do
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", 16, -148 - i * 15)
    t:SetWidth(588)
    t:SetJustifyH("LEFT")
    f.recent[i] = t
  end

  local share = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  share:SetSize(24, 24)
  share:SetPoint("BOTTOMLEFT", 12, 10)
  share:SetScript("OnClick", function(self) ns.db.share = self:GetChecked() and true or false end)
  local shareText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  shareText:SetPoint("LEFT", share, "RIGHT", 2, 0)
  shareText:SetText("Share anonymous sale prices with wowfah.com when I upload")
  f.share = share

  local loot = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  loot:SetSize(24, 24)
  loot:SetPoint("BOTTOMLEFT", 12, 32)
  loot:SetScript("OnClick", function(self) if ns.SetLoot then ns.SetLoot(self:GetChecked() and true or false, true) end end)
  local lootText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lootText:SetPoint("LEFT", loot, "RIGHT", 2, 0)
  lootText:SetText("Share what drops where (creatures, nodes, vendors, quests). No character names")
  f.loot = loot

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("BOTTOMRIGHT", -12, 12)
  close:SetText(CLOSE or "Close")
  close:SetScript("OnClick", function() f:Hide() end)
  local export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  export:SetSize(110, 22)
  export:SetPoint("RIGHT", close, "LEFT", -6, 0)
  export:SetText("Export code")
  export:SetScript("OnClick", function() ns.ShowExport() end)
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
