-------------------------------------------------------------------------------
-- BuyFrame.lua
--
-- Implements the "Buy" tab.
-------------------------------------------------------------------------------

local BUY_DISPLAY_SIZE = 15;
local ROW_HEIGHT = 21;
local EXPAND_ROWS = 4;

-- Height of expandable frame.
local ExpandHeight = 0;

-- Data to be shown in detail view.
local DetailLink = nil;
local DetailName = nil;
local DetailData = {};

-- Selected item in detail view.
local SelectedItem = nil;

-- Data to be shown in summary view.
local SummaryData = {};

-- Info about current purchase for display in expandable frame.
local PurchaseOrder = nil;

-- Overall data returned from search.
local SearchData = nil;

-- Set current item to be shown in detail view, and update dependent data.
function AuctionLite:SetDetailLink(link)
  DetailLink = link;

  if DetailLink ~= nil then
    DetailName = self:SplitLink(DetailLink);
    DetailData = SearchData[DetailLink].data;
  else
    DetailName = nil;
    DetailData = {};
  end

  SelectedItem = nil;
end

-- Set the data for the scrolling frame.
function AuctionLite:SetBuyData(results)
  SummaryData = {};

  local count = 0;
  local last = nil;

  -- Sort everything and assemble the summary data.
  for link, result in pairs(results) do
    table.sort(result.data, function(a, b) return a.price < b.price end);

    table.insert(SummaryData, link);

    count = count + 1;
    last = link;
  end

  -- If we found more than one item, just stay at the summary screen.
  -- If we have one item, we'll jump to the detail frame.
  if count > 1 then
    last = nil;
  end

  table.sort(SummaryData,
    function(a, b) return self:SplitLink(a) < self:SplitLink(b) end);

  SearchData = results;
  self:SetDetailLink(last);

  BuyStatusText:Hide();

  self:AuctionFrameBuy_Update();
end

-- Create a purchase order for the selected item in detail view.
function AuctionLite:CreateSingleOrder(isBuyout)
  if DetailLink ~= nil and SelectedItem ~= nil then
    local listing = DetailData[SelectedItem];

    -- Create a purchase order.
    local order = { list = { listing }, price = 0, count = listing.count,
                    batch = 1, isBuyout = isBuyout };

    -- Set the bid/buyout price.
    if isBuyout then
      order.price = listing.buyout;
    else
      order.price = listing.bid;
    end

    -- Compare with historical prices.
    local hist = self:GetHistoricalPrice(DetailLink);
    if hist ~= nil then
      order.histPrice = math.floor(order.count * hist.price);
    else
      order.histPrice = 0;
    end

    -- Submit the query.
    if self:QueryBuy(DetailName, order.list, isBuyout) then
      PurchaseOrder = order;
    end

    -- Update the display.
    self:AuctionFrameBuy_Update();
  end
end

-- Called after a search query ends in order to start a mass buyout.
function AuctionLite:StartMassBuyout()
  -- See if the user requested a specific quantity.
  local requested = BuyQuantity:GetNumber();
  if DetailLink ~= nil and requested > 0 then
    -- Create purchase order object to be filled out.
    local order = { list = {}, price = 0, count = 0,
                    batch = 1, isBuyout = true };

    -- Pick the listings with the lowest per-item prices.
    -- Note that DetailData is sorted!
    local i = 1;
    local warned = false;
    while i <= table.getn(DetailData) and order.count < requested do
      if DetailData[i].buyout > 0 then
        if DetailData[i].owner ~= UnitName("player") then
          table.insert(order.list, DetailData[i]);
          order.price = order.price + DetailData[i].buyout;
          order.count = order.count + DetailData[i].count;
        elseif not warned then
          warned = true;
          self:Print("|cffff0000[Warning]|r Skipping your own auctions. You might want to cancel them instead.");
        end
      end
      i = i + 1;
    end

    -- If we overshot, figure out how much we can resell the excess for.
    if order.count > requested then
      order.resell = order.count - requested;

      local price = SearchData[DetailLink].price;
      order.resellPrice = math.floor(order.resell * price);

      order.netPrice = order.price - order.resellPrice;
    end

    -- Get a historical comparison.
    local hist = self:GetHistoricalPrice(DetailLink);
    if hist ~= nil then
      order.histPrice = math.floor(requested * hist.price);
    else
      order.histPrice = 0;
    end

    -- Submit the query.  If it goes through, save it here too.
    if self:QueryBuy(DetailName, order.list) then
      PurchaseOrder = order;
    end

    -- Update the display.
    self:AuctionFrameBuy_Update();
  end
end

