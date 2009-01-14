-------------------------------------------------------------------------------
-- Query.lua
--
-- Queries the auction house.
-------------------------------------------------------------------------------

-- Number of results returned per query.
local AUCTIONS_PER_PAGE = 50;

-- Maximum number of bytes in the first argument of QueryAuctionItems().
local MAX_QUERY_BYTES = 63;

-- State of our current auction query.
local QUERY_STATE_IDLE    = 1; -- no query running
local QUERY_STATE_SEND    = 2; -- ready to request a new page
local QUERY_STATE_WAIT    = 3; -- waiting for results of previous request
local QUERY_STATE_APPROVE = 4; -- waiting for approval of a purchase

-- Type of the current query.
local QUERY_TYPE_NONE     = 1; -- no query running
local QUERY_TYPE_SCAN     = 2; -- auction scan
local QUERY_TYPE_SEARCH   = 3; -- search for buy tab (by name)
local QUERY_TYPE_BUY      = 4; -- place a buyout
local QUERY_TYPE_SELL     = 5; -- search for sell tab (by link)

-- Time to wait (in seconds) after incomplete results are returned.
local QUERY_DELAY = 5;

-- Info about current AH query.
local QueryState = QUERY_STATE_IDLE;
local QueryType = QUERY_TYPE_NONE;
local QueryName = nil;
local QueryLink = nil;
local QueryPage = nil;
local QueryTime = nil;
local QueryData = nil;
local QueryIsBuyout = nil;

-- Info about a purchase request.
local ShoppingList = nil;  -- list of all items to be purchased
local ShoppingCart = nil;  -- list of items to be purchased on current page

-- Reset the state of the auction query.
function AuctionLite:ResetQuery()
  QueryState = QUERY_STATE_IDLE;
  QueryType = QUERY_TYPE_NONE;

  QueryName = nil;
  QueryLink = nil;
  QueryPage = nil;
  QueryTime = nil;
  QueryData = nil;
  QueryIsBuyout = nil;

  ShoppingList = nil;
  ShoppingCart = nil;
end

-- Start an auction query.
function AuctionLite:StartQuery(queryType)
  if QueryState == QUERY_STATE_APPROVE then
    self:QueryCancel();
  end
  if QueryState == QUERY_STATE_IDLE then
    self:ResetQuery();
    QueryState = QUERY_STATE_SEND;
    QueryType = queryType;
    QueryPage = 0;
    QueryData = {};
    return true;
  else
    return false;
  end
end

-- Query for an item dropped in the sell tab.
function AuctionLite:QuerySell(link)
  local result = self:StartQuery(QUERY_TYPE_SELL);
  if result then
    QueryLink = link;
  end
  return result;
end

-- Query to bid or buy out an item.
function AuctionLite:QueryBuy(name, list, isBuyout)
  local result = self:StartQuery(QUERY_TYPE_BUY);
  if result then
    QueryName = name;
    ShoppingList = list;
    QueryIsBuyout = isBuyout;
  end
  return result;
end

-- Query by name for the buy tab.
function AuctionLite:QuerySearch(name)
  local result = self:StartQuery(QUERY_TYPE_SEARCH);
  if result then
    QueryName = name;
  end
  return result;
end

-- Query all items in the AH.
function AuctionLite:QueryScan()
  return self:StartQuery(QUERY_TYPE_SCAN);
end

-- Called periodically to check whether a new query should be sent.
function AuctionLite:QueryUpdate()
  local canSend = CanSendAuctionQuery("list");
  if canSend and QueryState == QUERY_STATE_SEND then
    local name = nil;
    if QueryType == QUERY_TYPE_SCAN then
      name = "";
    elseif QueryType == QUERY_TYPE_SEARCH or QueryType == QUERY_TYPE_BUY then
      name = QueryName;
    elseif QueryType == QUERY_TYPE_SELL then
      name = self:SplitLink(QueryLink);
    end
    if name ~= nil then
      name = self:Truncate(name, MAX_QUERY_BYTES);
      QueryAuctionItems(name, 0, 0, 0, 0, 0, QueryPage, 0, 0);
      QueryState = QUERY_STATE_WAIT;
    else
      self:ResetQuery();
    end
  end

  if QueryState == QUERY_STATE_WAIT and
     QueryTime ~= nil and QueryTime + QUERY_DELAY < time() then
    QueryTime = nil;
    self:QueryNewData();
  end
end

-- Wait for purchase approval.
function AuctionLite:QueryRequestApproval()
  assert(QueryState == QUERY_STATE_WAIT);
  QueryState = QUERY_STATE_APPROVE;
end

