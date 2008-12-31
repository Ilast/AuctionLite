-------------------------------------------------------------------------------
-- AuctionLite 0.3
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
    showvendor = {
      type = "toggle",
      desc = "Show vendor sell price in tooltips",
      name = "Show Vendor Price",
      get = "ShowVendor",
      set = "ToggleShowVendor",
    },
    showauction = {
      type = "toggle",
      desc = "Show auction house value in tooltips",
      name = "Show Auction Value",
      get = "ShowAuction",
      set = "ToggleShowAuction",
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
  duration = 3,
  method = 1,
});

local AUCTIONLITE_VERSION = 0.3;

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- Hooks and boostrap code
-------------------------------------------------------------------------------

-- Clean up if the auction house is closed.
function AuctionLite:AUCTION_HOUSE_CLOSED()
  self:ClearBuyFrame();
  self:ClearSellFrame();
  self:ClearSavedPrices();
  self:ResetAuctionCreation();
end

-- Hook some AH functions and UI widgets when the AH gets loaded.
function AuctionLite:ADDON_LOADED(name)
  if name == "Blizzard_AuctionUI" then
    self:SecureHook("AuctionFrameTab_OnClick", "AuctionFrameTab_OnClick_Hook");
    self:SecureHook("ClickAuctionSellItemButton", "ClickAuctionSellItemButton_Hook");
    self:HookAuctionFrameUpdate();
    self:AddAuctionFrameTabs();
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