-- The query system needs us to approve purchases.
function AuctionLite:RequestApproval()
  -- Just update the display!
  -- TODO: Process shopping cart here.
  self:AuctionFrameBuy_Update();
end

-- Notification that a purchase has completed.
function AuctionLite:PurchaseComplete()
  -- Update our display according to the purchase.
  if DetailData ~= nil then
    local i = table.getn(DetailData);
    while i > 0 do
      DetailData[i].found = nil;
      if DetailData[i].purchased then
        if PurchaseOrder.isBuyout then
          -- If we bought an item, remove it.
          table.remove(DetailData, i);
          if SelectedItem == i then
            SelectedItem = nil;
          end
        else
          -- If we bid on an item, update the minimum bid.
          local increment = math.floor(DetailData[i].bid / 100) * 5;
          DetailData[i].purchased = false;
          DetailData[i].bidder = 1;
          DetailData[i].bid = DetailData[i].bid + increment;
          if DetailData[i].bid > DetailData[i].buyout and
             DetailData[i].buyout > 0 then
            DetailData[i].bid = DetailData[i].buyout;
          end
        end
      end
      i = i - 1;
    end
  end

  -- Clear our purchase order.
  PurchaseOrder = nil;

  -- Update the display.
  self:AuctionFrameBuy_Update();
end

-- Update search progress display.
function AuctionLite:UpdateProgressSearch(pct)
  BuyStatusText:SetText("Searching: " .. pct .. "%");
end

-- Handles clicks on the buttons in the "Buy" scroll frame.
function AuctionLite:BuyButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);

  if DetailLink ~= nil then
    -- We're in detail view, so select the item.
    SelectedItem = offset + id;
  else
    -- We're in summary view, so switch to detail view.
    self:SetDetailLink(SummaryData[offset + id]);
    self:StartMassBuyout();
  end

  self:AuctionFrameBuy_Update();
end

-- Returns to the summary page.
function AuctionLite:BuySummaryButton_OnClick()
  if PurchaseOrder ~= nil then
    self:QueryCancel();
  end

  self:SetDetailLink(nil);

  self:AuctionFrameBuy_Update();
end

-- Approve a pending purchase.
function AuctionLite:BuyApproveButton_OnClick()
  PurchaseOrder.batch = PurchaseOrder.batch + 1;
  self:QueryApprove();
  self:AuctionFrameBuy_Update();
end

-- Cancel a pending purchase.
function AuctionLite:BuyCancelButton_OnClick()
  self:QueryCancel();
  self:AuctionFrameBuy_Update();
end

-- Bid on the currently-selected item.
function AuctionLite:BuyBidButton_OnClick()
  self:CreateSingleOrder(false);
end

-- Buy out the currently-selected item.
function AuctionLite:BuyBuyoutButton_OnClick()
  self:CreateSingleOrder(true);
end

-- Submit a search query.
function AuctionLite:AuctionFrameBuy_Search()
  if self:QuerySearch(BuyName:GetText()) then
    self:ClearBuyFrame(true);
    self:UpdateProgressSearch(0);
    BuyStatusText:Show();
  end
end

-- Adjust frame buttons for repaint.
function AuctionLite:AuctionFrameBuy_OnUpdate()
  local canSend = CanSendAuctionQuery("list");

  if canSend and not self:QueryInProgress() then
    BuySearchButton:Enable();
  else
    BuySearchButton:Disable();
  end

  if canSend and not self:QueryInProgress() and DetailLink ~= nil and
     SelectedItem ~= nil and
     DetailData[SelectedItem].owner ~= UnitName("player") then
    BuyBidButton:Enable();
  else
    BuyBidButton:Disable();
  end

  if canSend and not self:QueryInProgress() and DetailLink ~= nil and
     SelectedItem ~= nil and
     DetailData[SelectedItem].buyout > 0 and
     DetailData[SelectedItem].owner ~= UnitName("player") then
    BuyBuyoutButton:Enable();
  else
    BuyBuyoutButton:Disable();
  end
end

-- Update the scroll frame with either the detail view or summary view.
function AuctionLite:AuctionFrameBuy_Update()
  -- First clear everything.
  local i;
  for i = 1, BUY_DISPLAY_SIZE do
    local buttonName = "BuyButton" .. i;

    local button = _G[buttonName];
    local buttonDetail = _G[buttonName .. "Detail"];
    local buttonSummary = _G[buttonName .. "Summary"];

    button:Hide();
    buttonDetail:Hide();
    buttonSummary:Hide();
  end

  BuyHeader:Hide();
  BuySummaryHeader:Hide();

  -- Update the expandable header.
  self:AuctionFrameBuy_UpdateExpand();

  -- Use detail view if we've chosen an item, or summary view otherwise.
  if DetailLink ~= nil then
    self:AuctionFrameBuy_UpdateDetail();
  else
    self:AuctionFrameBuy_UpdateSummary();
  end
