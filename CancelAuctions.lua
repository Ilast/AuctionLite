-------------------------------------------------------------------------------
-- CancelAuctions.lua
--
-- Cancel a group of auctions.
-------------------------------------------------------------------------------

local L = LibStub("AceLocale-3.0"):GetLocale("AuctionLite", false)

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
    self:IgnoreMessage(ERR_AUCTION_REMOVED);
    listingsCancelled = listingsCancelled + 1;
  end

  -- Print a summary.
  self:Print(L["Cancelled %d listings of %s"]:format(listingsCancelled, name));
end
