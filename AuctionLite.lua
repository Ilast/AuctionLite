-------------------------------------------------------------------------------
-- AuctionLite 0.2
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
  },
}

-- Do some initial setup.
AuctionLite:RegisterChatCommand("/al", options);
AuctionLite:RegisterDB("AuctionLiteDB");
AuctionLite:RegisterDefaults("realm", {
  prices = {},
});

-- Constants.
local AUCTIONLITE_VERSION = 0.2;
local AUCTIONS_PER_PAGE = 50;
local POST_DISPLAY_SIZE = 16;
local MIN_TIME_BETWEEN_SCANS = 0;
local HALF_LIFE = 604800; -- 1 week
local INDEPENDENT_SCANS = 172800; -- 2 days

-- Flag indicating whether we're currently posting auctions.
local Selling = false;

-- Info about current AH query.
local QueryRunning = false;
local QueryWait = false;
local QueryLink = nil;
local QueryPage = nil;
local QueryData = nil;

-- Market price of current auction item.
local ItemValue = 0;

-- Info about data to be shown in scrolling pane.
local ScrollName = nil;
local ScrollData = nil;

-- Status shown in auction posting frame.
local StatusMessage = "";
local StatusError = false;

-- Coroutine.
local Coro = nil;

-- Index of our tab in the auction frame.
local TabIndex = nil;

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

  if PostShortAuctionButton:GetChecked() then
    time = 720;
  elseif PostMediumAuctionButton:GetChecked() then
    time = 1440;
  elseif PostLongAuctionButton:GetChecked() then
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

-- Given the name of an item in the auction slot, get the item link for
-- that item.  Since it's in the auction slot, it must be locked.
-- Returns nil if the item is not found or if the correct link cannot be
-- conclusively determined.
function AuctionLite:GetAuctionSellItemLink()
  local targetName = GetAuctionSellItemInfo();

  local result = nil;
  local ambiguous = false;
  local i, j;

  for i = 0, 4 do
    local numItems = GetContainerNumSlots(i);
    for j = 1, numItems do
      local _, _, locked = GetContainerItemInfo(i, j);
      if locked then
        local link = GetContainerItemLink(i, j);
        local name = self:SplitLink(link);
        if name == targetName then
          if result == nil then
            result = link;
          elseif result ~= link then
            ambiguous = true;
          end
        end
      end
    end
  end

  if ambiguous then
    result = nil;
  end

  return result;
end

-- Count the number of items matching the link (ignoring uniqueId).
function AuctionLite:CountItems(targetLink)
  local total = 0;
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

  return total;
end

-- Count the number of items matching the current auction item.
function AuctionLite:CountAuctionSellItems()
  local link = self:RemoveUniqueId(self:GetAuctionSellItemLink());
  return self:CountItems(link);
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

-- Create new auctions based on the fields in the "Post Auctions" tab.
function AuctionLite:CreateAuctions()
  -- TODO: check stack size against max size

  Selling = true;

  local name, _, count = GetAuctionSellItemInfo();
  local link = self:RemoveUniqueId(self:GetAuctionSellItemLink());

  local stacks = PostStacks:GetNumber();
  local size = PostSize:GetNumber();

  local bid = MoneyInputFrame_GetCopper(PostBidPrice);
  local buyout = MoneyInputFrame_GetCopper(PostBuyoutPrice);
  local time = self:GetDuration();

  if bid == 0 then
    self:Print("Invalid starting bid.");
  elseif buyout < bid then
    self:Print("Buyout cannot be less than starting bid.");
  elseif GetMoney() < self:CalculateDeposit() then
    self:Print("Not enough cash for deposit.");
  elseif self:CountAuctionSellItems() < stacks * size then
    self:Print("Not enough items available.");
  elseif count ~= nil and stacks > 0 then
    local created = 0;

    -- If the auction slot already contains a stack of the correct size,
    -- auction it!  Otherwise, just clear out the auction slot to make
    -- room for the real thing.
    if count == size then
      StartAuction(bid, buyout, time);
      created = created + 1;
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
      end

      self:ClearAuctionFrame();
    elseif created < stocks then
      -- Couldn't find an empty bag slot.
      self:Print("Need an empty bag slot to create auctions.");
    else
      -- We're done anyway.
      self:ClearAuctionFrame();
    end

    self:Print("Created " .. created .. " auctions of " .. name .. " x" .. size .. ".");
  end

  Selling = false;
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
  local stacks = PostStacks:GetNumber();
  local size = PostSize:GetNumber();
  local _, _, count = GetAuctionSellItemInfo();

  return math.floor(CalculateAuctionDeposit(time) * stacks * size / count);
