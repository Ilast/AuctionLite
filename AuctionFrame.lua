-------------------------------------------------------------------------------
-- AuctionFrame.lua
--
-- UI functions for modifying the parent auction frame.
-------------------------------------------------------------------------------

-- Index of our tab in the auction frame.
local BuyTabIndex = nil;
local SellTabIndex = nil;

-- Currently open AH tab.
local CurrentTab = nil;

-- Use this update event to do a bunch of housekeeping.
function AuctionLite:AuctionFrame_OnUpdate()
  -- Continue pending auction queries.
  self:QueryUpdate();
end

-- Handle tab clicks by showing or hiding our frame as appropriate.
function AuctionLite:AuctionFrameTab_OnClick_Hook(button, index)
  if not index then
    index = button:GetID();
  end

  CurrentTab = index;

  AuctionFrameBuy:Hide();
  AuctionFrameSell:Hide();

  if index == BuyTabIndex then
    AuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopLeft");
    AuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-Top");
    AuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopRight");
    AuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft");
    AuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-Bot");
    AuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight");
    AuctionFrameBuy:Show();
    BuyName:SetFocus();
  elseif index == SellTabIndex then
    AuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopLeft");
    AuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
    AuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
    AuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotLeft");
    AuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
    AuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotRight");
    AuctionFrameSell:Show();
  end
end

-- Adds our hook to the main auction frame's update handler.
function AuctionLite:HookAuctionFrameUpdate()
  local frameUpdate = AuctionFrame:GetScript("OnUpdate");
  AuctionFrame:SetScript("OnUpdate", function()
    if frameUpdate ~= nil then
      frameUpdate();
    end
    AuctionLite:AuctionFrame_OnUpdate();
  end);
end

-- Handle modified clicks on bag spaces.
function AuctionLite:ContainerFrameItemButton_OnModifiedClick_Hook(widget, button)
  if AuctionFrame:IsShown() then
    local container = widget:GetParent():GetID();
    local slot = widget:GetID();

    if IsAltKeyDown() and button == "RightButton" then
      AuctionFrameTab_OnClick(_G["AuctionFrameTab" .. SellTabIndex]);
      self:BagClickSell(container, slot);
    elseif IsControlKeyDown() and button == "RightButton" then
      AuctionFrameTab_OnClick(_G["AuctionFrameTab" .. BuyTabIndex]);
      self:BagClickBuy(container, slot);
    elseif IsShiftKeyDown() and button == "LeftButton" and
           CurrentTab == BuyTabIndex then
      self:BagClickBuy(container, slot);
    end
  end
end

-- Jump to the selected tab on opening the AH.
function AuctionLite:AUCTION_HOUSE_SHOW()
  local jumpTab = nil;

  if self.db.profile.startTab == "b_buy" then
    jumpTab = BuyTabIndex;
  elseif self.db.profile.startTab == "c_sell" then
    jumpTab = SellTabIndex;
  elseif self.db.profile.startTab == "d_last" then
    jumpTab = self.db.profile.lastTab;
  end

  if jumpTab ~= nil and _G["AuctionFrameTab" .. jumpTab] ~= nil then
    AuctionFrameTab_OnClick(_G["AuctionFrameTab" .. jumpTab]);
  end

  if self.db.profile.openBags then
    OpenAllBags(true);
  end
end

-- Clean up if the auction house is closed.
function AuctionLite:AUCTION_HOUSE_CLOSED()
  self.db.profile.lastTab = CurrentTab;

  self:ClearBuyFrame();
  self:ClearSellFrame();
  self:ClearSavedPrices();

  self:ResetAuctionCreation();

  collectgarbage("collect");
end

-- Create a new tab on the auction frame.  Caller provides the name of the
-- tab and the frame object to which it will be linked.
function AuctionLite:CreateTab(name, frame)
  -- Find a free index.
  local tabIndex = 1;
  while getglobal("AuctionFrameTab" .. tabIndex) ~= nil do
    tabIndex = tabIndex + 1;
  end

  -- Create the tab itself.
  local tab = CreateFrame("Button", "AuctionFrameTab" .. tabIndex,
                          AuctionFrame, "AuctionTabTemplate");
  tab:SetID(tabIndex);
  tab:SetText(name);
  tab:SetPoint("TOPLEFT", "AuctionFrameTab" .. (tabIndex - 1),
               "TOPRIGHT", -8, 0);

  -- Link it into the auction frame.
  PanelTemplates_DeselectTab(tab);
  PanelTemplates_SetNumTabs(AuctionFrame, tabIndex);

  frame:SetParent(AuctionFrame);
  frame:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 0, 0);

  return tabIndex;
end

-- Add our tabs.
function AuctionLite:AddAuctionFrameTabs()
  BuyTabIndex = self:CreateBuyFrame();
  SellTabIndex = self:CreateSellFrame();
end