end

-- Update the expandable frame at the top of the scroll frame.
function AuctionLite:AuctionFrameBuy_UpdateExpand()
  -- Figure out how big a window to make.
  local order = PurchaseOrder;
  if order == nil then
    ExpandHeight = 0;
  elseif order.resell == nil then
    ExpandHeight = 2;
  else
    ExpandHeight = 4;
  end

  -- Set the height of the expandable window.  It's always one higher than
  -- the number of rows because WoW gets confused if it goes to zero;
  -- other frame offsets are computed appropriately.
  BuyExpand:SetHeight((ExpandHeight + 1) * ROW_HEIGHT);

  -- Show rows as appropriate.
  local i;
  for i = 1, EXPAND_ROWS do
    local prefix = "BuyExpand" .. i;
    local text = _G[prefix .. "Text"];
    local money = _G[prefix .. "MoneyFrame"];

    if i <= ExpandHeight then
      text:Show();
      money:Show();
    else
      text:Hide();
      money:Hide();
    end
  end

  -- Populate the expandable frame with appropriate data from the order.
  local order = PurchaseOrder;
  if order ~= nil then
    local action;
    if order.isBuyout then
      action = "Buyout";
    else
      action = "Bid";
    end

    if order.resell == nil then
      BuyExpand1Text:SetText(action .. " cost for " .. order.count .. ":");
      MoneyFrame_Update(BuyExpand1MoneyFrame, order.price);

      BuyExpand2Text:SetText("Historical price for " .. order.count .. ":");
      MoneyFrame_Update(BuyExpand2MoneyFrame, order.histPrice);
    else
      BuyExpand1Text:SetText(action .. " cost for " .. order.count .. ":");
      MoneyFrame_Update(BuyExpand1MoneyFrame, order.price);

      BuyExpand2Text:SetText("Resell " .. order.resell .. ":");
      MoneyFrame_Update(BuyExpand2MoneyFrame, order.resellPrice);
      self:MakeNegative("BuyExpand2MoneyFrame");

      BuyExpand3Text:SetText("Net cost for " .. (order.count - order.resell) .. ":");
      if order.netPrice < 0 then
        MoneyFrame_Update(BuyExpand3MoneyFrame, - order.netPrice);
        self:MakeNegative("BuyExpand3MoneyFrame");
      else
        MoneyFrame_Update(BuyExpand3MoneyFrame, order.netPrice);
      end

      BuyExpand4Text:SetText("Historical price for " .. (order.count - order.resell) .. ":");
      MoneyFrame_Update(BuyExpand4MoneyFrame, order.histPrice);
    end
  end

  -- Fill out the text describing the current batch to be purchased,
  -- assuming we're buying batches.
  BuyBatchText:SetText("");

  local cart = self:GetCart();
  if cart ~= nil and order ~= nil then
    local count = 0;
    local price = 0;

    local i;
    for i = 1, table.getn(cart) do
      count = count + cart[i].count;
      price = price + cart[i].buyout;
    end

    if count < order.count then
      BuyBatchText:SetText("Batch " .. order.batch .. ": " .. count ..
                           " at " .. self:PrintMoney(price));
    end
  end

  -- Show/hide and enable/disable approval buttons.
  if ExpandHeight > 0 then
    BuyApproveButton:Show();
    BuyCancelButton:Show();

    if cart ~= nil then
      BuyApproveButton:Enable();
      BuyCancelButton:Enable();
    else
      BuyApproveButton:Disable();
      BuyCancelButton:Disable();
    end
  else
    BuyApproveButton:Hide();
    BuyCancelButton:Hide();
  end
end