-- Get the next page.
function AuctionLite:QueryNext()
  assert(QueryState == QUERY_STATE_WAIT or QueryState == QUERY_STATE_APPROVE);
  QueryState = QUERY_STATE_SEND;
  QueryPage = QueryPage + 1;
end

-- End the current query.
function AuctionLite:QueryEnd()
  assert(QueryState == QUERY_STATE_WAIT or QueryState == QUERY_STATE_APPROVE);
  self:ResetQuery();
end

-- Is there currently a query pending?
function AuctionLite:QueryInProgress()
  return (QueryState ~= QUERY_STATE_IDLE and QueryState ~= QUERY_STATE_APPROVE);
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
    local bid = rawData[i].bid;
    local buyout = rawData[i].buyout
    local owner = rawData[i].owner;
    local bidder = rawData[i].highBidder;

    if link ~= nil then
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
    local result = { price = 1000000000, items = 0, listings = 0,
                     itemsAll = 0, listingsAll = 0 };
    local setPrice = false;

    for i = 1, table.getn(data) do
      if data[i].keep then
        result.items = result.items + data[i].count;
        result.listings = result.listings + 1;
        if data[i].price < result.price then
          result.price = data[i].price;
          setPrice = true;
        end
      end
      result.itemsAll = result.itemsAll + data[i].count;
      result.listingsAll = result.listingsAll + 1;
    end

    -- If we kept no data (e.g., all auctions are ours), pick the first
    -- price.  By construction of itemData, there is at least one entry.
    if not setPrice then
      result.price = data[1].price;
    end

    result.data = data;
    results[link] = result;
  end

  return results;
end

-- Our query has completed.  Analyze the data!
function AuctionLite:QueryFinished(queryType, queryLink, queryData)
  local results = self:AnalyzeData(queryData);
  -- Get the info for the item we really care about.
  if queryType == QUERY_TYPE_SEARCH then
    self:SetBuyData(results);
  elseif queryType == QUERY_TYPE_SELL then
    self:SetSellData(results, queryLink);
  end
  -- Update our price info.
  for link, result in pairs(results) do 
    self:UpdateHistoricalPrice(link, result);
  end
end

-- Get the current shopping cart info for approval.
function AuctionLite:GetCart()
  return ShoppingCart;
end

-- Approve purchase of a pending shopping cart.
function AuctionLite:QueryApprove()
  assert(QueryState == QUERY_STATE_APPROVE);
  assert(ShoppingCart ~= nil);

  -- Place the request bid or buyout.
  local i;
  for i = 1, table.getn(ShoppingCart) do
    local listing = ShoppingCart[i];
    if not listing.target.purchased then
      local price;
      if QueryIsBuyout then
        price = listing.buyout;
      else
        price = listing.bid;
      end
      PlaceAuctionBid("list", listing.index, price);
      listing.target.purchased = true;
    end
  end

  -- Clean up.
  ShoppingCart = nil;

  -- Figure out whether we've purchased everything on our list.
  local done = true;
  for i = 1, table.getn(ShoppingList) do
    if not ShoppingList[i].purchased then
      done = false;
      break;
    end
  end

  -- If we're done, cleanup.  If not, request the next page.
  if done then
    self:ShowReceipt();
    self:QueryEnd();
  else
    self:QueryNext();
  end
end

-- Cancel purchase of a shopping cart.
function AuctionLite:QueryCancel()
  assert(QueryState == QUERY_STATE_APPROVE);
  assert(ShoppingCart ~= nil);

  -- Clean up.
  ShoppingCart = nil;

  -- End the purchase.
  self:ShowReceipt(true);
  self:QueryEnd();
end

-- Print out a summary of the items purchased.
function AuctionLite:ShowReceipt(cancelled)
  local listingsBought = 0;
  local itemsBought = 0;

  local listingsNotFound = 0;
  local itemsNotFound = 0;

  local price = 0;

  -- Figure out what we bought.
  local i;
  for i = 1, table.getn(ShoppingList) do
    local target = ShoppingList[i];
    if target.purchased then
      listingsBought = listingsBought + 1;
      itemsBought = itemsBought + target.count;
      if QueryIsBuyout then
        price = price + target.buyout;
      else
        price = price + target.bid;
      end
    else
      listingsNotFound = listingsNotFound + 1;
      itemsNotFound = itemsNotFound + target.count;
    end
  end

  -- Print a summary.
  local action;
  if QueryIsBuyout then
    action = "Bought";
  else
    action = "Bid on";
  end

  if not cancelled or listingsBought > 0 then
    self:Print(action .. " " .. itemsBought .. "x " .. QueryName ..
               " (" .. self:MakePlural(listingsBought, "listing") ..
               " at " ..  self:PrintMoney(price) .. ").");

    if itemsNotFound > 0 then
      self:Print("Note: " .. self:MakePlural(listingsNotFound, "listing") ..
                 " of " .. self:MakePlural(itemsNotFound, "item") ..
                 " were not purchased.");
    end
  end

  -- Notify the buy tab that we're done.
  self:PurchaseComplete();
