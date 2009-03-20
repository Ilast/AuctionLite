-------------------------------------------------------------------------------
-- Disenchant.lua
--
-- Compute expected disenchant value.  Data source:
--   http://www.wowwiki.com/Disenchanting_tables
-- Thanks, WowWiki!
-------------------------------------------------------------------------------

-- Item ids for disenchanting materials.
local AbyssCrystal_Id = 34057;
local ArcaneDust_Id = 22445;
local DreamDust_Id = 11176;
local DreamShard_Id = 34052;
local GreaterAstralEssence_Id = 11082;
local GreaterCosmicEssence_Id = 34055;
local GreaterEternalEssence_Id = 16203;
local GreaterMagicEssence_Id = 10939;
local GreaterMysticEssence_Id = 11135;
local GreaterNetherEssence_Id = 11175;
local GreaterPlanarEssence_Id = 22446;
local IllusionDust_Id = 16204;
local InfiniteDust_Id = 34054;
local LargeBrilliantShard_Id = 14344;
local LargeGlimmeringShard_Id = 11084;
local LargeGlowingShard_Id = 11139;
local LargePrismaticShard_Id = 22449;
local LargeRadiantShard_Id = 11178;
local LesserAstralEssence_Id = 10998;
local LesserCosmicEssence_Id = 34056;
local LesserEternalEssence_Id = 16202;
local LesserMagicEssence_Id = 10938;
local LesserMysticEssence_Id = 11134;
local LesserNetherEssence_Id = 11174;
local LesserPlanarEssence_Id = 22447;
local NexusCrystal_Id = 20725;
local SmallBrilliantShard_Id = 14343;
local SmallDreamShard_Id = 34053;
local SmallGlimmeringShard_Id = 10978;
local SmallGlowingShard_Id = 11138;
local SmallPrismaticShard_Id = 22448;
local SmallRadiantShard_Id = 11177;
local SoulDust_Id = 11083;
local StrangeDust_Id = 10940;
local VisionDust_Id = 11137;
local VoidCrystal_Id = 22450;

