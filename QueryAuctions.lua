-------------------------------------------------------------------------------
-- Query.lua
--
-- Queries the auction house.
-------------------------------------------------------------------------------

local AUCTIONS_PER_PAGE = 50;

local QUERY_STATE_IDLE = 1;
local QUERY_STATE_SEND = 2;
local QUERY_STATE_WAIT = 3;

local QUERY_TYPE_NONE = 1;
local QUERY_TYPE_SCAN = 2;
local QUERY_TYPE_SEARCH = 3;
local QUERY_TYPE_BID = 4;
local QUERY_TYPE_BUY = 5;
local QUERY_TYPE_SELL = 6;

-- Info about current AH query.
local QueryState = QUERY_STATE_IDLE;
local QueryType = QUERY_TYPE_NONE;
local QueryName = nil;
local QueryLink = nil;
local QueryPage = nil;
local QueryData = nil;

-- Popup dialog for bidding on auctions.
StaticPopupDialogs["AUCTIONLITE_BID"] = {
	text = "Bid on auction at:",
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(self)
    -- Place the buyout.
		PlaceAuctionBid("list", TargetIndex, TargetPrice);
    -- Update the scroll frame.
    AuctionLite:BidPlaced(TargetPrice);
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
    AuctionLite:BuyoutPlaced();
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

-- Reset the state of the auction query.
function AuctionLite:ResetQuery()
  QueryState = QUERY_STATE_IDLE;
  QueryType = QUERY_TYPE_NONE;

  QueryName = nil;
  QueryLink = nil;
  QueryData = nil;
end

-- Start an auction query.
function AuctionLite:StartQuery(queryType, name, link)
  if QueryState == QUERY_STATE_IDLE then
    QueryState = QUERY_STATE_SEND;
    QueryType = queryType;
    QueryName = name;
    QueryLink = link;
    QueryPage = 0;
    QueryData = {};
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

-- Called periodically to check whether a new query should be sent.
function AuctionLite:QueryUpdate()
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

-- Is there currently a query pending?
function AuctionLite:QueryInProgress()
  return (QueryState ~= QUERY_STATE_IDLE);
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
      local name = self:SplitLink(link);
      self:SetBuyScrollData(name, result.data);
    end
  elseif QueryLink ~= "" then
    local result = results[QueryLink];
    local itemValue = 0;
    if result ~= nil and result.listings > 0 then
      local name = self:SplitLink(QueryLink);
      itemValue = result.price;
      self:SetScrollData(name, result.data);
      self:ShowPriceData(QueryLink, itemValue, SellSize:GetNumber());
      self:SetStatus("|cff00ff00Scanned " .. result.listings ..  " listings.|r");
    else
      local hist = self:GetHistoricalPrice(QueryLink);
      if hist ~= nil then
        itemValue = hist.price;
        self:ShowPriceData(QueryLink, itemValue, SellSize:GetNumber());
        self:SetStatus("|cffff0000Using historical data.|r");
      else
        local _, _, count, _, _, vendor = GetAuctionSellItemInfo();
        itemValue = 3 * vendor / count;
        self:SetStatus("|cffff0000Using 3x vendor price.|r");
      end
    end
    -- Update the suggested prices.
    self:UpdatePrices(itemValue);
  end
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
      local targetName, target = self:GetBuyItem();
      if targetName ~= nil and target ~= nil then
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
          if targetName == name and
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
