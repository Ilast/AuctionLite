-------------------------------------------------------------------------------
-- Util.lua
--
-- General utility functions.
-------------------------------------------------------------------------------

-- Make a printable string for a time in seconds.
function AuctionLite:PrintTime(sec)
  local min = math.floor(sec / 60);
  sec = sec % 60;

  local hr = math.floor(min / 60);
  min = min % 60;

  local result = "";

  if hr > 0 then
    result = tostring(hr) .. ":" .. string.format("%02d", min) .. ":";
  else
    result = tostring(min) .. ":";
  end

  result = result .. string.format("%02d", sec);

  return result;
end

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

-- Dissect an item link or item string.
function AuctionLite:SplitLink(link)
  -- Parse the link.
  local _, _, color, str, name = link:find("|c(.*)|H(.*)|h%[(.*)%]");

  -- If we failed, then assume it's actually an item string.
  if str == nil then
    str = link;
  end

  -- Split the item string.
  local _, id, enchant, jewel1, jewel2, jewel3, jewel4, suffix, unique =
        strsplit(":", str);

  return name, color,
         tonumber(id), tonumber(suffix), tonumber(enchant),
         tonumber(jewel1), tonumber(jewel2),
         tonumber(jewel3), tonumber(jewel4),
         tonumber(unique);
end

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

-- Make a money frame value negative.
function AuctionLite:MakeNegative(frameName)
  local adjust = function(button)
    local current = button:GetText();
    if button:IsShown() then
      button:SetText("-" .. current);
      return true;
    else
      return false;
    end
  end

	local goldButton = getglobal(frameName .. "GoldButton");
  if not adjust(goldButton) then
    local silverButton = getglobal(frameName .. "SilverButton");
    if not adjust(silverButton) then
      local copperButton = getglobal(frameName .. "CopperButton");
      adjust(copperButton);
    end
  end
end

-- Truncates a UTF-8 string to a fixed number of bytes.
function AuctionLite:Truncate(str, bytes)
  -- We need to make sure that we don't truncate mid-character, and in
  -- UTF-8, all mid-character bytes start with bits 10.  So, reduce bytes
  -- until the first character we're dropping does not start with 10.

  if str:len() > bytes then
    while bytes > 0 and bit.band(str:byte(bytes + 1), 0xc0) == 0x80 do
      bytes = bytes - 1;
    end
  end

  return str:sub(1, bytes);
end

-- Get a listing from the auction house.
function AuctionLite:GetListing(kind, i)
  -- There has *got* to be a better way to do this...
  local link = self:RemoveUniqueId(GetAuctionItemLink(kind, i));
  local name, texture, count, quality, canUse, level,
        minBid, minIncrement, buyout, bidAmount,
        highBidder, owner = GetAuctionItemInfo(kind, i);

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

  return listing;
end

-- Does a target from the "Buy" frame match an auction listing?
function AuctionLite:MatchListing(targetName, target, listing)
  return targetName == listing.name and
         target.count == listing.count and
         target.bid == listing.bid and
         target.buyout == listing.buyout and
         (target.owner == nil or listing.owner == nil or
          target.owner == listing.owner);
end

-- Do two pages from an AH scan match exactly?
function AuctionLite:MatchPages(data, page1, page2)
  local i;
  for i = 1, NUM_AUCTION_ITEMS_PER_PAGE do
    local listing1 = data[page1 * NUM_AUCTION_ITEMS_PER_PAGE + i];
    local listing2 = data[page2 * NUM_AUCTION_ITEMS_PER_PAGE + i];
    if listing1 == nil or listing2 == nil or
       not self:MatchListing(listing1.name, listing1, listing2) then
      return false;
    end
  end

  return true;
end

-- Get the names of all my auctions.
function AuctionLite:GetMyAuctionLinks()
  local batch = GetNumAuctionItems("owner");
  local links = {};

  -- Find all the auctions to cancel.
  local i;
  for i = 1, batch do
    local listing = self:GetListing("owner", i);
    links[listing.link] = true;
  end

  return links;
end

-- Sort the columns by the designated sort type.
function AuctionLite:ApplySort(info, data, cmp)
  local fn = function(a, b)
    if cmp(a, b) == cmp(b, a) then
      if info.justFlipped then
        return a.orig < b.orig;
      else
        return b.orig < a.orig;
      end
    else
      if info.flipped then
        return cmp(b, a);
      else
        return cmp(a, b);
      end
    end
  end

  local i = 1;

  local item;
  for _, item in ipairs(data) do
    item.orig = i;
    i = i + 1;
  end

  table.sort(data, fn);

  local item;
  for _, item in ipairs(data) do
    item.orig = nil;
  end

  info.sorted = true;
  info.justFlipped = false;
end

-- Update the current sort for a click.
function AuctionLite:SortButton_OnClick(info, sort)
  if info.sort == sort then
    info.flipped = not info.flipped;
  else
    info.sort = sort;
    info.flipped = false;
    info.justFlipped = true;
  end

  info.sorted = false;
end

-- Update sortable header buttons.
function AuctionLite:UpdateSortButton(prefix, buttonName, text)
  local button = _G[prefix .. buttonName .. "Button"];
  local arrow = _G[prefix .. buttonName .. "ButtonArrow"];
  button:SetText(text);
  local offset = button:GetTextWidth();
  if offset > button:GetWidth() - 10 then
    offset = button:GetWidth() - 10;
  end
  arrow:SetPoint("RIGHT", button, "RIGHT", -offset - 1, -1);
end

-- Update sort arrows.
function AuctionLite:UpdateSortArrow(prefix, buttonSort, sort, flipped)
  local arrow = _G[prefix .. buttonSort .. "ButtonArrow"];
  if buttonSort == sort then
    arrow:Show();
    if flipped then
			arrow:SetTexCoord(0, 0.5625, 1.0, 0);
		else
		  arrow:SetTexCoord(0, 0.5625, 0, 1.0);
    end
  else
    arrow:Hide();
  end
end
