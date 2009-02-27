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
local DetailData = {};

-- Save the last selected item.
local DetailLinkPrev = nil;

-- Selected item in detail view and index of last item clicked.
local SelectedItems = {};
local LastClick = nil;

-- Data to be shown in summary view.
local SummaryData = {};

-- Info about current purchase for display in expandable frame.
local PurchaseOrder = nil;

-- Information about current search progress.
local StartTime = nil;
local LastTime = nil;
local LastRemaining = nil;
local Progress = nil;
local GetAll = nil;
local Scanning = nil;

-- Overall data returned from search.
local SearchData = nil;
local NoResults = false;

-- Stored scan data from the latest full scan.
local ScanData = nil;
local DealsMode = false;

-- Data for favorites as they are scanned.
local FavoritesData = {};

-- Static popup advertising AL's fast scan.
StaticPopupDialogs["AL_FAST_SCAN"] = {
	text = "AuctionLite's fast auction scan can scan the entire auction " ..
         "house in a few seconds, but may cause disconnects to occur. " ..
         "\n\n" ..
         "Enable fast auction scans?" ..
         "\n\n" ..
         "(This setting can be modified later on the AuctionLite " ..
         "options screen.)",
	button1 = "Enable",
  button2 = "Disable",
	OnAccept = function(self)
    AuctionLite.db.profile.fastScanAd = true;
    AuctionLite.db.profile.getAll = true;
    AuctionLite:StartFullScan();
  end,
	OnCancel = function(self)
    AuctionLite.db.profile.fastScanAd = true;
    AuctionLite.db.profile.getAll = false;
    AuctionLite:StartFullScan();
  end,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

-- Set current item to be shown in detail view, and update dependent data.
function AuctionLite:SetDetailLink(link)
  DetailLink = link;

  if DetailLink ~= nil then
    DetailData = SearchData[DetailLink].data;
  else
    DetailData = {};
  end

  SelectedItems = {};
  LastClick = nil;
end

-- Set the data for the scrolling frame.
function AuctionLite:SetBuyData(results, dealsMode)
  SummaryData = {};

  local count = 0;
  local last = nil;
  local foundPrev = false;

  -- Sort everything and assemble the summary data.
  for link, result in pairs(results) do
    table.sort(result.data, function(a, b) return a.price < b.price end);

    table.insert(SummaryData, link);

    count = count + 1;
    last = link;

    if DetailLinkPrev == link then
      foundPrev = true;
    end
  end

  -- Sort our data by name/profit.
  local sortByName = function(a, b)
    local aFav = self.db.profile.favorites[a];
    local bFav = self.db.profile.favorites[b];
    if aFav == bFav then
      return self:SplitLink(a) < self:SplitLink(b);
    elseif aFav then
      return true;
    else
      return false;
    end
  end

  local sortByProfit = function(a, b)
    return results[a].profit > results[b].profit;
  end

  if dealsMode then
    table.sort(SummaryData, sortByProfit);
  else
    table.sort(SummaryData, sortByName);
  end

  -- If we found our last-selected item, then select it again.
  -- If we found only one item, select it.  Otherwise, select nothing.
  local newLink = nil;
  if foundPrev then
    newLink = DetailLinkPrev;
  elseif count == 1 then
    newLink = last;
  end
  DetailLinkPrev = nil;

  -- Reset current query info.
  self:ResetSearch();

  -- Save our data and set our detail link, if we only got one kind of item.
  SearchData = results;
  NoResults = (count == 0);
  DealsMode = dealsMode;
  self:SetDetailLink(newLink);

  -- Clean up the display.
  BuyIntroText:Hide();
  BuyNoItemsText:Hide();
  BuyStatus:Hide();

  -- Start a mass buyout, if necessary.
  self:StartMassBuyout();

  -- Repaint.
  self:AuctionFrameBuy_Update();
end

-- Handle results for a full scan.  Make a list of the deals.
function AuctionLite:SetScanData(results)
  ScanData = {};

  -- Search through all scanned items.
  for link, result in pairs(results) do
    local hist = self:GetHistoricalPrice(link);

    -- Find the lowest buyout.
    local min = 0;
    for _, listing in ipairs(result.data) do
      if min == 0 or (0 < listing.buyout and listing.buyout < min) then
        min = listing.buyout;
      end
    end

    -- If it meets a bunch of conditions below, it's considered a deal.
    if min > 0 and hist ~= nil and
       min < hist.price - (10000 * self.db.profile.minProfit) and
       min < hist.price * (1 - self.db.profile.minDiscount) and
       hist.listings / hist.scans > 1.2 then

      result.profit = hist.price - min;
      ScanData[link] = result;
    end
  end

  -- Display our list of deals.
  DetailLinkPrev = nil;
  self:SetBuyData(ScanData, true);
end

-- Determine whether the selected items are biddable/buyable.
function AuctionLite:GetSelectionStatus()
  local biddable = true;
  local buyable = true;
  local found = false;

  if DetailLink ~= nil then
    for i, _ in pairs(SelectedItems) do
      -- We can't bid/buy our own auctions.
      if DetailData[i].owner == UnitName("player") then
        biddable = false;
        buyable = false;
      end
      -- To buy, we must have a buyout price listed.
      if DetailData[i].buyout == 0 then
        buyable = false;
      end
      -- We must find at least one selected item.
      found = true;
    end
  end

  return (found and biddable), (found and buyable);
end

-- Create a purchase order based on the current selection.  The first
-- argument indicates whether we're bidding or buying, and the second
-- argument (optional) indicates the actual number of items the user wants.
function AuctionLite:CreateOrder(isBuyout, requested)
  if DetailLink ~= nil then
    -- Create purchase order object to be filled out.
    local order = { list = {}, price = 0, count = 0,
                    batch = 1, isBuyout = isBuyout };

    -- Add information about each selected item.
    local i;
    for i, _ in pairs(SelectedItems) do
      assert(DetailData[i].owner ~= UnitName("player"));

      local price;
      if isBuyout then
        price = DetailData[i].buyout;
      else
        price = DetailData[i].bid;
      end

      table.insert(order.list, DetailData[i]);
      order.count = order.count + DetailData[i].count;
      order.price = order.price + price;
    end

    -- If we found any selected items and we have enough money, proceed.
    if order.price > GetMoney() then
      self:Print("|cffff0000[Error]|r Insufficient funds.");
    elseif order.count > 0 then
      -- If the second argument wasn't specified, the user wants exactly
      -- the number of items selected.
      if requested == nil then
        requested = order.count;
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

      local name = self:SplitLink(DetailLink);

      -- Submit the query.  If it goes through, save it here too.
      local query = {
        name = name,
        list = order.list,
        isBuyout = isBuyout,
        finish = function() AuctionLite:PurchaseComplete() end,
      };

      if self:StartQuery(query) then
        PurchaseOrder = order;
      end
    end
  end
end

-- Called after a search query ends in order to start a mass buyout.
function AuctionLite:StartMassBuyout()
  -- See if the user requested a specific quantity.
  local requested = BuyQuantity:GetNumber();
  if DetailLink ~= nil and requested > 0 then
    -- Clear our selected items.  (Should already be done, but what the hey.)
    SelectedItems = {};

    -- Pick the listings with the lowest per-item prices.
    -- Note that DetailData is sorted!
    local i = 1;
    local count = 0;
    local warned = false;
    while i <= table.getn(DetailData) and count < requested do
      if DetailData[i].buyout > 0 then
        if DetailData[i].owner ~= UnitName("player") then
          SelectedItems[i] = true;
          count = count + DetailData[i].count;
        elseif not warned then
          warned = true;
          self:Print("|cffff0000[Warning]|r Skipping your own auctions. You might want to cancel them instead.");
        end
      end
      i = i + 1;
    end

    -- Now create our buyout order.
    self:CreateOrder(true, requested);
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
          -- The selected items map is going to get all screwed up, so
          -- just nuke it.  (TODO: Do a better job here!)
          SelectedItems = {};
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
function AuctionLite:UpdateProgressSearch(pct, getAll, scan)
  -- If we got a progress update, record it.
  if pct ~= nil then
    Progress = pct;
  end

  -- Record a start time if we don't have one already.
  if StartTime == nil then
    StartTime = math.floor(time());
  end

  -- Figure out whether we're actually doing getAll and/or scanning.
  if GetAll == nil and getAll ~= nil then
    GetAll = getAll;
  end
  if Scanning == nil and scan ~= nil then
    Scanning = scan;
  end

  -- Update the display every second.
  local currentTime = math.floor(time());
  if LastTime == nil or currentTime > LastTime then
    LastTime = currentTime;

    -- If we have some data, compute the time remaining.
    local elapsed = currentTime - StartTime;
    if elapsed > 0 and Progress > 0 then
      -- In order to reduce jitter in the estimate, do the following:
      -- 1. Update once every two seconds at first.
      -- 2. Average each estimate with the previous one.
      -- 3. Ignore estimates that exceed the previous by less than 10%.
      if Progress > 15 or (elapsed % 2) == 0 then
        local remaining = math.floor((100 * elapsed / Progress) - elapsed);

        if LastRemaining ~= nil then
          remaining = math.floor((remaining + LastRemaining) / 2);

          if remaining > LastRemaining and remaining < LastRemaining * 1.1 then
            remaining = LastRemaining;
          end
        end

        LastRemaining = remaining;

        BuyRemainingData:SetText(self:PrintTime(remaining));
      end
    else
      BuyRemainingData:SetText("---");
    end

    -- Update the percentage.
    if GetAll then
      BuyStatusText:SetText("Scanning...");
      BuyStatusData:SetText("");
    else
      if Scanning then
        BuyStatusText:SetText("Scanning:");
      else
        BuyStatusText:SetText("Searching:");
      end
      BuyStatusData:SetText(tostring(Progress) .. "%");
    end

    -- Update the elapsed time and show the whole pane.
    BuyElapsedData:SetText(self:PrintTime(elapsed));
    BuyStatus:Show();
  end
end

-- Show our progress for the favorites scan.  We assume each scan takes
-- roughly the same amount of time, and then split each segment accordingly.
function AuctionLite:UpdateProgressFavorites(pct)
  local numDone = 0;
  for _, _ in pairs(FavoritesData) do
    numDone = numDone + 1;
  end

  local numFavs = 0;
  for _, _ in pairs(self.db.profile.favorites) do
    numFavs = numFavs + 1;
  end

  local overall = math.floor(((100 * numDone) + pct) / numFavs);
  self:UpdateProgressSearch(overall);
end

-- Take the next step in a favorites scan.  If we need to scan for another
-- item, do it; if there are no favorites left, display our results.
function AuctionLite:FavoritesScan(first)
  local request = nil;
  local link;

  -- Find an unscanned favorite.
  for link, _ in pairs(self.db.profile.favorites) do
    if FavoritesData[link] == nil then
      request = link;
      break;
    end
  end

  if request ~= nil then
    -- Start the scan.
    local query = {
      link = request,
      update = function(pct) AuctionLite:UpdateProgressFavorites(pct) end,
      finish = function(data, link) AuctionLite:SetFavoritesData(data, link) end,
    };

    if self:StartQuery(query) and first then
      DetailLinkPrev = nil;
      self:ClearBuyFrame(true);
    end
  else
    -- Nothing left to scan, so erase any empty objects in our list.
    for link, results in pairs(FavoritesData) do
      if results.empty then
        FavoritesData[link] = nil;
      end
    end

    -- Show our results.
    self:SetBuyData(FavoritesData);
    FavoritesData = {};
  end
end

-- Get the results for a favorites scan.
function AuctionLite:SetFavoritesData(data, searchLink)
  -- Put something in the slot we searched for to make sure we don't
  -- search for it again.
  FavoritesData[searchLink] = { empty = true };

  -- Gather all relevant results returned by the search.
  for link, results in pairs(data) do
    if self.db.profile.favorites[link] then
      FavoritesData[link] = results;
    end
  end

  -- Continue the scan.
  self:FavoritesScan();
end

-- Toggle the favorites flag for this item.
function AuctionLite:FavoritesButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);
  local link = SummaryData[offset + id];

  if self.db.profile.favorites[link] == nil then
    self.db.profile.favorites[link] = true;
  else
    self.db.profile.favorites[link] = nil;
  end

  self:AuctionFrameBuy_Update();
