-------------------------------------------------------------------------------
-- AuctionFrame.lua
--
-- UI functions for modifying the parent auction frame.
-------------------------------------------------------------------------------

-- Index of our tab in the auction frame.
local BuyTabIndex = nil;
local SellTabIndex = nil;

-- Use this update event to do a bunch of housekeeping.
function AuctionLite:AuctionFrame_OnUpdate()
  -- Continue pending auction queries.
  self:QueryUpdate();

  -- Update the scan button.
  local canSend = CanSendAuctionQuery("list");
  if canSend and not self:QueryInProgress() then
    BrowseScanButton:Enable();
  else
    BrowseScanButton:Disable();
  end
end

-- Handle tab clicks by showing or hiding our frame as appropriate.
function AuctionLite:AuctionFrameTab_OnClick_Hook(button, index)
  if not index then
    index = button:GetID();
  end

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
  if IsAltKeyDown() and button == "RightButton" then
    local container = widget:GetParent():GetID();
    local slot = widget:GetID();

    if AuctionFrameBuy:IsVisible() then
      self:BagClickBuy(container, slot);
    elseif AuctionFrameSell:IsVisible() then
      self:BagClickSell(container, slot);
    else
      AuctionFrameTab_OnClick(_G["AuctionFrameTab" .. SellTabIndex]);
      self:BagClickSell(container, slot);
    end
  end
end

-- Updates our scan progress.
function AuctionLite:UpdateProgressScan(pct)
  self:UpdateProgressSearch(pct);

  if pct == 100 then
    BrowseScanText:SetText("");
  else
    BrowseScanText:SetText(tostring(pct) .. "%");
  end
end

-- Adds our scan button to the "Browse" tab.
function AuctionLite:ModifyBrowseTab()
  local buttonText = "Scan";
  local scanOffset = 185;
  local pctOffset = 4;

  -- If Auctioneer is around, move our button out of the way.
  if AucAdvanced ~= nil then
    buttonText = "AL Scan";
    scanOffset = 485;
    pctOffset = 2;
  end

  -- Create the scan button.
  local scan = CreateFrame("Button", "BrowseScanButton", AuctionFrameBrowse, "UIPanelButtonTemplate");
  scan:SetWidth(65);
  scan:SetHeight(22);
  scan:SetText(buttonText);
  scan:SetPoint("TOPLEFT", AuctionFrameBrowse, "TOPLEFT", scanOffset, -410);
  scan:SetScript("OnClick", function() AuctionLite:StartFullScan() end);

  -- Create the status text next to it.
  local scanText = AuctionFrameBrowse:CreateFontString("BrowseScanText", "BACKGROUND", "GameFontNormal");
  scanText:SetPoint("TOPLEFT", scan, "TOPRIGHT", pctOffset, -5);
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
  local tab = CreateFrame("Button", "AuctionFrameTab" .. tabIndex, AuctionFrame, "AuctionTabTemplate");
  tab:SetID(tabIndex);
  tab:SetText(name);
  tab:SetPoint("TOPLEFT", "AuctionFrameTab" .. (tabIndex - 1), "TOPRIGHT", -8, 0);

  -- Link it into the auction frame.
  PanelTemplates_DeselectTab(tab);
  PanelTemplates_SetNumTabs(AuctionFrame, tabIndex);

  frame:SetParent(AuctionFrame);
  frame:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 0, 0);

  return tabIndex;
end

-- Add our tabs.
function AuctionLite:AddAuctionFrameTabs()
  self:ModifyBrowseTab();
  BuyTabIndex = self:CreateBuyFrame();
  SellTabIndex = self:CreateSellFrame();
end
