-------------------------------------------------------------------------------
-- AuctionLite 0.3
--
-- Lightweight addon to determine accurate market prices and to simplify
-- the process of posting auctions.
--
-- Send suggestions, comments, and bugs to merial.kilrogg@gmail.com.
-------------------------------------------------------------------------------

-- Create our addon.
AuctionLite = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0",
                                             "AceHook-2.1", "AceDB-2.0");

-- Currently no slash commands...
local options = {
  type = 'group',
  args = {
    showvendor = {
      type = "toggle",
      desc = "Show vendor sell price in tooltips",
      name = "Show Vendor Price",
      get = "ShowVendor",
      set = "ToggleShowVendor",
    },
    showauction = {
      type = "toggle",
      desc = "Show auction house value in tooltips",
      name = "Show Auction Value",
      get = "ShowAuction",
      set = "ToggleShowAuction",
    },
  },
}

-- Do some initial setup.
AuctionLite:RegisterChatCommand("/al", options);
AuctionLite:RegisterDB("AuctionLiteDB");
AuctionLite:RegisterDefaults("realm", {
  prices = {},
});
AuctionLite:RegisterDefaults("profile", {
  showVendor = true,
  showAuction = true,
  duration = 3,
  method = 1,
});

-- Constants.
local AUCTIONLITE_VERSION = 0.3;

local AUCTIONS_PER_PAGE = 50;
local BUY_DISPLAY_SIZE = 15;
local SELL_DISPLAY_SIZE = 16;

local QUERY_STATE_IDLE = 1;
local QUERY_STATE_SEND = 2;
local QUERY_STATE_WAIT = 3;

local QUERY_TYPE_NONE = 1;
local QUERY_TYPE_SCAN = 2;
local QUERY_TYPE_SEARCH = 3;
local QUERY_TYPE_BID = 4;
local QUERY_TYPE_BUY = 5;
local QUERY_TYPE_SELL = 6;

local MIN_TIME_BETWEEN_SCANS = 0;
local HALF_LIFE = 604800; -- 1 week
local INDEPENDENT_SCANS = 172800; -- 2 days

-- Flag indicating whether we're currently posting auctions.
local Selling = false;

-- Info about current AH query.
local QueryState = QUERY_STATE_IDLE;
local QueryType = QUERY_TYPE_NONE;
local QueryName = nil;
local QueryLink = nil;
local QueryPage = nil;
local QueryData = nil;

-- Market price of current auction item.
local ItemValue = 0;

-- Info about data to be shown in scrolling pane.
local ScrollName = nil;
local ScrollData = {};
local BuyScrollName = nil;
local BuyScrollData = {};
local BuySelectedItem = nil;

-- Info for auction buyout.
local TargetIndex = nil;
local TargetPrice = nil;

-- Status shown in auction posting frame.
local StatusMessage = "";
local StatusError = false;

-- Coroutine.
local Coro = nil;

-- Index of our tab in the auction frame.
local BuyTabIndex = nil;
local SellTabIndex = nil;

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- Make a printable string for a given amount of money (in copper).
function AuctionLite:PrintMoney(money)
  money = math.floor(money);
  local copper = money % 100;
  money = math.floor(money / 100);
  local silver = money % 100;
  money = math.floor(money / 100);
  local gold = money;

  local result = "";

  local append = function(s)
    if result ~= "" then
      result = result .. " ";
    end
    result = result .. s;
  end

  if gold > 0 then
    append("|cffd3c63a" .. gold .. "|cffffffffg|r");
  end
  if silver > 0 then
    append("|cffb0b0b0" .. silver .. "|cffffffffs|r");
  end
  if copper > 0 then
    append("|cffb2734a" .. copper .. "|cffffffffc|r");
  end

  if result == "" then
    result = "0";
  end

  return result;
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

-- Retrieve the item id and suffix id from an item link.
function AuctionLite:SplitLink(link)
  local _, _, str, name = link:find("|H(.*)|h%[(.*)%]");
  local _, id, enchant, jewel1, jewel2, jewel3, jewel4, suffix, unique =
        strsplit(":", str);
  return name, tonumber(id), tonumber(suffix);
end

-------------------------------------------------------------------------------
-- Bag functions
-------------------------------------------------------------------------------

