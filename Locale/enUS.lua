local L = LibStub("AceLocale-3.0"):NewLocale("AuctionLite", "enUS", true);

if L then

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
L["AuctionLite v%s loaded!"] = true;

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
L["Bid cost for %d:"] = true;
L["Buyout cost for %d:"] = true;
L["Historical price for %d:"] = true;
L["Resell %d:"] = true;
L["Net cost for %d:"] = true;
L["Batch %d: %d at %s"] = true;
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
L["Scan complete.  Try again later to find deals!"] = true;
L["No deals found"] = true;
L["No current auctions"] = true;
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

L["Cancelled %d listings of %s"] = true;
L["Error locating item in bags.  Please try again!"] = true;
L["Invalid starting bid."] = true;
L["Buyout cannot be less than starting bid."] = true;
L["Not enough cash for deposit."] = true;
L["Not enough items available."] = true;
L["Error when creating auctions."] = true;
L["Need an empty bag slot to create auctions."] = true;
L["Created %d |4auction:auctions; of %s x%d."] = true;
L["Auction creation is already in progress."] = true;

-- QueryAuctions.lua

L["|cffffd000[Note]|r " ..
  "Fast auction scans can only be used once every " ..
  "15 minutes. Using a slow scan for now."] = true;
L["Bought %dx %s (%d |4listing:listings; at %s)."] = true;
L["Bid on %dx %s (%d |4listing:listings; at %s)."] = true;
L["Note: %d |4listing:listings; of %d |4item was:items were; not purchased."] = true;

-- SellFrame.lua

L["|cff8080ffData for %s x%d|r"] = true;
L["Vendor: %s"] = true;
L["Historical: %s (%d |4listing:listings;/scan, %d |4item:items;/scan)"] = true;
L["Current: %s (%.2gx historical, %.2gx vendor)"] = true;
L["Current: %s (%.2gx historical)"] = true;
L["Current: %s (%.2gx vendor)"] = true;
L["|cffff0000Invalid stack size/count.|r"] = true;
L["|cffff0000Not enough items available.|r"] = true;
L["|cffff0000No bid price set.|r"] = true;
L["|cffff0000Buyout less than bid.|r"] = true;
L["|cffff0000Not enough cash for deposit.|r"] = true;
L["|cffff0000Buyout less than vendor price.|r"] = true;
L["|cff00ff00Scanned %d listings.|r"] = true;
L["|cffffd000Using historical data.|r"] = true;
L["|cffff0000Using %.1gx vendor price.|r"] = true;
L["|cff00ff00Using previous price.|r"] = true;
L["|cff808080(per item)|r"] = true;
L["|cff808080(per stack)|r"] = true;
L["|cffffff00Scanning: %d%%|r"] = true;
L["AuctionLite - Sell"] = true;
L["Number of Items |cff808080(max %d)|r"] = true;
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
