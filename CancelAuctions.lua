-------------------------------------------------------------------------------
-- CancelAuctions.lua
--
-- Cancel a group of auctions.
-------------------------------------------------------------------------------

-- Cancel all auctions for "name" listed in "targets".
function AuctionLite:CancelAuctions(name, targets)
  local batch = GetNumAuctionItems("owner");
  local cancel = {};

  -- Find all the auctions to cancel.
  local i;
  for i = 1, batch do
    local listing = self:GetListing("owner", i);

    for _, target in ipairs(targets) do
      if not target.cancelled and
         self:MatchListing(name, target, listing) then
        target.cancelled = true;
        table.insert(cancel, i);
        break;
      end
    end
  end

  -- Sort them from highest to lowest so that we can cancel the higher
  -- ones without throwing off the indices of the remaining ones.
  table.sort(cancel, function(a, b) return a > b end);

  -- Cancel them!
  local listingsCancelled = 0;
  for _, index in ipairs(cancel) do
    CancelAuction(index);
    listingsCancelled = listingsCancelled + 1;
  end

  -- Print a summary.
  self:Print("Cancelled " .. self:MakePlural(listingsCancelled, "listing") ..
             " of " .. name);
end
