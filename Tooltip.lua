-------------------------------------------------------------------------------
-- Tooltip.lua
--
-- Displays tooltips with vendor and auction prices.
-------------------------------------------------------------------------------

local MAX_BANK_COLUMNS = 7;
local MAX_BANK_ROWS = 14;

local LinkTooltips = true;

-- Make an appropriate money string
function AuctionLite:AddTooltipLine(tooltip, option, getPrice, label,
                                    link, count1, count2)
  if option ~= "c_no" then
    local priceInfo;
    local price = getPrice(link);
    if price ~= nil then
      priceInfo = self:PrintMoney(price * count1);
      if count2 ~= nil then
        priceInfo = priceInfo .. " |cffffffff-|r " ..
                    self:PrintMoney(price * count2);
      end
    end
    if priceInfo ~= nil then
      tooltip:AddDoubleLine(label, priceInfo);
    elseif option == "a_yes" then
      tooltip:AddDoubleLine(label, "|cffffffffn/a|r");
    end
  end
end

-- Add vendor and auction data to a tooltip.  We have count1 and count2
-- for the upper and lower bound on the number of items; count2 may be nil.
function AuctionLite:AddTooltipData(tooltip, link, count1, count2)
  if link ~= nil and count1 ~= nil then
    -- Do we multiply by the stack size?
    local stackPrice = self.db.profile.showStackPrice;
    if (stackPrice and IsShiftKeyDown()) or
       (not stackPrice and not IsShiftKeyDown()) then
      count1 = 1;
      count2 = nil;
    end

    -- Figure out how to display the multiplier.
    local suffix;
    if count2 == nil then
      suffix = " |cffb09000(x" .. count1 .. ")|r";
    else
      suffix = " |cffb09000(x" .. count1 .. "-" .. count2 .. ")|r";
    end

    -- Add lines for vendor, auction, and disenchant as appropriate.
    self:AddTooltipLine(tooltip, self.db.profile.showVendor,
      function(link) return AuctionLite:GetVendorValue(link) end,
      "Vendor" .. suffix, link, count1, count2);

    self:AddTooltipLine(tooltip, self.db.profile.showDisenchant,
      function(link) return AuctionLite:GetDisenchantValue(link) end,
      "Disenchant" .. suffix, link, count1, count2);

    self:AddTooltipLine(tooltip, self.db.profile.showAuction,
      function(link) return AuctionLite:GetAuctionValue(link) end,
      "Auction" .. suffix, link, count1, count2);

    tooltip:Show();
  end
end

-- Add data to bag item tooltips.
function AuctionLite:BagTooltip(tooltip, bag, slot)
  if tooltip:NumLines() > 0 then
    local link = GetContainerItemLink(bag, slot);
    local _, count = GetContainerItemInfo(bag, slot);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to inventory/bank tooltips.
function AuctionLite:InventoryTooltip(tooltip, unit, slot)
  if tooltip:NumLines() > 0 and
     not (20 <= slot and slot <= 23) and  -- skip inventory bags
     not (68 <= slot and slot <= 74) then -- skip bank bags
    local link = GetInventoryItemLink(unit, slot);
    local count = GetInventoryItemCount(unit, slot);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to guild bank tooltips.
function AuctionLite:GuildBankTooltip(tooltip, tab, slot)
  if tooltip:NumLines() > 0 then
    local link = GetGuildBankItemLink(tab, slot);
    local _, count = GetGuildBankItemInfo(tab, slot);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to trade skill tooltips.
function AuctionLite:TradeSkillTooltip(tooltip, recipe, reagent)
  if tooltip:NumLines() > 0 then
    local link;
    local count1;
    local count2;
    if reagent == nil then
      -- We want the target of this skill.  If we make multiple items,
      -- estimate the value based on the average number produced.
      link = GetTradeSkillItemLink(recipe);
      local min, max = GetTradeSkillNumMade(recipe);
      count1 = min;
      if min ~= max then
        count2 = max;
      end
    else
      -- We want a reagent.
      link = GetTradeSkillReagentItemLink(recipe, reagent);
      _, _, count1 = GetTradeSkillReagentInfo(recipe, reagent);
    end
    self:AddTooltipData(tooltip, link, count1, count2);
  end
end

-- Add data to merchant tooltips.
function AuctionLite:MerchantTooltip(tooltip, id)
  if tooltip:NumLines() > 0 then
    local link = GetMerchantItemLink(id);
    local _, _, _, count = GetMerchantItemInfo(id);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to buyback tooltips.
