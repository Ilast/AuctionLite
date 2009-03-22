local L = LibStub("AceLocale-3.0"):NewLocale("AuctionLite", "enUS", true);

if L then

-- Helper functions.

local function money(price)
  return AuctionLite:PrintMoney(price);
end

local function plural(count, name)
  local base = tostring(count) .. " " .. name;
  if count ~= 1 then
    base = base .. "s";
  end
  return base;
end

-- AuctionLite.lua

L["Percent to undercut market value for bid prices (0-100)."] = true;
L["Bid Undercut"] = true;
L["Percent to undercut market value for buyout prices (0-100)."] = true;
L["Buyout Undercut"] = true;
L["Amount to multiply by vendor price to get default sell price."] = true;
L["Vendor Multiplier"] = true;
L["Round all prices to this granularity, or zero to disable (0-1)."] = true;
L["Round Prices"] = true;
L["Deals must be below the historical price by this much gold."] = true;
L["Minimum Profit (Gold)"] = true;
L["Deals must be below the historical price by this percentage."] = true;
L["Minimum Profit (Pct)"] = true;
L["Use fast method for full scans (may cause disconnects)."] = true;
L["Fast Auction Scan"] = true;
L["Open all your bags when you visit the auction house."] = true;
L["Open All Bags at AH"] = true;
L["Print detailed price data when selling an item."] = true;
L["Print Detailed Price Data"] = true;
L["Choose which tab is selected when opening the auction house."] = true;
L["Start Tab"] = true;
L["Show vendor sell price in tooltips."] = true;
L["Show Vendor Price"] = true;
L["Show expected disenchant value in tooltips."] = true;
L["Show Disenchant Value"] = true;
L["Show auction house value in tooltips."] = true;
L["Show Auction Value"] = true;
L["Uses the standard gold/silver/copper icons in tooltips."] = true;
L["Use Coin Icons in Tooltips"] = true;
L["Show full stack prices in tooltips (shift toggles on the fly)."] = true;
L["Show Full Stack Price"] = true;
L["Open configuration dialog"] = true;
L["Configure"] = true;
L["Always"] = true;
L["If Applicable"] = true;
L["Never"] = true;
L["Tooltips"] = true;
L["Profiles"] = true;
L["AuctionLite"] = true;
L["AuctionLite vX loaded!"] = function(version)
  return "AuctionLite v" .. version .. " loaded!"
end

-- BuyFrame.lua

L["FAST_SCAN_AD"] =
  "AuctionLite's fast auction scan can scan the entire auction " ..
  "house in a few seconds." ..
  "\n\n" ..
  "However, depending on your connection, a fast scan can cause " ..
  "you to be disconnected from the server.  If this happens, you " ..
  "can disable fast scanning on the AuctionLite options screen." ..
  "\n\n" ..
  "Enable fast auction scans?";
L["Fast auction scan enabled."] = true;
L["Fast auction scan disabled."] = true;
L["|cffff0000[Error]|r Insufficient funds."] = true;
L["|cffff0000[Warning]|r Skipping your own auctions.  " ..
  "You might want to cancel them instead."] = true;
L["Scanning..."] = true;
L["Scanning:"] = true;
L["Searching:"] = true;
L["Bid/buyout cost for X:"] = function(isBuyout, count)
  local action;
  if isBuyout then
    action = "Buyout";
  else
    action = "Bid";
  end
  return action .. " cost for " .. count .. ":";
end
L["Historical price for X:"] = function(count)
  return "Historical price for " .. count .. ":";
end
L["Resell X:"] = function(count)
  return "Resell " .. count .. ":";
end
L["Net cost for X:"] = function(count)
  return "Net cost for " .. count .. ":";
end
L["Historical price for X:"] = function(count)
  return "Historical price for " .. count .. ":";
end
L["Batch X: Y at Z"] = function(batch, count, price)
  return "Batch " .. batch .. ": " .. count .. " at " .. money(price);
end
L["Potential Profit"] = true;
L["Historical Price"] = true;
L["Show Deals"] = true;
L["Show Favorites"] = true;
L["Show My Auctions"] = true;
L["Configure AuctionLite"] = true;
L["AuctionLite - Buy"] = true;
L["Name"] = true;
L["Qty"] = true;
L["Enter item name and click \"Search\""] = true;
L["No items found"] = true;
L["Searching:"] = true;
L["Time Elapsed:"] = true;
L["Time Remaining:"] = true;
L["Approve"] = true;
L["Cancel"] = true;
L["Item Summary"] = true;
L["Historical Price"] = true;
L["Market Price"] = true;
L["Item"] = true;
L["Items"] = true;
L["Listings"] = true;
L["Buyout Total"] = true;
L["Buyout Per Item"] = true;
L["Bid Total"] = true;
L["Bid Per Item"] = true;
L["Advanced"] = true;
L["Full Scan"] = true;
L["Search"] = true;

