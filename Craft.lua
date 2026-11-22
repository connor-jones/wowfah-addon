-- Crafting profit from the synced price list: what the result sells for after the cut, minus the materials at market
-- price. Shown on the profession window for the recipe you are looking at, and as a short list with /wowfah crafts.
-- Read only: the addon never crafts, buys or posts anything.

local _, ns = ...

-- recipe: { out = item id, qty = how many one craft makes, reagents = { { id, qty }, ... } }
-- -> { revenue, cost, profit, missing (materials with no price) } or nil when the result has no price
function ns.CraftProfit(recipe)
  if type(recipe) ~= "table" or not recipe.out then return nil end
  local price = ns.SitePrice(recipe.out)
  if not price then return nil end
  local cost, missing = 0, 0
  for _, r in ipairs(recipe.reagents or {}) do
    local p = ns.SitePrice(r.id)
    if p then cost = cost + p * (r.qty or 1) else missing = missing + 1 end
  end
  local revenue = price * (recipe.qty or 1) * ns.Keep()
  return { revenue = revenue, cost = cost, profit = revenue - cost, missing = missing }
end

-- one recipe from the game, in the shape above (or nil)
function ns.ReadRecipe(recipeID)
  local T = C_TradeSkillUI
  if not (T and T.GetRecipeSchematic and recipeID) then return nil end
  local s = ns.Try(T.GetRecipeSchematic, recipeID, false)
  if type(s) ~= "table" or type(s.outputItemID) ~= "number" or s.outputItemID <= 0 then return nil end
  local lo, hi = tonumber(s.quantityMin) or 1, tonumber(s.quantityMax) or tonumber(s.quantityMin) or 1
  local recipe = { id = recipeID, name = s.name, out = s.outputItemID, qty = math.max(1, (lo + hi) / 2), reagents = {} }
  for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
    -- only the materials every craft needs: optional and finishing slots are left out
    local basic = slot.reagentType == nil or slot.reagentType == 1
    local first = type(slot.reagents) == "table" and slot.reagents[1]
    if basic and slot.required ~= false and type(first) == "table" and first.itemID and (slot.quantityRequired or 0) > 0 then
      recipe.reagents[#recipe.reagents + 1] = { id = first.itemID, qty = slot.quantityRequired }
    end
  end
  return recipe
end

-- the recipes you know in the open profession, most profitable first: { name, profit, cost, revenue, sold }
function ns.Crafts(limit)
  local out = {}
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs) then return out end
  for _, id in ipairs(ns.Try(T.GetAllRecipeIDs) or {}) do
    local info = T.GetRecipeInfo and ns.Try(T.GetRecipeInfo, id)
    if type(info) ~= "table" or info.learned ~= false then
      local recipe = ns.ReadRecipe(id)
      local p = recipe and #recipe.reagents > 0 and ns.CraftProfit(recipe)
      if p and p.missing == 0 and p.profit > 0 then
        local _, _, _, sold = ns.SitePrice(recipe.out)
        out[#out + 1] = { name = recipe.name or (type(info) == "table" and info.name) or ("recipe " .. id),
          profit = p.profit, cost = p.cost, revenue = p.revenue, sold = sold or 0 }
      end
    end
  end
  table.sort(out, function(a, b) if a.profit ~= b.profit then return a.profit > b.profit end return a.name < b.name end)
  for i = #out, (limit or 8) + 1, -1 do out[i] = nil end
  return out
end

function ns.PrintCrafts()
  if type(WowfahPrices) ~= "table" then
    ns.Print("No market prices yet. They come from the wowfah Sync app: wowfah.com/sync")
    return
  end
  local list = ns.Crafts(8)
  if #list == 0 then
    ns.Print("No profitable crafts found. Open a profession window first; recipes with a material that has no price are left out.")
    return
  end
  ns.Print("Most profitable crafts in this profession, at market prices after the cut:")
  for _, c in ipairs(list) do
    ns.Print(string.format("  %s: %s profit each craft (materials %s), about %d sold a day", c.name, ns.Coins(c.profit), ns.Coins(c.cost), c.sold))
  end
end

-- the line under a recipe on the profession window
function ns.RecipeLine(recipeID)
  local recipe = ns.ReadRecipe(recipeID)
  local p = recipe and ns.CraftProfit(recipe)
  if not p then return "" end
  local text = "Materials " .. ns.Coins(p.cost) .. "  |cff7d8a80/|r  sells for " .. ns.Coins(p.revenue) .. " after the cut  |cff7d8a80/|r  "
    .. (p.profit >= 0 and "|cff58c383profit " or "|cffe06a5closs ") .. ns.Coins(math.abs(p.profit)) .. "|r"
  if p.missing > 0 then text = text .. string.format("  (%d material%s without a price)", p.missing, p.missing == 1 and "" or "s") end
  return text
end

local label, hookedForm
local function show(form, info)
  if not label then
    label = form:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 28, 8)
    label:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -28, 8)
    label:SetJustifyH("LEFT")
  end
  local id = type(info) == "table" and info.recipeID
  label:SetText(ns.db and ns.db.tips and id and ns.RecipeLine(id) or "")
end

ns.On("TRADE_SKILL_SHOW", function()
  local page = type(ProfessionsFrame) == "table" and ProfessionsFrame.CraftingPage
  local form = type(page) == "table" and page.SchematicForm
  if type(form) == "table" and type(form.Init) == "function" and hookedForm ~= form then
    hookedForm = form
    hooksecurefunc(form, "Init", function(self, info) pcall(show, self, info) end)
  end
end)
