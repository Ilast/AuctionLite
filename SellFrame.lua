-------------------------------------------------------------------------------
-- SellFrame.lua
--
-- Implements the "Sell" tab.
-------------------------------------------------------------------------------

local SELL_DISPLAY_SIZE = 16;

-- Pricing methods.
local METHOD_PER_ITEM = 1;
local METHOD_PER_STACK = 2;

-- Durations.
local DURATION_SHORT = 1;
local DURATION_MEDIUM = 2;
local DURATION_LONG = 3;

-- Info about data to be shown in scrolling pane.
local ScrollName = nil;
local ScrollData = {};

-- Value of item currently in "Sell" tab.
local ItemValue = nil;

-- User-specified bid and buyout values for current item.
local ItemBid = nil;
local ItemBuyout = nil;

-- Status shown in auction posting frame.
local StatusMessage = "";
local StatusError = false;

-- Previous prices set by the user.
local SavedPrices = {};

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

-- Set the market value for the current item.
function AuctionLite:SetItemValue(value)
  ItemValue = value;
  ItemBid = nil;
  ItemBuyout = nil;
end

-- Set the user-specified bid and buyout.
function AuctionLite:SetItemBidBuyout(bid, buyout)
  ItemBid = bid;
  ItemBuyout = buyout;
end

-- Fill in suggested prices based on a query result or a change in the
-- stack size.
function AuctionLite:UpdatePrices()
  if ItemValue ~= nil then
    local bid, buyout;
    if ItemBid ~= nil and ItemBuyout ~= nil then
      bid, buyout = ItemBid, ItemBuyout;
    else
      bid, buyout = self:GeneratePrice(ItemValue);
    end

    -- If we're pricing by stack, multiply by our stack size.
    if self.db.profile.method == METHOD_PER_STACK then
      local stackSize = SellSize:GetNumber();
      bid = bid * stackSize;
      buyout = buyout * stackSize;
    end
    
    MoneyInputFrame_SetCopper(SellBidPrice, math.floor(bid + 0.5));
    SellBidPrice.expectChanges = SellBidPrice.expectChanges + 1;

    MoneyInputFrame_SetCopper(SellBuyoutPrice, math.floor(buyout + 0.5));
    SellBuyoutPrice.expectChanges = SellBuyoutPrice.expectChanges + 1;

    -- Validate auction and enable create button.
    self:ValidateAuction();
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
    if self.db.profile.method == METHOD_PER_ITEM then
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
  if AuctionFrameSell:IsShown() and not self:CreateInProgress() then
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

      SellStacks:SetFocus();

      local total = self:CountItems(link);
      SellStackText:SetText("Number of Items |cff808080(max " .. total .. ")|r");

      self:UpdateDeposit();
      if self:QuerySell(link) then
        self:UpdateProgressSell(0);
      end
    end
  end
end

-- Forget all our saved prices.
function AuctionLite:ClearSavedPrices()
  SavedPrices = {};
end

-- Clean up the "Sell" tab.
function AuctionLite:ClearSellFrame()
  self:ResetQuery();

  ScrollName = nil;
  ScrollData = {};

  ItemValue = nil;
  ItemBid = nil;
  ItemBuyout = nil;

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

-- Get our query results.
function AuctionLite:SetSellData(results, link)
  -- Get our recommended item value.
  local result = results[link];
  local itemValue = 0;
  if result ~= nil and result.listings > 0 then
    itemValue = result.price;
    local name = self:SplitLink(link);
    self:SetScrollData(name, result.data);
    self:ShowPriceData(link, itemValue, SellSize:GetNumber());
    self:SetStatus("|cff00ff00Scanned " ..
                   self:MakePlural(result.listings,  "listing") .. ".|r");
  else
    local hist = self:GetHistoricalPrice(link);
    if hist ~= nil then
      itemValue = hist.price;
      self:SetStatus("|cffff0000Using historical data.|r");
    else
      local _, _, count, _, _, vendor = GetAuctionSellItemInfo();
      itemValue = 3 * vendor / count;
      self:SetStatus("|cffff0000Using 3x vendor price.|r");
    end
  end
  self:SetItemValue(itemValue);

  -- Load the user's saved price, if it exists.
  local saved = SavedPrices[link];
  if saved ~= nil then
    self:SetStatus("|cff00ff00Using previous price.|r");
    self:SetItemBidBuyout(saved.bid, saved.buyout);
  end

  -- Update the UI.
  self:UpdatePrices();
  self:AuctionFrameSell_Update();
end

-- Save the current prices for later use.
function AuctionLite:RecordSellPrices()
  if ItemBid ~= nil and ItemBuyout ~= nil then
    local _, _, _, _, _, _, link = self:GetAuctionSellItemInfoAndLink();
    if link then
      SavedPrices[link] = { bid = ItemBid, buyout = ItemBuyout };
    end
  end
end

