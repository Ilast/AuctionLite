-------------------------------------------------------------------------------
-- CancelAuctions.lua
--
-- Cancel a group of auctions.
-------------------------------------------------------------------------------

local L = LibStub("AceLocale-3.0"):GetLocale("AuctionLite", false)

-- Static popup advertising AL's fast scan.
StaticPopupDialogs["AL_CANCEL_CONFIRM"] = {
  text = L["CANCEL_CONFIRM_TEXT"],
  button1 = L["Cancel All"],
  button3 = L["Cancel Unbid"],
  button2 = L["Do Nothing"],
  OnAccept = function(self)
    AuctionLite:FinishCancel(self.data, true);
  end,
  OnAlt = function(self)
    AuctionLite:FinishCancel(self.data, false);
  end,
  OnCancel = function(self)
    -- Do nothing.
  end,
  showAlert = 1,
  timeout = 0,
  exclusive = 1,
  hideOnEscape = 1
};

-- Cancel all auctions for "name" listed in "targets".
function AuctionLite:CancelAuctions(name, targets)
  local batch = GetNumAuctionItems("owner");
  local cancel = {};
  local bidsDetected = false;

  -- Find all the auctions to cancel.
  local i;
  for i = 1, batch do
    local listing = self:GetListing("owner", i);

    for _, target in ipairs(targets) do
      if not target.found and
         self:MatchListing(name, target, listing) then

        target.found = true;

        local item = { index = i,
                       target = target,
                       hasBid = (listing.bidAmount > 0) };

        table.insert(cancel, item);

        if item.hasBid then
          bidsDetected = true;
        end

        break;
      end
    end
  end

  -- Clear all our marks.
  for _, target in ipairs(targets) do
    target.found = nil;
  end

  -- If we found any bids, show our confirmation dialog.
  -- Otherwise, just cancel the auctions.
  local data = { name = name, cancel = cancel };
  if bidsDetected then
    local dialog = StaticPopup_Show("AL_CANCEL_CONFIRM");
    if dialog ~= nil then
      dialog.data = data;
    end
  else
    self:FinishCancel(data, false);
  end
end

-- Actually cancel the selected auctions.
function AuctionLite:FinishCancel(data, cancelBid)
  local name = data.name;
  local cancel = data.cancel;

  -- Sort them from highest to lowest so that we can cancel the higher
  -- ones without throwing off the indices of the remaining ones.
  table.sort(cancel, function(a, b) return a.index > b.index end);

  -- Cancel them!
  local listingsCancelled = 0;
  for _, item in ipairs(cancel) do
    if cancelBid or not item.hasBid then
      item.target.cancelled = true;
      CancelAuction(item.index);
      self:IgnoreMessage(ERR_AUCTION_REMOVED);
      listingsCancelled = listingsCancelled + 1;
    end
  end

  -- Print a summary.
  self:Print(L["Cancelled %d |4listing:listings; of %s."]:format(listingsCancelled, name));

  -- Notify the "Buy" frame.
  self:CancelComplete();
end
