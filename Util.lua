-------------------------------------------------------------------------------
-- Util.lua
--
-- General utility functions.
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

-- Retrieve the item id and suffix id from an item link.
function AuctionLite:SplitLink(link)
  local _, _, str, name = link:find("|H(.*)|h%[(.*)%]");
  local _, id, enchant, jewel1, jewel2, jewel3, jewel4, suffix, unique =
        strsplit(":", str);
  return name, tonumber(id), tonumber(suffix);
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
