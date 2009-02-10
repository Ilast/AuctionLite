-------------------------------------------------------------------------------
-- AuctionLite 0.6
--
-- Lightweight addon to determine accurate market prices and to simplify
-- the process of posting auctions.
--
-- Send suggestions, comments, and bugs to merial.kilrogg@gmail.com.
-------------------------------------------------------------------------------

-- Create our addon.
AuctionLite = LibStub("AceAddon-3.0"):NewAddon("AuctionLite",
                                               "AceConsole-3.0",
                                               "AceEvent-3.0",
                                               "AceHook-3.0");

-- Currently no slash commands...
local Options = {
  type = 'group',
  get = function(item) return AuctionLite.db.profile[item[#item]] end,
  set = function(item, value) AuctionLite.db.profile[item[#item]] = value end,
  args = {
    bidUndercut = {
      type = "range",
      desc = "Percent to undercut market value for bid prices (0-100).",
      name = "Bid Undercut",
      isPercent = true,
      order = 1,
    },
    buyoutUndercut = {
      type = "range",
      desc = "Percent to undercut market value for buyout prices (0-100).",
      name = "Buyout Undercut",
      isPercent = true,
      order = 2,
    },
    vendorMultiplier = {
      type = "range",
      desc = "Amount to multiply by vendor price to get default sell price.",
      name = "Vendor Multiplier",
      min = 0,
      max = 100,
      step = 0.1,
      order = 3,
    },
    roundPrices = {
      type = "range",
      desc = "Round all prices to this granularity, or zero to disable (0-1).",
      name = "Round Prices",
      order = 4,
    },
    showVendor = {
      type = "toggle",
      desc = "Show vendor sell price in tooltips.",
      name = "Show Vendor Price",
      order = 5,
    },
    showAuction = {
      type = "toggle",
      desc = "Show auction house value in tooltips.",
      name = "Show Auction Value",
      order = 6,
    },
    showStackPrice = {
      type = "toggle",
      desc = "Show full stack prices in tooltips (shift toggles on the fly).",
      name = "Show Stack Price",
      order = 7,
    },
    printPriceData = {
      type = "toggle",
      desc = "Print detailed price data when selling an item.",
      name = "Print Price Data",
      order = 8,
    },
  },
}

local SlashOptions = {
  type = 'group',
  handler = AuctionLite,
  args = {
    config = {
      type = "execute",
      desc = "Open configuration dialog",
      name = "Configure",
      func = function()
        InterfaceOptionsFrame_OpenToCategory(AuctionLite.optionFrames.main);
      end,
    },
  },
};

local SlashCmds = {
  "al",
  "auctionlite",
};

local Defaults = {
  factionrealm = {
    prices = {},
  },
  profile = {
    method = 1,
    duration = 3,
    bidUndercut = 0.25,
    buyoutUndercut = 0.02,
    vendorMultiplier = 3,
    roundPrices = 0.05,
    showVendor = true,
    showAuction = true,
    showStackPrice = true,
    printPriceData = false,
    showGreeting = false,
  },
};

local DBName = "AuctionLiteDB";

local AUCTIONLITE_VERSION = 0.6;

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

-- Hook some AH/GB functions and UI widgets when the AH/GB gets loaded.
function AuctionLite:ADDON_LOADED(_, name)
  if name == "Blizzard_AuctionUI" then
    self:SecureHook("AuctionFrameTab_OnClick",
                    "AuctionFrameTab_OnClick_Hook");
    self:SecureHook("ContainerFrameItemButton_OnModifiedClick",
                    "ContainerFrameItemButton_OnModifiedClick_Hook");
    self:SecureHook("ClickAuctionSellItemButton",
                    "ClickAuctionSellItemButton_Hook");
    self:SecureHook("QueryAuctionItems",
                    "QueryAuctionItems_Hook");
    self:HookAuctionFrameUpdate();
    self:AddAuctionFrameTabs();
  elseif name == "Blizzard_GuildBankUI" then
    self:HookBankTooltips();
  end
end

-- If we see an Ace2 database, convert it to Ace3.
function AuctionLite:ConvertDB()
  local db = _G[DBName];

  -- It's Ace2 if it uses "realms" instead of "factionrealm".
  if db ~= nil and db.realms ~= nil and db.factionrealm == nil then
    -- Change "Realm - Faction" keys to "Faction - Realm" keys.
    db.factionrealm = {}
    for k, v in pairs(db.realms) do
      db.factionrealm[k:gsub("(.*) %- (.*)", "%2 - %1")] = v;
    end

    -- Now unlink the old DB.
    db.realms = nil;
  end
end

-- We're alive!
function AuctionLite:OnInitialize()
  -- Load our database.
  self:ConvertDB();
  self.db = LibStub("AceDB-3.0"):New(DBName, Defaults, "Default");

  -- Set up our config options.
  local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);
  
  local config = LibStub("AceConfig-3.0");
  config:RegisterOptionsTable("AuctionLite", SlashOptions, SlashCmds);

  local registry = LibStub("AceConfigRegistry-3.0");
  registry:RegisterOptionsTable("AuctionLite Options", Options);
  registry:RegisterOptionsTable("AuctionLite Profiles", profiles);

  local dialog = LibStub("AceConfigDialog-3.0");
  self.optionFrames = {
    main     = dialog:AddToBlizOptions("AuctionLite Options", "AuctionLite"),
    profiles = dialog:AddToBlizOptions("AuctionLite Profiles", "Profiles",
                                       "AuctionLite");
  };

  -- Register for events.
  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");
  self:RegisterEvent("AUCTION_HOUSE_CLOSED");

  -- Another addon may have forced the Blizzard addons to load early.
  -- If so, just run the init code now.
  if IsAddOnLoaded("Blizzard_AuctionUI") then
    self:ADDON_LOADED("Blizzard_AuctionUI");
  elseif IsAddOnLoaded("Blizzard_GuildBankUI") then
    self:ADDON_LOADED("Blizzard_GuildBankUI");
  end

  -- Add any hooks that don't depend upon Blizzard addons.
  self:HookCoroutines();
  self:HookTooltips();

  -- And print a message if we're debugging.
  if self.db.profile.showGreeting then
    self:Print("AuctionLite v" .. AUCTIONLITE_VERSION .. " loaded!");
  end
end