-- Handles clicks on buttons in the "Competing Auctions" display.
-- Get the appropriate auction and undercut it!
function AuctionLite:SellButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(SellScrollFrame);
  local item = ScrollData[offset + id];

  if item ~= nil then
    if item.owner == UnitName("player") then
      self:SetItemBidBuyout(item.bid / item.count, item.buyout / item.count);
    else
      self:SetItemValue(item.price);
    end

    self:UpdatePrices();
  end
end

-- Mouse has entered a row in the scrolling frame.
function AuctionLite:SellButton_OnEnter(widget)
  -- Get our index into the current display data.
  local offset = FauxScrollFrame_GetOffset(SellScrollFrame);
  local id = widget:GetID();

  -- If there's an item at this location, create a tooltip for it.
  local item = ScrollData[offset + id];
  if item ~= nil then
    local _, _, _, _, _, _, link = self:GetAuctionSellItemInfoAndLink();
    local shift = SellButton1Name:GetLeft() - SellButton1Count:GetLeft();

    GameTooltip:SetOwner(widget, "ANCHOR_TOPLEFT", shift);
    GameTooltip:SetHyperlink(link);
    self:AddTooltipData(GameTooltip, link, item.count);
  end
end

-- Mouse has left a row in the scrolling frame.
function AuctionLite:SellButton_OnLeave(widget)
  GameTooltip:Hide();
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

-- Handle updates to the auction duration.
function AuctionLite:ChangeAuctionDuration(value)
  self.db.profile.duration = value;

  SellShortAuctionButton:SetChecked(nil);
  SellMediumAuctionButton:SetChecked(nil);
  SellLongAuctionButton:SetChecked(nil);

  if value == DURATION_SHORT then
    SellShortAuctionButton:SetChecked(true);
  elseif value == DURATION_MEDIUM then
    SellMediumAuctionButton:SetChecked(true);
  elseif value == DURATION_LONG then
    SellLongAuctionButton:SetChecked(true);
  end

  self:UpdateDeposit();
end

-- Handle updates to the pricing method.
function AuctionLite:ChangePricingMethod(value)
  local prevValue = self.db.profile.method;
  self.db.profile.method = value;

  local stackSize = SellSize:GetNumber();

  -- Clear everything.
  SellPerItemButton:SetChecked(nil);
  SellPerStackButton:SetChecked(nil);

  -- Now update the UI based on the new value.
  if value == METHOD_PER_ITEM then
    SellPerItemButton:SetChecked(true);

    SellBidStackText:SetText("|cff808080(per item)|r");
    SellBuyoutStackText:SetText("|cff808080(per item)|r");
  elseif value == METHOD_PER_STACK then
    SellPerStackButton:SetChecked(true);

    SellBidStackText:SetText("|cff808080(per stack)|r");
    SellBuyoutStackText:SetText("|cff808080(per stack)|r");
  end

  -- Update the listed prices based on the new pricing method.
  self:UpdatePrices();
end

-- User changed the prices manually.
function AuctionLite:UserChangedPrices()
  -- Get the user's values.
  local bid = MoneyInputFrame_GetCopper(SellBidPrice);
  local buyout = MoneyInputFrame_GetCopper(SellBuyoutPrice);

  -- If we're pricing by stack, divide by our stack size.
  if self.db.profile.method == METHOD_PER_STACK then
    local stackSize = SellSize:GetNumber();
    bid = bid / stackSize;
    buyout = buyout / stackSize;
  end

  -- Set our new state.
  self:SetItemBidBuyout(bid, buyout);
end

-- Update query progress.
function AuctionLite:UpdateProgressSell(pct)
  self:SetStatus("|cffffff00Scanning: " .. pct .. "%|r");
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

      MoneyFrame_Update(buyoutEachFrame, math.floor(item.buyout / item.count + 0.5));
      buyoutEachFrame:SetAlpha(a);

      MoneyFrame_Update(buyoutFrame, math.floor(item.buyout + 0.5));
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

-- Handle bag item clicks by dropping the item into the sell tab.
function AuctionLite:BagClickSell(container, slot)
  if GetContainerItemLink(container, slot) ~= nil then
    ClearCursor();
    ClickAuctionSellItemButton();
    ClearCursor();
    PickupContainerItem(container, slot);
    ClickAuctionSellItemButton();
  end
end

-- Create the "Sell" tab.
function AuctionLite:CreateSellFrame()
  -- Create our tab.
  local index = self:CreateTab("AuctionLite - Sell", AuctionFrameSell);

  -- Set our constants.
  SellPerItemButton:SetID(METHOD_PER_ITEM);
  SellPerStackButton:SetID(METHOD_PER_STACK);

  SellShortAuctionButton:SetID(DURATION_SHORT);
  SellMediumAuctionButton:SetID(DURATION_MEDIUM);
  SellLongAuctionButton:SetID(DURATION_LONG);

  -- Set up tabbing between fields.
  MoneyInputFrame_SetNextFocus(SellBidPrice, SellBuyoutPriceGold);
  MoneyInputFrame_SetPreviousFocus(SellBidPrice, SellSize);

  MoneyInputFrame_SetNextFocus(SellBuyoutPrice, SellStacks);
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