end

-- Handles clicks on the buttons in the "Buy" scroll frame.
function AuctionLite:BuyButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);

  if DetailLink ~= nil then
    -- We're in detail view, so select the item.

    -- Unless we're holding control, this is a new selection.
    if not IsControlKeyDown() then
      SelectedItems = {};
    end

    if LastClick ~= nil and IsShiftKeyDown() then
      -- Shift is down and we have a previous click.
      -- Add all items in this range to the selection.
      local lower = offset + id;
      local upper = offset + id;

      if LastClick < offset + id then
        lower = LastClick;
      else
        upper = LastClick;
      end

      local i;
      for i = lower, upper do
        SelectedItems[i] = true;
      end
    else
      -- No shift, or first click; add only the current item to the selection.
      -- If control is down, toggle the item.
      LastClick = offset + id;
      if IsControlKeyDown() and SelectedItems[offset + id] then
        SelectedItems[offset + id] = nil;
      else
        SelectedItems[offset + id] = true;
      end
    end
  else
    -- We're in summary view, so switch to detail view.
    self:SetDetailLink(SummaryData[offset + id]);
    self:StartMassBuyout();
  end

  self:AuctionFrameBuy_Update();
end

-- Mouse has entered a row in the scrolling frame.
function AuctionLite:BuyButton_OnEnter(widget)
  -- Get our index into the current display data.
  local offset = FauxScrollFrame_GetOffset(BuyScrollFrame);
  local id = widget:GetID();

  -- Get a link and count for the item we're currently hovering over.
  -- The "shift" is used to move the tooltip to the right in detail view
  -- so that it doesn't obscure item quantities.
  local link = nil;
  local count = 1;
  local shift = 0;

  if DetailLink ~= nil then
    local item = DetailData[offset + id];
    if item ~= nil then
      link = DetailLink;
      count = item.count;
      shift = BuyButton1DetailName:GetLeft() - BuyButton1DetailCount:GetLeft();
    end
    shift = shift + 200;
  else
    link = SummaryData[offset + id];
    shift = shift + 250;
  end

  -- If we have an item, show the tooltip.
  if link ~= nil then
    self:SetHyperlinkTooltips(false);
    GameTooltip:SetOwner(widget, "ANCHOR_TOPLEFT", shift);
    GameTooltip:SetHyperlink(link);
    self:AddTooltipData(GameTooltip, link, count);
    self:SetHyperlinkTooltips(true);
  end
