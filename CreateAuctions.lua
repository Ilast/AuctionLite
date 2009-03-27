-------------------------------------------------------------------------------
-- CreateAuctions.lua
--
-- Create a group of auctions based on input in the "Sell" tab.
-------------------------------------------------------------------------------

local L = LibStub("AceLocale-3.0"):GetLocale("AuctionLite", false)

-- Flag indicating whether we're currently posting auctions.
local Selling = false;

-- Current coroutine.
local Coro = nil;

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

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
function AuctionLite:CreateAuctionsCore()
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
      self:Print(L["Error locating item in bags.  Please try again!"]);
    elseif bid == 0 then
      self:Print(L["Invalid starting bid."]);
    elseif 0 < buyout and buyout < bid then
      self:Print(L["Buyout cannot be less than starting bid."]);
    elseif GetMoney() < self:CalculateDeposit() then
      self:Print(L["Not enough cash for deposit."]);
    elseif self:CountItems(link) < stacks * size then
      self:Print(L["Not enough items available."]);
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
            self:Print(L["Error when creating auctions."]);
            break;
          end

          created = created + 1;
          SellStacks:SetNumber(stacks - created);
        end

        self:ClearSellFrame();
      elseif created < stocks then
        -- Couldn't find an empty bag slot.
        self:Print(L["Need an empty bag slot to create auctions."]);
      else
        -- We're done anyway.
        self:ClearSellFrame();
      end

      self:Print(L["Created %d |4auction:auctions; of %s x%d."]:
                 format(created, name, size));
    end

    Selling = false;
  else
    self:Print(L["Auction creation is already in progress."]);
  end
end

-- Start a coroutine to create auctions.
function AuctionLite:CreateAuctions()
  self:StartCoroutine(function() AuctionLite:CreateAuctionsCore() end);
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

-------------------------------------------------------------------------------
-- Coroutine hooks
-------------------------------------------------------------------------------

-- An item lock has changed, so wake up the coroutine.
function AuctionLite:ITEM_LOCK_CHANGED()
  self:ResumeCoroutine();
end

-- A bag slot has changed, so wake up the coroutine.
function AuctionLite:BAG_UPDATE()
  self:ResumeCoroutine();
end

-- Add the hooks needed for our coroutines.
function AuctionLite:HookCoroutines()
  self:RegisterEvent("BAG_UPDATE");
  self:RegisterEvent("ITEM_LOCK_CHANGED");
end

-------------------------------------------------------------------------------
-- Miscellaneous
-------------------------------------------------------------------------------

-- Indicate whether we're creating auctions.
function AuctionLite:CreateInProgress()
  return Selling;
end

-- Reset state.  Useful for recovering from bugs.
function AuctionLite:ResetAuctionCreation()
  Selling = false;
  Coro = nil;
end