end

-- Update the deposit field.
function AuctionLite:UpdateDeposit()
  MoneyFrame_Update("PostDepositMoneyFrame", self:CalculateDeposit());
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

  local link = self:RemoveUniqueId(self:GetAuctionSellItemLink());

  --self:Print("|cff8080ffData for " .. link .. " x" .. stackSize ..
  --           "|cff8080ff at " .. time() .. "|r");
  self:Print("|cff8080ffData for " .. link .. " x" .. stackSize .. "|r");
  self:Print("Vendor: " .. self:PrintMoney(itemVendor * stackSize));

  if hist ~= nil then
    self:Print("Historical: " .. self:PrintMoney(hist.price * stackSize) .. " (" ..
               math.floor(0.5 + hist.listings / hist.scans) .. " listings/scan, " ..
               math.floor(0.5 + hist.items / hist.scans) .. " items/scan)");
    self:Print("Current: " .. self:PrintMoney(stackValue) .. " (" ..
               (math.floor(100 * itemValue / hist.price) / 100) .. "x historical, " ..
               (math.floor(100 * itemValue / itemVendor) / 100) .. "x vendor)");
  else
    self:Print("Current: " .. self:PrintMoney(stackValue) .. " (" ..
               (math.floor(100 * itemValue / itemVendor) / 100) .. "x vendor)");
  end

  return bid, buyout;
end

-- Fill in suggested prices based on a query result or a change in the
-- stack size.
function AuctionLite:UpdatePrices()
  if ItemValue > 0 then
    local stackSize = PostSize:GetNumber();

    local itemBid, itemBuyout = self:GeneratePrice(ItemValue);
    local bid = itemBid * stackSize;
    local buyout = itemBuyout * stackSize;
    
    MoneyInputFrame_SetCopper(PostBidPrice, bid);
    MoneyInputFrame_SetCopper(PostBuyoutPrice, buyout);
  end
end

-- Check whether there are any errors in the auction.
function AuctionLite:ValidateAuction()
  local name, _, count, _, _, vendor = GetAuctionSellItemInfo();
  if name ~= nil and not QueryRunning then
    local bid = MoneyInputFrame_GetCopper(PostBidPrice);
    local buyout = MoneyInputFrame_GetCopper(PostBuyoutPrice);

    local stacks = PostStacks:GetNumber();
    local size = PostSize:GetNumber();

    if stacks * size <= 0 then
      StatusError = true;
      PostStatusText:SetText("|cffff0000Invalid stack size/count.|r");
      PostCreateAuctionButton:Disable();
    elseif self:CountAuctionSellItems() < stacks * size then
      StatusError = true;
      PostStatusText:SetText("|cffff0000Not enough items available.|r");
      PostCreateAuctionButton:Disable();
    elseif bid == 0 then
      StatusError = true;
      PostStatusText:SetText("|cffff0000No bid price set.|r");
      PostCreateAuctionButton:Disable();
    elseif buyout < bid then
      StatusError = true;
      PostStatusText:SetText("|cffff0000Buyout less than bid.|r");
      PostCreateAuctionButton:Disable();
    elseif GetMoney() < self:CalculateDeposit() then
      StatusError = true;
      PostStatusText:SetText("|cffff0000Not enough cash for deposit.|r");
      PostCreateAuctionButton:Disable();
    elseif buyout <= (vendor * size / count) then
      StatusError = true;
      PostStatusText:SetText("|cffff0000Buyout less than vendor price.|r");
      PostCreateAuctionButton:Disable();
    else
      StatusError = false;
      PostStatusText:SetText(StatusMessage);
      PostCreateAuctionButton:Enable();
    end
  end
