-------------------------------------------------------------------------------
-- BuyFrame.lua
--
-- Implements the "Buy" tab.
-------------------------------------------------------------------------------

local BUY_DISPLAY_SIZE = 15;

-- Data to be shown in detail view.
local DetailLink = nil;
local DetailName = nil;
local DetailData = {};

-- Selected item in detail view.
local SelectedItem = nil;

-- Data to be shown in summary view.
local SummaryData = {};

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

  for link, result in pairs(results) do
    table.sort(result.data, function(a, b) return a.price < b.price end);

    table.insert(SummaryData, link);

    count = count + 1;
    last = link;
  end

  if count > 1 then
    last = nil;
  end

  table.sort(SummaryData,
    function(a, b) return self:SplitLink(a) < self:SplitLink(b) end);

  SearchData = results;
  self:SetDetailLink(last);
end

-- Get the currently selected item.
function AuctionLite:GetDetailLink()
  return DetailName, DetailData[SelectedItem];
end

-- We placed a bid on the selected item at the given price.
function AuctionLite:BidPlaced(bid)
  DetailData[SelectedItem].bid = bid;
  self:AuctionFrameBuy_Update();
end

-- We bought out the selected item.
function AuctionLite:BuyoutPlaced()
  table.remove(DetailData, SelectedItem);
  SelectedItem = nil;
  self:AuctionFrameBuy_Update();
end

-- Handles clicks on the buttons in the "Buy" scroll frame.
function AuctionLite:BuyButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);

  if DetailLink ~= nil then
    SelectedItem = offset + id;
  else
    self:SetDetailLink(SummaryData[offset + id]);
  end

  self:AuctionFrameBuy_Update();
end

-- Handles clicks on the "Summary" button
function AuctionLite:BuySummaryButton_OnClick()
  self:SetDetailLink(nil);
  self:AuctionFrameBuy_Update();
end

-- Handles clicks on the "Bid" button
function AuctionLite:BuyBidButton_OnClick()
  self:QueryBid(DetailName);
end

-- Handles clicks on the "Buyout" button
function AuctionLite:BuyBuyoutButton_OnClick()
  self:QueryBuy(DetailName);
end

-- Handle clicks on the "Buy" tab search button.
function AuctionLite:AuctionFrameBuy_Search()
  self:QuerySearch(BuyName:GetText());
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
     SelectedItem ~= nil then
    BuyBidButton:Enable();
  else
    BuyBidButton:Disable();
  end

  if canSend and not self:QueryInProgress() and DetailLink ~= nil and
     SelectedItem ~= nil and DetailData[SelectedItem].buyout > 0 then
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

  -- Use detail view if we've chosen an item, or summary view otherwise.
  if DetailLink ~= nil then
    self:AuctionFrameBuy_UpdateDetail();
  else
    self:AuctionFrameBuy_UpdateSummary();
  end
end

-- Update the scroll frame with the detail view.
function AuctionLite:AuctionFrameBuy_UpdateDetail()
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);

  local i;
  for i = 1, BUY_DISPLAY_SIZE do
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
        SetMoneyFrameColor(buttonName .. "BidEachFrame", "yellow");
      else
        SetMoneyFrameColor(buttonName .. "BidEachFrame", "white");
      end

      MoneyFrame_Update(bidFrame, math.floor(item.bid));
      bidFrame:SetAlpha(0.5);
      if item.bidder then
        SetMoneyFrameColor(buttonName .. "BidFrame", "yellow");
      else
        SetMoneyFrameColor(buttonName .. "BidFrame", "white");
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
                         BUY_DISPLAY_SIZE, BuyButton1:GetHeight());

  if table.getn(DetailData) > 0 then
    BuyHeader:Show();
  end
end

-- Update the scroll frame with the summary view.
function AuctionLite:AuctionFrameBuy_UpdateSummary()
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);

  local i;
  for i = 1, BUY_DISPLAY_SIZE do
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
                         BUY_DISPLAY_SIZE, BuyButton1:GetHeight());

  if table.getn(SummaryData) > 0 then
    BuySummaryHeader:Show();
  end
end

-- Clean up the "Buy" tab.
function AuctionLite:ClearBuyFrame()
  DetailLink = nil;
  DetailName = nil;
  DetailData = {};
  SelectedItem = nil;

  SummaryData = {};

  SearchData = nil;

  BuyName:SetText("");

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