-- CancelAuctions.lua

L["Cancelled X listings of Y"] = function(listings, name)
  return "Cancelled " .. listings .. " of " .. name;
end
L["Error locating item in bags.  Please try again!"] = true;
L["Invalid starting bid."] = true;
L["Buyout cannot be less than starting bid."] = true;
L["Not enough cash for deposit."] = true;
L["Not enough items available."] = true;
L["Error when creating auctions."] = true;
L["Need an empty bag slot to create auctions."] = true;
L["Created X auctions of Y xZ."] = function(count, name, size)
  return "Created " .. plural(count, "auction") ..
         " of " ..  name .. " x" ..  size;
end
L["Auction creation is already in progress."] = true;

-- QueryAuctions.lua

L["|cffffd000[Note]|r " ..
  "Fast auction scans can only be used once every " ..
  "15 minutes. Using a slow scan for now."] = true;
L["Bought/bid on Xx Y (Z listings at W)."] =
function(isBuyout, items, name, listings, price)
  local action;
  if isBuyout then
    action = "Bought ";
  else
    action = "Bid on ";
  end
  return action .. items .. "x " .. name ..
         " (" .. plural(listings, "listing") ..
         " at " .. money(price) ..  ").";
end
L["Note: X listings of Y items was/were not purchased."] =
function(listings, items)
  local verb;
  if listingsNotFound == 1 then
    verb = "was";
  else
    verb = "were";
  end
  return "Note: " .. plural(listings, "listing") .. " of " ..
         plural(items, "item") .. " " .. verb .. " not purchased.";
end

-- SellFrame.lua

L["|cff8080ffData for X xY|r"] = function(link, size)
  return "|cff8080ffData for " .. link .. " x" .. size .. "|r";
end
L["Vendor: X"] =function(price)
  return "Vendor: " .. money(price);
end
L["Historical: X (Y listings/scan, Z items/scan)"] =
function(price, listings, items)
  return "Historical: " .. money(price) ..  " (" ..
          plural(listings, "listing") .. "/scan, " ..
          plural(items, "item") .. "/scan)";
end
L["Current: X (Yx historical, Zx vendor)"] =
function(price, hist, vendor)
  return "Current: " .. money(price) ..  " (" ..
          hist .. "x historical, " ..  vendor .. "x vendor)";
end
L["Current: X (Yx historical)"] =
function(price, hist)
  return "Current: " .. money(price) ..  " (" ..  hist .. "x historical)";
end
L["Current: X (Yx vendor)"] =
function(price, vendor)
  return "Current: " .. money(price) ..  " (" ..  vendor .. "x vendor)";
end
L["|cffff0000Invalid stack size/count.|r"] = true;
L["|cffff0000Not enough items available.|r"] = true;
L["|cffff0000No bid price set.|r"] = true;
L["|cffff0000Buyout less than bid.|r"] = true;
L["|cffff0000Not enough cash for deposit.|r"] = true;
L["|cffff0000Buyout less than vendor price.|r"] = true;
L["|cff00ff00Scanned X listings.|r"] = function(listings)
  return "|cff00ff00Scanned " .. plural(listings, "listing") .. ".|r";
end
L["|cffff0000Using historical data.|r"] = true;
L["|cffff0000Using Xx vendor price.|r"] = function(mult)
  return "|cffff0000Using " .. mult .. "x vendor price.|r";
end
L["|cff00ff00Using previous price.|r"] = true;
L["|cff808080(per item)|r"] = true;
L["|cff808080(per stack)|r"] = true;
L["|cffffff00Scanning: X%|r"] = function(pct)
  return "|cffffff00Scanning: " .. pct .. "%|r";
end
L["AuctionLite - Sell"] = true;
L["Number of Items |cff808080(max X)|r"] = function(total)
  return "Number of Items |cff808080(max " .. total .. ")|r";
end
L["Number of Items"] = true;
L["stacks of"] = true;
L["Buyout Price"] = true;
L["Pricing Method"] = true;
L["Competing Auctions"] = true;

-- Tooltip.lua

L["Vendor"] = true;
L["Disenchant"] = true;
L["Auction"] = true;

end
