-------------------------------------------------------------------------------
-- SellFrame.lua
--
-- Implements the "Sell" tab.
-------------------------------------------------------------------------------

local SELL_DISPLAY_SIZE = 16;

-- Info about data to be shown in scrolling pane.
local ScrollName = nil;
local ScrollData = {};

-- Value of item currently in "Sell" tab.
local ItemValue = 0;

-- Status shown in auction posting frame.
local StatusMessage = "";
local StatusError = false;

-- Add a money type that updates the deposit correctly.
MoneyTypeInfo["AUCTIONLITE_DEPOSIT"] = {
  UpdateFunc = function() return AuctionLite:CalculateDeposit() end,
  collapse = 1,
}

-- Determine the correct deposit for a single item.
function AuctionLite:CalculateDeposit()
  local time = self:GetDuration();
  local stacks = SellStacks:GetNumber();
  local size = SellSize:GetNumber();
  local _, _, count = GetAuctionSellItemInfo();

  return math.floor(CalculateAuctionDeposit(time) * stacks * size / count);
end

-- Update the deposit field.
function AuctionLite:UpdateDeposit()
  MoneyFrame_Update("SellDepositMoneyFrame", self:CalculateDeposit());
end

-- Generate a suggested bid and buyout from the market value.  These
-- are 98% and 80% of the market value, respectively, rounded down to
-- a reasonably "pretty" number.
function AuctionLite:GeneratePrice(value)
  local digits = math.floor(math.log10(value));
  local granularity = math.pow(10, math.max(0, digits - 2)) * 5;

  local bid = math.floor((value * 0.80) / granularity) * granularity;
  local buyout = math.floor((value * 0.98) / granularity) * granularity;

  return bid, buyout;
end

-- Generate price, and dump some data to the console.
function AuctionLite:ShowPriceData(itemLink, itemValue, stackSize)
  local hist = self:GetHistoricalPrice(itemLink);

  local stackValue = itemValue * stackSize;

  local _, _, count, _, _, vendor = GetAuctionSellItemInfo();
  local itemVendor = vendor / count;

  self:Print("|cff8080ffData for " .. itemLink .. " x" .. stackSize .. "|r");
  self:Print("Vendor: " .. self:PrintMoney(itemVendor * stackSize));

  if hist ~= nil and hist.scans > 0 and hist.price > 0 then
    self:Print("Historical: " .. self:PrintMoney(hist.price * stackSize) .. " (" ..
               math.floor(0.5 + hist.listings / hist.scans) .. " listings/scan, " ..
               math.floor(0.5 + hist.items / hist.scans) .. " items/scan)");
    if itemVendor > 0 then
      self:Print("Current: " .. self:PrintMoney(stackValue) .. " (" ..
                 (math.floor(100 * itemValue / hist.price) / 100) .. "x historical, " ..
                 (math.floor(100 * itemValue / itemVendor) / 100) .. "x vendor)");
    else
      self:Print("Current: " .. self:PrintMoney(stackValue) .. " (" ..
                 (math.floor(100 * itemValue / hist.price) / 100) .. "x historical)");
    end
  elseif itemVendor > 0 then
    self:Print("Current: " .. self:PrintMoney(stackValue) .. " (" ..
               (math.floor(100 * itemValue / itemVendor) / 100) .. "x vendor)");
  end

  return bid, buyout;
end

-- Fill in suggested prices based on a query result or a change in the
-- stack size.
function AuctionLite:UpdatePrices(itemValue)
  if itemValue ~= nil then
    ItemValue = itemValue;
  end
  if ItemValue > 0 then
    local bid, buyout = self:GeneratePrice(ItemValue);

    -- If we're pricing by stack, multiply by our stack size.
    if self.db.profile.method == 2 then
      local stackSize = SellSize:GetNumber();
      bid = bid * stackSize;
      buyout = buyout * stackSize;
    end
    
    MoneyInputFrame_SetCopper(SellBidPrice, bid);
    MoneyInputFrame_SetCopper(SellBuyoutPrice, buyout);
  end
end

