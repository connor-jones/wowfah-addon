-- Price questions in guild chat. Off until you switch it on in Settings or with /wowfah guild on.
-- A guild member types a question mark and an item link, and one player running the addon answers with one short
-- line from the synced price list. Nothing else is ever sent: no links to websites, no repeats, no whispers.

local _, ns = ...

local MARK = "(wowfah)"
local answered = {}      -- itemID -> when somebody last answered, so two players never answer the same question
local lastSent = 0

-- "? [item link]" -> itemID, the link as sent
function ns.GuildQuestion(msg)
  if type(msg) ~= "string" then return nil end
  local link, id = msg:match("^%s*%?%s*(|c.-|Hitem:(%d+).-|h%[.-%]|h|r)%s*$")
  if not id then return nil end
  return tonumber(id), link
end

-- the one line we would answer with, or nil when there is no price for the item
function ns.GuildAnswer(itemID, link)
  local market, at, lowest, sold = ns.SitePrice(itemID)
  if not market then return nil end
  local text = (link or ("item " .. itemID)) .. ": market " .. ns.FormatMoney(market)
  if lowest and lowest > 0 then text = text .. ", lowest " .. ns.FormatMoney(lowest) end
  if sold and sold > 0 then text = text .. ", about " .. sold .. " sold a day" end
  return text .. ", " .. ns.Ago(at) .. " " .. MARK
end

local function send(text)
  local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if fn then ns.Try(fn, text, "GUILD") end
end

-- returns the text it will send (after a short random wait), or nil
function ns.OnGuildChat(msg)
  if type(msg) ~= "string" then return nil end
  local now = time()
  -- an answer from anyone running the addon, ourselves included, settles the question for a minute
  if msg:find(MARK, 1, true) then
    local id = tonumber(msg:match("|Hitem:(%d+)"))
    if id then answered[id] = now end
    return nil
  end
  if not (ns.db and ns.db.guildReply) then return nil end
  local id, link = ns.GuildQuestion(msg)
  if not id or (answered[id] and now - answered[id] < 60) or now - lastSent < 5 then return nil end
  local text = ns.GuildAnswer(id, link)
  if not text then return nil end
  local function go()
    if answered[id] and time() - answered[id] < 60 then return end
    answered[id], lastSent = time(), time()
    send(text)
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.5 + math.random() * 2, go) else go() end
  return text
end

ns.On("CHAT_MSG_GUILD", function(msg) pcall(ns.OnGuildChat, msg) end)