end

-- Mouse has left a row in the scrolling frame.
function AuctionLite:BuyButton_OnLeave(widget)
  GameTooltip:Hide();
end

-- Returns to the summary page.
function AuctionLite:BuySummaryButton_OnClick()
  if PurchaseOrder ~= nil and self:GetCart() ~= nil then
    self:CancelQuery();
    self:ResetSearch();
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
  self:CancelQuery();
  self:ResetSearch();
  self:AuctionFrameBuy_Update();
end

-- Bid on the currently-selected item.
function AuctionLite:BuyBidButton_OnClick()
  self:CreateOrder(false);
  self:AuctionFrameBuy_Update();
end

-- Buy out the currently-selected item.
function AuctionLite:BuyBuyoutButton_OnClick()
  self:CreateOrder(true);
  self:AuctionFrameBuy_Update();
end

-- Starts a full scan of the auction house.
function AuctionLite:StartFullScan()
  if not self.db.profile.fastScanAd then
    StaticPopup_Show("AL_FAST_SCAN");
  else
    local query = {
      name = "",
      getAll = self.db.profile.getAll,
      update = function(pct, all)
        AuctionLite:UpdateProgressSearch(pct, all, true);
      end,
      finish = function(data, link)
        AuctionLite:SetScanData(data);
      end,
    };

    if self:StartQuery(query) then
      DetailLinkPrev = nil;
      self:ClearBuyFrame(true);
    end
  end