function AuctionLite:BuybackTooltip(tooltip, id)
  if tooltip:NumLines() > 0 then
    local link = GetBuybackItemLink(id);
    local _, _, _, count = GetBuybackItemInfo(id);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to quest item tooltips.
function AuctionLite:QuestTooltip(tooltip, itemType, id)
  if tooltip:NumLines() > 0 then
    local link = GetQuestItemLink(itemType, id);
    local _, _, count = GetQuestItemInfo(itemType, id);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to quest log item tooltips.
function AuctionLite:QuestLogTooltip(tooltip, itemType, id)
  if tooltip:NumLines() > 0 then
    local link = GetQuestLogItemLink(itemType, id);
    local _, _, count = GetQuestLogRewardInfo(id);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to loot item tooltips.
function AuctionLite:LootTooltip(tooltip, id)
  if tooltip:NumLines() > 0 and LootSlotIsItem(id) then
    local link = GetLootSlotLink(id);
    local _, _, count = GetLootSlotInfo(id);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to loot roll item tooltips.
function AuctionLite:LootRollTooltip(tooltip, id)
  if tooltip:NumLines() > 0 then
    local link = GetLootRollItemLink(id);
    local _, _, count = GetLootRollItemInfo(id);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to auction item tooltips.
function AuctionLite:AuctionTooltip(tooltip, itemType, index)
  if tooltip:NumLines() > 0 then
    local link = GetAuctionItemLink(itemType, index);
    local _, _, count = GetAuctionItemInfo(itemType, index);
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to auction sell item tooltips.
function AuctionLite:AuctionSellTooltip(tooltip)
  if tooltip:NumLines() > 0 then
    local _, _, count, _, _, _, link = self:GetAuctionSellItemInfoAndLink();
    self:AddTooltipData(tooltip, link, count);
  end
end

-- Add data to item link tooltips.
function AuctionLite:HyperlinkTooltip(tooltip, link)
  if tooltip:NumLines() > 0 and link:find("item") and LinkTooltips then
    self:AddTooltipData(tooltip, link, 1);
  end
end

-- Enable/disable hyperlink tooltips.
function AuctionLite:SetHyperlinkTooltips(enabled)
  LinkTooltips = enabled;
end

-- Guild bank buttons don't have an update function for their tooltips.
-- Add one of our own so that they change when you hit shift!
function AuctionLite:HookBankTooltips()
  local i, j;
  for i = 1, MAX_BANK_COLUMNS do
    for j = 1, MAX_BANK_ROWS do
      local button = _G["GuildBankColumn" .. i .. "Button" .. j];
      if button ~= nil then
        button.UpdateTooltipOrigAL = button.UpdateTooltip;
        button.UpdateTooltip = function(button)
          if button.UpdateTooltipOrigAL ~= nil then
            button:UpdateTooltipOrigAL();
          end
          GuildBankItemButton_OnEnter(button);
        end
      end
    end
  end
end

-- Hook a given tooltip.
function AuctionLite:AddHooksToTooltip(tooltip)
  self:SecureHook(tooltip, "SetBagItem", "BagTooltip");
  self:SecureHook(tooltip, "SetInventoryItem", "InventoryTooltip");
  self:SecureHook(tooltip, "SetGuildBankItem", "GuildBankTooltip");
  self:SecureHook(tooltip, "SetTradeSkillItem", "TradeSkillTooltip");
  self:SecureHook(tooltip, "SetMerchantItem", "MerchantTooltip");
  self:SecureHook(tooltip, "SetBuybackItem", "BuybackTooltip");
  self:SecureHook(tooltip, "SetQuestItem", "QuestTooltip");
  self:SecureHook(tooltip, "SetQuestLogItem", "QuestLogTooltip");
  self:SecureHook(tooltip, "SetLootItem", "LootTooltip");
  self:SecureHook(tooltip, "SetLootRollItem", "LootRollTooltip");
  self:SecureHook(tooltip, "SetAuctionItem", "AuctionTooltip");
  self:SecureHook(tooltip, "SetAuctionSellItem", "AuctionSellTooltip");
  self:SecureHook(tooltip, "SetHyperlink", "HyperlinkTooltip");
end

-- Add all of our tooltip hooks.
function AuctionLite:HookTooltips()
  self:AddHooksToTooltip(GameTooltip);
  self:AddHooksToTooltip(ItemRefTooltip);
end