end

-- There's been a click on the auction sell item slot.
function AuctionLite:ClickAuctionSellItemButton_Hook()
  -- Ignore clicks that we generated ourselves.
  if not Selling then
    -- Clear everything first.
    self:ClearAuctionFrame();

    -- If we've got a new item in the auction slot, fill out the fields.
    local name, texture, count = GetAuctionSellItemInfo();
    if name ~= nil then
      PostItemButton:SetNormalTexture(texture);
      PostItemButtonName:SetText(name);

      if count > 1 then
        PostItemButtonCount:SetText(count);
        PostItemButtonCount:Show();
      else
        PostItemButtonCount:Hide();
      end

      PostStacks:SetText(1);
      PostSize:SetText(count);

      local total = self:CountAuctionSellItems();
      PostStackText:SetText("Number of Items |cff808080(max " .. total .. ")|r");

      self:UpdateDeposit();
      self:QueryAuctions(self:RemoveUniqueId(self:GetAuctionSellItemLink()));
    end
  end
end

-------------------------------------------------------------------------------
-- Auction scanning
-------------------------------------------------------------------------------

-- Start an auction query.
function AuctionLite:StartQuery(link)
  if not QueryRunning then
    QueryRunning = true;
    QueryWait = true;
    QueryLink = link;
    QueryPage = 0;
    QueryData = {};
    ItemValue = 0;
    return true;
  else
    return false;
  end
end

-- Query a named item in the AH.
function AuctionLite:QueryAuctions(link)
  if self:StartQuery(link) then
    self:SetStatus("|cffffff00Scanning...|r");
  end
end

-- Query all items in the AH.
function AuctionLite:QueryAll()
  if self:StartQuery("") then
    BrowseScanText:SetText("0%");
  end
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
    local buyoutPrice = rawData[i].buyoutPrice
    local owner = rawData[i].owner;

    local pricePerItem = buyoutPrice / count;
    if pricePerItem > 0 then
      if itemData[link] == nil then
        itemData[link] = {};
      end

      local ourAuction = (owner == UnitName("player"));
      local listing = { price = pricePerItem, count = count,
                        owner = owner, keep = not ourAuction };
      table.insert(itemData[link], listing);
    end
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
        if data[i].keep and math.abs(data[i].price - avg) > 2 * stddev then
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

-- Request the next page of the current query.
function AuctionLite:QueryNext()
  QueryPage = QueryPage + 1;
  QueryWait = true;
end

-- Our query has completed.  Analyze the data!
function AuctionLite:QueryDone()
  local results = self:AnalyzeData(QueryData);
  -- Get the info for the item we really care about.
  if QueryLink ~= "" then
    local result = results[QueryLink];
    if result ~= nil and result.listings > 0 then
      local name = self:SplitLink(QueryLink);
      ItemValue = result.price;
      self:SetScrollData(name, result.data);
      self:UpdatePrices();
      self:ShowPriceData(QueryLink, ItemValue, PostSize:GetNumber());
      self:SetStatus("|cff00ff00Scanned " .. result.listings ..  " listings.|r");
    else
      local hist = self:GetHistoricalPrice(QueryLink);
      if hist ~= nil then
        ItemValue = hist.price;
        self:UpdatePrices();
        self:ShowPriceData(QueryLink, ItemValue, PostSize:GetNumber());
        self:SetStatus("|cffff0000Using historical data.|r");
      else
        ItemValue = 0;
        self:SetStatus("|cffff0000No data for this item.|r");
      end
    end
  end
  -- Update our price info.
  for link, result in pairs(results) do 
    self:UpdateHistoricalPrice(link, result);
  end
  -- Update the UI.
  self:AuctionFramePost_Update();
  -- Indicate that we're done with this query.
  QueryRunning = false;
  QueryData = nil;
end