end

-- List current deals.  If we haven't done a full scan, do it now.
function AuctionLite:AuctionFrameBuy_Deals()
  if ScanData ~= nil then
    DetailLinkPrev = nil;
    self:SetScanData(ScanData);
  else
    self:StartFullScan();
  end
end

-- Query and display favorites.
function AuctionLite:AuctionFrameBuy_Favorites()
  self:FavoritesScan(true);
end

-- Submit a search query.
function AuctionLite:AuctionFrameBuy_Search()
  local query = {
    name = BuyName:GetText(),
    wait = true,
    update = function(pct) AuctionLite:UpdateProgressSearch(pct) end,
    finish = function(data) AuctionLite:SetBuyData(data) end,
  };

  if self:StartQuery(query) then
    DetailLinkPrev = DetailLink;
    self:ClearBuyFrame(true);
  end
end

-- Adjust frame buttons for repaint.
function AuctionLite:AuctionFrameBuy_OnUpdate()
  local canSend = CanSendAuctionQuery("list") and not self:QueryInProgress();
  local biddable, buyable = self:GetSelectionStatus();

  if canSend and BuyName:GetText() ~= "" then
    BuySearchButton:Enable();
  else
    BuySearchButton:Disable();
  end

  if canSend then
    BuyScanButton:Enable();
  else
    BuyScanButton:Disable();
  end

  if canSend and biddable then
    BuyBidButton:Enable();
  else
    BuyBidButton:Disable();
  end

  if canSend and buyable then
    BuyBuyoutButton:Enable();
  else
    BuyBuyoutButton:Disable();
  end

  if StartTime ~= nil then
    self:UpdateProgressSearch();
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

  BuyStatus:Hide();

  -- If we have no items, say so.
  if NoResults then
    BuyNoItemsText:Show();
  else
    BuyNoItemsText:Hide();
  end

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
    for _, listing in ipairs(cart) do
      count = count + listing.count;
      price = price + listing.buyout;
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

  local _, _, _, _, enchant, jewel1, jewel2, jewel3, jewel4 =
    self:SplitLink(DetailLink);

  local showPlus = enchant ~= 0 or
                   jewel1 ~= 0 or jewel2 ~= 0 or
                   jewel3 ~= 0 or jewel4 ~= 0;

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
      local plusText         = _G[buttonDetailName .. "Plus"];
      local bidEachFrame     = _G[buttonDetailName .. "BidEachFrame"];
      local bidFrame         = _G[buttonDetailName .. "BidFrame"];
      local buyoutEachFrame  = _G[buttonDetailName .. "BuyoutEachFrame"];
      local buyoutFrame      = _G[buttonDetailName .. "BuyoutFrame"];
      
      local name, color = self:SplitLink(DetailLink);

      local countColor;
      local nameColor;
      if item.owner == UnitName("player") then
        countColor = "ffffff00";
        nameColor = "ffffff00";
      else
        countColor = "ffffffff";
        nameColor = color;
      end

      countText:SetText("|c" .. countColor .. item.count .. "x|r");

      nameText:SetText("|c" .. nameColor .. name .. "|r");

      if showPlus then
        plusText:SetPoint("LEFT", nameText, "LEFT",
                          nameText:GetStringWidth(), 0);
        plusText:Show();
      else
        plusText:Hide();
      end

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
        buyoutEachFrame:Show();

        MoneyFrame_Update(buyoutFrame, math.floor(item.buyout));
        buyoutFrame:Show();
      else
        buyoutEachFrame:Hide();
        buyoutFrame:Hide();
      end

      if SelectedItems[offset + i] then
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
      local result;
      
      if DealsMode then
        result = ScanData[link];
      else
        result = SearchData[link];
      end

      local buttonName = "BuyButton" .. i;
      local button = _G[buttonName];

      local buttonSummaryName = buttonName .. "Summary";
      local buttonSummary     = _G[buttonSummaryName];

      local starButton        = _G[buttonSummaryName .. "StarButton"];
      local nameText          = _G[buttonSummaryName .. "Name"];
      local plusText          = _G[buttonSummaryName .. "Plus"];
      local listingsText      = _G[buttonSummaryName .. "Listings"];
      local itemsText         = _G[buttonSummaryName .. "Items"];
      local marketFrame       = _G[buttonSummaryName .. "MarketPriceFrame"];
      local histFrame         = _G[buttonSummaryName .. "HistPriceFrame"];

      if self.db.profile.favorites[link] then
        starButton:GetNormalTexture():SetAlpha(1.0);
      else
        starButton:GetNormalTexture():SetAlpha(0.1);
      end

      local name, color, _, _, enchant, jewel1, jewel2, jewel3, jewel4 =
        self:SplitLink(link);

      nameText:SetText("|c" .. color .. name .. "|r");
      listingsText:SetText("|cffffffff" .. result.listingsAll .. "|r");
      itemsText:SetText("|cffffffff" .. result.itemsAll .. "|r");

      MoneyFrame_Update(marketFrame, math.floor(result.price));

      if DealsMode then
        MoneyFrame_Update(histFrame, math.floor(result.profit));
        histFrame:Show();
      else
        local hist = self:GetHistoricalPrice(link);
        if hist ~= nil then
          MoneyFrame_Update(histFrame, math.floor(hist.price));
          histFrame:Show();
        else
          histFrame:Hide();
        end
      end

      if enchant ~= 0 or
         jewel1 ~= 0 or jewel2 ~= 0 or
         jewel3 ~= 0 or jewel4 ~= 0 then
        plusText:SetPoint("LEFT", nameText, "LEFT",
                          nameText:GetStringWidth(), 0);
        plusText:Show();
      else
        plusText:Hide();
      end

      button:UnlockHighlight();

      buttonSummary:Show();
      button:Show();
    end
  end

  FauxScrollFrame_Update(BuyScrollFrame, table.getn(SummaryData),
                         displaySize, ROW_HEIGHT);

  if table.getn(SummaryData) > 0 then
    BuySummaryHeader:Show();
    if DealsMode then
      BuyHistPriceText:SetText("Potential Profit");
    else
      BuyHistPriceText:SetText("Historical Price");
    end
  end
