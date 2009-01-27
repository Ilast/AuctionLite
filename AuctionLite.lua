-------------------------------------------------------------------------------
-- AuctionLite 0.5
--
-- Lightweight addon to determine accurate market prices and to simplify
-- the process of posting auctions.
--
-- Send suggestions, comments, and bugs to merial.kilrogg@gmail.com.
-------------------------------------------------------------------------------

-- Create our addon.
AuctionLite = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0",
                                             "AceHook-2.1", "AceDB-2.0");

-- Currently no slash commands...
local options = {
  type = 'group',
  args = {
    bidundercut = {
      type = "range",
      desc = "Percent to undercut market value for bid prices (0-100).",
      name = "Bid Undercut",
      isPercent = true,
      get = "GetBidUndercut",
      set = "SetBidUndercut",
      order = 1,
    },
    buyoutundercut = {
      type = "range",
      desc = "Percent to undercut market value for buyout prices (0-100).",
      name = "Buyout Undercut",
      isPercent = true,
      get = "GetBuyoutUndercut",
      set = "SetBuyoutUndercut",
      order = 2,
    },
    vendormultiplier = {
      type = "range",
      desc = "Amount to multiply by vendor price to get default sell price.",
      name = "Vendor Multiplier",
      get = "GetVendorMultiplier",
      set = "SetVendorMultiplier",
      min = 0,
      max = 100,
      step = 0.1,
      order = 3,
    },
    roundprices = {
      type = "range",
      desc = "Round all prices to this granularity, or zero to disable (0-1).",
      name = "Round Prices",
      get = "GetRoundPrices",
      set = "SetRoundPrices",
      order = 4,
    },
    showvendor = {
      type = "toggle",
      desc = "Show vendor sell price in tooltips.",
      name = "Show Vendor Price",
      get = "ShowVendor",
      set = "ToggleShowVendor",
      order = 5,
    },
    showauction = {
      type = "toggle",
      desc = "Show auction house value in tooltips.",
      name = "Show Auction Value",
      get = "ShowAuction",
      set = "ToggleShowAuction",
      order = 6,
    },
    showstackprice = {
      type = "toggle",
      desc = "Show full stack prices in tooltips (shift toggles on the fly).",
      name = "Show Stack Price",
      get = "ShowStackPrice",
      set = "ToggleShowStackPrice",
      order = 7,
    },
    printpricedata = {
      type = "toggle",
      desc = "Print detailed price data when selling an item.",
      name = "Print Price Data",
      get = "PrintPriceData",
      set = "TogglePrintPriceData",
      order = 8,
    },
  },
}

-- Do some initial setup.
AuctionLite:RegisterChatCommand("/al", options);
AuctionLite:RegisterDB("AuctionLiteDB");
AuctionLite:RegisterDefaults("realm", {
  prices = {},
});
AuctionLite:RegisterDefaults("profile", {
  showVendor = true,
  showAuction = true,
  showStackPrice = true,
  printPriceData = false,
  bidUndercut = 0.25,
  buyoutUndercut = 0.02,
  vendorMultiplier = 3,
  roundPrices = 0.05,
  duration = 3,
  method = 1,
});

local AUCTIONLITE_VERSION = 0.5;

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

-- Get bid undercut.
function AuctionLite:GetBidUndercut()
  return self.db.profile.bidUndercut;
end

-- Set bid undercut.
function AuctionLite:SetBidUndercut(value)
  self.db.profile.bidUndercut = value;
end

-- Get buyout undercut.
function AuctionLite:GetBuyoutUndercut()
  return self.db.profile.buyoutUndercut;
end

-- Set buyout undercut.
function AuctionLite:SetBuyoutUndercut(value)
  self.db.profile.buyoutUndercut = value;
end

-- Get vendor multiplier.
function AuctionLite:GetVendorMultiplier()
  return self.db.profile.vendorMultiplier;
end

-- Set vendor multiplier.
function AuctionLite:SetVendorMultiplier(value)
  self.db.profile.vendorMultiplier = value;
end

-- Get round price granularity.
function AuctionLite:GetRoundPrices()
  return self.db.profile.roundPrices;
end

-- Set round price granularity.
function AuctionLite:SetRoundPrices(value)
  self.db.profile.roundPrices = value;
end

-- Show vendor data in tooltips?
function AuctionLite:ShowVendor()
  return self.db.profile.showVendor;
end

-- Toggle vendor data in tooltips.
function AuctionLite:ToggleShowVendor()
  self.db.profile.showVendor = not self.db.profile.showVendor;
end

-- Show auction value in tooltips?
function AuctionLite:ShowAuction()
  return self.db.profile.showAuction;
end

-- Toggle auction value in tooltips.
function AuctionLite:ToggleShowAuction()
  self.db.profile.showAuction = not self.db.profile.showAuction;
end

-- Show full stack price in tooltips?
function AuctionLite:ShowStackPrice()
  return self.db.profile.showStackPrice;
end

-- Toggle stack price in tooltips.
function AuctionLite:ToggleShowStackPrice()
  self.db.profile.showStackPrice = not self.db.profile.showStackPrice;
end

-- Print detailed price data to chat window when selling?
function AuctionLite:PrintPriceData()
  return self.db.profile.printPriceData;
end

-- Toggle detailed price data.
function AuctionLite:TogglePrintPriceData()
  self.db.profile.printPriceData = not self.db.profile.printPriceData;
end

-------------------------------------------------------------------------------
-- Hooks and boostrap code
-------------------------------------------------------------------------------

-- Clean up if the auction house is closed.
function AuctionLite:AUCTION_HOUSE_CLOSED()
  self:ClearBuyFrame();
  self:ClearSellFrame();
  self:ClearSavedPrices();

  self:ResetAuctionCreation();

  collectgarbage("collect");
end

-- Hook some AH functions and UI widgets when the AH gets loaded.
function AuctionLite:ADDON_LOADED(name)
  if name == "Blizzard_AuctionUI" then
    self:SecureHook("AuctionFrameTab_OnClick", "AuctionFrameTab_OnClick_Hook");
    self:SecureHook("ContainerFrameItemButton_OnModifiedClick", "ContainerFrameItemButton_OnModifiedClick_Hook");
    self:SecureHook("ClickAuctionSellItemButton", "ClickAuctionSellItemButton_Hook");
    self:HookAuctionFrameUpdate();
    self:AddAuctionFrameTabs();
  elseif name == "Blizzard_GuildBankUI" then
    self:HookBankTooltips();
  end
end

-- We're alive!  Register our event handlers.
function AuctionLite:OnEnable()
  self:Print("AuctionLite v" .. AUCTIONLITE_VERSION .. " loaded!");

  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");
  self:RegisterEvent("AUCTION_HOUSE_CLOSED");

  self:HookCoroutines();
  self:HookTooltips();
end