local UncommonArmor = {
  {
    minlvl = 5,
    maxlvl = 15,
    shards = {
      { id = StrangeDust_Id, p = 0.8, min = 1, max = 2, },
      { id = LesserMagicEssence_Id, p = 0.2, min = 1, max = 2, },
    },
  },
  {
    minlvl = 16,
    maxlvl = 20,
    shards = {
      { id = StrangeDust_Id, p = 0.75, min = 2, max = 3, },
      { id = GreaterMagicEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = SmallGlimmeringShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 21,
    maxlvl = 25,
    shards = {
      { id = StrangeDust_Id, p = 0.75, min = 4, max = 6, },
      { id = LesserAstralEssence_Id, p = 0.15, min = 1, max = 2, },
      { id = SmallGlimmeringShard_Id, p = 0.1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 26,
    maxlvl = 30,
    shards = {
      { id = SoulDust_Id, p = 0.75, min = 1, max = 2, },
      { id = GreaterAstralEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = LargeGlimmeringShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 31,
    maxlvl = 35,
    shards = {
      { id = SoulDust_Id, p = 0.75, min = 2, max = 5, },
      { id = LesserMysticEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = SmallGlowingShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 36,
    maxlvl = 40,
    shards = {
      { id = VisionDust_Id, p = 0.75, min = 1, max = 2, },
      { id = GreaterMysticEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = LargeGlowingShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 41,
    maxlvl = 45,
    shards = {
      { id = VisionDust_Id, p = 0.75, min = 2, max = 5, },
      { id = LesserNetherEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = SmallRadiantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 46,
    maxlvl = 50,
    shards = {
      { id = DreamDust_Id, p = 0.75, min = 1, max = 2, },
      { id = GreaterNetherEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = LargeRadiantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 51,
    maxlvl = 55,
    shards = {
      { id = DreamDust_Id, p = 0.75, min = 2, max = 5, },
      { id = LesserEternalEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = SmallBrilliantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 56,
    maxlvl = 60,
    shards = {
      { id = IllusionDust_Id, p = 0.75, min = 1, max = 2, },
      { id = GreaterEternalEssence_Id, p = 0.2, min = 1, max = 2, },
      { id = LargeBrilliantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 61,
    maxlvl = 65,
    shards = {
      { id = IllusionDust_Id, p = 0.75, min = 2, max = 5, },
      { id = GreaterEternalEssence_Id, p = 0.2, min = 2, max = 3, },
      { id = LargeBrilliantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 66,
    maxlvl = 80,
    shards = {
      { id = ArcaneDust_Id, p = 0.75, min = 1, max = 3, },
      { id = LesserPlanarEssence_Id, p = 0.22, min = 1, max = 3, },
      { id = SmallPrismaticShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 81,
    maxlvl = 100,
    shards = {
      { id = ArcaneDust_Id, p = 0.75, min = 2, max = 3, },
      { id = LesserPlanarEssence_Id, p = 0.22, min = 2, max = 3, },
      { id = SmallPrismaticShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 101,
    maxlvl = 120,
    shards = {
      { id = ArcaneDust_Id, p = 0.75, min = 2, max = 5, },
      { id = GreaterPlanarEssence_Id, p = 0.22, min = 1, max = 2, },
      { id = LargePrismaticShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 121,
    maxlvl = 151,
    shards = {
      { id = InfiniteDust_Id, p = 0.75, min = 1, max = 2, },
      { id = LesserCosmicEssence_Id, p = 0.22, min = 1, max = 2, },
      { id = SmallDreamShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 152,
    maxlvl = 200,
    shards = {
      { id = InfiniteDust_Id, p = 0.75, min = 2, max = 5, },
      { id = GreaterCosmicEssence_Id, p = 0.22, min = 1, max = 2, },
      { id = DreamShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
};

local UncommonWeapon = {
  {
    minlvl = 6,
    maxlvl = 15,
    shards = {
      { id = StrangeDust_Id, p = 0.2, min = 1, max = 2, },
      { id = LesserMagicEssence_Id, p = 0.8, min = 1, max = 2, },
    },
  },
  {
    minlvl = 16,
    maxlvl = 20,
    shards = {
      { id = StrangeDust_Id, p = 0.2, min = 2, max = 3, },
      { id = GreaterMagicEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = SmallGlimmeringShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 21,
    maxlvl = 25,
    shards = {
      { id = StrangeDust_Id, p = 0.15, min = 4, max = 6, },
      { id = LesserAstralEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = SmallGlimmeringShard_Id, p = 0.1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 26,
    maxlvl = 30,
    shards = {
      { id = SoulDust_Id, p = 0.2, min = 1, max = 2, },
      { id = GreaterAstralEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = LargeGlimmeringShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 31,
    maxlvl = 35,
    shards = {
      { id = SoulDust_Id, p = 0.2, min = 2, max = 5, },
      { id = LesserMysticEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = SmallGlowingShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 36,
    maxlvl = 40,
    shards = {
      { id = VisionDust_Id, p = 0.2, min = 1, max = 2, },
      { id = GreaterMysticEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = LargeGlowingShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 41,
    maxlvl = 45,
    shards = {
      { id = VisionDust_Id, p = 0.2, min = 2, max = 5, },
      { id = LesserNetherEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = SmallRadiantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 46,
    maxlvl = 50,
    shards = {
      { id = DreamDust_Id, p = 0.2, min = 1, max = 2, },
      { id = GreaterNetherEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = LargeRadiantShard_Id, p = 0.05, min = 1, max = 1, },
    },
  },
  {
    minlvl = 51,
    maxlvl = 55,
    shards = {
      { id = DreamDust_Id, p = 0.22, min = 2, max = 5, },
      { id = LesserEternalEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = SmallBrilliantShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 56,
    maxlvl = 60,
    shards = {
      { id = IllusionDust_Id, p = 0.22, min = 1, max = 2, },
      { id = GreaterEternalEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = LargeBrilliantShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 61,
    maxlvl = 65,
    shards = {
      { id = IllusionDust_Id, p = 0.22, min = 2, max = 5, },
      { id = GreaterEternalEssence_Id, p = 0.75, min = 2, max = 3, },
      { id = LargeBrilliantShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 66,
    maxlvl = 100,
    shards = {
      { id = ArcaneDust_Id, p = 0.22, min = 2, max = 3, },
      { id = LesserPlanarEssence_Id, p = 0.75, min = 2, max = 3, },
      { id = SmallPrismaticShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 101,
    maxlvl = 120,
    shards = {
      { id = ArcaneDust_Id, p = 0.22, min = 2, max = 5, },
      { id = GreaterPlanarEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = LargePrismaticShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 121,
    maxlvl = 151,
    shards = {
      { id = InfiniteDust_Id, p = 0.22, min = 1, max = 2, },
      { id = LesserCosmicEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = SmallDreamShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
  {
    minlvl = 152,
    maxlvl = 200,
    shards = {
      { id = InfiniteDust_Id, p = 0.22, min = 2, max = 5, },
      { id = GreaterCosmicEssence_Id, p = 0.75, min = 1, max = 2, },
      { id = DreamShard_Id, p = 0.03, min = 1, max = 1, },
    },
  },
};

local Rare = {
  {
    minlvl = 11,
    maxlvl = 25,
    shards = {
      { id = SmallGlimmeringShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 26,
    maxlvl = 30,
    shards = {
      { id = LargeGlimmeringShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 31,
    maxlvl = 35,
    shards = {
      { id = SmallGlowingShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 36,
    maxlvl = 40,
    shards = {
      { id = LargeGlowingShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 41,
    maxlvl = 45,
    shards = {
      { id = SmallRadiantShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 46,
    maxlvl = 50,
    shards = {
      { id = LargeRadiantShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 51,
    maxlvl = 55,
    shards = {
      { id = SmallBrilliantShard_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 56,
    maxlvl = 65,
    shards = {
      { id = LargeBrilliantShard_Id, p = 0.995, min = 1, max = 1, },
      { id = NexusCrystal_Id, p = 0.005, min = 1, max = 1, },
    },
  },
  {
    minlvl = 66,
    maxlvl = 99,
    shards = {
      { id = SmallPrismaticShard_Id, p = 0.995, min = 1, max = 1, },
      { id = NexusCrystal_Id, p = 0.005, min = 1, max = 1, },
    },
  },
  {
    minlvl = 100,
    maxlvl = 120,
    shards = {
      { id = LargePrismaticShard_Id, p = 0.995, min = 1, max = 1, },
      { id = VoidCrystal_Id, p = 0.005, min = 1, max = 1, },
    },
  },
  {
    minlvl = 121,
    maxlvl = 166,
    shards = {
      { id = SmallDreamShard_Id, p = 0.995, min = 1, max = 1, },
      { id = AbyssCrystal_Id, p = 0.005, min = 1, max = 1, },
    },
  },
  {
    minlvl = 167,
    maxlvl = 200,
    shards = {
      { id = DreamShard_Id, p = 0.995, min = 1, max = 1, },
      { id = AbyssCrystal_Id, p = 0.005, min = 1, max = 1, },
    },
  },
};

local EpicArmor = {
  {
    minlvl = 40,
    maxlvl = 45,
    shards = {
      { id = SmallRadiantShard_Id, p = 1, min = 2, max = 4, },
    },
  },
  {
    minlvl = 46,
    maxlvl = 50,
    shards = {
      { id = LargeRadiantShard_Id, p = 1, min = 2, max = 4, },
    },
  },
  {
    minlvl = 51,
    maxlvl = 55,
    shards = {
      { id = SmallBrilliantShard_Id, p = 1, min = 2, max = 4, },
    },
  },
  {
    minlvl = 56,
    maxlvl = 60,
    shards = {
      { id = NexusCrystal_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 61,
    maxlvl = 94,
    shards = {
      { id = NexusCrystal_Id, p = 1, min = 1, max = 2, },
    },
  },
  {
    minlvl = 95,
    maxlvl = 165,
    shards = {
      { id = VoidCrystal_Id, p = 0.33, min = 1, max = 1, },
      { id = VoidCrystal_Id, p = 0.67, min = 2, max = 2, },
    },
  },
  {
    minlvl = 166,
    maxlvl = 200,
    shards = {
      { id = AbyssCrystal_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 201,
    maxlvl = 226,
    shards = {
      { id = AbyssCrystal_Id, p = 1, min = 1, max = 2, },
    },
  },
};

local EpicWeapon = {
  {
    minlvl = 40,
    maxlvl = 45,
    shards = {
      { id = SmallRadiantShard_Id, p = 1, min = 2, max = 4, },
    },
  },
  {
    minlvl = 46,
    maxlvl = 50,
    shards = {
      { id = LargeRadiantShard_Id, p = 1, min = 2, max = 4, },
    },
  },
  {
    minlvl = 51,
    maxlvl = 55,
    shards = {
      { id = SmallBrilliantShard_Id, p = 1, min = 2, max = 4, },
    },
  },
  {
    minlvl = 56,
    maxlvl = 60,
    shards = {
      { id = NexusCrystal_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 61,
    maxlvl = 75,
    shards = {
      { id = NexusCrystal_Id, p = 1, min = 1, max = 2, },
    },
  },
  {
    minlvl = 76,
    maxlvl = 94,
    shards = {
      { id = NexusCrystal_Id, p = 0.33, min = 1, max = 1, },
      { id = NexusCrystal_Id, p = 0.67, min = 2, max = 2, },
    },
  },
  {
    minlvl = 95,
    maxlvl = 165,
    shards = {
      { id = VoidCrystal_Id, p = 0.33, min = 1, max = 1, },
      { id = VoidCrystal_Id, p = 0.67, min = 2, max = 2, },
    },
  },
  {
    minlvl = 166,
    maxlvl = 200,
    shards = {
      { id = AbyssCrystal_Id, p = 1, min = 1, max = 1, },
    },
  },
  {
    minlvl = 201,
    maxlvl = 226,
    shards = {
      { id = AbyssCrystal_Id, p = 1, min = 1, max = 2, },
    },
  },
};

-- Constants used to build the disenchant table.
local ITEM_TYPE_ARMOR = 1;
local ITEM_TYPE_WEAPON = 2;

local Qualities = {
  ITEM_QUALITY_UNCOMMON,
  ITEM_QUALITY_RARE,
  ITEM_QUALITY_EPIC,
};

local Types = {
  ITEM_TYPE_ARMOR,
  ITEM_TYPE_WEAPON,
};

-- This table collects the raw data above.
local DisenchantInfo = {
  [ITEM_QUALITY_UNCOMMON] = {
    [ITEM_TYPE_ARMOR] = UncommonArmor,
    [ITEM_TYPE_WEAPON] = UncommonWeapon,
  },
  [ITEM_QUALITY_RARE] = {
    [ITEM_TYPE_ARMOR] = Rare,
    [ITEM_TYPE_WEAPON] = Rare,
  },
  [ITEM_QUALITY_EPIC] = {
    [ITEM_TYPE_ARMOR] = EpicArmor,
    [ITEM_TYPE_WEAPON] = EpicWeapon,
  },
};

-- Here's the official disenchant table, built on startup.
local DisenchantTable;

local LocalizedWeapon;
local LocalizedArmor;

-- Flesh out the disenchant table for quick lookup.
function AuctionLite:BuildDisenchantTable()
  -- Get the localized names for weapons and armor, which we use to
  -- determine item type.
  LocalizedWeapon, LocalizedArmor = GetAuctionItemClasses();

  -- Build the lookup table.
  DisenchantTable = {};

  local quality;
  for _, quality in ipairs(Qualities) do
    DisenchantTable[quality] = {};

    local typ;
    for _, typ in ipairs(Types) do
      DisenchantTable[quality][typ] = {};

      local table = DisenchantTable[quality][typ];
      local ranges = DisenchantInfo[quality][typ];

      for _, range in ipairs(ranges) do
        local i;
        for i = range.minlvl, range.maxlvl do
          table[i] = range.shards;
        end
      end
    end
  end

  -- We're done with the original data, so free it.
  DisenchantInfo = nil;
end

-- Compute the expected disenchant value for this item.
function AuctionLite:GetDisenchantValue(item)
  local result = nil;

  -- Get the item quality, level, and type.
  local _, _, quality, ilvl, _, typeStr = GetItemInfo(item);

  local disenchantable =
    quality == ITEM_QUALITY_UNCOMMON or
    quality == ITEM_QUALITY_RARE or
    quality == ITEM_QUALITY_EPIC;

  local typ;
  if typeStr == LocalizedWeapon then
    typ = ITEM_TYPE_WEAPON;
  elseif typeStr == LocalizedArmor then
    typ = ITEM_TYPE_ARMOR;
  end

  -- If it's disenchantable, look it up.
  if disenchantable and typ ~= nil then
    local shards = DisenchantTable[quality][typ][ilvl];
    if shards ~= nil then
      -- Iterate through all the possible shards we could generate
      -- to compute the expected value.
      local failed = false;
      local total = 0;
      local shard;
      for _, shard in ipairs(shards) do
        local shardValue = self:GetAuctionValue(shard.id);
        if shardValue ~= nil then
          total = total + shardValue * shard.p *
                          (shard.min + (shard.max - shard.min) / 2);
        else
          failed = true;
        end
      end

      -- If we looked up all the shards successfully, we're done.
      if not failed then
        result = total;
      end
    end
  end

  return result;
end
