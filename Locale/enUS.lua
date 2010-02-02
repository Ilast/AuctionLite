local L = LibStub("AceLocale-3.0"):NewLocale("AuctionLite", "enUS", true);

if L then

-- AuctionLite.lua

L["AuctionLite v%s loaded!"] = true;

-- Config.lua

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
L["On the summary view, show how many listings/items are yours."] = true;
L["Show How Many Listings are Mine"] = true;
L["Store price data for all items seen (disable to save memory)."] = true;
L["Store Price Data"] = true;
L["Clear all auction house price data."] = true;
L["Clear All Data"] = true;
L["Open all your bags when you visit the auction house."] = true;
L["Open All Bags at AH"] = true;
L["Consider resale value of excess items when filling an order on the \"Buy\" tab."] = true;
L["Consider Resale Value When Buying"] = true;
L["Print detailed price data when selling an item."] = true;
L["Print Detailed Price Data"] = true;
L["Choose which tab is selected when opening the auction house."] = true;
L["Start Tab"] = true;
L["Number of stacks suggested when an item is first placed in the \"Sell\" tab."] = true;
L["Default Number of Stacks"] = true;
L["One Stack"] = true;
L["Max Stacks"] = true;
L["Max Stacks + Excess"] = true;
L["Stack size suggested when an item is first placed in the \"Sell\" tab."] = true;
L["Default Stack Size"] = true;
L["One Item"] = true;
L["Selected Stack Size"] = true;
L["Full Stack"] = true;
L["AuctionLite Buy"] = true;
L["AuctionLite Sell"] = true;
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
L["Select a Favorites List"] = true;
L["Choose a favorites list to edit."] = true;
L["New..."] = true;
L["Create a new favorites list."] = true;
L["Delete"] = true;
L["Delete the selected favorites list."] = true;
L["Add an Item"] = true;
L["Add a new item to a favorites list by entering the name here."] = true;
L["Remove Items"] = true;
L["Remove the selected items from the current favorites list."] = true;
L["Open configuration dialog"] = true;
L["Configure"] = true;
L["Default"] = true;
L["Buy Tab"] = true;
L["Sell Tab"] = true;
L["Last Used Tab"] = true;
L["Always"] = true;
L["If Applicable"] = true;
L["Never"] = true;
L["Enter the name of the new favorites list:"] = true;
L["Accept"] = true;
L["Cancel"] = true;
L["Favorites"] = true;
L["Tooltips"] = true;
L["Profiles"] = true;
L["AuctionLite"] = true;

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
L["CANCEL_TOOLTIP"] =
  "|cffffffffClick:|r Cancel all auctions\n" ..
  "|cffffffffCtrl-Click:|r Cancel undercut auctions";
L["Enable"] = true;
L["Disable"] = true;
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
L["Member Of"] = true;
L["Cancel Undercut Auctions"] = true;
L["Cancel All Auctions"] = true;
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

L["CANCEL_CONFIRM_TEXT"] =
  "Some of your auctions have bids on them.  Do you want to cancel " ..
  "all auctions, cancel only those with no bids, or do nothing?";
L["Cancel All"] = true;
L["Cancel Unbid"] = true;
L["Do Nothing"] = true;
L["Cancelled %d |4listing:listings; of %s."] = true;
L["Error locating item in bags.  Please try again!"] = true;
L["Invalid starting bid."] = true;
L["Buyout cannot be less than starting bid."] = true;
L["Not enough cash for deposit."] = true;
L["Not enough items available."] = true;
L["Stack size too large."] = true;
L["Error when creating auctions."] = true;
L["Need an empty bag slot to create auctions."] = true;
L["Created %d |4auction:auctions; of %s x%d (%s total)."] = true;
L["Auction creation is already in progress."] = true;

-- History.lua


L["CLEAR_DATA_WARNING"] =
  "Do you really want to delete all auction house " ..
  "price data gathered by AuctionLite?";
L["Do it!"] = true;
L["Auction house data cleared."] = true;

-- QueryAuctions.lua

L["|cffffd000[Note]|r " ..
  "Fast auction scans can only be used once every " ..
  "15 minutes. Using a slow scan for now."] = true;
L["Bought %dx %s (%d |4listing:listings; at %s)."] = true;
L["Bid on %dx %s (%d |4listing:listings; at %s)."] = true;
L["Note: %d |4listing:listings; of %d |4item was:items were; not purchased."] = true;

-- SellFrame.lua

L["VENDOR_WARNING"] =
  "Your buyout price is below the vendor price.  " ..
  "Do you still want to create this auction?";
L["|cff8080ffData for %s x%d|r"] = true;
L["Vendor: %s"] = true;
L["Historical: %s (%d |4listing:listings;/scan, %d |4item:items;/scan)"] = true;
L["Current: %s (%.2fx historical, %.2fx vendor)"] = true;
L["Current: %s (%.2fx historical)"] = true;
L["Current: %s (%.2fx vendor)"] = true;
L["|cffff0000Invalid stack size/count.|r"] = true;
L["|cffff0000Not enough items available.|r"] = true;
L["|cffff0000Stack size too large.|r"] = true;
L["|cffff0000No bid price set.|r"] = true;
L["|cffff0000Buyout less than bid.|r"] = true;
L["|cffff0000Not enough cash for deposit.|r"] = true;
L["|cffff7030Buyout less than vendor price.|r"] = true;
L["|cffff7030Stack %d will have %d |4item:items;.|r"] = true;
L["|cff00ff00Scanned %d listings.|r"] = true;
L["|cffffd000Using historical data.|r"] = true;
L["|cffff0000Using %.3gx vendor price.|r"] = true;
L["|cff00ff00Using previous price.|r"] = true;
L["|cff808080(per item)|r"] = true;
L["|cff808080(per stack)|r"] = true;
L["|cffffff00Scanning: %d%%|r"] = true;
L["AuctionLite - Sell"] = true;
L["Number of Items |cff808080(max %d)|r"] = true;
L["Number of Items"] = true;
L["stacks of"] = true;
L["Pricing Method"] = true;
L["Competing Auctions"] = true;
L["per item"] = true;
L["per stack"] = true;
L["%dh"] = true;
L["Saved Item Settings"] = true;
L["(none set)"] = true;
L["Stack Count"] = true;
L["Stack Size"] = true;
L["Bid Price"] = true;
L["Buyout Price"] = true;
L["Save All"] = true;
L["Clear All"] = true;

-- Tooltip.lua

L["Vendor"] = true;
L["Disenchant"] = true;
L["Auction"] = true;

end
