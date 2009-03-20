-------------------------------------------------------------------------------
-- AuctionLite 0.8
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
  type = "group",
  get = function(item) return AuctionLite.db.profile[item[#item]] end,
  set = function(item, value) AuctionLite.db.profile[item[#item]] = value end,
  args = {
    bidUndercut = {
      type = "range",
      desc = "Percent to undercut market value for bid prices (0-100).",
      name = "Bid Undercut",
      isPercent = true,
      min = 0,
      max = 1,
      order = 1,
    },
    buyoutUndercut = {
      type = "range",
      desc = "Percent to undercut market value for buyout prices (0-100).",
      name = "Buyout Undercut",
      isPercent = true,
      min = 0,
      max = 1,
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
    minProfit = {
      type = "range",
      desc = "Deals must be below the historical price by this much gold.",
      name = "Minimum Profit (Gold)",
      min = 0,
      max = 1000,
      step = 1,
      order = 5,
    },
    minDiscount = {
      type = "range",
      desc = "Deals must be below the historical price by this percentage.",
      name = "Minimum Profit (Pct)",
      isPercent = true,
      min = 0,
      max = 1,
      order = 6,
    },
    getAll = {
      type = "toggle",
      desc = "Use fast method for full scans (may cause disconnects).",
      name = "Fast Auction Scan",
      width = "double",
      order = 7,
    },
    openBags = {
      type = "toggle",
      desc = "Open all your bags when you visit the auction house.",
      name = "Open All Bags at AH",
      width = "double",
      order = 8,
    },
    printPriceData = {
      type = "toggle",
      desc = "Print detailed price data when selling an item.",
      name = "Print Detailed Price Data",
      width = "double",
      order = 9,
    },
    startTab = {
      type = "select",
      desc = "Choose which tab is selected when opening the auction house.",
      name = "Start Tab",
      style = "dropdown",
      values = {
        a_default = "Default",
        b_buy = "Buy Tab",
        c_sell = "Sell Tab",
        d_last = "Last Used Tab",
      },
    },
  },
}

local TooltipOptions = {
  type = "group",
  get = function(item) return AuctionLite.db.profile[item[#item]] end,
  set = function(item, value) AuctionLite.db.profile[item[#item]] = value end,
  args = {
    showVendor = {
      type = "select",
      desc = "Show vendor sell price in tooltips.",
      name = "Show Vendor Price",
      style = "dropdown",
      values = {
        a_yes = "Always",
        b_maybe = "If Applicable",
        c_no = "Never",
      },
      order = 1,
    },
    blankVendor = {
      type = "description",
      name = "",
      desc = "",
      order = 2,
    },
    showDisenchant = {
      type = "select",
      desc = "Show expected disenchant value in tooltips.",
      name = "Show Disenchant Value",
      style = "dropdown",
      values = {
        a_yes = "Always",
        b_maybe = "If Applicable",
        c_no = "Never",
      },
      order = 3,
    },
    blankDisenchant = {
      type = "description",
      name = "",
      desc = "",
      order = 4,
    },
    showAuction = {
      type = "select",
      desc = "Show auction house value in tooltips.",
      name = "Show Auction Value",
      style = "dropdown",
      values = {
        a_yes = "Always",
        b_maybe = "If Applicable",
        c_no = "Never",
      },
      order = 5,
    },
    blankAuction = {
      type = "description",
      name = "",
      desc = "",
      order = 6,
    },
    blank = {
      type = "description",
      name = " ",
      desc = " ",
      order = 7,
    },
    showStackPrice = {
      type = "toggle",
      desc = "Show full stack prices in tooltips (shift toggles on the fly).",
      name = "Show Full Stack Price",
      order = 8,
    },
  },
};

local SlashOptions = {
  type = "group",
  handler = AuctionLite,
  args = {
    config = {
      type = "execute",
      desc = "Open configuration dialog",
      name = "Configure",
      func = function()
        InterfaceOptionsFrame_OpenToCategory(AuctionLite.optionFrames.tooltips);
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
    minProfit = 10,
    minDiscount = 0.25,
    showVendor = "a_yes",
    showAuction = "b_maybe",
    showDisenchant = "b_maybe",
    showStackPrice = true,
    printPriceData = false,
    getAll = false,
    openBags = false,
    startTab = "a_default",
    lastTab = 1,
    fastScanAd = false,
    showGreeting = false,
    favorites = {},
  },
};

local DBName = "AuctionLiteDB";

local AUCTIONLITE_VERSION = 0.8;

-------------------------------------------------------------------------------
-- Hooks and boostrap code
-------------------------------------------------------------------------------

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

-- If any of the options are outdated, convert them.
function AuctionLite:ConvertOptions()
  for _, profile in pairs(self.db.profiles) do
    if type(profile.showAuction) == "boolean" then
      self:Print("converting auction");
      if profile.showAuction then
        profile.showAuction = "b_maybe";
      else
        profile.showAuction = "c_no";
      end
    elseif type(profile.showVendor) == "boolean" then
      self:Print("converting vendor");
      if profile.showVendor then
        profile.showVendor = "a_yes";
      else
        profile.showVendor = "c_no";
      end
    end
  end
end

-- We're alive!
function AuctionLite:OnInitialize()
  -- Load our database.
  self:ConvertDB();
  self.db = LibStub("AceDB-3.0"):New(DBName, Defaults, "Default");

  -- Update any options that have changed.
  self:ConvertOptions();

  -- Set up our config options.
  local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);
  
  local config = LibStub("AceConfig-3.0");
  config:RegisterOptionsTable("AuctionLite", SlashOptions, SlashCmds);

  local registry = LibStub("AceConfigRegistry-3.0");
  registry:RegisterOptionsTable("AuctionLite Options", Options);
  registry:RegisterOptionsTable("AuctionLite Tooltips", TooltipOptions);
  registry:RegisterOptionsTable("AuctionLite Profiles", profiles);

  local dialog = LibStub("AceConfigDialog-3.0");
  self.optionFrames = {
    main     = dialog:AddToBlizOptions("AuctionLite Options", "AuctionLite"),
    tooltips = dialog:AddToBlizOptions("AuctionLite Tooltips", "Tooltips",
                                       "AuctionLite");
    profiles = dialog:AddToBlizOptions("AuctionLite Profiles", "Profiles",
                                       "AuctionLite");
  };

  -- Register for events.
  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");
  self:RegisterEvent("AUCTION_HOUSE_SHOW");
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

  -- Set up our disenchant info.
  self:BuildDisenchantTable();

  -- And print a message if we're debugging.
  if self.db.profile.showGreeting then
    self:Print("AuctionLite v" .. AUCTIONLITE_VERSION .. " loaded!");
  end
end