end

-- Does a target from the shopping list match a listing?
function AuctionLite:ListingMatch(targetName, target, listing)
  return targetName == listing.name and
         target.count == listing.count and
         target.bid == listing.bid and
         target.buyout == listing.buyout and
         (target.owner == nil or listing.owner == nil or
          target.owner == listing.owner);
end

-- We've got new data.
function AuctionLite:QueryNewData()
  assert(QueryState == QUERY_STATE_WAIT);

  -- We've completed one of our own queries.
  local seen = QueryPage * AUCTIONS_PER_PAGE + Batch;
  -- Update status.
  local pct = math.floor(seen * 100 / Total);
  if QueryType == QUERY_TYPE_SCAN then
    self:UpdateProgressScan(pct);
  elseif QueryType == QUERY_TYPE_SEARCH then
    self:UpdateProgressSearch(pct);
  elseif QueryType == QUERY_TYPE_SELL then
    self:UpdateProgressSell(pct);
  end
  -- Record results.
  if QueryType == QUERY_TYPE_SCAN or
     QueryType == QUERY_TYPE_SEARCH or
     QueryType == QUERY_TYPE_SELL then
    if seen < Total then
      -- Request the next page.
      self:QueryNext();
    else
      local queryType = QueryType;
      local queryLink = QueryLink;
      local queryData = QueryData;
      -- We're done.  End the query and return the results.
      self:QueryEnd();
      self:QueryFinished(queryType, queryLink, queryData);
    end
  elseif QueryType == QUERY_TYPE_BUY then
    ShoppingCart = {};

    -- See if we've found the auction we're looking for.
    local i, j;
    for i = 1, Batch do
      local listing = QueryData[QueryPage * AUCTIONS_PER_PAGE + i];
      for j = 1, table.getn(ShoppingList) do
        local target = ShoppingList[j];
        if not target.found and
           self:ListingMatch(QueryName, target, listing) then
          target.found = true;
          listing.index = i;
          listing.target = target;
          table.insert(ShoppingCart, listing);
          break;
        end
      end
    end

    -- Clear the shopping cart if we found nothing.
    if table.getn(ShoppingCart) == 0 then
      ShoppingCart = nil;
    end

    -- If we found something, request approval.
    -- Otherwise, get the next page or end the query.
    if ShoppingCart ~= nil then
      self:RequestApproval();
      self:QueryRequestApproval();
    elseif seen < Total then
      self:QueryNext();
    else
      self:ShowReceipt();
      self:QueryEnd();
    end
  end
end

-- Handle a completed auction query.
function AuctionLite:AUCTION_ITEM_LIST_UPDATE(x)
  if QueryState == QUERY_STATE_WAIT then
    Batch, Total = GetNumAuctionItems("list");

    local incomplete = 0;
    local i;

    for i = 1, Batch do
      -- There has *got* to be a better way to do this...
      local link = self:RemoveUniqueId(GetAuctionItemLink("list", i));
      local name, texture, count, quality, canUse, level,
            minBid, minIncrement, buyout, bidAmount,
            highBidder, owner = GetAuctionItemInfo("list", i);

      -- Figure out the true minimum bid.
      local bid;
      if bidAmount <= 0 then
        bid = minBid;
      else
        bid = bidAmount + minIncrement;
        if bid > buyout and buyout > 0 then
          bid = buyout;
        end
      end

      -- Craete a listing object with all this data.
      local listing = {
        link = link, name = name, texture = texture, count = count,
        quality = quality, canUse = canUse, level = level,
        bid = bid, minBid = minBid, minIncrement = minIncrement,
        buyout = buyout, bidAmount = bidAmount,
        highBidder = highBidder, owner = owner
      };

      -- Sometimes we get incomplete records.  Is this one of them?
      if owner == nil then
        incomplete = incomplete + 1;
      end

      -- Record the data.
      QueryData[QueryPage * AUCTIONS_PER_PAGE + i] = listing;
    end

    -- If we got an incomplete record, wait.  Otherwise, process the data.
    if (QueryType == QUERY_TYPE_SEARCH or QueryType == QUERY_TYPE_BUY) and
       incomplete > 0 then
      QueryTime = time();
    else
      QueryTime = nil;
      self:QueryNewData();
    end
  end
end
