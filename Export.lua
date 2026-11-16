-- Export code for copy and paste at wowfah.com/ledger/upload, for players who would rather not upload
-- the saved file. The code is the same data, compressed when the game provides a compressor.

local _, ns = ...

-- one line per record; the first field says what the line is
function ns.BuildLines()
  local db = ns.db
  local out = { ns.Row("V", db.v or 1, ns.VERSION, db.share and 1 or 0, time(),
    db.lootShare == nil and "" or (db.lootShare and 1 or 0), db.install or "") }    -- blank: the loot question is not answered yet
  for key, row in pairs(db.chars) do out[#out + 1] = "C|" .. ns.Clean(key) .. "|" .. row end
  for i = 1, #db.events do out[#out + 1] = "E|" .. db.events[i] end
  for i = 1, #db.owned do out[#out + 1] = "O|" .. db.owned[i] end
  for i = 1, #db.sightings do out[#out + 1] = "S|" .. db.sightings[i] end
  for k, v in pairs(db.debug) do out[#out + 1] = ns.Row("D", k, v) end
  if ns.LootLines then ns.LootLines(out) end
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
    local f = CreateFrame("Frame", "WowfahLedgerExport", UIParent)
    f:SetSize(520, 320)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    ns.Flat(f, ns.C.bg, ns.C.brass)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = ns.Text(f, "title")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Upload to wowfah.com")
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 14, -34)
    hint:SetText("1. Press Ctrl+C (Cmd+C on a Mac)    2. Open wowfah.com/ledger/upload    3. Paste and press Upload")

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

    local close = ns.Button(f, CLOSE or "Close", 90, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -12, 12)
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.note:SetPoint("BOTTOMLEFT", 14, 16)
    exportFrame = f
  end
  exportFrame.box:SetText(code)
  exportFrame.note:SetText(string.format("The code is already selected (%d characters). The website can also read the saved file by itself.", #code))
  exportFrame:Show()
  exportFrame.box:SetFocus()
  exportFrame.box:HighlightText()
end
