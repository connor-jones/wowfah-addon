-- The look of every wowfah window: flat dark panels, thin borders, one brass accent. Kept in one place so
-- the windows match each other and the website.

local _, ns = ...

ns.C = {
  bg = { 0.045, 0.055, 0.05, 0.97 }, panel = { 0.075, 0.09, 0.08, 1 }, raised = { 0.11, 0.13, 0.115, 1 },
  line = { 0.19, 0.23, 0.20, 1 }, brass = { 0.83, 0.64, 0.30, 1 }, text = { 0.92, 0.91, 0.86, 1 },
  dim = { 0.58, 0.62, 0.58, 1 }, up = { 0.50, 0.77, 0.42, 1 }, down = { 0.87, 0.39, 0.31, 1 },
}
local C = ns.C

local function thin(tex, horizontal)
  -- one screen pixel whatever the interface scale, where the game can work that out
  if PixelUtil and PixelUtil.SetHeight then
    if horizontal then PixelUtil.SetHeight(tex, 1) else PixelUtil.SetWidth(tex, 1) end
  elseif horizontal then tex:SetHeight(1) else tex:SetWidth(1) end
end

-- a flat background and a one pixel border on any frame
function ns.Flat(f, bg, border)
  bg, border = bg or C.panel, border or C.line
  local fill = f:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(f)
  fill:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
  f.fill = fill
  f.edges = {}
  for i, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                       { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
    t:SetPoint(e[1])
    t:SetPoint(e[2])
    thin(t, e[3])
    f.edges[i] = t
  end
  return f
end

function ns.SetBorder(f, colour)
  for _, t in ipairs(f.edges or {}) do t:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1) end
end

-- a horizontal rule across a frame, `y` below its top
function ns.Rule(f, y, inset)
  local t = f:CreateTexture(nil, "BORDER")
  t:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  t:SetPoint("TOPLEFT", inset or 0, y)
  t:SetPoint("TOPRIGHT", -(inset or 0), y)
  thin(t, true)
  return t
end

local FONT = { title = "GameFontNormalLarge", big = "GameFontNormalLarge", body = "GameFontHighlight",
  small = "GameFontHighlightSmall", label = "GameFontNormalSmall", number = "NumberFontNormal" }

function ns.Text(parent, kind, colour)
  local t = parent:CreateFontString(nil, "OVERLAY", FONT[kind] or FONT.body)
  colour = colour or (kind == "label" and C.brass) or (kind == "title" and C.brass) or C.text
  t:SetTextColor(colour[1], colour[2], colour[3])
  t:SetJustifyH("LEFT")
  return t
end

-- a flat button; `primary` fills it with the accent colour
function ns.Button(parent, label, width, onClick, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 24)
  ns.Flat(b, primary and { C.brass[1] * 0.9, C.brass[2] * 0.9, C.brass[3] * 0.9, 1 } or C.raised, primary and C.brass or C.line)
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("CENTER")
  t:SetText(label)
  if primary then t:SetTextColor(0.08, 0.07, 0.04) else t:SetTextColor(C.text[1], C.text[2], C.text[3]) end
  b.label = t
  b:SetScript("OnEnter", function(self)
    ns.SetBorder(self, C.brass)
    if not primary then t:SetTextColor(C.brass[1], C.brass[2], C.brass[3]) end
  end)
  b:SetScript("OnLeave", function(self)
    ns.SetBorder(self, primary and C.brass or C.line)
    if not primary then t:SetTextColor(C.text[1], C.text[2], C.text[3]) end
  end)
  b:SetScript("OnClick", onClick)
  return b
end

function ns.Check(parent, label, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
  local t = ns.Text(parent, "small")
  t:SetPoint("LEFT", c, "RIGHT", 2, 0)
  t:SetText(label)
  c.label = t
  return c
end

-- gold, silver and copper with the game's coin icons, for headline figures and tooltips
function ns.Coins(copper)
  copper = math.floor((copper or 0) + 0.5)
  local sign = ""
  if copper < 0 then sign, copper = "-", -copper end
  local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
  local s = fn and ns.Try(fn, copper)
  if s and s ~= "" then return sign .. s end
  return sign .. ns.FormatMoney(copper)
end

function ns.Colour(t, colour)
  t:SetTextColor(colour[1], colour[2], colour[3])
end