-- Handle a completed auction query.
function AuctionLite:AUCTION_ITEM_LIST_UPDATE()
  if QueryRunning and not QueryWait then
    -- We've completed one of our own queries.
    local batch, total = GetNumAuctionItems("list");
    -- Update status.
    if QueryLink == "" then
      local pct = math.floor((QueryPage * AUCTIONS_PER_PAGE + batch) * 100 / total);
      if pct == 100 then
        BrowseScanText:SetText("");
      else
        BrowseScanText:SetText(tostring(pct) .. "%");
      end
    end
    -- Record results.
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
    if QueryPage * AUCTIONS_PER_PAGE + batch < total then
      -- Request the next page.
      self:QueryNext();
    else
      -- We're done--time to analyze the data.
      self:QueryDone();
    end
  end
end

-- Clean up if the auction house is closed.
function AuctionLite:AUCTION_HOUSE_CLOSED()
  self:ClearAuctionFrame();
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
  if info.time + MIN_TIME_BETWEEN_SCANS < time then
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

-- Clean up the "Post Auctions" frame.
function AuctionLite:ClearAuctionFrame()
  QueryRunning = false;
  QueryWait = false;
  QueryLink = nil;
  ItemValue = 0;

  ScrollName = nil;
  ScrollData = {};

  PostItemButton:SetNormalTexture(nil);
  PostItemButtonName:SetText("");
  PostItemButtonCount:Hide();

  PostStackText:SetText("Number of Items");
  PostStacks:SetText("");
  PostSize:SetText("");

  MoneyInputFrame_ResetMoney(PostBidPrice);
  MoneyInputFrame_ResetMoney(PostBuyoutPrice);

  PostCreateAuctionButton:Disable();

  self:SetStatus("");
  self:UpdateDeposit();

  self:AuctionFramePost_Update();
end

-- Set the status line.
function AuctionLite:SetStatus(message)
  StatusMessage = message;
  if not StatusError then
    PostStatusText:SetText(message);
  end
end

-- Set the data for the scrolling frame.
function AuctionLite:SetScrollData(name, data)
  table.sort(data, function(a, b) return a.price < b.price end);

  ScrollName = name;
  ScrollData = data;
end

-- Use this update event to continue a pending AH query.
function AuctionLite:AuctionFrame_OnUpdate()
  local canSend = CanSendAuctionQuery("list");
  if canSend and QueryWait then
    local name;
    if QueryLink == "" then
      name = "";
    else
      name = self:SplitLink(QueryLink);
    end
    QueryAuctionItems(name, 0, 0, 0, 0, 0, QueryPage, 0, 0);
    QueryWait = false;
  end
  if canSend and not QueryRunning then
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

  if index == TabIndex then
    AuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopLeft");
    AuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
    AuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
    AuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotLeft");
    AuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
    AuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotRight");
    AuctionFramePost:Show();
  else
    AuctionFramePost:Hide();
  end
end

-- Handle clicks on the duration radio buttons.
function AuctionLite:PostAuctionDuration_OnClick(widget)
  PostShortAuctionButton:SetChecked(nil);
  PostMediumAuctionButton:SetChecked(nil);
  PostLongAuctionButton:SetChecked(nil);

  if widget:GetID() == 1 then
    PostShortAuctionButton:SetChecked(true);
  elseif widget:GetID() == 2 then
    PostMediumAuctionButton:SetChecked(true);
  elseif widget:GetID() == 3 then
    PostLongAuctionButton:SetChecked(true);
  end

  self:UpdateDeposit();
end

-- Paint the scroll frame on the right-hand side with competing auctions.
function AuctionLite:AuctionFramePost_Update()
  local offset = FauxScrollFrame_GetOffset(PostScrollFrame);

  local i;
  for i = 1, POST_DISPLAY_SIZE do
    local item = ScrollData[offset + i];

    local buttonName = "PostButton" .. i;
    local button = _G[buttonName];

    if item ~= nil then
      local itemCount = _G[buttonName .. "Count"];
      local itemName = _G[buttonName .. "Name"];
      local bidFrame = _G[buttonName .. "BidFrame"];
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

      MoneyFrame_Update(bidFrame, math.floor(item.price));
      bidFrame:SetAlpha(a);

      MoneyFrame_Update(buyoutFrame, math.floor(item.price *item.count));
      buyoutFrame:SetAlpha(a);

      button:Show();
    else
      button:Hide();
    end
  end

  FauxScrollFrame_Update(PostScrollFrame, table.getn(ScrollData),
                         POST_DISPLAY_SIZE, PostButton1:GetHeight());
