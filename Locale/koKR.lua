﻿local L = LibStub("AceLocale-3.0"):NewLocale("AuctionLite", "koKR", false);

if L then

L["Advanced"] = "추가기능"
L["Always"] = "항상 표시"
L["Amount to multiply by vendor price to get default sell price."] = "지금까지 한번도 검색되지 않은 물품을 판매할 때 상점가에 아래 설정한 값을 곱하여 등록합니다."
L["Approve"] = "확인"
L["Auction"] = "경매가"
L["Auction creation is already in progress."] = "이미 경매 생성이 진행중입니다."
L["AuctionLite"] = "경매도우미"
-- L["AuctionLite Buy"] = ""
L["AuctionLite - Buy"] = "경매도우미 - 구입"
-- L["AuctionLite Sell"] = ""
L["AuctionLite - Sell"] = "경매도우미 - 판매"
L["AuctionLite v%s loaded!"] = "경매도우미 v%s 로딩됨!"
L["Batch %d: %d at %s"] = "일괄 수행 %d: %d개일 때 %s"
L["Bid cost for %d:"] = "%d개 입찰가:"
L["Bid on %dx %s (%d |4listing:listings; at %s)."] = "[입찰]: %dx %s (총 %d건, 비용: %s)"
L["Bid Per Item"] = "개당 입찰가"
L["Bid Total"] = "입찰가 총액"
L["Bid Undercut"] = "입찰가 할인"
L["Bought %dx %s (%d |4listing:listings; at %s)."] = "[즉시 구입]: %dx %s (총 %d건, 비용: %s)"
L["Buyout cannot be less than starting bid."] = "즉시 구입가가 시작가보다 낮습니다."
L["Buyout cost for %d:"] = "%d개 즉시 구매가:"
L["Buyout Per Item"] = "개당 즉시 구입가"
L["Buyout Price"] = "즉시 구입가"
L["Buyout Total"] = "즉시 구입가 총액"
L["Buyout Undercut"] = "즉시 구입가 할인"
L["Buy Tab"] = "경매도우미 - 구입 탭"
L["Cancel"] = "취소"
L["Cancelled %d listings of %s"] = "%d 건의 %s 취소됨"
L["|cff00ff00Scanned %d listings.|r"] = "|cff00ff00%d개의 품목이 검색됨.|r"
L["|cff00ff00Using previous price.|r"] = "|cff00ff00이전 가격으로 책정합니다.|r"
L["|cff808080(per item)|r"] = "|cff808080(단가)|r"
L["|cff808080(per stack)|r"] = "|cff808080(묶음가)|r"
L["|cff8080ffData for %s x%d|r"] = "|cff8080ff%s의 가격 정보(%d개)|r"
L["|cffff0000Buyout less than bid.|r"] = "|cffff0000즉시 구입가를 경매 시작가 이상 입력하세요.|r"
L["|cffff0000Buyout less than vendor price.|r"] = "|cffff0000즉시 구입가를 상점가 이상 입력하세요.|r"
L["|cffff0000[Error]|r Insufficient funds."] = "|cffff0000[오류]|r 소지 금액이 부족합니다."
L["|cffff0000Invalid stack size/count.|r"] = "|cffff0000묶음 갯수가 올바르지 않습니다.|r"
L["|cffff0000No bid price set.|r"] = "|cffff0000경매 시작가를 입력하세요.|r"
L["|cffff0000Not enough cash for deposit.|r"] = "|cffff0000보증금이 부족합니다.|r"
L["|cffff0000Not enough items available.|r"] = "|cffff0000수량이 충분하지 않습니다.|r"
L["|cffff0000Using %.3gx vendor price.|r"] = "|cffff0000상점가의 %.3g배 가격으로 책정합니다.|r"
L["|cffff0000[Warning]|r Skipping your own auctions.  You might want to cancel them instead."] = "|cffff0000[경고]|r 자신이 등록한 경매 물품은 보여주지 않습니다. 자신이 등록한 경매 물품은 경매 취소하면 됩니다."
-- L["|cffff7030Stack %d will have %d |4item:items;.|r"] = ""
L["|cffffd000Using historical data.|r"] = "|cffffd000저장된 가격으로 책정합니다.|r"
L["|cffffff00Scanning: %d%%|r"] = "|cffffff00조사중: %d%%|r"
L["Choose which tab is selected when opening the auction house."] = "경매장을 열 때 어떤 탭에서 시작할지 선택할 수 있습니다."
L["Competing Auctions"] = "다른 플레이어가 등록한 경매 품목"
L["Configure"] = "설정"
L["Configure AuctionLite"] = "경매도우미 설정"
-- L["Consider resale value of excess items when filling an order on the \"Buy\" tab."] = ""
-- L["Consider Resale Value When Buying"] = ""
L["Created %d |4auction:auctions; of %s x%d."] = "[경매 시작]: %d건 (%sx%d)"
L["Current: %s (%.2fx historical)"] = "시세: %s (저장된 가격의 %.2f배)"
L["Current: %s (%.2fx historical, %.2fx vendor)"] = "시세: %s (저장된 가격의 %.2f배, 상점가의 %.2f배)"
L["Current: %s (%.2fx vendor)"] = "시세: %s (상점가의 %.2f배)"
L["Deals must be below the historical price by this much gold."] = "세일 품목을 저장된 가격과 비교하여 아래에서 설정한 금액 이상 이익을 볼 수 있는 품목만 표시합니다."
L["Deals must be below the historical price by this percentage."] = "세일 품목을 저장된 가격과 비교하여 아래에서 설정한 비율 이상 이익을 볼 수 있는 품목만 표시합니다."
L["Default"] = "기본 경매 탭"
-- L["Default Number of Stacks"] = ""
-- L["Default Stack Size"] = ""
L["%dh"] = "%d시간"
L["Disable"] = "사용 안 함"
L["Disenchant"] = "뽀각가"
L["Enable"] = "사용함"
L["Enter item name and click \"Search\""] = "원하는 품목명을 입력한 후 \"검색\" 버튼을 누르십시오."
L["Error locating item in bags.  Please try again!"] = "가방에 아이템을 넣을 수 없습니다. 다시 시도하세요!"
L["Error when creating auctions."] = "경매 생성중 에러가 발생했습니다."
L["Fast Auction Scan"] = "고속 검색"
L["Fast auction scan disabled."] = "고속 검색 기능을 사용하지 않습니다."
L["Fast auction scan enabled."] = "고속 검색 기능을 사용합니다."
L["FAST_SCAN_AD"] = [=[경매도우미의 고속 검색은 경매장 전체 품목을 몇 초만에 검색할 수 있습니다.

하지만 이 경우 당신의 접속상황에 따라 서버와 연결이 끊어질 수 있습니다. 만약 접속이 끊어진다면 경매도우미 설정 화면에서 고속 검색 기능을 꺼주시기 바랍니다.

고속 검색 기능을 사용하시겠습니까?]=]
L["Full Scan"] = "전체 검색"
-- L["Full Stack"] = ""
L["Historical Price"] = "저장된 가격"
L["Historical price for %d:"] = "%d개의 저장된 가격:"
L["Historical: %s (%d |4listing:listings;/scan, %d |4item:items;/scan)"] = "저장된 가격: %s (검색당 %d개의 품목, 검색당 단위수량 %d개)"
L["If Applicable"] = "해당하는 경우"
L["Invalid starting bid."] = "시작가가 올바르지 않습니다."
L["Item"] = "품목명"
L["Items"] = "전체"
L["Item Summary"] = "품목 요약"
L["Last Used Tab"] = "최근에 사용한 탭"
L["Listings"] = "품목"
L["Market Price"] = "시세"
-- L["Max Stacks"] = ""
-- L["Max Stacks + Excess"] = ""
L["Minimum Profit (Gold)"] = "최소 이익(금액)"
L["Minimum Profit (Pct)"] = "최소 이익(비율)"
L["Name"] = "품목명"
L["Net cost for %d:"] = "%d개의 최종 가격:"
L["Never"] = "표시하지 않음"
L["No current auctions"] = "등록한 경매 물품이 없습니다."
L["No deals found"] = "세일 품목을 찾을 수 없습니다."
L["No items found"] = "검색된 품목이 없습니다."
L["Note: %d |4listing:listings; of %d |4item was:items were; not purchased."] = "주의: %d 건의 %d|1을;를; 구매하지 못했습니다."
L["Not enough cash for deposit."] = "경매 보증금이 부족합니다."
L["Not enough items available."] = "수량이 충분하지 않습니다."
L["Number of Items"] = "물품 수량"
L["Number of Items |cff808080(max %d)|r"] = "물품 수량 |cff808080(총 %d개)|r"
-- L["Number of stacks suggested when an item is first placed in the \"Sell\" tab."] = ""
-- L["One Item"] = ""
-- L["One Stack"] = ""
-- L["On the summary view, show how many listings/items are yours."] = ""
L["Open All Bags at AH"] = "모든 가방 열기"
L["Open all your bags when you visit the auction house."] = "경매장을 사용할 때 모든 가방을 엽니다."
L["Open configuration dialog"] = "설정 창을 엽니다."
L["Percent to undercut market value for bid prices (0-100)."] = "입찰가를 아래의 비율에 따라 시세보다 싸게 등록합니다. (0-100)"
L["Percent to undercut market value for buyout prices (0-100)."] = "즉시 구입가를 아래의 비율에 따라 시세보다 싸게 등록합니다. (0-100)"
L["per item"] = "단가"
L["per stack"] = "묶음가"
L["Potential Profit"] = "잠재적 이익"
L["Pricing Method"] = "가격 책정 방식"
L["Print Detailed Price Data"] = "상세 정보 출력"
L["Print detailed price data when selling an item."] = "경매장에 물품을 등록할 때 대화창에 자세한 가격 정보를 출력합니다."
L["Profiles"] = "프로필"
L["Qty"] = "희망수량"
L["Resell %d:"] = "초과 구입 수량 %d개:"
L["Round all prices to this granularity, or zero to disable (0-1)."] = "경매장에 등록하는 모든 가격을 반올림합니다. 0으로 설정하면 반올림하지 않습니다."
L["Round Prices"] = "가격 반올림"
L["Scan complete.  Try again later to find deals!"] = "검색 완료. 세일 품목이 없습니다! 다음에 다시 검색하세요."
L["Scanning:"] = "조사중:"
L["Scanning..."] = "조사중..."
L["Search"] = "검색"
L["Searching:"] = "검색중:"
-- L["Selected Stack Size"] = ""
L["Sell Tab"] = "경매도우미 - 판매 탭"
L["Show auction house value in tooltips."] = "툴팁에 경매장 가격을 보여줍니다."
L["Show Auction Value"] = "경매가 보이기"
L["Show Deals"] = "세일 품목"
L["Show Disenchant Value"] = "마력추출 기대 골드 보이기"
L["Show expected disenchant value in tooltips."] = "툴팁에 아이템을 마력 추출하였을 때 얻을 수 있는 기대 골드를 보여줍니다."
L["Show Favorites"] = "즐겨찾는 품목"
L["Show Full Stack Price"] = "묶음가 보이기"
L["Show full stack prices in tooltips (shift toggles on the fly)."] = "묶음 가격을 보여줍니다. (Shift 키를 누르면 일시적으로 단가를 표시합니다.)"
-- L["Show How Many Listings are Mine"] = ""
L["Show My Auctions"] = "내 경매 현황"
L["Show Vendor Price"] = "상점가 보이기"
L["Show vendor sell price in tooltips."] = "툴팁에 상점에 팔 때의 가격을 표시합니다."
-- L["Stack size suggested when an item is first placed in the \"Sell\" tab."] = ""
L["stacks of"] = "번에 나눠           개씩 판매"
L["Start Tab"] = "처음 시작할 탭"
L["Time Elapsed:"] = "경과 시간:"
L["Time Remaining:"] = "남은 시간:"
L["Tooltips"] = "툴팁"
L["Use Coin Icons in Tooltips"] = "동전 아이콘 사용"
L["Use fast method for full scans (may cause disconnects)."] = "전체 검색시 고속 검색을 사용합니다. (접속이 끊어질 수 있습니다.)"
L["Uses the standard gold/silver/copper icons in tooltips."] = "툴팁에 동전 아이콘을 사용합니다. 사용하지 않으면 g, s, c로 표시합니다."
L["Vendor"] = "상점가"
L["Vendor Multiplier"] = "상점가 배수"
L["Vendor: %s"] = "상점가: %s"

end
