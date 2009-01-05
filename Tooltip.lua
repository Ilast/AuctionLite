-------------------------------------------------------------------------------
-- Tooltip.lua
--
-- Displays tooltips with vendor and auction prices.
-------------------------------------------------------------------------------

local LinkTooltips = true;

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

    -- First add vendor info.  Always print a line for the vendor price.
    if self.db.profile.showVendor then
      local _, id = self:SplitLink(link);
      local vendor = self.VendorData[id];
      local vendorInfo;
      if vendor ~= nil then
        vendorInfo = self:PrintMoney(vendor * count1);
        if count2 ~= nil then
          vendorInfo = vendorInfo .. " |cffffffff-|r " ..
                       self:PrintMoney(vendor * count2);
        end
      else
        vendorInfo = "|cffffffffn/a|r";
      end
      tooltip:AddDoubleLine("Vendor" .. suffix, vendorInfo);
    end

    -- Next show the auction price, if any exists.
    if self.db.profile.showAuction then
      local hist = self:GetHistoricalPrice(link);
      if hist ~= nil and hist.price ~= nil then
        local auctionInfo = self:PrintMoney(hist.price * count1);
        if count2 ~= nil then
          auctionInfo = auctionInfo .. " |cffffffff-|r " ..
                        self:PrintMoney(hist.price * count2);
        end
        tooltip:AddDoubleLine("Auction" .. suffix, auctionInfo);
      end
    end

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
  if tooltip:NumLines() > 0 and LinkTooltips then
    self:AddTooltipData(tooltip, link, 1);
  end
end

-- Enable/disable hyperlink tooltips.
function AuctionLite:SetHyperlinkTooltips(enabled)
  LinkTooltips = enabled;
end

-- Hook a given tooltip.
function AuctionLite:AddHooksToTooltip(tooltip)
  self:SecureHook(tooltip, "SetBagItem", "BagTooltip");
  self:SecureHook(tooltip, "SetInventoryItem", "InventoryTooltip");
  self:SecureHook(tooltip, "SetGuildBankItem", "GuildBankTooltip");
  self:SecureHook(tooltip, "SetTradeSkillItem", "TradeSkillTooltip");
  self:SecureHook(tooltip, "SetQuestItem", "QuestTooltip");
  self:SecureHook(tooltip, "SetQuestLogItem", "QuestLogTooltip");
  self:SecureHook(tooltip, "SetAuctionItem", "AuctionTooltip");
  self:SecureHook(tooltip, "SetAuctionSellItem", "AuctionSellTooltip");
  self:SecureHook(tooltip, "SetHyperlink", "HyperlinkTooltip");
end

-- Add all of our tooltip hooks.
function AuctionLite:HookTooltips()
  self:AddHooksToTooltip(GameTooltip);
  self:AddHooksToTooltip(ItemRefTooltip);
end
