-------------------------------------------------------------------------------
-- AuctionLite 1.5.4
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

local AUCTIONLITE_VERSION = "1.5.4";

local DBName = "AuctionLiteDB";

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
    -- Convert tooltip options.
    if type(profile.showAuction) == "boolean" then
      if profile.showAuction then
        profile.showAuction = "b_maybe";
      else
        profile.showAuction = "c_no";
      end
    end
    if type(profile.showVendor) == "boolean" then
      if profile.showVendor then
        profile.showVendor = "a_yes";
      else
        profile.showVendor = "c_no";
      end
    end
    -- Convert favorites.
    local value = true;
    for _, v in pairs(profile.favorites) do
      value = v;
      break;
    end
    if type(value) == "boolean" then
      profile.favorites = { [L["Favorites"]] = profile.favorites };
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
  self:InitConfig();

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

  -- Add our chat message filter.
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(...)
    return self:MessageEventFilter(...);
  end);

  -- Set up our disenchant info.
  self:BuildDisenchantTable();

  -- And print a message if we're debugging.
  if self.db.profile.showGreeting then
    self:Print(L["AuctionLite v%s loaded!"]:format(AUCTIONLITE_VERSION));
  end
end
