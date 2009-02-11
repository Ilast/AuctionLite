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
local QUERY_STATE_SEND    = 1; -- ready to request a new page
local QUERY_STATE_WAIT    = 2; -- waiting for results of previous request
local QUERY_STATE_APPROVE = 3; -- waiting for approval of a purchase

-- Time to wait (in seconds) after incomplete results are returned.
local QUERY_DELAY = 5;

-- Info about current AH query.
local Query = nil;

-- Is the current call to QueryAuctionItems ours?
local OurQuery = false;

-- Start an auction query.
function AuctionLite:StartQuery(newQuery)
  if Query ~= nil and Query.state == QUERY_STATE_APPROVE then
    self:CancelQuery();
  end
  if Query == nil then
    Query = newQuery;
    Query.state = QUERY_STATE_SEND;
    Query.page = 0;
    Query.data = {};
    return true;
  else
    return false;
  end
end

-- Cancel an auction query.
function AuctionLite:CancelQuery()
  if Query ~= nil then
    if Query.state == QUERY_STATE_APPROVE then
      assert(Query.cart ~= nil);
      Query.cart = nil;
      self:ShowReceipt(true);
    end
    self:QueryEnd();
  end
end

-- Cancel our queries if we see somebody else interfere.
function AuctionLite:QueryAuctionItems_Hook()
  if not OurQuery then
    self:CancelQuery();
  end
end

-- Called periodically to check whether a new query should be sent.
function AuctionLite:QueryUpdate()
  -- Find out whether we can send queries.
  local canSend, canGetAll = CanSendAuctionQuery("list");
  if canSend and Query ~= nil and Query.state == QUERY_STATE_SEND then
    -- Determine the query string.
    local name = nil;
    if Query.name ~= nil then
      name = Query.name;
    elseif Query.link ~= nil then
      name = self:SplitLink(Query.link);
    end

    -- Did we get a reasonable query?  We need a name, and if it's a getAll
    -- query, it should be on the first page with no shopping list.
    if name ~= nil and
       (not Query.getAll or (Query.page == 0 and Query.list == nil)) then

      -- Truncate to avoid disconnects.
      name = self:Truncate(name, MAX_QUERY_BYTES);

      -- Was getAll requested, and can we actually use it?
      local getAll = false;
      if Query.getAll then
        if canGetAll then
          getAll = true;
        else
          Query.getAll = false;
          self:Print("|cffff0000[Warning]|r Fast queries can only be used " ..
                     "once every 15 minutes. Using a slow query for now.");
        end
      end

      -- Submit the query.
      OurQuery = true;
      QueryAuctionItems(name, 0, 0, 0, 0, 0, Query.page, 0, 0, getAll);
      OurQuery = false;

      -- Wait for our result.
      Query.state = QUERY_STATE_WAIT;
    else
      self:CancelQuery();
    end
  end

  -- Are we waiting for a more detailed update?  If so, check to see
  -- whether we've timed out.
  if Query ~= nil and Query.state == QUERY_STATE_WAIT and
     Query.time ~= nil and Query.time + QUERY_DELAY < time() then
    Query.time = nil;
    self:QueryNewData();
  end
end

-- Wait for purchase approval.
function AuctionLite:QueryRequestApproval()
  assert(Query ~= nil and Query.state == QUERY_STATE_WAIT);
  Query.state = QUERY_STATE_APPROVE;
end

-- Get the next page.
function AuctionLite:QueryNext()
  assert(Query ~= nil and
         (Query.state == QUERY_STATE_WAIT or
          Query.state == QUERY_STATE_APPROVE));
  Query.state = QUERY_STATE_SEND;
  Query.page = Query.page + 1;
end

-- Get the current page again.
function AuctionLite:QueryCurrent()
  assert(Query ~= nil and
         (Query.state == QUERY_STATE_WAIT or
          Query.state == QUERY_STATE_APPROVE));
  Query.state = QUERY_STATE_SEND;
end

-- End the current query.
function AuctionLite:QueryEnd()
  assert(Query ~= nil);
  Query = nil;
end

-- Is there currently a query pending?
function AuctionLite:QueryInProgress()
  return (Query ~= nil and Query.state ~= QUERY_STATE_APPROVE);
end

-- Compute the average and standard deviation of the points in data.
function AuctionLite:ComputeStats(data)
  local count = 0;
  local sum = 0;
  local sumSquared = 0;

  for _, listing in ipairs(data) do
    if listing.keep then
      count = count + listing.count;
      sum = sum + listing.price * listing.count;
      sumSquared = sumSquared + (listing.price ^ 2) * listing.count;
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
  for _, entry in ipairs(rawData) do
    local link = entry.link;
    local count = entry.count;
    local bid = entry.bid;
    local buyout = entry.buyout
    local owner = entry.owner;
    local bidder = entry.highBidder;

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
      for _, listing in ipairs(data) do
        if listing.keep and math.abs(listing.price - avg) > 2.5 * stddev then
          listing.keep = false;
          done = false;
        end
      end
    end

    -- We've converged.  Compute our min price and other stats.
    local result = { price = 1000000000, items = 0, listings = 0,
                     itemsAll = 0, listingsAll = 0 };
    local setPrice = false;

    for _, listing in ipairs(data) do
      if listing.keep then
        result.items = result.items + listing.count;
        result.listings = result.listings + 1;
        if listing.price < result.price then
          result.price = listing.price;
          setPrice = true;
        end
      end
      result.itemsAll = result.itemsAll + listing.count;
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

