-------------------------------------------------------------------------------
-- Tooltip.lua
--
-- Displays tooltips with vendor and auction prices.
-------------------------------------------------------------------------------

local L = LibStub("AceLocale-3.0"):GetLocale("AuctionLite", false)

local MAX_BANK_COLUMNS = 7;
local MAX_BANK_ROWS = 14;

local LinkTooltips = true;

local ResetMoneyFrames = {};

MoneyTypeInfo["AUCTIONLITE_TOOLTIP"] = {
  UpdateFunc = function(self) return self.staticMoney end,
  showSmallerCoins = 1,
  collapse = 1,
};

-- Since we futz with the money frame anchors, we need to reset them
-- when the tooltip is cleared.
function AuctionLite:GameTooltip_ClearMoney_Hook(tooltip)
  local money;
  for money, _ in pairs(ResetMoneyFrames) do
    if money ~= nil then
      money:ClearAllPoints();
      money:Hide();
    end
  end
  ResetMoneyFrames = {};
end

-- Make an appropriate money string
function AuctionLite:AddTooltipLine(tooltip, option, getPrice, label,
                                    link, count1, count2)
  -- Do we want any tooltip at all?
  if option ~= "c_no" then
    -- Looks like we do, so fetch the price.
    local price = getPrice(link);
    if price ~= nil then
      -- We have price data here, so now we need to show it.
      price = math.floor(price);
      if self.db.profile.coinTooltips then
        -- We can only show one number, so give the average if there's
        -- a range of prices.
        local priceAvg;
        if count2 == nil then
          priceAvg = price * count1;
        else
          priceAvg = math.floor(price * (count1 + count2) / 2);
        end

        -- Add the money frame.
        SetTooltipMoney(tooltip, priceAvg, "AUCTIONLITE_TOOLTIP", label, nil);

        -- Adjust the money frame so that it aligns right.
        local text = _G[tooltip:GetName() .. "TextLeft" ..  tooltip:NumLines()];
        local moneyName = tooltip:GetName() .. "MoneyFrame" ..
                          tooltip.shownMoneyFrames;
        local money = _G[moneyName];
        local moneyPrefix = _G[moneyName .. "PrefixText"];

        text:SetText(label);
        moneyPrefix:Hide();

        money:ClearAllPoints();
        money:SetPoint("RIGHT", tooltip, "RIGHT", -5, 0);
        money:SetPoint("TOP", text, "TOP", 0, 0);

        ResetMoneyFrames[money] = true;
      else
        -- Show the old-school text tooltip.
        local priceInfo = self:PrintMoney(price * count1);
        if count2 ~= nil then
          priceInfo = priceInfo .. " |cffffffff-|r " ..
                      self:PrintMoney(price * count2);
        end

        tooltip:AddDoubleLine(label, priceInfo);
      end
    elseif option == "a_yes" then
      -- We have no price info, but the user wants a line anyway.
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

    -- Remember how many money frames this tooltip had originally.
    local startMoney = tooltip.shownMoneyFrames;
    if startMoney == nil then
      startMoney = 0;
    end

    -- Add lines for vendor, auction, and disenchant as appropriate.
    self:AddTooltipLine(tooltip, self.db.profile.showVendor,
      function(link) return AuctionLite:GetVendorValue(link) end,
      "|cffffd000" .. L["Vendor"] .. "|r" .. suffix, link, count1, count2);

    self:AddTooltipLine(tooltip, self.db.profile.showDisenchant,
      function(link) return AuctionLite:GetDisenchantValue(link) end,
      "|cffffd000" .. L["Disenchant"] .. "|r" .. suffix, link, count1, count2);

    self:AddTooltipLine(tooltip, self.db.profile.showAuction,
      function(link) return AuctionLite:GetAuctionValue(link) end,
      "|cffffd000" .. L["Auction"] .. "|r" .. suffix, link, count1, count2);

    -- Find out how many money frames we added.
    local endMoney = tooltip.shownMoneyFrames;
    if endMoney == nil then
      endMoney = 0;
    end

    -- Figure out the maximum width for each denomination in our tooltips.
    local goldWidth = 0;
    local silverWidth = 0;
    local copperWidth = 0;

    local maxWidth = function(buttonName, width)
      local button = _G[buttonName];
      if button:IsShown() and button:GetWidth() > width then
        return button:GetWidth();
      else
        return width;
      end
    end

    local i;
    for i = startMoney + 1, endMoney do
      local moneyName = tooltip:GetName() .. "MoneyFrame" .. i;
      goldWidth = maxWidth(moneyName .. "GoldButton", goldWidth);
      silverWidth = maxWidth(moneyName .. "SilverButton", silverWidth);
      copperWidth = maxWidth(moneyName .. "CopperButton", copperWidth);
    end

    -- Now update the width of each denomination and each money frame
    -- so that they line up nicely.
    local updateWidth = function(buttonName, newWidth, totalWidth)
      local button = _G[buttonName];
      totalWidth = totalWidth + newWidth - button:GetWidth();
      button:SetWidth(newWidth);
      return totalWidth;
    end

    local i;
    for i = startMoney + 1, endMoney do
      local moneyName = tooltip:GetName() .. "MoneyFrame" .. i;
      local money = _G[moneyName];
      local width = money:GetWidth();
      width = updateWidth(moneyName .. "GoldButton", goldWidth, width);
      width = updateWidth(moneyName .. "SilverButton", silverWidth, width);
      width = updateWidth(moneyName .. "CopperButton", copperWidth, width);
      if tooltip:GetMinimumWidth() < width then
        tooltip:SetMinimumWidth(width);
      end
    end

    -- We're done!  Show the tooltip.
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
  self:SecureHook("GameTooltip_ClearMoney", "GameTooltip_ClearMoney_Hook");
end