-- Check whether there are any errors in the auction.
function AuctionLite:ValidateAuction()
  local name, _, count, _, _, vendor, link =
    self:GetAuctionSellItemInfoAndLink();

  if name ~= nil and not self:QueryInProgress() then
    local bid = MoneyInputFrame_GetCopper(SellBidPrice);
    local buyout = MoneyInputFrame_GetCopper(SellBuyoutPrice);

    local stacks = SellStacks:GetNumber();
    local size = SellSize:GetNumber();

    -- If we're pricing by item, get the full stack price.
    if self.db.profile.method == 1 then
      bid = bid * size;
      buyout = buyout * size;
    end
    
    -- Now perform our checks.
    if stacks * size <= 0 then
      StatusError = true;
      SellStatusText:SetText("|cffff0000Invalid stack size/count.|r");
      SellCreateAuctionButton:Disable();
    elseif self:CountItems(link) < stacks * size then
      StatusError = true;
      SellStatusText:SetText("|cffff0000Not enough items available.|r");
      SellCreateAuctionButton:Disable();
    elseif bid == 0 then
      StatusError = true;
      SellStatusText:SetText("|cffff0000No bid price set.|r");
      SellCreateAuctionButton:Disable();
    elseif buyout < bid then
      StatusError = true;
      SellStatusText:SetText("|cffff0000Buyout less than bid.|r");
      SellCreateAuctionButton:Disable();
    elseif GetMoney() < self:CalculateDeposit() then
      StatusError = true;
      SellStatusText:SetText("|cffff0000Not enough cash for deposit.|r");
      SellCreateAuctionButton:Disable();
    elseif buyout <= (vendor * size / count) then
      StatusError = true;
      SellStatusText:SetText("|cffff0000Buyout less than vendor price.|r");
      SellCreateAuctionButton:Disable();
    else
      StatusError = false;
      SellStatusText:SetText(StatusMessage);
      SellCreateAuctionButton:Enable();
    end
  end
end

-- There's been a click on the auction sell item slot.
function AuctionLite:ClickAuctionSellItemButton_Hook()
  -- Ignore clicks that we generated ourselves.
  if not self:CreateInProgress() then
    -- Clear everything first.
    self:ClearSellFrame();

    -- If we've got a new item in the auction slot, fill out the fields.
    local name, texture, count, _, _, _, link =
      self:GetAuctionSellItemInfoAndLink();

    if name ~= nil then
      SellItemButton:SetNormalTexture(texture);
      SellItemButtonName:SetText(name);

      if count > 1 then
        SellItemButtonCount:SetText(count);
        SellItemButtonCount:Show();
      else
        SellItemButtonCount:Hide();
      end

      SellStacks:SetText(1);
      SellSize:SetText(count);

      local total = self:CountItems(link);
      SellStackText:SetText("Number of Items |cff808080(max " .. total .. ")|r");

      self:UpdateDeposit();
      self:QuerySell(link);
    end
  end
end

-- Clean up the "Sell" tab.
function AuctionLite:ClearSellFrame()
  self:ResetQuery();

  ScrollName = nil;
  ScrollData = {};

  SellItemButton:SetNormalTexture(nil);
  SellItemButtonName:SetText("");
  SellItemButtonCount:Hide();

  SellStackText:SetText("Number of Items");
  SellStacks:SetText("");
  SellSize:SetText("");

  MoneyInputFrame_ResetMoney(SellBidPrice);
  MoneyInputFrame_ResetMoney(SellBuyoutPrice);

  SellCreateAuctionButton:Disable();

  self:SetStatus("");
  self:UpdateDeposit();

  FauxScrollFrame_SetOffset(SellScrollFrame, 0);

  self:AuctionFrameSell_Update();
end

-- Set the status line.
function AuctionLite:SetStatus(message)
  StatusMessage = message;
  if not StatusError then
    SellStatusText:SetText(message);
  end
end

-- Set the data for the scrolling frame.
function AuctionLite:SetScrollData(name, data)
  local filtered = {};
  
  local i;
  for i = 1, table.getn(data) do
    if data[i].buyout > 0 then
      table.insert(filtered, data[i]);
    end
  end

  table.sort(filtered, function(a, b) return a.price < b.price end);

  ScrollName = name;
  ScrollData = filtered;
end

-- Handles clicks on buttons in the "Competing Auctions" display.
-- Get the appropriate auction and undercut it!
function AuctionLite:SellButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(SellScrollFrame);
  local item = ScrollData[offset + id];

  if item ~= nil then
    self:UpdatePrices(math.floor(item.price));
  end
end

-- Get the auction duration.
function AuctionLite:GetDuration()
  local time = 0;

  if SellShortAuctionButton:GetChecked() then
    time = 720;
  elseif SellMediumAuctionButton:GetChecked() then
    time = 1440;
  elseif SellLongAuctionButton:GetChecked() then
    time = 2880;
  end

  return time;
end

-- Handle updates to the auction duration (1 = 12h, 2 = 24h, 3 = 48h).
function AuctionLite:ChangeAuctionDuration(value)
  self.db.profile.duration = value;

  SellShortAuctionButton:SetChecked(nil);
  SellMediumAuctionButton:SetChecked(nil);
  SellLongAuctionButton:SetChecked(nil);

  if value == 1 then
    SellShortAuctionButton:SetChecked(true);
  elseif value == 2 then
    SellMediumAuctionButton:SetChecked(true);
  elseif value == 3 then
    SellLongAuctionButton:SetChecked(true);
  end

  self:UpdateDeposit();
end