-- Get the current shopping cart info for approval.
function AuctionLite:GetCart()
  if Query ~= nil then
    return Query.cart;
  else
    return nil;
  end
end

-- Approve purchase of a pending shopping cart.
function AuctionLite:QueryApprove()
  assert(Query ~= nil);
  assert(Query.state == QUERY_STATE_APPROVE);
  assert(Query.cart ~= nil);

  -- Place the request bid or buyout.
  local i;
  for _, listing in ipairs(Query.cart) do
    if not listing.target.purchased then
      local price;
      if Query.isBuyout then
        price = listing.buyout;
      else
        price = listing.bid;
      end
      if price <= GetMoney() then
        PlaceAuctionBid("list", listing.index, price);
        listing.target.purchased = true;
      end
    end
  end

  -- Clean up.
  Query.cart = nil;

  -- Figure out whether we've found everything on our list.
  -- If so, we don't need to look any further.
  local done = true;
  for _, target in ipairs(Query.list) do
    if not target.found then
      done = false;
      break;
    end
  end

  -- If we're done, cleanup.  If not, make the next request.
  -- Note that we request the same page again, since our purchase may
  -- have caused some auctions from the next page to move onto this one.
  if done then
    self:ShowReceipt();
    self:QueryEnd();
  else
    self:QueryCurrent();
  end
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
  for _, target in ipairs(Query.list) do
    if target.purchased then
      listingsBought = listingsBought + 1;
      itemsBought = itemsBought + target.count;
      if Query.isBuyout then
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
  if Query.isBuyout then
    action = "Bought";
  else
    action = "Bid on";
  end

  if not cancelled or listingsBought > 0 then
    self:Print(action .. " " .. itemsBought .. "x " .. Query.name ..
               " (" .. self:MakePlural(listingsBought, "listing") ..
               " at " ..  self:PrintMoney(price) .. ").");

    if itemsNotFound > 0 then
      local verb;
      if listingsNotFound == 1 then
        verb = "was";
      else
        verb = "were";
      end
      self:Print("Note: " .. self:MakePlural(listingsNotFound, "listing") ..
                 " of " .. self:MakePlural(itemsNotFound, "item") ..
                 " " .. verb .. " not purchased.");
    end
  end

  -- Notify the buy tab that we're done.
  if Query.finish ~= nil then
    Query.finish();
  end
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
  assert(Query ~= nil);
  assert(Query.state == QUERY_STATE_WAIT);

  -- We've completed one of our own queries.
  local seen = Query.page * AUCTIONS_PER_PAGE + Query.batch;

  -- If we're running a getAll query, we'd better have seen everything.
  assert(not Query.getAll or seen == Query.total);

  -- Update status.
  local pct = math.floor(seen * 100 / Query.total);
  if Query.update ~= nil then
    Query.update(pct);
  end

  -- Handle the new data based on the kind of query.
  if Query.list == nil then
    -- This is a search query, not a purchase.
    if seen < Query.total then
      -- Request the next page.
      self:QueryNext();
    else
      local oldQuery = Query;
      -- We're done.  End the query and return the results.
      self:QueryEnd();
      local results = self:AnalyzeData(oldQuery.data);
      if oldQuery.finish ~= nil then
        oldQuery.finish(results, oldQuery.link);
      end
      -- Update our price info.
      for link, result in pairs(results) do 
        self:UpdateHistoricalPrice(link, result);
      end
    end
  else
    assert(not Query.getAll);

    -- This is a purchase.  We're going to compare the current page
    -- against our shopping list to create a shopping cart, which is the
    -- set of items from the current page that we plan to buy.
    local cart = {};

    -- See if we've found the auction we're looking for.
    local i, j;
    for i = 1, Query.batch do
      local listing = Query.data[Query.page * AUCTIONS_PER_PAGE + i];
      for _, target in ipairs(Query.list) do
        if not target.found and
           self:ListingMatch(Query.name, target, listing) then
          target.found = true;
          listing.index = i;
          listing.target = target;
          table.insert(cart, listing);
          break;
        end
      end
    end

    -- If we found something, request approval.
    -- Otherwise, get the next page or end the query.
    if table.getn(cart) > 0 then
      Query.cart = cart;
      self:RequestApproval();
      self:QueryRequestApproval();
    elseif seen < Query.total then
      self:QueryNext();
    else
      self:ShowReceipt();
      self:QueryEnd();
    end
  end
end

-- Handle a completed auction query.
function AuctionLite:AUCTION_ITEM_LIST_UPDATE()
  if Query ~= nil and Query.state == QUERY_STATE_WAIT then
    Query.batch, Query.total = GetNumAuctionItems("list");

    local incomplete = 0;
    local i;

    for i = 1, Query.batch do
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
      Query.data[Query.page * AUCTIONS_PER_PAGE + i] = listing;
    end

    -- If we got an incomplete record, wait.  Otherwise, process the data.
    if Query.wait and incomplete > 0 then
      Query.time = time();
    else
      Query.time = nil;
      self:QueryNewData();
    end
  end
end