-- Update the scroll frame with the detail view.
function AuctionLite:AuctionFrameBuy_UpdateDetail()
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);
  local displaySize = BUY_DISPLAY_SIZE - ExpandHeight;

  local i;
  for i = 1, displaySize do
    local item = DetailData[offset + i];
    if item ~= nil then
      local buttonName = "BuyButton" .. i;
      local button = _G[buttonName];

      local buttonDetailName = buttonName .. "Detail";
      local buttonDetail     = _G[buttonDetailName];

      local countText        = _G[buttonDetailName .. "Count"];
      local nameText         = _G[buttonDetailName .. "Name"];
      local bidEachFrame     = _G[buttonDetailName .. "BidEachFrame"];
      local bidFrame         = _G[buttonDetailName .. "BidFrame"];
      local buyoutEachFrame  = _G[buttonDetailName .. "BuyoutEachFrame"];
      local buyoutFrame      = _G[buttonDetailName .. "BuyoutFrame"];

      local r, g, b, a = 1.0, 1.0, 1.0, 1.0;
      if item.owner == UnitName("player") then
        b = 0.0;
      end

      countText:SetText(tostring(item.count) .. "x");
      countText:SetVertexColor(r, g, b);
      countText:SetAlpha(a);

      nameText:SetText(DetailName);
      nameText:SetVertexColor(r, g, b);
      nameText:SetAlpha(a);

      MoneyFrame_Update(bidEachFrame, math.floor(item.bid / item.count));
      bidEachFrame:SetAlpha(0.5);
      if item.bidder then
        SetMoneyFrameColor(buttonDetailName .. "BidEachFrame", "yellow");
      else
        SetMoneyFrameColor(buttonDetailName .. "BidEachFrame", "white");
      end

      MoneyFrame_Update(bidFrame, math.floor(item.bid));
      bidFrame:SetAlpha(0.5);
      if item.bidder then
        SetMoneyFrameColor(buttonDetailName .. "BidFrame", "yellow");
      else
        SetMoneyFrameColor(buttonDetailName .. "BidFrame", "white");
      end

      if item.buyout > 0 then
        MoneyFrame_Update(buyoutEachFrame, math.floor(item.buyout / item.count));
        buyoutEachFrame:SetAlpha(a);
        buyoutEachFrame:Show();

        MoneyFrame_Update(buyoutFrame, math.floor(item.buyout));
        buyoutFrame:SetAlpha(a);
        buyoutFrame:Show();
      else
        buyoutEachFrame:Hide();
        buyoutFrame:Hide();
      end

      if offset + i == SelectedItem then
        button:LockHighlight();
      else
        button:UnlockHighlight();
      end

      buttonDetail:Show();
      button:Show();
    end
  end

  FauxScrollFrame_Update(BuyScrollFrame, table.getn(DetailData),
                         displaySize, ROW_HEIGHT);

  if table.getn(DetailData) > 0 then
    BuyHeader:Show();
  end
end

-- Update the scroll frame with the summary view.
function AuctionLite:AuctionFrameBuy_UpdateSummary()
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);
  local displaySize = BUY_DISPLAY_SIZE - ExpandHeight;

  local i;
  for i = 1, displaySize do
    local link = SummaryData[offset + i];
    if link ~= nil then
      local result = SearchData[link];

      local buttonName = "BuyButton" .. i;
      local button = _G[buttonName];

      local buttonSummaryName = buttonName .. "Summary";
      local buttonSummary     = _G[buttonSummaryName];

      local nameText          = _G[buttonSummaryName .. "Name"];
      local listingsText      = _G[buttonSummaryName .. "Listings"];
      local itemsText         = _G[buttonSummaryName .. "Items"];
      local priceFrame        = _G[buttonSummaryName .. "MarketPriceFrame"];

      nameText:SetText(self:SplitLink(link));
      nameText:SetVertexColor(1.0, 1.0, 1.0);
      nameText:SetAlpha(1.0);

      listingsText:SetText(tostring(result.listingsAll));
      listingsText:SetVertexColor(1.0, 1.0, 1.0);
      listingsText:SetAlpha(1.0);

      itemsText:SetText(tostring(result.itemsAll));
      itemsText:SetVertexColor(1.0, 1.0, 1.0);
      itemsText:SetAlpha(1.0);

      MoneyFrame_Update(priceFrame, math.floor(result.price));
      priceFrame:SetAlpha(1.0);

      button:UnlockHighlight();

      buttonSummary:Show();
      button:Show();
    end
  end

  FauxScrollFrame_Update(BuyScrollFrame, table.getn(SummaryData),
                         displaySize, ROW_HEIGHT);

  if table.getn(SummaryData) > 0 then
    BuySummaryHeader:Show();
  end
end

-- Clean up the "Buy" tab.
function AuctionLite:ClearBuyFrame(partial)
  DetailLink = nil;
  DetailName = nil;
  DetailData = {};
  SelectedItem = nil;

  SummaryData = {};

  SearchData = nil;

  ExpandHeight = 0;
  PurchaseOrder = nil;

  if not partial then
    BuyName:SetText("");
    BuyQuantity:SetText("");
    BuyName:SetFocus();
  end

  BuyStatusText:Hide();

  FauxScrollFrame_SetOffset(BuyScrollFrame, 0);

  self:AuctionFrameBuy_Update();
end

-- Create the "Buy" tab.
function AuctionLite:CreateBuyFrame()
  -- Create our tab.
  local index = self:CreateTab("AuctionLite - Buy", AuctionFrameBuy);

  -- Make sure it's pristine.
  self:ClearBuyFrame();

  return index;
end
