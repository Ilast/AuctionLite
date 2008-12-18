-------------------------------------------------------------------------------
-- BuyFrame.lua
--
-- Implements the "Buy" tab.
-------------------------------------------------------------------------------

local BUY_DISPLAY_SIZE = 15;

-- Info about data to be shown in scrolling pane.
local BuyScrollName = nil;
local BuyScrollData = {};

-- Selected item in the scrolling pane, if any.
local BuySelectedItem = nil;

-- Set the data for the scrolling frame.
function AuctionLite:SetBuyScrollData(name, data)
  table.sort(data, function(a, b) return a.price < b.price end);

  BuyScrollName = name;
  BuyScrollData = data;
end

-- Get the currently selected item.
function AuctionLite:GetBuyItem()
  return BuyScrollName, BuyScrollData[BuySelectedItem];
end

-- We placed a bid on the selected item at the given price.
function AuctionLite:BidPlaced(bid)
  BuyScrollData[BuySelectedItem].bid = bid;
  self:AuctionFrameBuy_Update();
end

-- We bought out the selected item.
function AuctionLite:BuyoutPlaced()
  table.remove(BuyScrollData, BuySelectedItem);
  BuySelectedItem = nil;
  self:AuctionFrameBuy_Update();
end

-- Handles clicks on the buttons in the "Buy" scroll frame.
function AuctionLite:BuyButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);
  BuySelectedItem = offset + id;
  self:AuctionFrameBuy_Update();
end

-- Handles clicks on the "Bid" button
function AuctionLite:BuyBidButton_OnClick()
  self:QueryBid(BuyScrollName);
end

-- Handles clicks on the "Buyout" button
function AuctionLite:BuyBuyoutButton_OnClick()
  self:QueryBuy(BuyScrollName);
end

-- Handle clicks on the "Buy" tab search button.
function AuctionLite:AuctionFrameBuy_Search()
  self:QuerySearch(BuyName:GetText());
end

-- Adjust frame buttons for repaint.
function AuctionLite:AuctionFrameBuy_OnUpdate()
  local canSend = CanSendAuctionQuery("list");
  if canSend and not self:QueryInProgress() and
     BuySelectedItem ~= nil then
    BuyBidButton:Enable();
  else
    BuyBidButton:Disable();
  end
  if canSend and not self:QueryInProgress() and
     BuySelectedItem ~= nil and BuyScrollData[BuySelectedItem].buyout > 0 then
    BuyBuyoutButton:Enable();
  else
    BuyBuyoutButton:Disable();
  end
end

-- Paint the scroll frame on the right-hand side with competing auctions.
function AuctionLite:AuctionFrameBuy_Update()
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);

  local i;
  for i = 1, BUY_DISPLAY_SIZE do
    local item = BuyScrollData[offset + i];

    local buttonName = "BuyButton" .. i;
    local button = _G[buttonName];

    if item ~= nil then
      local itemCount = _G[buttonName .. "Count"];
      local itemName = _G[buttonName .. "Name"];
      local bidEachFrame = _G[buttonName .. "BidEachFrame"];
      local bidFrame = _G[buttonName .. "BidFrame"];
      local buyoutEachFrame = _G[buttonName .. "BuyoutEachFrame"];
      local buyoutFrame = _G[buttonName .. "BuyoutFrame"];

      local r, g, b, a = 1.0, 1.0, 1.0, 1.0;
      if item.owner == UnitName("player") then
        b = 0.0;
      end

      itemCount:SetText(tostring(item.count) .. "x");
      itemCount:SetVertexColor(r, g, b);
      itemCount:SetAlpha(a);

      itemName:SetText(BuyScrollName);
      itemName:SetVertexColor(r, g, b);
      itemName:SetAlpha(a);

      MoneyFrame_Update(bidEachFrame, math.floor(item.bid / item.count));
      bidEachFrame:SetAlpha(0.5);
      if item.bidder then
        SetMoneyFrameColor(buttonName .. "BidEachFrame", "yellow");
      end

      MoneyFrame_Update(bidFrame, math.floor(item.bid));
      bidFrame:SetAlpha(0.5);
      if item.bidder then
        SetMoneyFrameColor(buttonName .. "BidFrame", "yellow");
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

      if offset + i == BuySelectedItem then
        button:LockHighlight();
      else
        button:UnlockHighlight();
      end

      button:Show();
    else
      button:Hide();
    end
  end

  FauxScrollFrame_Update(BuyScrollFrame, table.getn(BuyScrollData),
                         BUY_DISPLAY_SIZE, BuyButton1:GetHeight());

  if table.getn(BuyScrollData) > 0 then
    BuyHeader:Show();
  else
    BuyHeader:Hide();
  end
end

-- Clean up the "Buy" tab.
function AuctionLite:ClearBuyFrame()
  BuyScrollName = nil;
  BuyScrollData = {};
  BuySelectedItem = nil;

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