end

-- Handle clicks on the scroll bar.
function AuctionLite:PostScrollFrame_OnVerticalScroll(offset)
  FauxScrollFrame_OnVerticalScroll(
    PostScrollFrame, offset, PostButton1:GetHeight(),
    function() AuctionLite:AuctionFramePost_Update() end);
end

-- Create the "Post Auctions" tab's scroll frame.
function AuctionLite:CreateScrollFrame()
  local frame = AuctionFramePost;

  local scroll = CreateFrame("ScrollFrame", "PostScrollFrame", frame, "FauxScrollFrameTemplate");
  scroll:SetWidth(435);
  scroll:SetHeight(339);
  scroll:SetPoint("TOPRIGHT", AuctionFrameAuctions, "TOPRIGHT", 40, -72);
  scroll:SetScript("OnEnter", function() AuctionLite:Print("enter") end);
  scroll:SetScript("OnVerticalScroll", function(widget, offset)
    AuctionLite:PostScrollFrame_OnVerticalScroll(offset)
  end);
  FauxScrollFrame_SetOffset(scroll, 0);

  local scrollTex1 = scroll:CreateTexture(nil, "ARTWORK");
  scrollTex1:SetWidth(31);
  scrollTex1:SetHeight(256);
  scrollTex1:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 5);
  scrollTex1:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");
  scrollTex1:SetTexCoord(0, 0.484375, 0, 1.0);

  local scrollTex2 = scroll:CreateTexture(nil, "ARTWORK");
  scrollTex2:SetWidth(31);
  scrollTex2:SetHeight(106);
  scrollTex2:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, -2);
  scrollTex2:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");
  scrollTex2:SetTexCoord(0.515625, 1.0, 0, 0.4140625);

  local i;
  for i = 1, POST_DISPLAY_SIZE do
    local button = CreateFrame("Button", "PostButton" .. i, frame, "PostButtonTemplate");
    button:SetID(i);
    if i == 1 then
      button:SetPoint("TOPLEFT", AuctionFrameAuctions, "TOPLEFT", 219, -76);
    else
      button:SetPoint("TOPLEFT", "PostButton" .. (i - 1), "BOTTOMLEFT", 0, 0);
    end
    button:Hide();
  end
end

