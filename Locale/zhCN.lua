﻿local L = LibStub("AceLocale-3.0"):NewLocale("AuctionLite", "zhCN", false);

if L then

L["Advanced"] = "高级"
L["Always"] = "总是"
L["Amount to multiply by vendor price to get default sell price."] = "默认售价等于商人出售乘以你设置的倍数。"
L["Approve"] = "核准"
L["Auction"] = "拍卖"
L["Auction creation is already in progress."] = "正在发布拍卖中。"
L["AuctionLite"] = "AuctionLite"
-- L["AuctionLite Buy"] = ""
L["AuctionLite - Buy"] = "AuctionLite - 购买"
-- L["AuctionLite Sell"] = ""
L["AuctionLite - Sell"] = "AuctionLite - 出售"
L["AuctionLite v%s loaded!"] = "AuctionLite v%s 已经载入！"
-- L["Batch %d: %d at %s"] = ""
-- L["Bid cost for %d:"] = ""
-- L["Bid on %dx %s (%d |4listing:listings; at %s)."] = ""
L["Bid Per Item"] = "竞标价/件"
L["Bid Total"] = "竞标价"
L["Bid Undercut"] = "竞标削价"
-- L["Bought %dx %s (%d |4listing:listings; at %s)."] = ""
L["Buyout cannot be less than starting bid."] = "一口价不能低于竞标价。"
-- L["Buyout cost for %d:"] = ""
L["Buyout Per Item"] = "一口价/件"
L["Buyout Price"] = "一口价"
L["Buyout Total"] = "一口价"
L["Buyout Undercut"] = "一口价削价"
L["Buy Tab"] = "购买标签"
L["Cancel"] = "取消"
-- L["Cancelled %d listings of %s"] = ""
-- L["|cff00ff00Scanned %d listings.|r"] = ""
L["|cff00ff00Using previous price.|r"] = "|cff00ff00使用之前的价格。|r"
L["|cff808080(per item)|r"] = "|cff808080(每件)|r"
L["|cff808080(per stack)|r"] = "|cff808080(每组)|r"
-- L["|cff8080ffData for %s x%d|r"] = ""
L["|cffff0000Buyout less than bid.|r"] = "|cffff0000一口价低于竞标价。|r"
L["|cffff0000Buyout less than vendor price.|r"] = "|cffff0000一口价低于商人售价。|r"
L["|cffff0000[Error]|r Insufficient funds."] = "|cffff0000[错误]|r 资金不足。"
L["|cffff0000Invalid stack size/count.|r"] = "|cffff0000无效的堆叠数。|r"
L["|cffff0000No bid price set.|r"] = "|cffff0000没有设置竞标价。|r"
L["|cffff0000Not enough cash for deposit.|r"] = "|cffff0000没有足够的现金。|r"
L["|cffff0000Not enough items available.|r"] = "|cffff0000没有足够的物品。|r"
-- L["|cffff0000Using %.3gx vendor price.|r"] = ""
L["|cffff0000[Warning]|r Skipping your own auctions.  You might want to cancel them instead."] = "|cffff0000[警告]|r 跳过你自己的拍卖。  也许你打算取消掉他们。"
-- L["|cffff7030Stack %d will have %d |4item:items;.|r"] = ""
L["|cffffd000Using historical data.|r"] = "|cffffd000使用历史数据。|r" -- Needs review
L["|cffffff00Scanning: %d%%|r"] = "|cffffff00搜索中：%d%%|r"
L["Choose which tab is selected when opening the auction house."] = "选择打开拍卖行时显示的标签。"
L["Competing Auctions"] = "相抵触的拍卖"
L["Configure"] = "设置"
L["Configure AuctionLite"] = "设置AuctionLite"
-- L["Consider resale value of excess items when filling an order on the \"Buy\" tab."] = ""
-- L["Consider Resale Value When Buying"] = ""
-- L["Created %d |4auction:auctions; of %s x%d."] = ""
-- L["Current: %s (%.2fx historical)"] = ""
-- L["Current: %s (%.2fx historical, %.2fx vendor)"] = ""
-- L["Current: %s (%.2fx vendor)"] = ""
L["Deals must be below the historical price by this much gold."] = "必须比历史价格低这么多金" -- Needs review
L["Deals must be below the historical price by this percentage."] = "必须比历史价格低这么多百分率" -- Needs review
L["Default"] = "默认"
-- L["Default Number of Stacks"] = ""
-- L["Default Stack Size"] = ""
-- L["%dh"] = ""
L["Disable"] = "禁用"
L["Disenchant"] = "分解"
L["Enable"] = "启用"
L["Enter item name and click \"Search\""] = "输入物品名称并点击“搜索”"
L["Error locating item in bags.  Please try again!"] = "在背包中定位物品错误，请重试！"
L["Error when creating auctions."] = "发布拍卖时出现错误。"
L["Fast Auction Scan"] = "快速扫描"
L["Fast auction scan disabled."] = "快速扫描已停用。"
L["Fast auction scan enabled."] = "快速扫描已启用。"
L["FAST_SCAN_AD"] = [=[快速扫描功能将在几秒钟之内扫描拍卖行。
但是，快速扫描可能会引起掉线问题。如果发生了掉线，请关闭快速扫描。
启用快速扫描？]=]
L["Full Scan"] = "完整扫描"
-- L["Full Stack"] = ""
L["Historical Price"] = "历史价格"
L["Historical price for %d:"] = "%d的历史价格："
-- L["Historical: %s (%d |4listing:listings;/scan, %d |4item:items;/scan)"] = ""
L["If Applicable"] = "如果可用"
L["Invalid starting bid."] = "无效的竞标价。"
L["Item"] = "物品"
L["Items"] = "物品"
L["Item Summary"] = "物品摘要"
L["Last Used Tab"] = "最后使用的标签"
L["Listings"] = "列表"
L["Market Price"] = "市场价"
-- L["Max Stacks"] = ""
-- L["Max Stacks + Excess"] = ""
L["Minimum Profit (Gold)"] = "最小利润（金）"
L["Minimum Profit (Pct)"] = "最小利润（百分率）"
L["Name"] = "名称"
-- L["Net cost for %d:"] = ""
L["Never"] = "从不"
-- L["No current auctions"] = ""
-- L["No deals found"] = ""
L["No items found"] = "未找到物品"
-- L["Note: %d |4listing:listings; of %d |4item was:items were; not purchased."] = ""
L["Not enough cash for deposit."] = "没有足够的金币。"
L["Not enough items available."] = "没有足够的物品。"
L["Number of Items"] = "物品数量"
-- L["Number of Items |cff808080(max %d)|r"] = ""
-- L["Number of stacks suggested when an item is first placed in the \"Sell\" tab."] = ""
-- L["One Item"] = ""
-- L["One Stack"] = ""
L["Open All Bags at AH"] = "打开所有背包"
L["Open all your bags when you visit the auction house."] = "当你打开拍卖行时自动打开所有背包。"
L["Open configuration dialog"] = "打开设置界面"
L["Percent to undercut market value for bid prices (0-100)."] = "将市场价削价后作为竞标价的百分比（0-100）。"
L["Percent to undercut market value for buyout prices (0-100)."] = "将市场价削价后作为一口价的百分比（0-100）。"
L["per item"] = "每件" -- Needs review
L["per stack"] = "每堆"
L["Potential Profit"] = "盈利潜力"
L["Pricing Method"] = "价格模式"
L["Print Detailed Price Data"] = "显示详细的价格数据"
L["Print detailed price data when selling an item."] = "当出售某物品时，显示详细的价格数据。"
L["Profiles"] = "配置"
L["Qty"] = "数量"
-- L["Resell %d:"] = ""
L["Round all prices to this granularity, or zero to disable (0-1)."] = "将所有物价限制在这个范围内，0为关闭该功能（0-1）。"
L["Round Prices"] = "价格范围"
-- L["Scan complete.  Try again later to find deals!"] = ""
L["Scanning:"] = "扫描中："
L["Scanning..."] = "扫描中……"
L["Search"] = "搜索"
L["Searching:"] = "搜索中："
-- L["Selected Stack Size"] = ""
L["Sell Tab"] = "出售标签"
L["Show auction house value in tooltips."] = "在鼠标提示中显示拍卖行价格。"
L["Show Auction Value"] = "显示拍卖行价格"
L["Show Deals"] = "显示交易" -- Needs review
L["Show Disenchant Value"] = "显示附魔等级"
L["Show expected disenchant value in tooltips."] = "显示分解该物品所需的附魔技能等级。"
L["Show Favorites"] = "显示收藏夹"
L["Show Full Stack Price"] = "堆叠价格"
L["Show full stack prices in tooltips (shift toggles on the fly)."] = "显示堆叠价格。"
L["Show My Auctions"] = "显示我的拍卖"
L["Show Vendor Price"] = "显示商人价格"
L["Show vendor sell price in tooltips."] = "在鼠标提示中显示商人的价格。"
-- L["Stack size suggested when an item is first placed in the \"Sell\" tab."] = ""
L["stacks of"] = "堆叠"
L["Start Tab"] = "初始标签"
L["Time Elapsed:"] = "花费时间："
L["Time Remaining:"] = "剩余时间："
L["Tooltips"] = "鼠标提示"
L["Use Coin Icons in Tooltips"] = "显示钱币图标"
L["Use fast method for full scans (may cause disconnects)."] = "使用快速模式扫描拍卖行（可能会引起掉线）。"
L["Uses the standard gold/silver/copper icons in tooltips."] = "在鼠标提示中使用图标代替 金、银、铜字样。"
L["Vendor"] = "商人"
L["Vendor Multiplier"] = "商人倍数" -- Needs review
L["Vendor: %s"] = "商人：%s"

end