end

-- Handle bag item clicks by searching for the item.
function AuctionLite:BagClickBuy(container, slot)
  local link = GetContainerItemLink(container, slot);
  if link ~= nil then
    local name = self:SplitLink(link);
    BuyName:SetText(name);
    BuyQuantity:SetFocus();
    AuctionLite:AuctionFrameBuy_Search();
  end
end

-- Resets all info about an in-progress search.
function AuctionLite:ResetSearch()
  StartTime = nil;
  LastTime = nil;
  LastRemaining = nil;
  Progress = nil;
  GetAll = nil;
  Scanning = nil;
end

-- Clean up the "Buy" tab.
function AuctionLite:ClearBuyFrame(partial)
  ExpandHeight = 0;

  DetailLink = nil;
  DetailData = {};

  if not partial then
    DetailLinkPrev = nil;
  end

  SelectedItems = {};
  LastClick = nil;

  SummaryData = {};
  PurchaseOrder = nil;

  self:ResetSearch();

  SearchData = nil;
  NoResults = false;

  if not partial then
    ScanData = nil;
  end

  DealsMode = false;

  FavoritesData = {};

  if not partial then
    BuyName:SetText("");
    BuyQuantity:SetText("");
    BuyName:SetFocus();
  end

  if not partial then
    BuyIntroText:Show();
  else
    BuyIntroText:Hide();
  end

  BuyStatus:Hide();

  FauxScrollFrame_SetOffset(BuyScrollFrame, 0);

  self:AuctionFrameBuy_Update();
end

-- Populate the advanced menu.
function AuctionLite:AdvancedMenuInit(menu)
  local info = UIDropDownMenu_CreateInfo();
  info.text = "Show Deals";
  info.func = function() AuctionLite:AuctionFrameBuy_Deals() end;
  UIDropDownMenu_AddButton(info);

  local info = UIDropDownMenu_CreateInfo();
  info.text = "Show Favorites";
  info.func = function() AuctionLite:AuctionFrameBuy_Favorites() end;
  UIDropDownMenu_AddButton(info);
end

-- Create the "Buy" tab.
function AuctionLite:CreateBuyFrame()
  -- Create our tab.
  local index = self:CreateTab("AuctionLite - Buy", AuctionFrameBuy);

  -- Set the intro text.
  BuyIntroText:SetText("Enter item name and click \"Search\"");

  -- Make sure it's pristine.
  self:ClearBuyFrame();

  return index;
end
