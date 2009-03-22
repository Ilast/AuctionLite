-------------------------------------------------------------------------------
-- External.lua
--
-- Implement external API.
-------------------------------------------------------------------------------

-- External interface for vendor values.
-- Based on Tekkub's GetSellValue sample on WowWiki.
function AuctionLite:GetVendorValue(arg1)
  -- If we got a number, a string, or a link, get the item id.
  local id =
    (type(arg1) == "number" and arg1) or
    (type(arg1) == "string" and tonumber(arg1:match("item:(%d+)")));

  -- Convert item name to itemid.
  -- Only works if the player has the item in his bags.
  if not id and type(arg1) == "string" then
    local _, link = GetItemInfo(arg1);
    id = link and tonumber(link:match("item:(%d+)")) ;
  end

  return id and self.VendorData[id];
end

-- Implement Tekkub's GetSellValue.
local origGetSellValue = GetSellValue;
function GetSellValue(item)
  return AuctionLite:GetVendorValue(item) or
         (origGetSellValue and origGetSellValue(item));
end

-- External interface for auction values.
function AuctionLite:GetAuctionValue(arg1, arg2)
  local result = nil;

  -- If we got a number, use it.
  -- If we got a string or a link, parse it.
  local id;
  local suffix;
  if type(arg1) == "number" then
    id = arg1;
    suffix = arg2;
    if suffix == nil then
      suffix = 0;
    end
  elseif type(arg1) == "string" then
    _, _, id, suffix = self:SplitLink(arg1);
  end

  -- Now look up the price.
  if id ~= nil then
    local hist = self:GetHistoricalPriceById(id, suffix);
    if hist ~= nil then
      result = math.floor(hist.price);
    end
  end

  return result;
end

-- Implement Tekkub's GetAuctionBuyout.
local origGetAuctionBuyout = GetAuctionBuyout;
function GetAuctionBuyout(item)
  return AuctionLite:GetAuctionValue(item) or
         (origGetAuctionBuyout and origGetAuctionBuyout(item));
end