-- Create the "Post Auctions" tab.
function AuctionLite:CreateFramePost()
  -- Tweak the "Browse" tab.
  local scan = CreateFrame("Button", "BrowseScanButton", AuctionFrameBrowse, "UIPanelButtonTemplate");
  scan:SetWidth(60);
  scan:SetHeight(22);
  scan:SetText("Scan");
  scan:SetPoint("TOPLEFT", AuctionFrameBrowse, "TOPLEFT", 185, -410);
  scan:SetScript("OnClick", function() AuctionLite:QueryAll() end);

  local scanText = AuctionFrameBrowse:CreateFontString("BrowseScanText", "BACKGROUND", "GameFontNormal");
  scanText:SetPoint("TOPLEFT", scan, "TOPRIGHT", 5, -5);

  -- Hook the auction frame's update function.
  local frameUpdate = AuctionFrame:GetScript("OnUpdate");
  AuctionFrame:SetScript("OnUpdate", function()
    if frameUpdate ~= nil then
      frameUpdate();
    end
    AuctionLite:AuctionFrame_OnUpdate();
  end);

  -- Create our new tab.
  TabIndex = 1;
  while getglobal("AuctionFrameTab" .. TabIndex) ~= nil do
    TabIndex = TabIndex + 1;
  end

  local tab = CreateFrame("Button", "AuctionFrameTab" .. TabIndex, AuctionFrame, "AuctionTabTemplate");
  tab:SetID(TabIndex);
  tab:SetText("AuctionLite - Sell");
  tab:SetPoint("TOPLEFT", "AuctionFrameTab" .. (TabIndex - 1), "TOPRIGHT", -8, 0);
  PanelTemplates_DeselectTab(tab);
  PanelTemplates_SetNumTabs(AuctionFrame, TabIndex);

  -- Create the frame associated with our tab.
  local frame = CreateFrame("Frame", "AuctionFramePost", AuctionFrame);
  frame:SetWidth(758);
  frame:SetHeight(447);

  local titleText = frame:CreateFontString("PostTitle", "BACKGROUND", "GameFontNormal");
  titleText:SetText("AuctionLite - Sell");
  titleText:SetPoint("TOP", AuctionFrame, "TOP", 0, -18);

  local tabText = frame:CreateFontString("PostTabText", "ARTWORK", "GameFontHighlightSmall");
  tabText:SetText("Create Auction");
  tabText:SetPoint("TOP", AuctionFrame, "TOPLEFT", 121, -55);

  local itemText = frame:CreateFontString("PostItemText", "ARTWORK", "GameFontHighlightSmall");
  itemText:SetText("Auction Item");
  itemText:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 28, -83);

  local item = CreateFrame("Button", "PostItemButton", frame);
  item:SetWidth(37);
  item:SetHeight(37);
  item:SetPoint("TOPLEFT", AuctionFrameAuctions, "TOPLEFT", 28, -98);
  item:RegisterForDrag("LeftButton");
  item:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
  item:SetScript("OnClick", function(widget, button)
    ClickAuctionSellItemButton(widget, button);
    AuctionsFrameAuctions_ValidateAuction();
  end);
  item:SetScript("OnReceiveDrag", item:GetScript("OnClick"));
  item:SetScript("OnDragStart", item:GetScript("OnClick"));

  local itemName = item:CreateFontString("PostItemButtonName", "BACKGROUND", "GameFontNormal");
  itemName:SetWidth(124);
  itemName:SetHeight(30);
  itemName:SetPoint("TOPLEFT", item, "TOPRIGHT", 5, 0);

  local itemCount = item:CreateFontString("PostItemButtonCount", "OVERLAY", "NumberFontNormal");
  itemCount:SetJustifyH("RIGHT");
  itemCount:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -5, 2);
  itemCount:Hide();

  local stackText = frame:CreateFontString("PostStackText", "ARTWORK", "GameFontHighlightSmall");
  stackText:SetText("Number of Items");
  stackText:SetPoint("TOPLEFT", itemText, "TOPLEFT", 0, -60);

  local stacks = CreateFrame("EditBox", "PostStacks", frame, "InputBoxTemplate");
  stacks:SetWidth(30);
  stacks:SetHeight(20);
  stacks:SetPoint("TOPLEFT", stackText, "BOTTOMLEFT", 3, -2);
  stacks:SetAutoFocus(nil);
  stacks:SetNumeric(true);
  stacks:SetScript("OnTextChanged", function()
    AuctionLite:UpdateDeposit();
    AuctionLite:ValidateAuction();
  end);

  local stackOfText = frame:CreateFontString("PostStacksOfText", "ARTWORK", "GameFontHighlightSmall");
  stackOfText:SetText("|cffc0c0c0stacks of|r");
  stackOfText:SetPoint("TOPLEFT", stacks, "TOPRIGHT", 5, -5);

  local size = CreateFrame("EditBox", "PostSize", frame, "InputBoxTemplate");
  size:SetWidth(30);
  size:SetHeight(20);
  size:SetPoint("TOPLEFT", stackOfText, "TOPRIGHT", 10, 5);
  size:SetAutoFocus(nil);
  size:SetNumeric(true);
  size:SetScript("OnTextChanged", function()
    AuctionLite:UpdateDeposit();
    AuctionLite:UpdatePrices();
    AuctionLite:ValidateAuction();
  end);

  local bidText = frame:CreateFontString("PostPriceText", "ARTWORK", "GameFontHighlightSmall");
  bidText:SetText("Starting Bid |cff808080(per stack)|r");
  bidText:SetPoint("TOPLEFT", stackText, "TOPLEFT", 0, -38);

  local bid = CreateFrame("Frame", "PostBidPrice", frame, "MoneyInputFrameTemplate");
  bid:SetPoint("TOPLEFT", bidText, "BOTTOMLEFT", 3, -2);
  MoneyInputFrame_SetOnValueChangedFunc(bid, function() AuctionLite:ValidateAuction() end);

  local buyoutText = frame:CreateFontString("PostBuyoutText", "ARTWORK", "GameFontHighlightSmall");
  buyoutText:SetText("Buyout Price |cff808080(per stack)|r");
  buyoutText:SetPoint("TOPLEFT", bidText, "TOPLEFT", 0, -38);

  local buyout = CreateFrame("Frame", "PostBuyoutPrice", frame, "MoneyInputFrameTemplate");
  buyout:SetPoint("TOPLEFT", buyoutText, "BOTTOMLEFT", 3, -2);
  MoneyInputFrame_SetOnValueChangedFunc(buyout, function() AuctionLite:ValidateAuction() end);

  local statusText = frame:CreateFontString("PostStatusText", "ARTWORK", "GameFontHighlightSmall");
  statusText:SetPoint("TOPLEFT", buyoutText, "TOPLEFT", 0, -38);

  local durationText = frame:CreateFontString("PostDurationText", "ARTWORK", "GameFontHighlightSmall");
  durationText:SetText("Auction Duration");
  durationText:SetPoint("TOPLEFT", buyoutText, "TOPLEFT", 0, -78);

  local short = CreateFrame("CheckButton", "PostShortAuctionButton", frame, "UIRadioButtonTemplate");
  short:SetID(1);
  short:SetPoint("TOPLEFT", durationText, "BOTTOMLEFT", 3, -2);
  short:SetScript("OnClick", function(widget, button) AuctionLite:PostAuctionDuration_OnClick(widget) end);
  PostShortAuctionButtonText:SetText("12h");

  local medium = CreateFrame("CheckButton", "PostMediumAuctionButton", frame, "UIRadioButtonTemplate");
  medium:SetID(2);
  medium:SetPoint("TOPLEFT", short, "TOPLEFT", 55, 0);
  medium:SetScript("OnClick", function(widget, button) AuctionLite:PostAuctionDuration_OnClick(widget) end);
  PostMediumAuctionButtonText:SetText("24h");

  local long = CreateFrame("CheckButton", "PostLongAuctionButton", frame, "UIRadioButtonTemplate");
  long:SetID(3);
  long:SetText("48h");
  long:SetPoint("TOPLEFT", medium, "TOPLEFT", 55, 0);
  long:SetChecked(true);
  long:SetScript("OnClick", function(widget, button) AuctionLite:PostAuctionDuration_OnClick(widget) end);
  PostLongAuctionButtonText:SetText("48h");

  local depositText = frame:CreateFontString("PostDepositText", "ARTWORK", "GameFontNormal");
  depositText:SetText("Deposit:");
  depositText:SetPoint("TOPLEFT", durationText, "TOPLEFT", 0, -67);

  local deposit = CreateFrame("Frame", "PostDepositMoneyFrame", frame, "SmallMoneyFrameTemplate");
  deposit:SetPoint("LEFT", depositText, "RIGHT", 5, 0);
  deposit.small = 1;
  MoneyFrame_SetType(deposit, "AUCTIONLITE_DEPOSIT");

  local close = CreateFrame("Button", "PostCloseButton", frame, "UIPanelButtonTemplate");
  close:SetWidth(80);
  close:SetHeight(22);
  close:SetText("Close");
  close:SetPoint("BOTTOMRIGHT", AuctionFrameAuctions, "BOTTOMRIGHT", 66, 14);
  close:SetScript("OnClick", function() HideUIPanel(AuctionFrame) end);

  local create = CreateFrame("Button", "PostCreateAuctionButton", frame, "UIPanelButtonTemplate");
  create:Disable();
  create:SetWidth(191);
  create:SetHeight(20);
  create:SetText("Create Auction");
  create:SetPoint("BOTTOMLEFT", AuctionFrameAuctions, "BOTTOMLEFT", 18, 39);
  create:SetScript("OnClick", function()
    Coro = coroutine.create(function() AuctionLite:CreateAuctions() end);
    coroutine.resume(Coro);
  end);

  local headerText = frame:CreateFontString("PostHeaderText", "ARTWORK", "GameFontHighlightSmall");
  headerText:SetText("Competing Auctions");
  headerText:SetPoint("TOPLEFT", AuctionFrameAuctions, "TOPLEFT", 230, -55);

  local eachHeaderText = frame:CreateFontString("PostEachHeaderText", "ARTWORK", "GameFontHighlightSmall");
  eachHeaderText:SetText("Buyout Per Item");
  eachHeaderText:SetPoint("TOPLEFT", headerText, "TOPRIGHT", 200, 0);

  local totalHeaderText = frame:CreateFontString("PostTotalHeaderText", "ARTWORK", "GameFontHighlightSmall");
  totalHeaderText:SetText("Buyout Total");
  totalHeaderText:SetPoint("TOPLEFT", eachHeaderText, "TOPRIGHT", 75, 0);

  -- Set up tabbing between fields.
  MoneyInputFrame_SetNextFocus(PostBidPrice, PostBuyoutPriceGold);
  MoneyInputFrame_SetPreviousFocus(PostBidPrice, size);

  MoneyInputFrame_SetNextFocus(PostBuyoutPrice, stacks);
  MoneyInputFrame_SetPreviousFocus(PostBuyoutPrice, PostBidPriceCopper);

  stacks:SetScript("OnTabPressed", function()
    if IsShiftKeyDown() then
      PostBuyoutPriceCopper:SetFocus();
    else
      PostSize:SetFocus();
    end
  end);

  size:SetScript("OnTabPressed", function()
    if IsShiftKeyDown() then
      PostStacks:SetFocus();
    else
      PostBidPriceGold:SetFocus();
    end
  end);
