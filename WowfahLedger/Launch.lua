-- Ways to open the ledger without typing a command: a minimap button, a button on the auction house and the
-- mailbox, and the addon list by the minimap where the game has one.

local _, ns = ...

ns.ICON = "Interface\\AddOns\\WowfahLedger\\icon"

local mini

local function place()
  if not (mini and Minimap) then return end
  local angle = math.rad((ns.db.minimap and ns.db.minimap.angle) or 215)
  local radius = ((ns.Try(Minimap.GetWidth, Minimap) or 140) / 2) + 6
  mini:ClearAllPoints()
  mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function follow()
  -- while it is being dragged, keep the button on the rim of the minimap under the cursor
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale() or 1
  if not (mx and px) then return end
  local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
  ns.db.minimap.angle = math.deg(atan2(py / scale - my, px / scale - mx)) % 360
  place()
end

local function tip(owner, anchor)
  if not GameTooltip then return end
  GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
  GameTooltip:AddLine("wowfah Ledger")
  GameTooltip:AddLine(ns.TodayLine and ns.TodayLine() or "", 1, 1, 1)
  GameTooltip:AddLine("Click to open your ledger", 0.6, 0.65, 0.6)
  GameTooltip:AddLine("Right-click for an upload code", 0.6, 0.65, 0.6)
  GameTooltip:Show()
end

local function click(_, mouse)
  if mouse == "RightButton" then
    if ns.ShowExport then ns.ShowExport() end
  elseif ns.ToggleUI then
    ns.ToggleUI()
  end
end

local function buildMinimapButton()
  if mini or not Minimap then return end
  local b = CreateFrame("Button", "WowfahLedgerMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture(ns.ICON)
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetPoint("TOPLEFT")
  b:SetScript("OnClick", click)
  b:SetScript("OnEnter", function(self) tip(self) end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", follow) end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mini = b
  place()
end

function ns.ShowMinimapButton(show)
  ns.db.minimap = ns.db.minimap or { angle = 215 }
  ns.db.minimap.hide = not show
  if show then
    if not mini then pcall(buildMinimapButton) end
    if mini then mini:Show() end
  elseif mini then
    mini:Hide()
  end
  if ns.RefreshUI then ns.RefreshUI() end
end

-- a small button on the auction house and the mailbox, where the ledger is most wanted
local attached = {}
local function attach(parent)
  if not parent or attached[parent] then return end
  attached[parent] = true
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(112, 22)
  b:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -6, 1)
  b:SetText("wowfah Ledger")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", click)
  b:SetScript("OnEnter", function(self) tip(self, "ANCHOR_TOP") end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

ns.On("AUCTION_HOUSE_SHOW", function() pcall(attach, AuctionHouseFrame or AuctionFrame) end)
ns.On("MAIL_SHOW", function() pcall(attach, MailFrame) end)

-- the game's own addon list beside the minimap, where it exists (named in the .toc file)
function WowfahLedger_OnAddonCompartmentClick(_, mouse)
  click(nil, mouse)
end

ns.On("PLAYER_LOGIN", function()
  ns.db.minimap = ns.db.minimap or { angle = 215 }
  if not ns.db.minimap.hide then pcall(buildMinimapButton) end
  if not ns.db.welcomed then
    ns.db.welcomed = true
    ns.Print("is recording your auction house sales. Click the coin button on the minimap to open your ledger.")
  end
end)