-- Handle updates to the pricing method (1 = per item, 2 = per stack).
function AuctionLite:ChangePricingMethod(value)
  local prevValue = self.db.profile.method;
  self.db.profile.method = value;

  local stackSize = SellSize:GetNumber();

  -- Clear everything.
  SellPerItemButton:SetChecked(nil);
  SellPerStackButton:SetChecked(nil);

  -- Now update the UI based on the new value.
  if value == 1 then
    -- We're now per-item.
    SellPerItemButton:SetChecked(true);

    SellBidStackText:SetText("|cff808080(per item)|r");
    SellBuyoutStackText:SetText("|cff808080(per item)|r");

    -- Adjust prices if we just came from per-stack.
    if prevValue == 2 and stackSize > 0 then
      local oldBid = MoneyInputFrame_GetCopper(SellBidPrice);
      MoneyInputFrame_SetCopper(SellBidPrice, oldBid / stackSize);

      local oldBuyout = MoneyInputFrame_GetCopper(SellBuyoutPrice);
      MoneyInputFrame_SetCopper(SellBuyoutPrice, oldBuyout / stackSize);
    end
  elseif value == 2 then
    -- We're not per-stack.
    SellPerStackButton:SetChecked(true);

    SellBidStackText:SetText("|cff808080(per stack)|r");
    SellBuyoutStackText:SetText("|cff808080(per stack)|r");

    -- Adjust prices if we just came from per-item.
    if prevValue == 1 and stackSize > 0 then
      local oldBid = MoneyInputFrame_GetCopper(SellBidPrice);
      MoneyInputFrame_SetCopper(SellBidPrice, oldBid * stackSize);

      local oldBuyout = MoneyInputFrame_GetCopper(SellBuyoutPrice);
      MoneyInputFrame_SetCopper(SellBuyoutPrice, oldBuyout * stackSize);
    end
  end
end

-- Paint the scroll frame on the right-hand side with competing auctions.
function AuctionLite:AuctionFrameSell_Update()
  local offset = FauxScrollFrame_GetOffset(SellScrollFrame);

  local i;
  for i = 1, SELL_DISPLAY_SIZE do
    local item = ScrollData[offset + i];

    local buttonName = "SellButton" .. i;
    local button = _G[buttonName];

    if item ~= nil then
      local itemCount = _G[buttonName .. "Count"];
      local itemName = _G[buttonName .. "Name"];
      local buyoutEachFrame = _G[buttonName .. "BuyoutEachFrame"];
      local buyoutFrame = _G[buttonName .. "BuyoutFrame"];

      local r, g, b, a = 1.0, 1.0, 1.0, 1.0;
      if item.owner == UnitName("player") then
        b = 0.0;
      elseif not item.keep then
        a = 0.5;
      end

      itemCount:SetText(tostring(item.count) .. "x");
      itemCount:SetVertexColor(r, g, b);
      itemCount:SetAlpha(a);

      itemName:SetText(ScrollName);
      itemName:SetVertexColor(r, g, b);
      itemName:SetAlpha(a);

      MoneyFrame_Update(buyoutEachFrame, math.floor(item.buyout / item.count));
      buyoutEachFrame:SetAlpha(a);

      MoneyFrame_Update(buyoutFrame, math.floor(item.buyout));
      buyoutFrame:SetAlpha(a);

      button:Show();
    else
      button:Hide();
    end
  end

  FauxScrollFrame_Update(SellScrollFrame, table.getn(ScrollData),
                         SELL_DISPLAY_SIZE, SellButton1:GetHeight());
end

-- Handle clicks on the scroll bar.
function AuctionLite:SellScrollFrame_OnVerticalScroll(offset)
  FauxScrollFrame_OnVerticalScroll(
    SellScrollFrame, offset, SellButton1:GetHeight(),
    function() AuctionLite:AuctionFrameSell_Update() end);
end

-- Create the "Sell" tab.
function AuctionLite:CreateSellFrame()
  -- Create our tab.
  local index = self:CreateTab("AuctionLite - Sell", AuctionFrameSell);

  -- Set up tabbing between fields.
  MoneyInputFrame_SetNextFocus(SellBidPrice, SellBuyoutPriceGold);
  MoneyInputFrame_SetPreviousFocus(SellBidPrice, size);

  MoneyInputFrame_SetNextFocus(SellBuyoutPrice, stacks);
  MoneyInputFrame_SetPreviousFocus(SellBuyoutPrice, SellBidPriceCopper);

	-- Miscellaneous additional setup.
	MoneyFrame_SetType(SellDepositMoneyFrame, "AUCTIONLITE_DEPOSIT");

  -- Make sure it's pristine.
  self:ClearSellFrame();

  -- Set preferences.
  self:ChangeAuctionDuration(self.db.profile.duration);
  self:ChangePricingMethod(self.db.profile.method);

  return index;
end