end

-------------------------------------------------------------------------------
-- Tooltip code
-------------------------------------------------------------------------------

-- Add vendor and auction data to a tooltip.  We have count1 and count2
-- for the upper and lower bound on the number of items; count2 may be nil.
function AuctionLite:AddTooltipData(tooltip, link, count1, count2)
  -- First add vendor info.  Always print a line for the vendor price.
  local _, id = self:SplitLink(link);
  local vendor = VendorData[id];
  local vendorInfo;
  if vendor ~= nil then
    vendorInfo = self:PrintMoney(vendor * count1);
    if count2 then
      vendorInfo = vendorInfo .. " |cffffffff-|r " ..
                   self:PrintMoney(vendor * count2);
    end
  else
    vendorInfo = "|cffffffffn/a|r";
  end
  tooltip:AddDoubleLine("Vendor", vendorInfo);

  -- Next show the auction price, if any exists.
  local hist = self:GetHistoricalPrice(link);
  if hist ~= nil and hist.price ~= nil then
    local auctionInfo = self:PrintMoney(hist.price * count1);
    if count2 then
      auctionInfo = auctionInfo .. " |cffffffff-|r " ..
                    self:PrintMoney(hist.price * count2);
    end
    tooltip:AddDoubleLine("Auction", auctionInfo);
  end

  tooltip:Show();
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

-------------------------------------------------------------------------------
-- Hooks and boostrap code
-------------------------------------------------------------------------------

-- Hook some AH functions and UI widgets when the AH gets loaded.
function AuctionLite:ADDON_LOADED(name)
  if name == "Blizzard_AuctionUI" then
    self:SecureHook("AuctionFrameTab_OnClick", "AuctionFrameTab_OnClick_Hook");
    self:SecureHook("ClickAuctionSellItemButton", "ClickAuctionSellItemButton_Hook");
    self:CreateFramePost();
    self:CreateScrollFrame();
    self:ClearAuctionFrame();
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
end