-- Zero out the uniqueId field from an item link.
function AuctionLite:RemoveUniqueId(link)
  if link ~= nil then
    return link:gsub(":%-?%d*:%-?%d*|h", ":0:0|h");
  else
    return nil;
  end
end

-- Get auction sell item info as well as a link to the item and the
-- location of the item in the player's bags.  We use the fact that it
-- must be locked (since it's in the auction slot).  Returns nil if the
-- item is not found or if we can't pinpoint the exact bag slot.
function AuctionLite:GetAuctionSellItemInfoAndLink()
  local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo();

  local link = nil;
  local container = nil;
  local slot = nil;

  if name ~= nil then
    local i, j;

    -- Look through the bags to find a matching item.
    for i = 0, 4 do
      local numItems = GetContainerNumSlots(i);
      for j = 1, numItems do
        local _, curCount, locked = GetContainerItemInfo(i, j);
        if count == curCount and locked then
          -- We've found a partial match.  Now check the name...
          local curLink = GetContainerItemLink(i, j);
          local curName = self:SplitLink(curLink);
          if name == curName then
            if link == nil then
              -- It's our first match--make a note of it.
              link = self:RemoveUniqueId(curLink);
              container = i;
              slot = j;
            else
              -- Ambiguous result.  Bail!
              return;
            end
          end
        end
      end
    end
  end

  -- Return all the original item info plus our three results.
  return name, texture, count, quality, canUse, price, link, container, slot;
end 

-- Count the number of items matching the link (ignoring uniqueId).
function AuctionLite:CountItems(targetLink)
  local total = 0;

  if targetLink ~= nil then
    local i, j;
    for i = 0, 4 do
      local numItems = GetContainerNumSlots(i);
      for j = 1, numItems do
        local link = self:RemoveUniqueId(GetContainerItemLink(i, j));
        if link == targetLink then
          local _, count = GetContainerItemInfo(i, j);
          total = total + count;
        end
      end
    end
  end

  return total;
end

-- Find an empty bag slot.
function AuctionLite:GetEmptySlot()
  local i, j;

  for i = 0, 4 do
    local numItems = GetContainerNumSlots(i);
    for j = 1, numItems do
      local link = GetContainerItemLink(i, j);
      if link == nil then
        return i, j;
      end
    end
  end

  return nil;
end

-- Make a stack of 'size' items of the item identified by 'targetLink'
-- in the bag slot designated by 'container' and 'slot'.  Must be called
-- from within a fresh coroutine.
function AuctionLite:MakeStackInSlot(targetLink, size, container, slot)
  local i, j;

  for i = 0, 4 do
    local numItems = GetContainerNumSlots(i);
    for j = 1, numItems do
      if i ~= container or j ~= slot then
        -- Make sure the item is unlocked so that we can pick it up.  We
        -- need to do this before getting the link, since the item might
        -- change/disappear before becoming unlocked.
        self:WaitForUnlock(i, j);

        local link = self:RemoveUniqueId(GetContainerItemLink(i, j));
        local _, count = GetContainerItemInfo(i, j);

        if link == targetLink then
          -- It's the item we're looking for, and it's unlocked.
          -- Pick up as many as we need.
          local moved = math.min(count, size);
          SplitContainerItem(i, j, moved);

          -- Drop the item in the target slot.
          self:WaitForUnlock(container, slot);
          PickupContainerItem(container, slot);

          -- Wait for the operation to complete.
          self:WaitForUnlock(i, j);

          size = size - moved;
          if size == 0 then
            return;
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Auction creation
-------------------------------------------------------------------------------

-- Create new auctions based on the fields in the "Sell" tab.
function AuctionLite:CreateAuctions()
  -- TODO: check stack size against max size

  if not Selling then
    Selling = true;

    local name, _, count, _, _, _, link, sellContainer, sellSlot =
      self:GetAuctionSellItemInfoAndLink();

    local stacks = SellStacks:GetNumber();
    local size = SellSize:GetNumber();

    local bid = MoneyInputFrame_GetCopper(SellBidPrice);
    local buyout = MoneyInputFrame_GetCopper(SellBuyoutPrice);
    local time = self:GetDuration();

    -- If we're pricing per item, then get the stack price.
    if self.db.profile.method == 1 then
      bid = bid * size;
      buyout = buyout * size;
    end

    -- Now do some sanity checks.
    if name == nil then
      self:Print("Error locating item in bags.  Please try again!");
    elseif bid == 0 then
      self:Print("Invalid starting bid.");
    elseif buyout < bid then
      self:Print("Buyout cannot be less than starting bid.");
    elseif GetMoney() < self:CalculateDeposit() then
      self:Print("Not enough cash for deposit.");
    elseif self:CountItems(link) < stacks * size then
      self:Print("Not enough items available.");
    elseif count ~= nil and stacks > 0 then
      local created = 0;

      -- Disable the auction creation button.
      SellCreateAuctionButton:Disable();

      -- If the auction slot already contains a stack of the correct size,
      -- auction it!  Otherwise, just clear out the auction slot to make
      -- room for the real thing.
      if count == size then
        StartAuction(bid, buyout, time);
        self:WaitForEmpty(sellContainer, sellSlot);
        created = created + 1;
        SellStacks:SetNumber(stacks - created);
      else
        ClearCursor();
        ClickAuctionSellItemButton();
        ClearCursor();
      end

      -- Do we have more to do?
      -- Find an empty bag slot in which we can build stacks of items.
      local container, slot = self:GetEmptySlot();
      if container ~= nil then
        -- Create the remaining auctions.
        while created < stacks do
          -- Create a stack of the appropriate size.
          self:MakeStackInSlot(link, size, container, slot);

          -- Pick it up and put it in the auction slot.
          self:WaitForUnlock(container, slot);
          PickupContainerItem(container, slot);
          ClickAuctionSellItemButton();

          -- One final sanity check.
          local auctionName, _, auctionCount = GetAuctionSellItemInfo();
          if auctionName == name and auctionCount == size then
            -- And away she goes!
            StartAuction(bid, buyout, time);
            self:WaitForEmpty(container, slot);
          else
            self:Print("Error when creating auctions.");
            break;
          end

          created = created + 1;
          SellStacks:SetNumber(stacks - created);
        end

        self:ClearSellFrame();
      elseif created < stocks then
        -- Couldn't find an empty bag slot.
        self:Print("Need an empty bag slot to create auctions.");
      else
        -- We're done anyway.
        self:ClearSellFrame();
      end

      self:Print("Created " .. created .. " auctions of " .. name .. " x" .. size .. ".");
    end

    Selling = false;
  else
    self:Print("Auction creation is already in progress.");
  end
end

-------------------------------------------------------------------------------
-- Deposit and price computations
-------------------------------------------------------------------------------

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
function AuctionLite:UpdatePrices()
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

  if name ~= nil and QueryState == QUERY_STATE_IDLE then
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
  if not Selling then
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

-------------------------------------------------------------------------------
-- Auction scanning
-------------------------------------------------------------------------------

-- Popup dialog for buying out auctions.
StaticPopupDialogs["AUCTIONLITE_BID"] = {
	text = "Bid on auction at:",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
    -- Place the buyout.
		PlaceAuctionBid("list", TargetIndex, TargetPrice);
    -- Update the scroll frame.
    BuyScrollData[BuySelectedItem].bid = TargetPrice;
    AuctionLite:AuctionFrameBuy_Update();
    -- Clean up.
    TargetIndex = nil;
    TargetPrice = nil;
	end,
	OnShow = function(self)
		MoneyFrame_Update(self.moneyFrame, TargetPrice);
	end,
	hasMoneyFrame = 1,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

-- Popup dialog for buying out auctions.
StaticPopupDialogs["AUCTIONLITE_BUYOUT"] = {
	text = BUYOUT_AUCTION_CONFIRMATION,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
    -- Place the buyout.
		PlaceAuctionBid("list", TargetIndex, TargetPrice);
    -- Update the scroll frame.
    table.remove(BuyScrollData, BuySelectedItem);
    BuySelectedItem = nil;
    AuctionLite:AuctionFrameBuy_Update();
    -- Clean up.
    TargetIndex = nil;
    TargetPrice = nil;
	end,
	OnShow = function(self)
		MoneyFrame_Update(self.moneyFrame, TargetPrice);
	end,
	hasMoneyFrame = 1,
	showAlert = 1,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1
};

-- Start an auction query.
function AuctionLite:StartQuery(queryType, name, link)
  if QueryState == QUERY_STATE_IDLE then
    QueryState = QUERY_STATE_SEND;
    QueryType = queryType;
    QueryName = name;
    QueryLink = link;
    QueryPage = 0;
    QueryData = {};
    ItemValue = 0;
    return true;
  else
    return false;
  end
end

-- Query for an item dropped in the sell tab.
function AuctionLite:QuerySell(link)
  if self:StartQuery(QUERY_TYPE_SELL, nil, link) then
    self:SetStatus("|cffffff00Scanning...|r");
  end
end

-- Query to bid on an item.
function AuctionLite:QueryBid(name)
  self:StartQuery(QUERY_TYPE_BID, name, nil);
end

-- Query to buyout an item.
function AuctionLite:QueryBuy(name)
  self:StartQuery(QUERY_TYPE_BUY, name, nil);
end

-- Query for the buy tab.
function AuctionLite:QuerySearch(name)
  self:StartQuery(QUERY_TYPE_SEARCH, name, nil);
end

-- Query all items in the AH.
function AuctionLite:QueryScan()
  if self:StartQuery(QUERY_TYPE_SCAN, nil, nil) then
    BrowseScanText:SetText("0%");
  end
end

-- Get the next page.
function AuctionLite:QueryNext()
  assert(QueryState == QUERY_STATE_WAIT);
  QueryState = QUERY_STATE_SEND;
  QueryPage = QueryPage + 1;
end

-- End the current query.
function AuctionLite:QueryEnd()
  assert(QueryState == QUERY_STATE_WAIT);
  QueryState = QUERY_STATE_IDLE;
  QueryType = QUERY_TYPE_NONE;
  QueryData = nil;
end

-- Compute the average and standard deviation of the points in data.
function AuctionLite:ComputeStats(data)
  local count = 0;
  local sum = 0;
  local sumSquared = 0;

  for i = 1, table.getn(data) do
    if data[i].keep then
      count = count + data[i].count;
      sum = sum + data[i].price * data[i].count;
      sumSquared = sumSquared + (data[i].price ^ 2) * data[i].count;
    end
  end

  local avg = sum / count;
  local stddev = math.max(0, sumSquared / count - (sum ^ 2 / count ^ 2)) ^ 0.5;

  return avg, stddev;
end

-- Analyze an AH query result.
function AuctionLite:AnalyzeData(rawData)
  local results = {};
  local itemData = {};
  local i;

  -- Split up our data into tables for each item.
  for i = 1, table.getn(rawData) do
    local link = rawData[i].link;
    local count = rawData[i].count;
    local buyout = rawData[i].buyoutPrice
    local owner = rawData[i].owner;
    local bidder = rawData[i].highBidder;

    local bid = rawData[i].bidAmount;
    if bid <= 0 then
      bid = rawData[i].minBid;
    end

    local price = buyout / count;
    if price <= 0 then
      price = bid / count;
    end

    local keep = owner ~= UnitName("player") and buyout > 0;

    local listing = { bid = bid, buyout = buyout,
                      price = price, count = count,
                      owner = owner, bidder = bidder, keep = keep };

    if itemData[link] == nil then
      itemData[link] = {};
    end

    table.insert(itemData[link], listing);
  end

  -- Process each data set.
  local link, data;
  for link, data in pairs(itemData) do 
    local done = false;

    -- Discard any points that are more than 2 SDs away from the mean.
    -- Repeat until no such points exist.
    while not done do
      done = true;
      local avg, stddev = self:ComputeStats(data);
      for i = 1, table.getn(data) do
        if data[i].keep and math.abs(data[i].price - avg) > 2.5 * stddev then
          data[i].keep = false;
          done = false;
        end
      end
    end

    -- We've converged.  Compute our min price and other stats.
    local result = { price = 100000000, items = 0, listings = 0 };
    for i = 1, table.getn(data) do
      if data[i].keep then
        result.items = result.items + data[i].count;
        result.listings = result.listings + 1;
        if data[i].price < result.price then
          result.price = data[i].price;
        end
      end
    end

    result.data = data;
    results[link] = result;
  end

  return results;
end

-- Our query has completed.  Analyze the data!
function AuctionLite:QueryFinished()
  local results = self:AnalyzeData(QueryData);
  -- Get the info for the item we really care about.
  if QueryType == QUERY_TYPE_SEARCH then
    for link, result in pairs(results) do
      self:Print(link);
      local name = self:SplitLink(link);
      self:SetBuyScrollData(name, result.data);
    end
  elseif QueryLink ~= "" then
    local result = results[QueryLink];
    if result ~= nil and result.listings > 0 then
      local name = self:SplitLink(QueryLink);
      ItemValue = result.price;
      self:SetScrollData(name, result.data);
      self:ShowPriceData(QueryLink, ItemValue, SellSize:GetNumber());
      self:SetStatus("|cff00ff00Scanned " .. result.listings ..  " listings.|r");
    else
      local hist = self:GetHistoricalPrice(QueryLink);
      if hist ~= nil then
        ItemValue = hist.price;
        self:ShowPriceData(QueryLink, ItemValue, SellSize:GetNumber());
        self:SetStatus("|cffff0000Using historical data.|r");
      else
        local _, _, count, _, _, vendor = GetAuctionSellItemInfo();
        ItemValue = 3 * vendor / count;
        self:SetStatus("|cffff0000Using 3x vendor price.|r");
      end
    end
  end
  -- Update the suggested prices.
  self:UpdatePrices();
  -- Update our price info.
  for link, result in pairs(results) do 
    self:UpdateHistoricalPrice(link, result);
  end
  -- Update the UI.
  self:AuctionFrameBuy_Update();
  self:AuctionFrameSell_Update();
end

-- Handle a completed auction query.
function AuctionLite:AUCTION_ITEM_LIST_UPDATE()
  if QueryState == QUERY_STATE_WAIT then
    -- We've completed one of our own queries.
    local batch, total = GetNumAuctionItems("list");
    local seen = QueryPage * AUCTIONS_PER_PAGE + batch;
    -- Update status.
    if QueryType == QUERY_TYPE_SCAN then
      local pct = math.floor(seen * 100 / total);
      if pct == 100 then
        BrowseScanText:SetText("");
      else
        BrowseScanText:SetText(tostring(pct) .. "%");
      end
    end
    -- Record results.
    if QueryType == QUERY_TYPE_SCAN or
       QueryType == QUERY_TYPE_SEARCH or
       QueryType == QUERY_TYPE_SELL then
      local i;
      for i = 1, batch do
        -- There has *got* to be a better way to do this...
        local link = self:RemoveUniqueId(GetAuctionItemLink("list", i));
        local name, texture, count, quality, canUse, level,
              minBid, minIncrement, buyoutPrice, bidAmount,
              highBidder, owner = GetAuctionItemInfo("list", i);
        local listing = {
          link = link, name = name, texture = texture, count = count,
          quality = quality, canUse = canUse, level = level,
          minBid = minBid, minIncrement = minIncrement,
          buyoutPrice = buyoutPrice, bidAmount = bidAmount,
          highBidder = highBidder, owner = owner
        };
        QueryData[QueryPage * AUCTIONS_PER_PAGE + i] = listing;
      end
      if seen < total then
        -- Request the next page.
        self:QueryNext();
      else
        -- We're done--time to analyze the data.
        self:QueryFinished();
        -- Indicate that we're done with this query.
        self:QueryEnd();
      end
    elseif QueryType == QUERY_TYPE_BID or QueryType == QUERY_TYPE_BUY then
      if BuyScrollData ~= nil then
        local target = BuyScrollData[BuySelectedItem];
        local success = false;

        -- See if we've found the auction we're looking for.
        for i = 1, batch do
          local name, texture, count, quality, canUse, level,
                minBid, minIncrement, buyoutPrice, bidAmount,
                highBidder, owner = GetAuctionItemInfo("list", i);
          local bid = bidAmount;
          if bid <= 0 then
            bid = minBid;
          end
          if BuyScrollName == name and
             target.count == count and
             target.bid == bid and
             target.buyout == buyoutPrice and
             target.owner == owner then
            -- Place our bid/buyout.
            if QueryType == QUERY_TYPE_BID then
              TargetIndex = i;
              TargetPrice = bid;
              if TargetPrice == bidAmount then
                TargetPrice = TargetPrice + minIncrement;
              end
              StaticPopup_Show("AUCTIONLITE_BID");
            elseif QueryType == QUERY_TYPE_BUY then
              TargetIndex = i;
              TargetPrice = buyoutPrice;
              StaticPopup_Show("AUCTIONLITE_BUYOUT");
            end
            -- Indicate that we succeeded.
            success = true;
            break;
          end
        end

        -- If we succeded, stop.  If we didn't, get the next page.
        if success then
          self:QueryEnd();
        elseif seen < total then
          self:QueryNext();
        else
          self:QueryEnd();
          self:Print("Could not find the selected listing in the auction house.");
        end
      end
    end
  end
end

-- Clean up if the auction house is closed.
function AuctionLite:AUCTION_HOUSE_CLOSED()
  self:ClearSellFrame();
  Selling = false;
  Coro = nil;
end

-------------------------------------------------------------------------------
-- Historical price functions
-------------------------------------------------------------------------------

-- Retrieve historical price data for an item.
function AuctionLite:GetHistoricalPrice(link)
  local name, id, suffix = self:SplitLink(link);
  local info = self.db.realm.prices[id];

  if info == nil then
    -- Check to see whether we're using a database generated by v0.1,
    -- which indexed by name instead of id.  If so, migrate it.
    info = self.db.realm.prices[name];
    if info ~= nil then
      self:SetHistoricalPrice(link, info);
      self.db.realm.prices[name] = nil;
    end
  elseif suffix ~= 0 or info.suffix then
    -- This item has sub-tables, one for each possible suffix.
    if suffix ~= 0 and info.suffix then
      info = info[suffix];
    else
      info = nil;
    end
  end

  if info ~= nil then
    -- Make sure we have the right format.
    self:ValidateHistoricalPrice(info);
  end

  return info;
end

-- Set historical price data for an item.
function AuctionLite:SetHistoricalPrice(link, info)
  local _, id, suffix = self:SplitLink(link);

  if suffix == 0 then
    -- This item has no suffix, so just use the id.
    self.db.realm.prices[id] = info;
  else
    -- This item has a suffix, so index by suffix as well.
    local parent = self.db.realm.prices[id];
    if parent == nil or not parent.suffix then
      parent = { suffix = true };
      self.db.realm.prices[id] = parent;
    end
    parent[suffix] = info;
  end
end

-- Make sure that the price data structure is a valid one.
function AuctionLite:ValidateHistoricalPrice(info)
  local field;
  for _, field in ipairs({"price", "listings", "scans", "time", "items"}) do
    if info[field] == nil then
      info[field] = 0;
    end
  end
end

-- Update historical price data for an item given a price (per item) and
-- the number of listings seen in the latest scan.
function AuctionLite:UpdateHistoricalPrice(link, data)
  -- Get the current data.
  local info = self:GetHistoricalPrice(link)

  -- If we have no data for this item, start a new one.
  if info == nil then
    info = { price = 0, listings = 0, scans = 0, time = 0, items = 0 };
    self:SetHistoricalPrice(link, info);
  end

  -- Update the current data with our new data.
  local time = time();
  if info.time + MIN_TIME_BETWEEN_SCANS < time and data.listings > 0 then
    local pastDiscountFactor = 0.5 ^ ((time - info.time) / HALF_LIFE);
    local presentDiscountFactor = 1 - 0.5 ^ ((time - info.time) / INDEPENDENT_SCANS);
    info.price = (data.price * data.listings * presentDiscountFactor +
                  info.price * info.listings * pastDiscountFactor) /
                 (data.listings * presentDiscountFactor +
                  info.listings * pastDiscountFactor);
    info.listings = data.listings * presentDiscountFactor +
                    info.listings * pastDiscountFactor;
    info.items = data.items * presentDiscountFactor + info.items * pastDiscountFactor;
    info.scans = 1 * presentDiscountFactor + info.scans * pastDiscountFactor;
    info.time = time;
  end
end

-------------------------------------------------------------------------------
-- Coroutine functions
-------------------------------------------------------------------------------

-- Wait for a bag slot to become unlocked.  Should be called from a
-- separate coroutine, and should expect that the item will become
-- unlocked soon.
function AuctionLite:WaitForUnlock(container, slot)
  local _, _, locked = GetContainerItemInfo(container, slot);
  while locked do
    coroutine.yield();
    _, _, locked = GetContainerItemInfo(container, slot);
  end
end

-- Wait for a bag slot to become empty.  Should be called from a
-- separate coroutine, and should expect that the bag slot will soon
-- become empty (e.g., the item has been submitted to the AH).
function AuctionLite:WaitForEmpty(container, slot)
  local name = GetContainerItemInfo(container, slot);
  while name ~= nil do
    coroutine.yield();
    name = GetContainerItemInfo(container, slot);
  end
end

-- Start a coroutine to call the specified function.
function AuctionLite:StartCoroutine(fn)
  if Coro == nil then
    Coro = coroutine.create(fn);
    AuctionLite:ResumeCoroutine();
  end
end

-- Resume the stalled coroutine.
function AuctionLite:ResumeCoroutine()
  if Coro ~= nil then
    coroutine.resume(Coro)
    if coroutine.status(Coro) == "dead" then
      Coro = nil;
    end
  end
end

-- An item lock has changed, so wake up the coroutine.
function AuctionLite:ITEM_LOCK_CHANGED()
  self:ResumeCoroutine();
end

-- A bag slot has changed, so wake up the coroutine.
function AuctionLite:BAG_UPDATE()
  self:ResumeCoroutine();
end

-------------------------------------------------------------------------------
-- UI functions
-------------------------------------------------------------------------------

-- Clean up the "Sell" tab.
function AuctionLite:ClearSellFrame()
  QueryState = QUERY_STATE_IDLE;
  QueryType = QUERY_TYPE_NONE;

  QueryName = nil;
  QueryLink = nil;
  QueryData = nil;

  ItemValue = 0;

  ScrollName = nil;
  ScrollData = {};

  BuyScrollName = nil;
  BuyScrollData = {};
  BuySelectedItem = nil;

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

-- Set the data for the scrolling frame.
function AuctionLite:SetBuyScrollData(name, data)
  table.sort(data, function(a, b) return a.price < b.price end);

  BuyScrollName = name;
  BuyScrollData = data;
end

-- Use this update event to do a bunch of housekeeping.
function AuctionLite:AuctionFrame_OnUpdate()
  -- Continue pending auction queries.
  local canSend = CanSendAuctionQuery("list");
  if canSend and QueryState == QUERY_STATE_SEND then
    local name = nil;
    if QueryType == QUERY_TYPE_SCAN then
      name = "";
    elseif QueryType == QUERY_TYPE_SEARCH or
           QueryType == QUERY_TYPE_BID or
           QueryType == QUERY_TYPE_BUY then
      name = QueryName;
    elseif QueryType == QUERY_TYPE_SELL then
      name = self:SplitLink(QueryLink);
    end
    if name ~= nil then
      QueryAuctionItems(name, 0, 0, 0, 0, 0, QueryPage, 0, 0);
      QueryState = QUERY_STATE_WAIT;
    else
      QueryState = QUERY_STATE_IDLE;
    end
  end

  -- Update the scan button.
  if canSend and QueryState == QUERY_STATE_IDLE then
    BrowseScanButton:Enable();
  else
    BrowseScanButton:Disable();
  end

  -- Update the bid and buyout buttons.
  if canSend and QueryState == QUERY_STATE_IDLE and
     BuySelectedItem ~= nil then
    BuyBidButton:Enable();
  else
    BuyBidButton:Disable();
  end
  if canSend and QueryState == QUERY_STATE_IDLE and
     BuySelectedItem ~= nil and BuyScrollData[BuySelectedItem].buyout > 0 then
    BuyBuyoutButton:Enable();
  else
    BuyBuyoutButton:Disable();
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

-- Handles clicks on the "Create Auctions" button.
function AuctionLite:CreateAuctionButton_OnClick()
  AuctionLite:StartCoroutine(function() AuctionLite:CreateAuctions() end);
end

-- Handles clicks on buttons in the "Competing Auctions" display.
-- Get the appropriate auction and undercut it!
function AuctionLite:SellButton_OnClick(id)
  local offset = FauxScrollFrame_GetOffset(SellScrollFrame);
  local item = ScrollData[offset + id];

  if item ~= nil then
    ItemValue = math.floor(item.price);
    self:UpdatePrices();
  end
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

-- Handle clicks on the "Buy" tab search button.
function AuctionLite:AuctionFrameBuy_Search()
  self:QuerySearch(BuyName:GetText());
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

-- Adds our scan button to the "Browse" tab.
function AuctionLite:ModifyBrowseTab()
  -- Create the scan button.
  local scan = CreateFrame("Button", "BrowseScanButton", AuctionFrameBrowse, "UIPanelButtonTemplate");
  scan:SetWidth(60);
  scan:SetHeight(22);
  scan:SetText("Scan");
  scan:SetPoint("TOPLEFT", AuctionFrameBrowse, "TOPLEFT", 185, -410);
  scan:SetScript("OnClick", function() AuctionLite:QueryScan() end);

  -- Create the status text next to it.
  local scanText = AuctionFrameBrowse:CreateFontString("BrowseScanText", "BACKGROUND", "GameFontNormal");
  scanText:SetPoint("TOPLEFT", scan, "TOPRIGHT", 5, -5);
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

-- Create the "Buy" tab.
function AuctionLite:CreateBuyFrame()
  -- Create our tab.
  BuyTabIndex = self:CreateTab("AuctionLite - Buy", AuctionFrameBuy);

  -- Paint the screen for good measure.
  self:AuctionFrameBuy_Update();
end

-- Create the "Sell" tab.
function AuctionLite:CreateSellFrame()
  -- Create our tab.
  SellTabIndex = self:CreateTab("AuctionLite - Sell", AuctionFrameSell);

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
end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

-- Show vendor data in tooltips?
function AuctionLite:ShowVendor()
  return self.db.profile.showVendor;
end

-- Toggle vendor data in tooltips.
function AuctionLite:ToggleShowVendor()
  self.db.profile.showVendor = not self.db.profile.showVendor;
end

-- Show auction value in tooltips?
function AuctionLite:ShowAuction()
  return self.db.profile.showAuction;
end

-- Toggle auction value in tooltips.
function AuctionLite:ToggleShowAuction()
  self.db.profile.showAuction = not self.db.profile.showAuction;
end

-------------------------------------------------------------------------------
-- Tooltip code
-------------------------------------------------------------------------------

-- Add vendor and auction data to a tooltip.  We have count1 and count2
-- for the upper and lower bound on the number of items; count2 may be nil.
function AuctionLite:AddTooltipData(tooltip, link, count1, count2)
  if link ~= nil and count1 ~= nil then
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
      tooltip:AddDoubleLine("Vendor", vendorInfo);
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
        tooltip:AddDoubleLine("Auction", auctionInfo);
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

-------------------------------------------------------------------------------
-- Hooks and boostrap code
-------------------------------------------------------------------------------

-- Hook some AH functions and UI widgets when the AH gets loaded.
function AuctionLite:ADDON_LOADED(name)
  if name == "Blizzard_AuctionUI" then
    self:SecureHook("AuctionFrameTab_OnClick", "AuctionFrameTab_OnClick_Hook");
    self:SecureHook("ClickAuctionSellItemButton", "ClickAuctionSellItemButton_Hook");

    self:HookAuctionFrameUpdate();

    self:ModifyBrowseTab();
    self:CreateBuyFrame();
    self:CreateSellFrame();
  end
end

-- We're alive!  Register our event handlers.
function AuctionLite:OnEnable()
  self:Print("AuctionLite v" .. AUCTIONLITE_VERSION .. " loaded!");

  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");
  self:RegisterEvent("AUCTION_HOUSE_CLOSED");
  self:RegisterEvent("BAG_UPDATE");
  self:RegisterEvent("ITEM_LOCK_CHANGED");

  self:SecureHook(GameTooltip, "SetBagItem", "BagTooltip");
  self:SecureHook(GameTooltip, "SetInventoryItem", "InventoryTooltip");
  self:SecureHook(GameTooltip, "SetGuildBankItem", "GuildBankTooltip");
  self:SecureHook(GameTooltip, "SetTradeSkillItem", "TradeSkillTooltip");
  self:SecureHook(GameTooltip, "SetQuestItem", "QuestTooltip");
  self:SecureHook(GameTooltip, "SetQuestLogItem", "QuestLogTooltip");
  self:SecureHook(GameTooltip, "SetAuctionItem", "AuctionTooltip");
  self:SecureHook(GameTooltip, "SetAuctionSellItem", "AuctionSellTooltip");
end
