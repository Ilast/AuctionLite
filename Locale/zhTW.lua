﻿local L = LibStub("AceLocale-3.0"):NewLocale("AuctionLite", "zhTW", false);

if L then

L["Advanced"] = "進階"
L["Always"] = "總是"
L["Amount to multiply by vendor price to get default sell price."] = "預設售價等於商人出售乘以你設定的倍數。"
L["Approve"] = "允許"
L["Auction"] = "拍賣"
L["Auction creation is already in progress."] = "正在發佈拍賣中。"
L["AuctionLite"] = "AuctionLite"
L["AuctionLite Buy"] = "AuctionLite 購買"
L["AuctionLite - Buy"] = "AuctionLite - 購買"
L["AuctionLite Sell"] = "AuctionLite 出售"
L["AuctionLite - Sell"] = "AuctionLite - 出售"
L["AuctionLite v%s loaded!"] = "AuctionLite v%s 已載入!"
L["Batch %d: %d at %s"] = "批量 %d: %d 在 %s"
L["Bid cost for %d:"] = "競標價花費 %d:"
L["Bid on %dx %s (%d |4listing:listings; at %s)."] = "競標價在 %dx %s (%d |4項:項; 在 %s)."
L["Bid Per Item"] = "競標價/件"
L["Bid Total"] = "競標價"
L["Bid Undercut"] = "競標削價"
L["Bought %dx %s (%d |4listing:listings; at %s)."] = "購買 %dx %s (%d |4項:項; 在 %s)."
L["Buyout cannot be less than starting bid."] = "直購價不能低於競標價。"
L["Buyout cost for %d:"] = "全部買下花費 %d:"
L["Buyout Per Item"] = "直購價/件"
L["Buyout Price"] = "直購價"
L["Buyout Total"] = "直購價"
L["Buyout Undercut"] = "直購價削價"
L["Buy Tab"] = "購買標籤"
L["Cancel"] = "取消"
L["Cancelled %d listings of %s"] = "取消 %d 在 %s 項"
L["|cff00ff00Scanned %d listings.|r"] = "|cff00ff00搜尋到 %d 項.|r"
L["|cff00ff00Using previous price.|r"] = "|cff00ff00使用之前的價格。|r"
L["|cff808080(per item)|r"] = "|cff808080(每件)|r"
L["|cff808080(per stack)|r"] = "|cff808080(每組)|r"
L["|cff8080ffData for %s x%d|r"] = "|cff8080ff數據: %s x%d|r"
L["|cffff0000Buyout less than bid.|r"] = "|cffff0000直購價低於競標價。|r"
L["|cffff0000Buyout less than vendor price.|r"] = "|cffff0000直購價低於商人售價。|r"
L["|cffff0000[Error]|r Insufficient funds."] = "|cffff0000[錯誤]|r 資金不足。"
L["|cffff0000Invalid stack size/count.|r"] = "|cffff0000無效的堆疊數。|r"
L["|cffff0000No bid price set.|r"] = "|cffff0000沒有設定競標價。|r"
L["|cffff0000Not enough cash for deposit.|r"] = "|cffff0000沒有足夠的現金。|r"
L["|cffff0000Not enough items available.|r"] = "|cffff0000沒有足夠的物品。|r"
L["|cffff0000Using %.3gx vendor price.|r"] = "|cffff0000使用 %.3gx 商店價格.|r"
L["|cffff0000[Warning]|r Skipping your own auctions.  You might want to cancel them instead."] = "|cffff0000[警告]|r 跳過你自己的拍賣。  也許你打算取消掉他們。"
L["|cffff7030Stack %d will have %d |4item:items;.|r"] = "|cffff7030堆疊 %d 將有 %d |4物品:物品;.|r"
L["|cffffd000Using historical data.|r"] = "|cffffd000使用歷史資料。|r"
L["|cffffff00Scanning: %d%%|r"] = "|cffffff00正在掃描: %d%%|r"
L["Choose which tab is selected when opening the auction house."] = "選擇打開拍賣行時顯示的標籤。"
L["Competing Auctions"] = "相抵觸的拍賣"
L["Configure"] = "設定"
L["Configure AuctionLite"] = "設定AuctionLite"
L["Consider resale value of excess items when filling an order on the \"Buy\" tab."] = "考慮轉售價值過剩的物品在在\"購買\"標籤上填寫訂單時。"
L["Consider Resale Value When Buying"] = "購買時考慮轉售價值"
L["Created %d |4auction:auctions; of %s x%d."] = "新增 %d |4拍賣:拍賣; : %s x%d."
L["Current: %s (%.2fx historical)"] = "目前:%s(%.2fx 歷史)"
L["Current: %s (%.2fx historical, %.2fx vendor)"] = "目前:%s(%.2fx 歷史,%.2fx 商店)"
L["Current: %s (%.2fx vendor)"] = "目前: %s (%.2fx 商店)"
L["Deals must be below the historical price by this much gold."] = "必須比歷史價格低這麼多金"
L["Deals must be below the historical price by this percentage."] = "必須比歷史價格低這麼多百分率"
L["Default"] = "預設"
L["Default Number of Stacks"] = "預設堆疊數目"
L["Default Stack Size"] = "預設堆疊大小"
L["%dh"] = "%d小時"
L["Disable"] = "禁用"
L["Disenchant"] = "分解"
L["Enable"] = "啟用"
L["Enter item name and click \"Search\""] = "輸入物品名稱並點擊\"搜索\""
L["Error locating item in bags.  Please try again!"] = "在背包中定位物品錯誤，請重試!"
L["Error when creating auctions."] = "發佈拍賣時出現錯誤。"
L["Fast Auction Scan"] = "快速掃描"
L["Fast auction scan disabled."] = "快速掃描已停用。"
L["Fast auction scan enabled."] = "快速掃描已啟用。"
L["FAST_SCAN_AD"] = [=[快速掃描功能將在幾秒鐘之內掃描拍賣行。
但是，快速掃描可能會引起斷線問題。如果發生了斷線，請關閉快速掃描。
啟用快速掃描？]=]
L["Full Scan"] = "完整掃描"
L["Full Stack"] = "完整堆疊"
L["Historical Price"] = "歷史價格"
L["Historical price for %d:"] = "歷史價格 %d:"
L["Historical: %s (%d |4listing:listings;/scan, %d |4item:items;/scan)"] = "歷史: %s (%d |4項:項;/掃描, %d |4物品:物品;/掃描)"
L["If Applicable"] = "如果可用"
L["Invalid starting bid."] = "無效的競標價。"
L["Item"] = "物品"
L["Items"] = "物品"
L["Item Summary"] = "物品摘要"
L["Last Used Tab"] = "最後使用的標籤"
L["Listings"] = "項目"
L["Market Price"] = "市場價"
L["Max Stacks"] = "最大堆疊"
L["Max Stacks + Excess"] = "最大堆疊 + 剩餘"
L["Minimum Profit (Gold)"] = "最小利潤（金）"
L["Minimum Profit (Pct)"] = "最小利潤（百分率）"
L["Name"] = "名稱"
L["Net cost for %d:"] = "%d的成本:"
L["Never"] = "從不"
L["No current auctions"] = "目前沒有拍賣"
L["No deals found"] = "沒有交易發現"
L["No items found"] = "未找到物品"
L["Note: %d |4listing:listings; of %d |4item was:items were; not purchased."] = "注意: %d |4項:項; 的 %d |4物品:物品; 沒有購買."
L["Not enough cash for deposit."] = "沒有足夠的金幣。"
L["Not enough items available."] = "沒有足夠的物品。"
L["Number of Items"] = "物品數量"
L["Number of Items |cff808080(max %d)|r"] = "物品數量 |cff808080(最大 %d)|r"
L["Number of stacks suggested when an item is first placed in the \"Sell\" tab."] = "建議堆疊數目當物品首先放置在\"出售\"標籤。"
L["One Item"] = "一件物品"
L["One Stack"] = "一堆疊"
-- L["On the summary view, show how many listings/items are yours."] = ""
L["Open All Bags at AH"] = "打開所有背包"
L["Open all your bags when you visit the auction house."] = "當你打開拍賣行時自動打開所有背包。"
L["Open configuration dialog"] = "打開設定介面"
L["Percent to undercut market value for bid prices (0-100)."] = "將市場價削價後作為競標價的百分比（0-100）。"
L["Percent to undercut market value for buyout prices (0-100)."] = "將市場價削價後作為直購價的百分比（0-100）。"
L["per item"] = "每件物品"
L["per stack"] = "堆疊"
L["Potential Profit"] = "盈利潛力"
L["Pricing Method"] = "價格模式"
L["Print Detailed Price Data"] = "顯示詳細的價格資料"
L["Print detailed price data when selling an item."] = "當出售某物品時，顯示詳細的價格資料。"
L["Profiles"] = "設定檔"
L["Qty"] = "數量"
L["Resell %d:"] = "再賣 %d:"
L["Round all prices to this granularity, or zero to disable (0-1)."] = "將所有物價限制在這個範圍內，0為關閉該功能（0-1）。"
L["Round Prices"] = "價格範圍"
L["Scan complete.  Try again later to find deals!"] = "掃描完成. 稍後再嘗試搜尋交易"
L["Scanning:"] = "掃描中："
L["Scanning..."] = "掃描中……"
L["Search"] = "搜索"
L["Searching:"] = "搜索中："
L["Selected Stack Size"] = "已選擇堆疊大小"
L["Sell Tab"] = "出售標籤"
L["Show auction house value in tooltips."] = "在滑鼠提示中顯示拍賣行價格。"
L["Show Auction Value"] = "顯示拍賣行價格"
L["Show Deals"] = "顯示交易"
L["Show Disenchant Value"] = "顯示附魔等級"
L["Show expected disenchant value in tooltips."] = "顯示分解該物品所需的附魔技能等級。"
L["Show Favorites"] = "顯示我的最愛"
L["Show Full Stack Price"] = "堆疊價格"
L["Show full stack prices in tooltips (shift toggles on the fly)."] = "顯示堆疊價格。"
-- L["Show How Many Listings are Mine"] = ""
L["Show My Auctions"] = "顯示我的拍賣"
L["Show Vendor Price"] = "顯示商人價格"
L["Show vendor sell price in tooltips."] = "在滑鼠提示中顯示商人的價格。"
L["Stack size suggested when an item is first placed in the \"Sell\" tab."] = "建議堆疊大小當物品首先放置在\"出售\"標籤。"
L["stacks of"] = "堆疊"
L["Start Tab"] = "初始標籤"
L["Time Elapsed:"] = "花費時間："
L["Time Remaining:"] = "剩餘時間："
L["Tooltips"] = "滑鼠提示"
L["Use Coin Icons in Tooltips"] = "顯示錢幣圖示"
L["Use fast method for full scans (may cause disconnects)."] = "使用快速模式掃描拍賣行（可能會引起掉線）。"
L["Uses the standard gold/silver/copper icons in tooltips."] = "在滑鼠提示中使用圖示代替 金、銀、銅字樣。"
L["Vendor"] = "商人"
L["Vendor Multiplier"] = "商人倍數"
L["Vendor: %s"] = "商人: %s"

end
