-- Export code for copy and paste at wowfah.com/ledger/upload, for players who would rather not upload
-- the saved file. The code is the same data, compressed when the game provides a compressor.

local _, ns = ...

-- one line per record; the first field says what the line is
function ns.BuildLines()
  local db = ns.db
  local out = { ns.Row("V", db.v or 1, ns.VERSION, db.share and 1 or 0, time()) }
  for key, row in pairs(db.chars) do out[#out + 1] = "C|" .. ns.Clean(key) .. "|" .. row end
  for i = 1, #db.events do out[#out + 1] = "E|" .. db.events[i] end
  for i = 1, #db.owned do out[#out + 1] = "O|" .. db.owned[i] end
  for i = 1, #db.sightings do out[#out + 1] = "S|" .. db.sightings[i] end
  for k, v in pairs(db.debug) do out[#out + 1] = ns.Row("D", k, v) end
  return out
end

function ns.BuildExport()
  local text = table.concat(ns.BuildLines(), "\n")
  if C_EncodingUtil and C_EncodingUtil.CompressString and C_EncodingUtil.EncodeBase64 then
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local packed = ns.Try(C_EncodingUtil.CompressString, text, method)
    local encoded = packed and ns.Try(C_EncodingUtil.EncodeBase64, packed)
    if encoded then return "WFL1:" .. encoded end
  end
  return "WFL0:" .. text
end

local exportFrame

function ns.ShowExport()
  local code = ns.BuildExport()
  if not exportFrame then
    local f = CreateFrame("Frame", "WowfahLedgerExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(520, 320)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
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

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("wowfah Ledger export")
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 14, -34)
    hint:SetText("Press Ctrl+C (Cmd+C on a Mac) to copy, then paste at wowfah.com/ledger/upload")

    local scroll = CreateFrame("ScrollFrame", "WowfahLedgerExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -54)
    scroll:SetPoint("BOTTOMRIGHT", -34, 44)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(460)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)
    f.box = box

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(90, 22)
    close:SetPoint("BOTTOMRIGHT", -12, 12)
    close:SetText(CLOSE or "Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.note:SetPoint("BOTTOMLEFT", 14, 16)
    exportFrame = f
  end
  exportFrame.box:SetText(code)
  exportFrame.note:SetText(string.format("%d characters. If copying is slow, upload the saved file instead: /wowfah path", #code))
  exportFrame:Show()
  exportFrame.box:SetFocus()
  exportFrame.box:HighlightText()
end
