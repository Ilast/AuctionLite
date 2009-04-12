-------------------------------------------------------------------------------
-- AuctionLite 1.1.2
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

local L = LibStub("AceLocale-3.0"):GetLocale("AuctionLite", false)

-- Currently no slash commands...
local Options = {
  type = "group",
  get = function(item) return AuctionLite.db.profile[item[#item]] end,
  set = function(item, value) AuctionLite.db.profile[item[#item]] = value end,
  args = {
    bidUndercut = {
      type = "range",
      desc = L["Percent to undercut market value for bid prices (0-100)."],
      name = L["Bid Undercut"],
      isPercent = true,
      min = 0,
      max = 1,
      step = 0.01,
      order = 1,
    },
    buyoutUndercut = {
      type = "range",
      desc = L["Percent to undercut market value for buyout prices (0-100)."],
      name = L["Buyout Undercut"],
      isPercent = true,
      min = 0,
      max = 1,
      step = 0.01,
      order = 2,
    },
    vendorMultiplier = {
      type = "range",
      desc = L["Amount to multiply by vendor price to get default sell price."],
      name = L["Vendor Multiplier"],
      min = 0,
      max = 100,
      step = 0.5,
      order = 3,
    },
    roundPrices = {
      type = "range",
      desc = L["Round all prices to this granularity, or zero to disable (0-1)."],
      name = L["Round Prices"],
      min = 0,
      max = 1,
      step = 0.01,
      order = 4,
    },
    minProfit = {
      type = "range",
      desc = L["Deals must be below the historical price by this much gold."],
      name = L["Minimum Profit (Gold)"],
      min = 0,
      max = 1000,
      step = 10,
      order = 5,
    },
    minDiscount = {
      type = "range",
      desc = L["Deals must be below the historical price by this percentage."],
      name = L["Minimum Profit (Pct)"],
      isPercent = true,
      min = 0,
      max = 1,
      step = 0.01,
      order = 6,
    },
    getAll = {
      type = "toggle",
      desc = L["Use fast method for full scans (may cause disconnects)."],
      name = L["Fast Auction Scan"],
      width = "double",
      order = 7,
    },
    openBags = {
      type = "toggle",
      desc = L["Open all your bags when you visit the auction house."],
      name = L["Open All Bags at AH"],
      width = "double",
      order = 8,
    },
    considerResale = {
      type = "toggle",
      desc = L["Consider resale value of excess items when filling an order on the \"Buy\" tab."],
      name = L["Consider Resale Value When Buying"],
      width = "double",
      order = 9,
    },
    printPriceData = {
      type = "toggle",
      desc = L["Print detailed price data when selling an item."],
      name = L["Print Detailed Price Data"],
      width = "double",
      order = 10,
    },
    startTab = {
      type = "select",
      desc = L["Choose which tab is selected when opening the auction house."],
      name = L["Start Tab"],
      style = "dropdown",
      values = {
        a_default = L["Default"],
        b_buy = L["Buy Tab"],
        c_sell = L["Sell Tab"],
        d_last = L["Last Used Tab"],
      },
    },
  },
}

local YesNoMaybe = {
  a_yes = L["Always"],
  b_maybe = L["If Applicable"],
  c_no = L["Never"],
};

local TooltipOptions = {
  type = "group",
  get = function(item) return AuctionLite.db.profile[item[#item]] end,
  set = function(item, value) AuctionLite.db.profile[item[#item]] = value end,
  args = {
    showVendor = {
      type = "select",
      desc = L["Show vendor sell price in tooltips."],
      name = L["Show Vendor Price"],
      style = "dropdown",
      values = YesNoMaybe,
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
      desc = L["Show expected disenchant value in tooltips."],
      name = L["Show Disenchant Value"],
      style = "dropdown",
      values = YesNoMaybe,
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
      desc = L["Show auction house value in tooltips."],
      name = L["Show Auction Value"],
      style = "dropdown",
      values = YesNoMaybe,
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
    coinTooltips = {
      type = "toggle",
      desc = L["Uses the standard gold/silver/copper icons in tooltips."],
      name = L["Use Coin Icons in Tooltips"],
      width = "double",
      order = 8,
    },
    showStackPrice = {
      type = "toggle",
      desc = L["Show full stack prices in tooltips (shift toggles on the fly)."],
      name = L["Show Full Stack Price"],
      width = "double",
      order = 9,
    },
  },
};

local SlashOptions = {
  type = "group",
  handler = AuctionLite,
  args = {
    config = {
      type = "execute",
      desc = L["Open configuration dialog"],
      name = L["Configure"],
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
    getAll = false,
    openBags = false,
    considerResale = false,
    printPriceData = false,
    showVendor = "a_yes",
    showAuction = "b_maybe",
    showDisenchant = "b_maybe",
    coinTooltips = true,
    showStackPrice = true,
    startTab = "a_default",
    lastTab = 1,
    fastScanAd = false,
    showGreeting = false,
    favorites = {},
  },
};

local DBName = "AuctionLiteDB";

local AUCTIONLITE_VERSION = "1.1.2";

-------------------------------------------------------------------------------
-- Hooks and boostrap code
-------------------------------------------------------------------------------

-- Hook some AH/GB functions and UI widgets when the AH/GB gets loaded.
function AuctionLite:ADDON_LOADED(_, name)
  if name == "Blizzard_AuctionUI" then
    self:RawHook("ChatEdit_InsertLink", "ChatEdit_InsertLink_Hook", true);
    self:SecureHook("ContainerFrameItemButton_OnModifiedClick",
                    "ContainerFrameItemButton_OnModifiedClick_Hook");
    self:SecureHook("AuctionFrameTab_OnClick",
                    "AuctionFrameTab_OnClick_Hook");
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
      if profile.showAuction then
        profile.showAuction = "b_maybe";
      else
        profile.showAuction = "c_no";
      end
    elseif type(profile.showVendor) == "boolean" then
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
    main     = dialog:AddToBlizOptions("AuctionLite Options", L["AuctionLite"]),
    tooltips = dialog:AddToBlizOptions("AuctionLite Tooltips", L["Tooltips"],
                                       L["AuctionLite"]);
    profiles = dialog:AddToBlizOptions("AuctionLite Profiles", L["Profiles"],
                                       L["AuctionLite"]);
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
    self:Print(L["AuctionLite v%s loaded!"]:format(AUCTIONLITE_VERSION));
  end
end
