-- ============================================================
--  Hindi Kahani App  v6.0  (improved)
--  6 Sources | 31 Categories | WordPress REST API
--  Features: Drawer Nav | Night Mode | Bookmarks | A11y
--             Font Resize | Share | Cache | Search
--  Back: global onKeyDown | No view reuse
-- ============================================================

require "import"
import "android.app.*"
import "android.os.*"
import "android.view.*"
import "android.widget.*"
import "android.graphics.*"
import "android.graphics.drawable.*"
import "android.content.*"

-- ─────────────────────────────────────────────
--  COLOURS
-- ─────────────────────────────────────────────
local C={
  purple=0xff6a1b9a, purpleDeep=0xff38006b,
  amberLight=0xffffb300, white=0xffffffff,
  bgDay=0xfff3e5f5,  bgNight=0xff120024,
  cardDay=0xffffffff, cardNight=0xff1e0040,
  txtDay=0xff212121,  txtNight=0xfff0e6ff,
  subDay=0xff6a1b9a,  subNight=0xffce93d8,
  red=0xffe53935,
  green=0xff00c853,
  orange=0xffff6d00,
  divider=0x22000000,
}

-- kahanizone(9) + hindimoralstory(3) + kahanihindime(4) + daanitv(7) + bhootkikahani(3) + horrorstoryhindi(5) = 31
local CAT_COLORS={
  -- kahanizone.com (9)
  0xff6a1b9a,0xff00695c,0xffe65100,0xff283593,
  0xff558b2f,0xff880e4f,0xff1565c0,0xff4e342e,0xff00838f,
  -- hindimoralstory.com (3)
  0xffb71c1c,0xff004d40,0xff1a237e,
  -- kahanihindime.com (4)
  0xff4a148c,0xff006064,0xff33691e,0xff827717,
  -- daanitv.com (7)
  0xff37474f,0xff4e342e,0xff1b5e20,0xff311b92,0xff01579b,0xff880e4f,0xff00695c,
  -- bhootkikahani.com (3)
  0xff1a1a2e,0xff16213e,0xff0f3460,
  -- horrorstoryhindi.com (5)
  0xff212121,0xff3e0000,0xff1b0000,0xff4a0000,0xff0d0d0d,
}
local CAT_ICONS={
  -- kahanizone.com (9)
  "\u2696","\u1F4D6","\u1F525","\u1F451","\u1F3AD","\u1F47B","\u270D","\u2B50","\u1F319",
  -- hindimoralstory.com (3)
  "\u1F4DD","\u1F4DA","\u1F516",
  -- kahanihindime.com (4)
  "\u1F4AA","\u26A1","\u1F407","\u1F602",
  -- daanitv.com (7)
  "\u2B50","\u1F333","\u1F451","\u1F52E","\u1F30D","\u1F319","\u1F4A4",
  -- bhootkikahani.com (3)
  "\u1F47B","\u1F9D9","\u1F608",
  -- horrorstoryhindi.com (5)
  "\u1F480","\u1F1EE\u1F1F3","\u1F9DF","\u1F479","\u1F310",
}

local MATCH=LinearLayout.LayoutParams.MATCH_PARENT
local WRAP=LinearLayout.LayoutParams.WRAP_CONTENT

-- ─────────────────────────────────────────────
--  CATEGORIES
--  base = WordPress API base URL for that site
-- ─────────────────────────────────────────────
local KZ  = "https://www.kahanizone.com/wp-json/wp/v2"
local HMS = "https://hindimoralstory.com/wp-json/wp/v2"
local KHM = "https://kahanihindime.com/wp-json/wp/v2"
local DTV = "https://daanitv.com/wp-json/wp/v2"
local BKK = "https://bhootkikahani.com/wp-json/wp/v2"
local HSH = "https://www.horrorstoryhindi.com/wp-json/wp/v2"

local CATEGORIES={
  -- ── kahanizone.com ──
  {base=KZ,  slug="moral-story",        name="\u0928\u0948\u0924\u093F\u0915 \u0915\u0939\u093E\u0928\u0940",    desc="\u0936\u093F\u0915\u094D\u0937\u093E\u092A\u094D\u0930\u0926 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",        site="kahanizone.com"},
  {base=KZ,  slug="hindi-kahaniya",     name="\u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901", desc="\u0930\u094B\u091A\u0915 \u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",        site="kahanizone.com"},
  {base=KZ,  slug="motivational-story", name="\u092A\u094D\u0930\u0947\u0930\u0923\u093E\u0926\u093E\u092F\u0915",    desc="\u091C\u0940\u0935\u0928 \u092C\u0926\u0932\u0928\u0947 \u0935\u093E\u0932\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",    site="kahanizone.com"},
  {base=KZ,  slug="akbar-birbal",       name="\u0905\u0915\u092C\u0930 \u092C\u0940\u0930\u092C\u0932",    desc="\u092C\u0941\u0926\u094D\u0927\u093F \u0914\u0930 \u091A\u0924\u0941\u0930\u093E\u0908 \u0915\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901", site="kahanizone.com"},
  {base=KZ,  slug="tenali-rama",        name="\u0924\u0947\u0928\u093E\u0932\u0940 \u0930\u093E\u092E\u093E",    desc="\u091A\u0924\u0941\u0930 \u0924\u0947\u0928\u093E\u0932\u0940 \u0915\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",     site="kahanizone.com"},
  {base=KZ,  slug="horror-stories",     name="\u0939\u0949\u0930\u0930 \u0915\u0939\u093E\u0928\u0940",     desc="\u0930\u094B\u092E\u093E\u0902\u091A\u0915 \u0921\u0930\u093E\u0935\u0928\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",     site="kahanizone.com"},
  {base=KZ,  slug="hindi-story",        name="\u0939\u093F\u0902\u0926\u0940 \u0938\u094D\u091F\u094B\u0930\u0940",   desc="\u0935\u093F\u0935\u093F\u0927 \u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",        site="kahanizone.com"},
  {base=KZ,  slug="moral",              name="English Moral", desc="English moral stories",       site="kahanizone.com"},
  {base=KZ,  slug="bedtime",            name="Bedtime",       desc="Bedtime stories for kids",    site="kahanizone.com"},
  -- ── hindimoralstory.com ──
  {base=HMS, slug="hindi-moral-story",  name="HMS \u0928\u0948\u0924\u093F\u0915",      desc="Hindi Moral Story \u2014 \u0928\u0948\u0924\u093F\u0915",   site="hindimoralstory.com"},
  {base=HMS, slug="hindi-kahaniya",     name="HMS \u0939\u093F\u0902\u0926\u0940",       desc="Hindi Moral Story \u2014 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",site="hindimoralstory.com"},
  {base=HMS, slug="chhoti-kahaniya",    name="HMS \u091B\u094B\u091F\u0940",        desc="Hindi Moral Story \u2014 \u091B\u094B\u091F\u0940",    site="hindimoralstory.com"},
  -- kahanihindime.com
  {base=KHM, slug="motivational-story", name="KHM \u092A\u094D\u0930\u0947\u0930\u0915",     desc="kahanihindime \u2014 \u092A\u094D\u0930\u0947\u0930\u0923\u093E\u0926\u093E\u092F\u0915", site="kahanihindime.com"},
  {base=KHM, slug="short-stories",      name="KHM \u0936\u0949\u0930\u094D\u091F",      desc="kahanihindime \u2014 \u091B\u094B\u091F\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",  site="kahanihindime.com"},
  {base=KHM, slug="hindi-moral-stories",name="KHM \u0928\u0948\u0924\u093F\u0915",      desc="kahanihindime \u2014 \u0928\u0948\u0924\u093F\u0915 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901", site="kahanihindime.com"},
  {base=KHM, slug="majedar-kahani",     name="KHM \u092E\u091C\u0947\u0926\u093E\u0930",    desc="kahanihindime \u2014 \u092E\u091C\u0947\u0926\u093E\u0930 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",  site="kahanihindime.com"},
  -- daanitv.com
  {base=DTV, slug="moral-stories",             name="DTV \u0928\u0948\u0924\u093F\u0915",      desc="daanitv \u2014 \u0928\u0948\u0924\u093F\u0915 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",       site="daanitv.com"},
  {base=DTV, slug="panchatantra-kahaniya",     name="DTV \u092A\u0902\u091A\u0924\u0902\u0924\u094D\u0930", desc="daanitv \u2014 \u092A\u0902\u091A\u0924\u0902\u0924\u094D\u0930 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901", site="daanitv.com"},
  {base=DTV, slug="akbar-birbal-ki-kahaniya",  name="DTV \u0905\u0915\u092C\u0930",          desc="daanitv \u2014 \u0905\u0915\u092C\u0930-\u092C\u0940\u0930\u092C\u0932",            site="daanitv.com"},
  {base=DTV, slug="jaduikahaniya",             name="DTV \u091C\u093E\u0926\u0941\u0908",     desc="daanitv \u2014 \u091C\u093E\u0926\u0941\u0908 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",        site="daanitv.com"},
  {base=DTV, slug="folk-tale-lok-katha",       name="DTV \u0932\u094B\u0915 \u0915\u0925\u093E", desc="daanitv \u2014 \u0932\u094B\u0915 \u0915\u0925\u093E\u090F\u0901",              site="daanitv.com"},
  {base=DTV, slug="motivational-hindi-story",  name="DTV \u092A\u094D\u0930\u0947\u0930\u0915",  desc="daanitv \u2014 \u092A\u094D\u0930\u0947\u0930\u0923\u093E\u0926\u093E\u092F\u0915 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901", site="daanitv.com"},
  {base=DTV, slug="bedtime-stories",           name="DTV \u0938\u094B\u0928\u0947 \u0938\u092E\u092F", desc="daanitv \u2014 Bedtime Stories",                                site="daanitv.com"},
  -- bhootkikahani.com (5)
  {base=BKK, slug="horror-stories-hindi",  name="BKK \u092D\u0942\u0924",      desc="bhootkikahani \u2014 \u092D\u0942\u0924 \u0915\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",   site="bhootkikahani.com"},
  {base=BKK, slug="chudail-ki-kahani",     name="BKK \u091A\u0941\u095C\u0948\u0932",    desc="bhootkikahani \u2014 \u091A\u0941\u095C\u0948\u0932 \u0915\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901", site="bhootkikahani.com"},
  {base=BKK, slug="darawani-kahani",       name="BKK \u0921\u0930\u093E\u0935\u0928\u0940", desc="bhootkikahani \u2014 \u0921\u0930\u093E\u0935\u0928\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",  site="bhootkikahani.com"},
  -- horrorstoryhindi.com (5)
  {base=HSH, slug="horror-stories",        name="HSH \u0939\u0949\u0930\u0930",     desc="horrorstoryhindi \u2014 Horror Stories Hindi",     site="horrorstoryhindi.com"},
  {base=HSH, slug="indian-horror-stories", name="HSH \u0907\u0902\u0921\u093F\u092F\u0928", desc="horrorstoryhindi \u2014 Indian Horror Stories",   site="horrorstoryhindi.com"},
  {base=HSH, slug="chudail",               name="HSH \u091A\u0941\u095C\u0948\u0932",    desc="horrorstoryhindi \u2014 Chudail Stories",          site="horrorstoryhindi.com"},
  {base=HSH, slug="monster-stories",       name="HSH \u092E\u0949\u0928\u094D\u0938\u094D\u091F\u0930", desc="horrorstoryhindi \u2014 Monster Stories", site="horrorstoryhindi.com"},
  {base=HSH, slug="horror-urban-legends",  name="HSH \u0915\u093F\u0902\u0935\u0926\u0902\u0924\u0940", desc="horrorstoryhindi \u2014 Urban Legends",   site="horrorstoryhindi.com"},
}

-- ─────────────────────────────────────────────
--  STATE
-- ─────────────────────────────────────────────
local night=false; local fsize=17; local bookmarks={}
local searchQuery=""; local searchResults=nil
local readHistory={}   -- {title,catIdx,storyIdx,ts}
local maxHistory=50
local screenBookmarks=nil
local screenHistory=nil
local curCat=1; local catIdCache={}; local storyCache={}
local screenHome=nil; local screenList=nil; local screenReader=nil
local navStack={"home"}

local function bgC()   return night and C.bgNight   or C.bgDay   end
local function cardC() return night and C.cardNight or C.cardDay end
local function txtC()  return night and C.txtNight  or C.txtDay  end
local function subC()  return night and C.subNight  or C.subDay  end

-- ─────────────────────────────────────────────
--  BACK NAVIGATION
-- ─────────────────────────────────────────────

-- ══════════════════════════════════════════════
--  OFFLINE FALLBACK STORIES
--  Used when network fails entirely
-- ══════════════════════════════════════════════
local OFFLINE_STORIES={
  {title="\u0936\u0947\u0930 \u0914\u0930 \u091A\u0942\u0939\u093E",
   excerpt="\u091B\u094B\u091F\u0940 \u092E\u0926\u0926 \u0915\u092D\u0940 \u0935\u094D\u092F\u0930\u094D\u0925 \u0928\u0939\u0940\u0902 \u091C\u093E\u0924\u0940\u0964",
   body="\u090F\u0915 \u092C\u093E\u0930 \u090F\u0915 \u0935\u093F\u0936\u093E\u0932 \u0936\u0947\u0930 \u091C\u0902\u0917\u0932 \u092E\u0947\u0902 \u0938\u094B \u0930\u0939\u093E \u0925\u093E\u0964 \u0924\u092D\u0940 \u090F\u0915 \u091B\u094B\u091F\u093E \u091A\u0942\u0939\u093E \u0909\u0938\u0915\u0947 \u0914\u0930 \u092A\u0930 \u091A\u095D \u0917\u092F\u093E\u0964 \u0936\u0947\u0930 \u0928\u0947 \u0909\u0938\u0947 \u092A\u0915\u095C \u0932\u093F\u092F\u093E\u0964\n\n\u091A\u0942\u0939\u0947 \u0928\u0947 \u0935\u093F\u0928\u0924\u0940 \u0915\u0940 -- \u092E\u0939\u093E\u0930\u093E\u091C \u091B\u094B\u095C \u0926\u0940\u091C\u093F\u090F, \u090F\u0915 \u0926\u093F\u0928 \u092E\u0948\u0902 \u092D\u0940 \u0915\u093E\u092E \u0906\u090A\u0901\u0917\u093E\u0964 \u0936\u0947\u0930 \u0939\u0901\u0938\u093E \u0914\u0930 \u091B\u094B\u095C \u0926\u093F\u092F\u093E\u0964\n\n\u0915\u0941\u091B \u0926\u093F\u0928 \u092C\u093E\u0926 \u0936\u0947\u0930 \u091C\u093E\u0932 \u092E\u0947\u0902 \u092B\u0901\u0938 \u0917\u092F\u093E\u0964 \u091A\u0942\u0939\u0947 \u0928\u0947 \u091C\u093E\u0932 \u0915\u093E\u091F \u0926\u093F\u092F\u093E\u0964\n\n\u0938\u0940\u0916: \u0915\u092D\u0940 \u0915\u093F\u0938\u0940 \u0915\u094B \u091B\u094B\u091F\u093E \u092E\u0924 \u0938\u092E\u091D\u094B\u0964",
   link="",site="offline"},
  {title="\u0915\u091B\u0941\u0906 \u0914\u0930 \u0916\u0930\u0917\u094B\u0936",
   excerpt="\u0928\u093F\u0930\u0902\u0924\u0930\u0924\u093E \u0938\u092B\u0932\u0924\u093E \u0915\u0940 \u0915\u0941\u0902\u091C\u0940 \u0939\u0948\u0964",
   body="\u0916\u0930\u0917\u094B\u0936 \u0915\u091B\u0941\u090F \u0915\u0940 \u0927\u0940\u092E\u0940 \u091A\u093E\u0932 \u0915\u093E \u092E\u091C\u093C\u093E\u0915 \u0909\u095C\u093E\u0924\u093E \u0925\u093E\u0964 \u0915\u091B\u0941\u090F \u0928\u0947 \u0926\u094C\u095C \u0915\u0940 \u091A\u0941\u0928\u094C\u0924\u0940 \u0926\u0940\u0964\n\n\u0916\u0930\u0917\u094B\u0936 \u0906\u0917\u0947 \u0928\u093F\u0915\u0932\u093E \u0914\u0930 \u0938\u094B \u0917\u092F\u093E\u0964 \u0915\u091B\u0941\u0906 \u092C\u093F\u0928\u093E \u0930\u0941\u0915\u0947 \u091A\u0932\u0924\u093E \u0930\u0939\u093E \u0914\u0930 \u091C\u0940\u0924 \u0917\u092F\u093E\u0964\n\n\u0938\u0940\u0916: \u0918\u092E\u0902\u0921 \u0928\u0939\u0940\u0902, \u0928\u093F\u0930\u0902\u0924\u0930 \u092E\u0947\u0939\u0928\u0924 \u0915\u0930\u094B\u0964",
   link="",site="offline"},
  {title="\u0932\u093E\u0932\u091A\u0940 \u0915\u0941\u0924\u094D\u0924\u093E",
   excerpt="\u0932\u093E\u0932\u091A \u092C\u0941\u0930\u0940 \u092C\u0932\u093E \u0939\u0948\u0964",
   body="\u090F\u0915 \u0915\u0941\u0924\u094D\u0924\u0947 \u0915\u094B \u0939\u095C\u094D\u0921\u0940 \u092E\u093F\u0932\u0940\u0964 \u0928\u0926\u0940 \u092E\u0947\u0902 \u0909\u0938\u0947 \u0905\u092A\u0928\u0940 \u092A\u0930\u091B\u093E\u0908\u0902 \u0926\u093F\u0916\u0940\u0964 \u0932\u093E\u0932\u091A \u092E\u0947\u0902 \u092D\u094C\u0902\u0915\u093E -- \u0939\u095C\u094D\u0921\u0940 \u0928\u0926\u0940 \u092E\u0947\u0902 \u0917\u093F\u0930 \u0917\u0908\u0964\n\n\u0938\u0940\u0916: \u091C\u094B \u0939\u0948 \u0909\u0938\u092E\u0947\u0902 \u0938\u0902\u0924\u094B\u0937 \u0930\u0916\u094B\u0964",
   link="",site="offline"},
  {title="\u0915\u094C\u0935\u093E \u0914\u0930 \u0918\u095C\u093E",
   excerpt="\u092C\u0941\u0926\u094D\u0927\u093F \u0938\u0947 \u0939\u0930 \u092E\u0941\u0936\u094D\u0915\u093F\u0932 \u0939\u0932 \u0939\u094B\u0924\u0940 \u0939\u0948\u0964",
   body="\u090F\u0915 \u092A\u094D\u092F\u093E\u0938\u0947 \u0915\u094C\u0935\u0947 \u0915\u094B \u0918\u095C\u093E \u092E\u093F\u0932\u093E\u0964 \u092A\u093E\u0928\u0940 \u0928\u0940\u091A\u0947 \u0925\u093E\u0964 \u0915\u094C\u0935\u0947 \u0928\u0947 \u092A\u0924\u094D\u0925\u0930 \u0921\u093E\u0932\u0947 -- \u092A\u093E\u0928\u0940 \u0909\u0928\u091A\u093E \u0906\u092F\u093E\u0964\n\n\u0938\u0940\u0916: \u092E\u0941\u0938\u0940\u092C\u0924 \u092E\u0947\u0902 \u092C\u0941\u0926\u094D\u0927\u093F \u0938\u0947 \u0915\u093E\u092E \u0932\u094B\u0964",
   link="",site="offline"},
  {title="\u0915\u093F\u0938\u093E\u0928 \u0915\u0947 \u092C\u0947\u091F\u0947",
   excerpt="\u092E\u0947\u0939\u0928\u0924 \u0939\u0940 \u0905\u0938\u0932\u0940 \u0916\u091C\u093C\u093E\u0928\u093E \u0939\u0948\u0964",
   body="\u0915\u093F\u0938\u093E\u0928 \u0928\u0947 \u092C\u0947\u091F\u094B\u0902 \u0938\u0947 \u0915\u0939\u093E -- \u0916\u0947\u0924 \u092E\u0947\u0902 \u0938\u094B\u0928\u093E \u0917\u095C\u093E \u0939\u0948\u0964 \u092C\u0947\u091F\u094B\u0902 \u0928\u0947 \u0916\u0947\u0924 \u0916\u094B\u0926\u093E\u0964 \u0938\u094B\u0928\u093E \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E \u092A\u0930 \u092B\u0938\u0932 \u0936\u093E\u0928\u0926\u093E\u0930 \u0939\u0941\u0908\u0964\n\n\u0938\u0940\u0916: \u092E\u0947\u0939\u0928\u0924 \u0939\u0940 \u0905\u0938\u0932\u0940 \u0927\u0928 \u0939\u0948\u0964",
   link="",site="offline"},
}

local function goBack()
  local top=navStack[#navStack]
  if top=="reader" then
    table.remove(navStack); activity.setContentView(screenList or screenHome)
  elseif top=="list" then
    table.remove(navStack); activity.setContentView(screenHome)
  elseif top=="bookmarks" then
    table.remove(navStack); activity.setContentView(screenHome)
  elseif top=="history" then
    table.remove(navStack); activity.setContentView(screenHome)
  else
    activity.finish()
  end
end

function onKeyDown(keyCode,event)
  if keyCode==4 then goBack(); return true end
  return false
end

-- ─────────────────────────────────────────────
--  UNICODE DECODER
-- ─────────────────────────────────────────────
local function utf8chr(cp)
  if cp<0x80 then return string.char(cp)
  elseif cp<0x800 then return string.char(0xC0+math.floor(cp/64),0x80+(cp%64))
  elseif cp<0x10000 then return string.char(
    0xE0+math.floor(cp/4096),0x80+math.floor((cp%4096)/64),0x80+(cp%64))
  else return string.char(
    0xF0+math.floor(cp/262144),0x80+math.floor((cp%262144)/4096),
    0x80+math.floor((cp%4096)/64),0x80+(cp%64)) end
end
local function uni(s)
  if not s then return "" end
  return s:gsub("\\u(%x%x%x%x)",function(h) return utf8chr(tonumber(h,16)) end)
end

-- Decode all category names, descs and icons from \uXXXX at startup
local function initDecodeCategories()


-- ─────────────────────────────────────────────
--  ACCESSIBILITY HELPERS
--  Android TalkBack / screen reader support
-- ─────────────────────────────────────────────
-- Set content description for screen readers
local function a11y(view, desc)
  if desc and desc ~= "" then
    view.setContentDescription(tostring(uni(desc)))
  end
  return view
end

-- Mark view as accessibility heading (TalkBack announces "Heading")
local function a11yHeading(view)
  if view.setAccessibilityHeading then
    pcall(function() view.setAccessibilityHeading(true) end)
  end
  return view
end

-- Mark view as not important for accessibility (decorative)
local function a11yDecor(view)
  view.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO)
  return view
end

-- Make a view focusable by TalkBack
local function a11yFocus(view)
  view.setFocusable(true)
  view.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES)
  return view
end

-- Announce a message to screen reader
local function a11yAnnounce(msg)
  pcall(function()
    local v = View(activity)
    v.announceForAccessibility(tostring(uni(msg)))
  end)
end

  for i=1,#CAT_ICONS do CAT_ICONS[i]=uni(CAT_ICONS[i]) end
  for _,cat in ipairs(CATEGORIES) do
    cat.name = uni(cat.name)
    cat.desc = uni(cat.desc)
  end
end
initDecodeCategories()

-- ─────────────────────────────────────────────
--  HELPERS  -- all return NEW objects every call
-- ─────────────────────────────────────────────
local function toast(m) Toast.makeText(activity,m,Toast.LENGTH_SHORT).show() end
local _dm=nil
local function dp(n)
  if not _dm then _dm=activity.getResources().getDisplayMetrics() end
  return math.floor(n*_dm.density+0.5)
end
local function rr(color,r,sc,sw)
  local g=GradientDrawable(); g.setColor(color); g.setCornerRadius(dp(r or 0))
  if sc then g.setStroke(dp(sw or 1),sc) end; return g
end
local function gr(c1,c2,r)
  local g=GradientDrawable(GradientDrawable.Orientation.TL_BR,{c1,c2})
  g.setCornerRadius(dp(r or 0)); return g
end
local function lp_fw(f) return LinearLayout.LayoutParams(0,WRAP,f) end
local function lp_wh(w,h) return LinearLayout.LayoutParams(dp(w),dp(h)) end
local function lp_mw() return LinearLayout.LayoutParams(MATCH,WRAP) end
local function lp_ms0() return LinearLayout.LayoutParams(MATCH,0,1.0) end
local function lp_m1() return LinearLayout.LayoutParams(0,dp(3),1.0) end

local function clean(s)
  if not s then return "" end; s=uni(s)
  s=s:gsub("<br%s*/?>","\n"):gsub("<p[^>]*>","\n"):gsub("</p>","\n")
  s=s:gsub("<h%d[^>]*>","\n"):gsub("</h%d>","\n")
  s=s:gsub("<li[^>]*>","\n\u2022 "):gsub("<[^>]+>","")
  s=s:gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
  s=s:gsub("&nbsp;"," "):gsub("&#?%w+;","")
  s=s:gsub("\n\n\n+","\n\n")
  return (s:match("^%s*(.-)%s*$") or "")
end
local function jval(j,k)
  local v=j:match('"'..k..'":%s*"(.-[^\\])"')
  if not v then return "" end
  return uni(v:gsub('\\"','"'):gsub("\\n","\n"):gsub("\\r",""):gsub("\\t"," "):gsub("\\/","/"))
end
local function jren(j,k)
  local b=j:match('"'..k..'":%s*(%b{})'); if b then return jval(b,"rendered") end; return ""
end
local function parsePosts(json,site)
  local list,pos={},1
  while #list<15 do
    local s=json:find("{",pos,true); if not s then break end
    local d,j=0,s
    while j<=#json do
      local c=json:sub(j,j)
      if c=="{" then d=d+1 elseif c=="}" then d=d-1; if d==0 then break end end; j=j+1
    end
    local obj=json:sub(s,j)
    local title=clean(jren(obj,"title"))
    if title=="" then title=uni(jval(obj,"slug"):gsub("-"," ")) end
    local exc=clean(jren(obj,"excerpt")); local body=clean(jren(obj,"content"))
    local link=jval(obj,"link")
    if title~="" and body~="" then
      list[#list+1]={title=title,excerpt=exc,body=body,link=link,site=site or ""}
    end
    pos=j+1
  end
  return list
end

local function mkTV(t,c,s,b,desc)
  local v=TextView(activity); v.setText(tostring(uni(t))); v.setTextColor(c); v.setTextSize(s)
  if b then v.setTypeface(Typeface.DEFAULT_BOLD) end
  if desc then
    -- Explicit description always wins
    v.setContentDescription(tostring(uni(desc)))
  elseif t~="" and #t<=120 then
    -- Only auto-set for short UI labels (not story body text)
    v.setContentDescription(tostring(uni(t)))
  end
  -- For long text (>120 chars), TalkBack reads the actual text automatically
  -- Do NOT set contentDescription on body/story text — it would truncate reading
  return v
end
local function mkBtn(t,tc,bg,s,desc)
  local b=Button(activity); b.setText(tostring(uni(t))); b.setTextColor(tc)
  if bg then b.setBackgroundColor(bg) end; b.setTextSize(s or 14)
  local cd = desc or t
  if cd~="" then b.setContentDescription(tostring(uni(cd))) end
  return b
end
local function mkRow()
  local r=LinearLayout(activity); r.setOrientation(LinearLayout.HORIZONTAL)
  r.setGravity(Gravity.CENTER_VERTICAL); return r
end
local function mkCol()
  local c=LinearLayout(activity); c.setOrientation(LinearLayout.VERTICAL); return c
end

-- ─────────────────────────────────────────────
--  HTTP + FETCH  (WordPress REST API)
-- ─────────────────────────────────────────────
local function httpGet(url,onDone,onErr)
  Http.get(url,function(code,body)
    if code==200 and body and #body>0 then onDone(body)
    else onErr("HTTP "..tostring(code)) end
  end)
end

local function fetchStories(catIdx,onReady,onFail)
  local cat=CATEGORIES[catIdx]
  local ckey=cat.base.."|"..cat.slug
  if storyCache[ckey] then onReady(storyCache[ckey]); return end

  local function getPosts(cid)
    local url=cat.base.."/posts?categories="..cid
      .."&per_page=12&orderby=date&order=desc"
      .."&_fields=title,excerpt,content,link"
    httpGet(url,function(body)
      local l=parsePosts(body,cat.site); storyCache[ckey]=l; onReady(l)
    end,onFail)
  end

  local idkey=cat.base.."|cat|"..cat.slug
  if catIdCache[idkey] then getPosts(catIdCache[idkey]); return end

  httpGet(cat.base.."/categories?slug="..cat.slug.."&per_page=1",
    function(body)
      local cid=body:match('"id":(%d+)')
      if not cid then onFail("Category not found: "..cat.slug.." on "..cat.site); return end
      catIdCache[idkey]=cid; getPosts(cid)
    end,onFail)
end

-- ══════════════════════════════════════════════
--  SCREEN 3: READER
-- ══════════════════════════════════════════════
local function buildReader(s,idx)
  local acc=CAT_COLORS[curCat] or C.purple
  local icon=CAT_ICONS[curCat]
  local bkey=curCat.."_"..idx
  local root=mkCol(); root.setBackgroundColor(bgC()); screenReader=root

  -- TOP BAR
  local bar=mkRow(); bar.setBackgroundColor(acc); bar.setPadding(dp(2),dp(4),dp(8),dp(4))
  local bkBtn=mkBtn("\u2039",C.white,0,30,"\u0935\u093E\u092A\u0938 \u091C\u093E\u090F\u0902"); bkBtn.setLayoutParams(lp_wh(48,48)); bar.addView(bkBtn)
  local tvT=mkTV(s.title,C.white,15,true,"\u0915\u0939\u093E\u0928\u0940: "..s.title); tvT.setMaxLines(2); tvT.setLayoutParams(lp_fw(1.0)); bar.addView(tvT)
  local bmBtn=mkBtn(bookmarks[bkey] and "\u2605" or "\u2606",C.amberLight,0,24,
    bookmarks[bkey] and "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0939\u091F\u093E\u090F\u0902" or "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0915\u0930\u0947\u0902")
  bmBtn.setLayoutParams(lp_wh(48,48)); bar.addView(bmBtn)
  root.addView(bar)

  -- FONT BAR
  local fbar=mkRow(); fbar.setBackgroundColor(night and 0xff1a0035 or 0xfff3e5f5)
  fbar.setPadding(dp(16),dp(6),dp(16),dp(6))
  local fLbl=mkTV("\u0905\u0915\u094D\u0937\u0930 \u0906\u0915\u093E\u0930",subC(),12,false); fLbl.setLayoutParams(lp_fw(1.0)); fbar.addView(fLbl)
  local amBtn=mkBtn("A-",C.white,0,12,"\u0905\u0915\u094D\u0937\u0930 \u091B\u094B\u091F\u093E \u0915\u0930\u0947\u0902"); amBtn.setBackground(rr(acc,20))
  local lpAm=lp_wh(48,34); lpAm.setMargins(0,0,dp(8),0); amBtn.setLayoutParams(lpAm); fbar.addView(amBtn)
  local apBtn=mkBtn("A+",C.white,0,12,"\u0905\u0915\u094D\u0937\u0930 \u092C\u095C\u093E \u0915\u0930\u0947\u0902"); apBtn.setBackground(rr(acc,20)); apBtn.setLayoutParams(lp_wh(48,34)); fbar.addView(apBtn)
  root.addView(fbar)

  -- Reading progress bar
  local progBar=View(activity); progBar.setBackgroundColor(acc)
  local progLp=LinearLayout.LayoutParams(0,dp(3)); progBar.setLayoutParams(progLp)
  local progRow=LinearLayout(activity); progRow.setOrientation(LinearLayout.HORIZONTAL)
  progRow.setBackgroundColor(night and 0xff0d0020 or 0xffe8ddf5)
  progRow.setLayoutParams(lp_mw()); progRow.addView(progBar)
  local progBg=View(activity); progBg.setBackgroundColor(0x00000000)
  progBg.setLayoutParams(LinearLayout.LayoutParams(0,dp(3),1.0)); progRow.addView(progBg)
  root.addView(progRow)

  -- SCROLL
  local sv=ScrollView(activity); sv.setLayoutParams(lp_ms0()); sv.setBackgroundColor(bgC())
  local cont=mkCol(); cont.setPadding(dp(20),dp(20),dp(20),dp(40))

  -- Category pill (decorative)
  local pill=mkTV("  "..icon.." "..CATEGORIES[curCat].name.."  ",C.white,11,true)
  pill.setBackground(rr(acc,30))
  pill.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO)
  cont.addView(pill)

  -- Source site
  if s.site and s.site~="" then
    local sl=mkTV("\u1F4CC "..s.site,subC(),11,false,"\u0938\u094D\u0930\u094B\u0924: "..s.site); sl.setPadding(0,dp(5),0,0); cont.addView(sl)
  end

  -- Title (accessibility heading)
  local hd=mkTV(s.title,acc,24,true,"\u0936\u0940\u0930\u094D\u0937\u0915: "..s.title)
  hd.setLineSpacing(dp(4),1.1); hd.setPadding(0,dp(10),0,dp(8))
  pcall(function() hd.setAccessibilityHeading(true) end)
  cont.addView(hd)

  -- Excerpt
  if s.excerpt~="" then
    local ex=mkTV(s.excerpt:sub(1,200),subC(),14,false)
    ex.setTypeface(Typeface.create(Typeface.DEFAULT,Typeface.ITALIC))
    ex.setLineSpacing(dp(2),1.2); ex.setPadding(0,0,0,dp(12)); cont.addView(ex)
  end

  -- Divider (purely decorative)
  local dr=mkRow(); dr.setGravity(Gravity.CENTER_VERTICAL); dr.setPadding(0,0,0,dp(18))
  dr.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO)
  local d1=View(activity); d1.setBackgroundColor(acc); d1.setLayoutParams(lp_wh(40,3)); dr.addView(d1)
  local dot=mkTV("  \u2726  ",acc,14,false); dr.addView(dot)
  local d2=View(activity); d2.setBackgroundColor(acc); d2.setLayoutParams(lp_m1()); dr.addView(d2)
  cont.addView(dr)

  -- Body (main story text)
  -- !! KEY FIX: Do NOT set contentDescription on body !!
  -- TalkBack reads the actual setText() content in full automatically.
  -- We also split into paragraphs so TalkBack can navigate sentence by sentence.
  local bodyTV = nil  -- reference to first para for font resize fallback
  local paragraphs = {}
  for para in (s.body.."\n\n"):gmatch("(.-)\n\n") do
    local trimmed = para:match("^%s*(.-)%s*$")
    if trimmed ~= "" then paragraphs[#paragraphs+1] = trimmed end
  end
  -- If no paragraph breaks found, use full body as one block
  if #paragraphs == 0 then paragraphs = {s.body} end

  for pi, para in ipairs(paragraphs) do
    local pTV = TextView(activity)
    pTV.setText(tostring(para))
    pTV.setTextColor(txtC())
    pTV.setTextSize(fsize)
    pTV.setLineSpacing(dp(6), 1.4)
    pTV.setPadding(0, 0, 0, dp(pi==#paragraphs and 30 or 14))
    pTV.setTextIsSelectable(true)
    -- Let TalkBack read the real text — NO contentDescription override
    pTV.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES)
    pTV.setFocusable(false)  -- don't steal focus, just be readable
    cont.addView(pTV)
    -- Keep reference to first paragraph for font resize
    if pi == 1 then bodyTV = pTV end
  end

  -- Store all paragraph views for font resize
  local allParaViews = {}
  for i = cont.getChildCount()-#paragraphs, cont.getChildCount()-1 do
    pcall(function() allParaViews[#allParaViews+1] = cont.getChildAt(i) end)
  end

  -- Source link
  if s.link and s.link~="" then
    local srcTV=mkTV("\u0938\u094D\u0930\u094B\u0924: "..(s.site or ""),subC(),11,false); cont.addView(srcTV)
  end

  sv.addView(cont); root.addView(sv)

  -- BOTTOM BAR
  local btm=mkRow(); btm.setBackgroundColor(night and 0xff1a0035 or 0xfff3e5f5)
  btm.setPadding(dp(12),dp(10),dp(12),dp(10)); btm.setGravity(Gravity.CENTER)
  local shBtn=mkBtn("\u0936\u0947\u092F\u0930 \u0915\u0930\u0947\u0902",C.white,0,14,s.title.." \u0936\u0947\u092F\u0930 \u0915\u0930\u0947\u0902"); shBtn.setTypeface(Typeface.DEFAULT_BOLD)
  shBtn.setBackground(rr(acc,24)); local lsh=lp_fw(1.0); lsh.setMargins(0,0,dp(10),0); shBtn.setLayoutParams(lsh); btm.addView(shBtn)
  local bm2Btn=mkBtn(bookmarks[bkey] and "\u2605 Saved" or "\u2606 Save",acc,0,14,
    bookmarks[bkey] and "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0939\u091F\u093E\u090F\u0902" or "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0915\u0930\u0947\u0902")
  bm2Btn.setBackground(rr(cardC(),24,acc,2)); bm2Btn.setLayoutParams(lp_fw(1.0)); btm.addView(bm2Btn)
  root.addView(btm)

  -- Events
  bkBtn.onClick=function() goBack() end
  local function rfBm()
    local m=bookmarks[bkey]
    bmBtn.setText(tostring(uni(m and "\u2605" or "\u2606")))
    bmBtn.setContentDescription(tostring(uni(m and "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0939\u091F\u093E\u090F\u0902" or "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0915\u0930\u0947\u0902")))
    bm2Btn.setText(tostring(uni(m and "\u2605 Saved" or "\u2606 Save")))
    bm2Btn.setContentDescription(tostring(uni(m and "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0939\u091F\u093E\u090F\u0902" or "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0915\u0930\u0947\u0902")))
  end
  bmBtn.onClick=function()  bookmarks[bkey]=not bookmarks[bkey]; rfBm(); toast(bookmarks[bkey] and "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0915\u093F\u092F\u093E \u2713" or "\u0939\u091F\u093E\u092F\u093E") end
  bm2Btn.onClick=function() bookmarks[bkey]=not bookmarks[bkey]; rfBm(); toast(bookmarks[bkey] and "\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0915\u093F\u092F\u093E \u2713" or "\u0939\u091F\u093E\u092F\u093E") end
  amBtn.onClick=function()
    if fsize>12 then fsize=fsize-1
      for _,pv in ipairs(allParaViews) do pcall(function() pv.setTextSize(fsize) end) end
      toast("Font "..fsize)
    end
  end
  apBtn.onClick=function()
    if fsize<30 then fsize=fsize+1
      for _,pv in ipairs(allParaViews) do pcall(function() pv.setTextSize(fsize) end) end
      toast("Font "..fsize)
    end
  end
  shBtn.onClick=function()
    local i=Intent(Intent.ACTION_SEND); i.setType("text/plain")
    i.putExtra(Intent.EXTRA_SUBJECT,s.title)
    local txt=s.title.."\n\n"..s.body:sub(1,500).."..."
    if s.link and s.link~="" then txt=txt.."\n\n\u092A\u0942\u0930\u0940 \u0915\u0939\u093E\u0928\u0940: "..s.link end
    i.putExtra(Intent.EXTRA_TEXT,txt.."\n\n\u2014 \u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u0940 App")
    activity.startActivity(Intent.createChooser(i,"\u0936\u0947\u092F\u0930 \u0915\u0930\u0947\u0902"))
  end
  return root
end

-- ══════════════════════════════════════════════
--  SCREEN 2: STORY LIST
-- ══════════════════════════════════════════════
local function buildStoryList(catIdx)
  curCat=catIdx
  local cat=CATEGORIES[catIdx]; local acc=CAT_COLORS[catIdx] or C.purple; local icon=CAT_ICONS[catIdx]
  local root=mkCol(); root.setBackgroundColor(bgC()); screenList=root

  -- HEADER
  local hdr=mkCol(); hdr.setBackground(gr(acc,C.purpleDeep,0))
  local topBar=mkRow(); topBar.setPadding(dp(2),dp(8),dp(16),dp(4))
  local bkBtn=mkBtn("\u2039",C.white,0,30,"\u0935\u093E\u092A\u0938 \u0936\u094D\u0930\u0947\u0923\u0940 \u0938\u0942\u091A\u0940 \u092E\u0947\u0902 \u091C\u093E\u090F\u0902"); bkBtn.setLayoutParams(lp_wh(48,48)); topBar.addView(bkBtn)
  local ttl=mkTV(icon.." "..cat.name,C.white,18,true); ttl.setMaxLines(2); ttl.setLayoutParams(lp_fw(1.0)); topBar.addView(ttl)
  local nmBtn=mkBtn(night and "\u2600" or "\u1F319",C.white,0,16); nmBtn.setBackground(rr(0x33ffffff,22)); nmBtn.setLayoutParams(lp_wh(42,42)); topBar.addView(nmBtn)
  hdr.addView(topBar)
  local srcLbl=mkTV("\u1F4E1 "..cat.site.."  \u2022  "..cat.desc,0xccffffff,12,false)
  srcLbl.setPadding(dp(56),0,dp(16),dp(6)); hdr.addView(srcLbl)

  -- Search bar
  local searchRow=mkRow(); searchRow.setPadding(dp(14),dp(6),dp(14),dp(12))
  local et=EditText(activity)
  et.setHint(tostring(uni("\u0915\u0939\u093E\u0928\u0940 \u0922\u0942\u0902\u0922\u0947\u0902...")))
  et.setHintTextColor(0xaaffffff); et.setTextColor(C.white); et.setTextSize(14)
  et.setBackground(rr(0x33ffffff,24)); et.setPadding(dp(14),dp(10),dp(14),dp(10))
  et.setSingleLine(true)
  et.setLayoutParams(lp_fw(1.0))
  local clrBtn=mkBtn("\u2715",C.white,0,16,"\u0916\u094B\u091C \u0938\u093E\u092B \u0915\u0930\u0947\u0902")
  clrBtn.setBackground(rr(0x33ffffff,20)); clrBtn.setLayoutParams(lp_wh(40,40))
  clrBtn.setVisibility(View.GONE)
  searchRow.addView(et); searchRow.addView(clrBtn)
  hdr.addView(searchRow)
  root.addView(hdr)

  -- LIST
  local sv=ScrollView(activity); sv.setLayoutParams(lp_ms0()); sv.setBackgroundColor(bgC())
  local lb=mkCol(); lb.setPadding(dp(14),dp(14),dp(14),dp(14)); lb.setBackgroundColor(bgC())
  sv.addView(lb); root.addView(sv)

  -- Scroll-to-top FAB
  local fabFrame=FrameLayout(activity)
  local fabLp=LinearLayout.LayoutParams(MATCH,dp(56))
  fabLp.setMargins(0,-dp(56),0,0); fabFrame.setLayoutParams(fabLp)
  local fab=mkBtn("\u2191 \u0936\u0940\u0930\u094D\u0937",C.white,0,12,"\u0936\u0940\u0930\u094D\u0937 \u092A\u0930 \u091C\u093E\u090F\u0902")
  fab.setBackground(rr(acc,24))
  local fabBtnLp=FrameLayout.LayoutParams(dp(110),dp(38))
  fabBtnLp.gravity=Gravity.RIGHT+Gravity.CENTER_VERTICAL
  fabBtnLp.setMargins(0,0,dp(16),0); fab.setLayoutParams(fabBtnLp)
  fab.setVisibility(View.GONE)
  fabFrame.addView(fab); root.addView(fabFrame)
  sv.setOnScrollChangeListener(luajava.createProxy("android.view.View$OnScrollChangeListener",{
    onScrollChange=function(v,x,y,ox,oy)
      if y>dp(300) then fab.setVisibility(View.VISIBLE)
      else fab.setVisibility(View.GONE) end
    end
  }))
  fab.onClick=function() sv.smoothScrollTo(0,0) end

  local ft=mkTV(cat.site.."  |  \u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u0940 App",0xaaffffff,10,false)
  ft.setGravity(Gravity.CENTER); ft.setBackgroundColor(acc); ft.setPadding(0,dp(6),0,dp(6)); root.addView(ft)

  local function showSpinner()
    lb.removeAllViews(); lb.setBackgroundColor(bgC()); sv.setBackgroundColor(bgC()); root.setBackgroundColor(bgC())
    local tv=mkTV("\n\n"..icon.."  "..cat.name.." \u0932\u094B\u0921 \u0939\u094B \u0930\u0939\u093E \u0939\u0948...",acc,16,false)
    tv.setGravity(Gravity.CENTER); tv.setPadding(0,dp(40),0,dp(20)); lb.addView(tv)
    local pb=ProgressBar(activity); local lp=lp_wh(48,48); lp.gravity=Gravity.CENTER_HORIZONTAL; pb.setLayoutParams(lp); lb.addView(pb)
  end

  local fullList=nil  -- keep original for search filter

  local function showStories(list,isErr)
    if not isErr and list then fullList=list end
    lb.removeAllViews(); lb.setBackgroundColor(bgC()); sv.setBackgroundColor(bgC()); root.setBackgroundColor(bgC())
    if isErr then
      local errCol=mkCol(); errCol.setGravity(Gravity.CENTER); errCol.setPadding(dp(20),dp(40),dp(20),dp(20))
      local tv=mkTV("\u26A0  \u0932\u094B\u0921 \u0928\u0939\u0940\u0902 \u0939\u094B \u0938\u0915\u093E",C.red,16,true)
      tv.setGravity(Gravity.CENTER); errCol.addView(tv)
      local tv2=mkTV("\u0907\u0902\u091F\u0930\u0928\u0947\u091F \u091C\u093E\u0901\u091A\u0947\u0902 \u0914\u0930 \u092A\u0941\u0928\u0903 \u092A\u094D\u0930\u092F\u093E\u0938 \u0915\u0930\u0947\u0902",subC(),13,false)
      tv2.setGravity(Gravity.CENTER); tv2.setPadding(0,dp(8),0,dp(20)); errCol.addView(tv2)
      local retryBtn=mkBtn("  \u21BA  \u092A\u0941\u0928\u0903 \u092A\u094D\u0930\u092F\u093E\u0938 \u0915\u0930\u0947\u0902",C.white,0,14)
      retryBtn.setBackground(rr(C.red,24))
      local lpr=lp_mw(); lpr.setMargins(dp(40),0,dp(40),0); retryBtn.setLayoutParams(lpr)
      retryBtn.onClick=function()
        storyCache[cat.base.."|"..cat.slug]=nil
        catIdCache[cat.base.."|cat|"..cat.slug]=nil
        showSpinner()
        fetchStories(catIdx,function(l) showStories(l,false) end,function(e) showStories({},true) end)
      end
      errCol.addView(retryBtn)
      lb.addView(errCol); return
    end
    if #list==0 then
      -- Show offline fallback stories
      local offRow=mkRow(); offRow.setPadding(dp(4),0,dp(4),dp(8))
      local offTv=mkTV("\u26A0 \u0911\u092B\u0932\u093E\u0907\u0928 \u2014 \u0938\u094D\u0925\u093E\u0928\u0940\u092F \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",C.orange,12,true)
      offTv.setLayoutParams(lp_fw(1.0)); offRow.addView(offTv); lb.addView(offRow)
      list=OFFLINE_STORIES
    end
    local cntRow=mkRow(); cntRow.setPadding(dp(4),0,dp(4),dp(12))
    local cnt=mkTV(icon.." "..#list.." \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",subC(),12,true); cnt.setLayoutParams(lp_fw(1.0)); cntRow.addView(cnt)
    local siteBadge=mkTV("  "..cat.site.."  ",C.white,9,false); siteBadge.setBackground(rr(acc,20)); cntRow.addView(siteBadge)
    lb.addView(cntRow)

    for i,s in ipairs(list) do
      local card=mkCol(); card.setBackground(rr(cardC(),16,night and 0x33ffffff or 0x22000000,1))
      local lpc=lp_mw(); lpc.setMargins(0,0,0,dp(12)); card.setLayoutParams(lpc); card.setClickable(true)
      -- a11y: card announces story number, title and excerpt
      local cardDesc = tostring(i)..". "..s.title
      if s.excerpt~="" then cardDesc = cardDesc..". "..s.excerpt:sub(1,80) end
      cardDesc = cardDesc..". \u0921\u0947\u0924\u094D\u0928 \u0932\u0947 \u0920\u0947\u0939\u094D\u0928\u0941\u0939\u094B\u0938\u094D."  -- tap to read
      card.setContentDescription(tostring(uni(cardDesc)))
      card.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES)

      -- colour strip (decorative, hide from a11y)
      local strip=View(activity); strip.setBackground(rr(acc,16))
      strip.setLayoutParams(LinearLayout.LayoutParams(MATCH,dp(5)))
      strip.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO)
      card.addView(strip)

      local inner=mkCol(); inner.setPadding(dp(16),dp(12),dp(16),dp(14))
      local row=mkRow()
      -- number badge (decorative)
      local num=mkTV(tostring(i),C.white,12,true); num.setGravity(Gravity.CENTER); num.setBackground(rr(acc,20))
      num.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO)
      local lpn=lp_wh(28,28); lpn.setMargins(0,0,dp(10),0); num.setLayoutParams(lpn); row.addView(num)
      local ti=mkTV(s.title,txtC(),16,true); ti.setMaxLines(3); ti.setLayoutParams(lp_fw(1.0)); row.addView(ti)
      inner.addView(row)

      if s.excerpt~="" then
        local ex=s.excerpt:sub(1,100); if #s.excerpt>100 then ex=ex.."\u2026" end
        local et=mkTV(ex,subC(),13,false); et.setLineSpacing(dp(2),1.2); et.setPadding(dp(38),dp(6),0,dp(6)); inner.addView(et)
      end

      -- Reading time estimate
      local wc = #s.body:gsub("[^%s]+","x"):gsub("[^x]","")
      local mins = math.max(1, math.floor(wc/200))
      local rtRow=mkRow(); rtRow.setPadding(dp(38),0,0,dp(6))
      local rtTv=mkTV("\u23F1 "..mins.." \u092E\u093F\u0928\u091F",subC(),11,false); rtTv.setLayoutParams(lp_fw(1.0)); rtRow.addView(rtTv)
      if bookmarks[tostring(curCat).."_"..tostring(i)] then
        local bmk=mkTV(" \u2605 ",C.amberLight,13,false); rtRow.addView(bmk)
      end
      inner.addView(rtRow)

      local br=mkRow(); br.setGravity(Gravity.RIGHT); br.setPadding(0,dp(4),0,0)
      local rd=mkBtn("\u092A\u0922\u093C\u0947\u0902  \u2192",C.white,0,13,s.title.." \u092A\u0922\u093C\u0947\u0902")
      rd.setTypeface(Typeface.DEFAULT_BOLD)
      rd.setBackground(rr(acc,24)); rd.setLayoutParams(lp_wh(120,40)); br.addView(rd)
      inner.addView(br); card.addView(inner)

      local ci,cs=i,s
      local function open()
        -- Track history
        local entry={title=cs.title,catIdx=catIdx,si=ci,ts=os.time()}
        table.insert(readHistory,1,entry)
        if #readHistory>maxHistory then table.remove(readHistory) end
        table.insert(navStack,"reader"); activity.setContentView(buildReader(cs,ci))
      end
      rd.onClick=open; card.onClick=open; lb.addView(card)
    end
  end

  showSpinner()
  fetchStories(catIdx,function(l) showStories(l,false) end,
    function(e) showStories({},true); toast("ERR: "..tostring(e):sub(1,60)) end)

  bkBtn.onClick=function() goBack() end

  -- Search events
  et.addTextChangedListener(luajava.createProxy("android.text.TextWatcher",{
    beforeTextChanged=function() end,
    onTextChanged=function() end,
    afterTextChanged=function(s2)
      local q=tostring(et.getText()):lower():gsub("^%s+",""):gsub("%s+$","")
      if q=="" then
        clrBtn.setVisibility(View.GONE)
        if fullList then showStories(fullList,false) end
      else
        clrBtn.setVisibility(View.VISIBLE)
        if fullList then
          local filtered={}
          for _,s in ipairs(fullList) do
            if s.title:lower():find(q,1,true) or
               (s.excerpt or ""):lower():find(q,1,true) or
               (s.body or ""):lower():find(q,1,true) then
              filtered[#filtered+1]=s
            end
          end
          showStories(filtered,false)
          if #filtered==0 then
            local tv=mkTV("\u2716 \""..(et.getText()).."\": \u0928\u0939\u0940\u0902 \u092E\u093F\u0932\u093E",subC(),14,false)
            tv.setGravity(Gravity.CENTER); tv.setPadding(0,dp(30),0,0); lb.addView(tv)
          end
        end
      end
    end
  }))
  clrBtn.onClick=function() et.setText(""); clrBtn.setVisibility(View.GONE); if fullList then showStories(fullList,false) end end

  nmBtn.onClick=function()
    night=not night; table.remove(navStack); local nl=buildStoryList(catIdx); table.insert(navStack,"list"); activity.setContentView(nl)
  end
  return root
end


-- ══════════════════════════════════════════════
--  BOOKMARKS SCREEN
-- ══════════════════════════════════════════════
local function buildBookmarksScreen()
  local root=mkCol(); root.setBackgroundColor(bgC()); screenBookmarks=root
  local bar=mkRow(); bar.setBackgroundColor(C.purple); bar.setPadding(dp(2),dp(4),dp(8),dp(4))
  local bkBtn=mkBtn("\u2039",C.white,0,30,"\u0935\u093E\u092A\u0938"); bkBtn.setLayoutParams(lp_wh(48,48)); bar.addView(bkBtn)
  bar.addView(mkTV("  \u2605 \u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915",C.white,18,true))
  root.addView(bar)

  local sv=ScrollView(activity); sv.setLayoutParams(lp_ms0())
  local lb=mkCol(); lb.setPadding(dp(14),dp(14),dp(14),dp(14)); lb.setBackgroundColor(bgC())
  sv.addView(lb); root.addView(sv)

  -- Collect bookmarked stories from cache
  local blist={}
  for catIdx,cat in ipairs(CATEGORIES) do
    local ckey=cat.base.."|"..cat.slug
    local stories=storyCache[ckey] or {}
    for si,s in ipairs(stories) do
      local bkey=tostring(catIdx).."_"..tostring(si)
      if bookmarks[bkey] then
        blist[#blist+1]={s=s, catIdx=catIdx, si=si, acc=CAT_COLORS[catIdx]}
      end
    end
  end

  if #blist==0 then
    local tv=mkTV("\u2605 \u0905\u092D\u0940 \u0915\u094B\u0908 \u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915 \u0928\u0939\u0940\u0902\n\u092A\u0922\u093C\u0924\u0947 \u0938\u092E\u092F \u2606 \u0926\u092C\u093E\u090F\u0902",subC(),15,false)
    tv.setGravity(Gravity.CENTER); tv.setPadding(dp(20),dp(60),dp(20),0); lb.addView(tv)
  else
    lb.addView(mkTV("\u2605 "..#blist.." \u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915",subC(),12,true))
    for _,entry in ipairs(blist) do
      local s,acc=entry.s,entry.acc
      local card=mkCol(); card.setBackground(rr(cardC(),14,acc,2)); card.setClickable(true)
      local lpc=lp_mw(); lpc.setMargins(0,dp(6),0,0); card.setLayoutParams(lpc)
      card.setPadding(dp(14),dp(12),dp(14),dp(12))
      card.addView(mkTV(CATEGORIES[entry.catIdx].name,acc,10,true))
      card.addView(mkTV(s.title,txtC(),16,true))
      if s.excerpt~="" then card.addView(mkTV(s.excerpt:sub(1,80),subC(),12,false)) end
      local ci,cs=entry.catIdx,s
      card.onClick=function()
        curCat=ci; table.insert(navStack,"reader")
        activity.setContentView(buildReader(cs,entry.si))
      end
      lb.addView(card)
    end
  end

  bkBtn.onClick=function() table.remove(navStack); activity.setContentView(screenHome) end
  return root
end


-- ══════════════════════════════════════════════
--  HISTORY SCREEN
-- ══════════════════════════════════════════════
local function buildHistoryScreen()
  local root=mkCol(); root.setBackgroundColor(bgC()); screenHistory=root
  local bar=mkRow(); bar.setBackgroundColor(C.purple); bar.setPadding(dp(2),dp(4),dp(8),dp(4))
  local bkBtn=mkBtn("\u2039",C.white,0,30,"\u0935\u093E\u092A\u0938"); bkBtn.setLayoutParams(lp_wh(48,48)); bar.addView(bkBtn)
  bar.addView(mkTV("  \u1F4D6 \u0939\u093E\u0932 \u092E\u0947\u0902 \u092A\u0922\u093C\u093E",C.white,18,true))
  local clrBtn=mkBtn("\u1F5D1",C.white,0,16,"\u0907\u0924\u093F\u0939\u093E\u0938 \u0938\u093E\u092B \u0915\u0930\u0947\u0902")
  clrBtn.setBackground(rr(0x33ffffff,20)); clrBtn.setLayoutParams(lp_wh(40,40))
  bar.addView(clrBtn); root.addView(bar)

  local sv=ScrollView(activity); sv.setLayoutParams(lp_ms0())
  local lb=mkCol(); lb.setPadding(dp(14),dp(14),dp(14),dp(14)); lb.setBackgroundColor(bgC())
  sv.addView(lb); root.addView(sv)

  local function renderHistory()
    lb.removeAllViews()
    if #readHistory==0 then
      local tv=mkTV("\u1F4D6 \u0905\u092D\u0940 \u0915\u094B\u0908 \u0907\u0924\u093F\u0939\u093E\u0938 \u0928\u0939\u0940\u0902\n\u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901 \u092A\u0922\u093C\u0928\u093E \u0936\u0941\u0930\u0942 \u0915\u0930\u0947\u0902",subC(),15,false)
      tv.setGravity(Gravity.CENTER); tv.setPadding(dp(20),dp(60),dp(20),0); lb.addView(tv); return
    end
    lb.addView(mkTV("\u1F4D6 "..#readHistory.." \u0939\u093E\u0932 \u0915\u0940 \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",subC(),12,true))
    for idx,entry in ipairs(readHistory) do
      if idx>30 then break end
      local cat=CATEGORIES[entry.catIdx] or {name="?",site="?"}
      local acc=CAT_COLORS[entry.catIdx] or C.purple
      local card=mkCol(); card.setBackground(rr(cardC(),12,night and 0x22ffffff or 0x11000000,1))
      local lpc=lp_mw(); lpc.setMargins(0,0,0,dp(8)); card.setLayoutParams(lpc)
      card.setPadding(dp(14),dp(10),dp(14),dp(10)); card.setClickable(true)
      local row=mkRow()
      local dot=mkTV("\u25CF",acc,14,false); dot.setPadding(0,0,dp(10),0); row.addView(dot)
      local col=mkCol(); col.setLayoutParams(lp_fw(1.0))
      col.addView(mkTV(entry.title,txtC(),15,true))
      col.addView(mkTV(cat.name.."  \u2022  "..cat.site,subC(),10,false))
      row.addView(col)
      card.addView(row)
      local ci,cs=entry.catIdx,entry
      card.onClick=function()
        -- Re-open from cache if available
        local ckey=CATEGORIES[ci].base.."|"..CATEGORIES[ci].slug
        local stories=storyCache[ckey] or {}
        if stories[cs.si] then
          curCat=ci; table.insert(navStack,"reader")
          activity.setContentView(buildReader(stories[cs.si],cs.si))
        else
          toast("\u0915\u0948\u0936 \u0916\u093E\u0932\u0940 \u2014 \u0936\u094D\u0930\u0947\u0923\u0940 \u0938\u0947 \u092A\u0922\u093C\u0947\u0902")
        end
      end
      lb.addView(card)
    end
  end
  renderHistory()

  bkBtn.onClick=function() table.remove(navStack); activity.setContentView(screenHome) end
  clrBtn.onClick=function()
    readHistory={}; renderHistory()
    toast("\u0907\u0924\u093F\u0939\u093E\u0938 \u0938\u093E\u092B \u2713")
  end
  return root
end

-- ══════════════════════════════════════════════
--  SCREEN 1: HOME -- 2-column grid, 2 sections
-- ══════════════════════════════════════════════
local function buildHome()
  local root=mkCol(); root.setBackgroundColor(bgC()); screenHome=root

  -- ── DRAWER PANEL (slide-in from right, hidden by default) ──
  -- We use a FrameLayout overlay approach
  local frame=FrameLayout(activity)
  frame.setLayoutParams(LinearLayout.LayoutParams(MATCH,0,1.0))

  -- Main content column inside frame
  local mainCol=mkCol(); mainCol.setBackgroundColor(bgC())
  mainCol.setLayoutParams(FrameLayout.LayoutParams(MATCH,MATCH))

  -- Drawer overlay (right side panel)
  local drawerBg=View(activity)
  drawerBg.setBackgroundColor(0x88000000)
  drawerBg.setLayoutParams(FrameLayout.LayoutParams(MATCH,MATCH))
  drawerBg.setVisibility(View.GONE)

  local drawer=mkCol()
  drawer.setBackgroundColor(night and 0xff1a003a or 0xffffffff)
  local drawerLp=FrameLayout.LayoutParams(dp(270),MATCH)
  drawerLp.gravity=Gravity.RIGHT
  drawer.setLayoutParams(drawerLp)
  drawer.setVisibility(View.GONE)
  drawer.setPadding(0,0,0,0)

  local function openDrawer()
    drawerBg.setVisibility(View.VISIBLE)
    drawer.setVisibility(View.VISIBLE)
  end
  local function closeDrawer()
    drawerBg.setVisibility(View.GONE)
    drawer.setVisibility(View.GONE)
  end
  drawerBg.onClick=function() closeDrawer() end

  -- ── DRAWER CONTENT ──
  -- Header
  local dh=mkCol(); dh.setBackgroundColor(C.purple); dh.setPadding(dp(20),dp(40),dp(20),dp(20))
  dh.addView(mkTV("\u2630  \u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u0940",C.white,20,true))
  dh.addView(mkTV("Menu & Settings",0xccffffff,12,false))
  drawer.addView(dh)

  local dsv=ScrollView(activity)
  dsv.setLayoutParams(LinearLayout.LayoutParams(MATCH,0,1.0))
  local dc=mkCol(); dc.setPadding(dp(8),dp(8),dp(8),dp(16))

  -- Helper: drawer menu item
  local function dItem(icon,label,onClick)
    local item=mkRow(); item.setPadding(dp(14),dp(16),dp(14),dp(16)); item.setClickable(true)
    item.setBackground(rr(night and 0xff2a0050 or 0xfff5f5f5,12))
    local lpi=lp_mw(); lpi.setMargins(0,0,0,dp(6)); item.setLayoutParams(lpi)
    local ic=mkTV(icon,C.purple,22,false); ic.setPadding(0,0,dp(14),0); item.addView(ic)
    local lb=mkTV(label,night and C.txtNight or C.txtDay,15,false); lb.setLayoutParams(lp_fw(1.0)); item.addView(lb)
    local ar=mkTV("\u203A",C.purple,20,false); item.addView(ar)
    item.onClick=onClick; dc.addView(item)
  end

  -- Section label
  local function dSec(text)
    local t=mkTV(text,subC(),11,true); t.setPadding(dp(14),dp(16),0,dp(6)); dc.addView(t)
  end

  -- ── EXPANDABLE ACCORDION ITEM ──
  -- Creates a collapsible section: header taps to show/hide children
  local function dAccordion(icon, title, buildChildren)
    local expanded = false

    -- Header row
    local head=mkRow(); head.setPadding(dp(14),dp(16),dp(14),dp(16)); head.setClickable(true)
    head.setBackground(rr(night and 0xff2a0050 or 0xfff0ebff,12))
    local lph=lp_mw(); lph.setMargins(0,0,0,dp(4)); head.setLayoutParams(lph)

    local hic=mkTV(icon,C.purple,20,false); hic.setPadding(0,0,dp(12),0); head.addView(hic)
    local hlbl=mkTV(title,night and C.txtNight or C.txtDay,15,true); hlbl.setLayoutParams(lp_fw(1.0)); head.addView(hlbl)
    local arr=mkTV("\u25B6",C.purple,13,false); head.addView(arr)  -- > collapsed

    -- Body container (hidden by default)
    local body=mkCol(); body.setVisibility(View.GONE)
    body.setBackgroundColor(night and 0xff1e0044 or 0xfff8f4ff)
    local lpb=lp_mw(); lpb.setMargins(0,0,0,dp(6)); body.setLayoutParams(lpb)

    -- Build children into body
    buildChildren(body)

    head.onClick=function()
      expanded = not expanded
      if expanded then
        body.setVisibility(View.VISIBLE)
        arr.setText(tostring(uni("\u25BC")))  -- v expanded
      else
        body.setVisibility(View.GONE)
        arr.setText(tostring(uni("\u25B6")))  -- > collapsed
      end
    end

    dc.addView(head)
    dc.addView(body)
  end

  -- ── Child item inside accordion ──
  local function dChild(parent, icon, label, sublabel, onClick)
    local item=mkRow(); item.setPadding(dp(20),dp(12),dp(14),dp(12))
    item.setBackground(rr(0x00000000,0))
    local lpi=lp_mw(); lpi.setMargins(0,0,0,dp(2)); item.setLayoutParams(lpi)
    if onClick then item.setClickable(true) end
    local ic=mkTV(icon,C.purple,18,false); ic.setPadding(0,0,dp(12),0); item.addView(ic)
    local col=mkCol(); col.setLayoutParams(lp_fw(1.0))
    col.addView(mkTV(label,night and C.txtNight or C.txtDay,14,false))
    if sublabel then col.addView(mkTV(sublabel,subC(),11,false)) end
    item.addView(col)
    if onClick then
      local ar2=mkTV("\u203A",subC(),18,false); item.addView(ar2)
      item.onClick=onClick
    end
    parent.addView(item)
    -- divider
    local dv=View(activity); dv.setBackgroundColor(night and 0x22ffffff or 0x11000000)
    dv.setLayoutParams(LinearLayout.LayoutParams(MATCH,dp(1))); parent.addView(dv)
  end

  -- Night mode direct toggle (not expandable -- most used)
  local nightItem=mkRow(); nightItem.setPadding(dp(14),dp(16),dp(14),dp(16)); nightItem.setClickable(true)
  nightItem.setBackground(rr(night and 0xff2a0050 or 0xfff0ebff,12))
  local lpni=lp_mw(); lpni.setMargins(0,0,0,dp(4)); nightItem.setLayoutParams(lpni)
  nightItem.addView(mkTV(night and "\u2600" or "\u1F319",C.purple,20,false))
  local nightLblTv=mkTV((night and "  Day Mode" or "  Night Mode").." \u2014 "..#CATEGORIES.." \u0915\u0939\u093E\u0928\u093F\u092F\u093E\u0901",night and C.txtNight or C.txtDay,14,false)
  nightLblTv.setLayoutParams(lp_fw(1.0)); nightItem.addView(nightLblTv)
  local swTv=mkTV(night and "ON" or "OFF",night and 0xff00e676 or 0xffaaaaaa,12,true); nightItem.addView(swTv)

  dSec("\u2699 QUICK ACTIONS")
  dc.addView(nightItem)

  -- ── SETTINGS accordion ──
  dAccordion("\u2699","\u0938\u0947\u091F\u093F\u0902\u0917\u094D\u0938  (Settings)",function(body)
    -- Font size row inside settings
    local fsRow=mkRow(); fsRow.setPadding(dp(20),dp(14),dp(14),dp(14))
    fsRow.setLayoutParams(lp_mw())
    local fsIc=mkTV("\u1F524",C.purple,18,false); fsIc.setPadding(0,0,dp(12),0); fsRow.addView(fsIc)
    local fsLbl=mkTV("\u0905\u0915\u094D\u0937\u0930 \u0906\u0915\u093E\u0930",night and C.txtNight or C.txtDay,14,false); fsLbl.setLayoutParams(lp_fw(1.0)); fsRow.addView(fsLbl)
    local fsMinus=mkBtn("A-",C.white,0,12); fsMinus.setBackground(rr(C.purple,16)); fsMinus.setLayoutParams(lp_wh(34,34)); fsRow.addView(fsMinus)
    local fsSzTv=mkTV(tostring(fsize),C.purple,14,true); fsSzTv.setPadding(dp(8),0,dp(8),0); fsRow.addView(fsSzTv)
    local fsPlus=mkBtn("A+",C.white,0,12); fsPlus.setBackground(rr(C.purple,16)); fsPlus.setLayoutParams(lp_wh(34,34)); fsRow.addView(fsPlus)
    fsMinus.onClick=function() if fsize>12 then fsize=fsize-1; fsSzTv.setText(tostring(fsize)); toast("Font: "..fsize) end end
    fsPlus.onClick=function()  if fsize<30 then fsize=fsize+1; fsSzTv.setText(tostring(fsize)); toast("Font: "..fsize) end end
    body.addView(fsRow)
    local dv=View(activity); dv.setBackgroundColor(night and 0x22ffffff or 0x11000000); dv.setLayoutParams(LinearLayout.LayoutParams(MATCH,dp(1))); body.addView(dv)

    dChild(body,"\u1F5D1","\u0915\u0948\u0936 \u0938\u093E\u092B \u0915\u0930\u0947\u0902","Clear cached stories -- reload fresh",function()
      storyCache={}; catIdCache={}; closeDrawer()
      toast("\u0915\u0948\u0936 \u0938\u093E\u092B \u2713"); activity.setContentView(buildHome())
    end)
    dChild(body,"\u1F310","\u092D\u093E\u0937\u093E / Language","Hindi UI (default)",nil)
  end)

  -- ── SOURCES accordion ──
  dAccordion("\u1F4E1","Sources  ("..#CATEGORIES.." \u0936\u094D\u0930\u0947\u0923\u093F\u092F\u093E\u0901)",function(body)
    local sources={
      {"\u1F4E1","kahanizone.com","9 categories -- moral, hindi, akbar birbal..."},
      {"\u1F4DD","hindimoralstory.com","3 categories -- moral, hindi, chhoti"},
      {"\u1F4AA","kahanihindime.com","4 categories -- motivational, short, majedar"},
      {"\u2B50","daanitv.com","7 categories -- panchatantra, jadui, folk..."},
      {"\u1F47B","bhootkikahani.com","3 categories -- bhoot, chudail, darawani"},
      {"\u1F480","horrorstoryhindi.com","5 categories -- horror, indian, monster..."},
    }
    for _,s in ipairs(sources) do
      dChild(body,s[1],s[2],s[3],nil)
    end
  end)

  -- ── BOOKMARKS + HISTORY quick buttons ──
  dSec("\u1F4DA LIBRARY")
  dItem("\u2605","\u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915  (Bookmarks)",function()
    closeDrawer()
    table.insert(navStack,"bookmarks")
    activity.setContentView(buildBookmarksScreen())
  end)
  dItem("\u1F4D6","\u0939\u093E\u0932 \u092E\u0947\u0902 \u092A\u0922\u093C\u093E  (History)",function()
    closeDrawer()
    table.insert(navStack,"history")
    activity.setContentView(buildHistoryScreen())
  end)

  -- ── ABOUT accordion ──
  dAccordion("\u2139","About  \u0907\u0938 App \u0915\u0947 \u092C\u093E\u0930\u0947 \u092E\u0947\u0902",function(body)
    dChild(body,"\u1F4F1","Hindi Kahani App","Version 5.2  |  AndroLua+ / Jieshuo+",nil)
    dChild(body,"\u1F4DA","\u0935\u093F\u0935\u0930\u0923","6 \u0938\u094D\u0930\u094B\u0924\u094B\u0902 \u0938\u0947 "..#CATEGORIES.." \u0936\u094D\u0930\u0947\u0923\u093F\u092F\u093E\u0901",nil)
    dChild(body,"\u1F310","\u0935\u0947\u092C\u0938\u093E\u0907\u091F","kahanizone.com \u0914\u0930 \u0905\u0928\u094D\u092F",nil)
    dChild(body,"\u1F512","\u0917\u094B\u092A\u0928\u0940\u092F\u0924\u093E","WordPress REST API \u0938\u0947 \u092A\u0922\u093C\u0940 \u0917\u0908 \u0938\u093E\u0930\u094D\u0935\u091C\u0928\u093F\u0915 \u0938\u093E\u092E\u0917\u094D\u0930\u0940",nil)
  end)

  -- ── DEVELOPER accordion ──
  dAccordion("\u1F9D1\u200D\u1F4BB","Developer  \u0928\u093F\u0930\u094D\u092E\u093E\u0924\u093E",function(body)
    dChild(body,"\u1F527","\u0928\u093F\u0930\u094D\u092E\u093F\u0924","AndroLua+ / Jieshuo+ Lua Script",nil)
    dChild(body,"\u1F4BB","\u092D\u093E\u0937\u093E","Lua 5.3  +  Java Android API",nil)
    dChild(body,"\u1F9E9","Framework","com.androlua.LuaActivity",nil)
    dChild(body,"\u2699","HTTP API","WordPress REST API v2",nil)
    dChild(body,"\u1F4AC","UI","Android Views -- LinearLayout, FrameLayout, ScrollView",nil)
    dChild(body,"\u2B50","Features","\u0928\u093E\u0907\u091F \u092E\u094B\u0921  \u2022  \u092C\u0941\u0915\u092E\u093E\u0930\u094D\u0915  \u2022  \u0936\u0947\u092F\u0930  \u2022  Accessibility",nil)
    dChild(body,"\u1F4EB","Feedback","\u090F\u092A \u092E\u0947\u0902 \u0938\u092E\u0938\u094D\u092F\u093E \u0939\u094B \u0924\u094B \u092A\u0941\u0928\u0903 \u0938\u094D\u0925\u093E\u092A\u093F\u0924 \u0915\u0930\u0947\u0902",function()
      toast("\u0927\u0928\u094D\u092F\u0935\u093E\u0926! \u0906\u092A\u0915\u0940 \u092A\u094D\u0930\u0924\u093F\u0915\u094D\u0930\u093F\u092F\u093E \u092E\u0939\u0924\u094D\u0935\u092A\u0942\u0930\u094D\u0923 \u0939\u0948\u0964")
    end)
  end)

  dsv.addView(dc); drawer.addView(dsv)

  -- Close button at bottom of drawer
  local closeBtn=mkBtn("\u2715  \u0928\u0947\u0935\u093F\u0917\u0947\u0936\u0928 \u092C\u0902\u0926 \u0915\u0930\u0947\u0902",C.white,0,14)
  closeBtn.setBackground(rr(C.purple,0)); closeBtn.setPadding(0,dp(16),0,dp(16))
  closeBtn.setGravity(Gravity.CENTER); closeBtn.onClick=function() closeDrawer() end
  drawer.addView(closeBtn)

  -- Night toggle event (outside accordion so always visible)
  nightItem.onClick=function()
    night=not night; closeDrawer(); activity.setContentView(buildHome())
  end
  -- HEADER
  local hdr=mkCol(); hdr.setBackground(gr(C.purple,C.purpleDeep,0)); hdr.setPadding(dp(16),dp(20),dp(16),dp(18))
  local topRow=mkRow()
  local logo=mkTV("\u1F4D6",C.white,28,false); logo.setPadding(0,0,dp(10),0); topRow.addView(logo)
  local tc=mkCol(); tc.setLayoutParams(lp_fw(1.0))
  tc.addView(mkTV("\u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u0940",C.white,22,true))
  tc.addView(mkTV("6 sources  \u2022  "..#CATEGORIES.." categories",0xaaffffff,10,false))
  topRow.addView(tc)
  -- Hamburger menu button ☰
  local menuBtn=mkBtn("\u2630",C.white,0,22,"\u092E\u0947\u0928\u0942 \u0916\u094B\u0932\u0947\u0902 - \u0938\u0947\u091F\u093F\u0902\u0917\u094D\u0938 \u0914\u0930 \u0938\u094D\u0930\u094B\u0924"); menuBtn.setBackground(rr(0x33ffffff,22)); menuBtn.setLayoutParams(lp_wh(46,46)); topRow.addView(menuBtn)
  hdr.addView(topRow)
  local sub=mkTV("\u0936\u094D\u0930\u0947\u0923\u0940 \u091A\u0941\u0928\u0947\u0902 \u2014 \u0915\u0939\u093E\u0928\u0940 \u092A\u0922\u093C\u0947\u0902",0xccffffff,12,false); sub.setPadding(0,dp(6),0,0); hdr.addView(sub)
  mainCol.addView(hdr)

  local sv=ScrollView(activity); sv.setLayoutParams(lp_ms0()); sv.setBackgroundColor(bgC())
  local grid=mkCol(); grid.setPadding(dp(14),dp(14),dp(14),dp(20)); grid.setBackgroundColor(bgC())

  -- helper: draw one 2-column section of category cards
  local function drawSection(label, from, to)
    local lbl=mkTV(label,subC(),12,true); lbl.setPadding(dp(4),dp(4),0,dp(10)); grid.addView(lbl)
    local row=nil
    for i=from,to do
      local cat=CATEGORIES[i]; local acc=CAT_COLORS[i]; local icon=CAT_ICONS[i]
      local col=(i-from)%2
      if col==0 then
        row=mkRow(); local lr=lp_mw(); lr.setMargins(0,0,0,dp(10)); row.setLayoutParams(lr); grid.addView(row)
      end
      local card=mkCol(); card.setPadding(dp(14),dp(18),dp(14),dp(14))
      card.setBackground(gr(acc,C.purpleDeep,16)); card.setClickable(true)
      -- a11y: describe category to screen reader
      card.setContentDescription(tostring(uni(cat.name..". "..cat.desc..". \u0916\u094B\u0932\u0928\u0947 \u0915\u0947 \u0932\u093F\u090F \u0921\u0947\u0924\u094D\u0928 \u0932\u0947\u0939\u094B\u0938\u094D.")))
      card.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES)
      local lc=lp_fw(1.0)
      if col==0 then lc.setMargins(0,0,dp(6),0) else lc.setMargins(dp(6),0,0,0) end
      card.setLayoutParams(lc)
      local ic=mkTV(icon,C.white,28,false); ic.setGravity(Gravity.CENTER_HORIZONTAL); ic.setPadding(0,0,0,dp(6)); card.addView(ic)
      local nm=mkTV(cat.name,C.white,13,true); nm.setGravity(Gravity.CENTER_HORIZONTAL); nm.setMaxLines(2); card.addView(nm)
      local ds=mkTV(cat.desc,0xccffffff,9,false); ds.setGravity(Gravity.CENTER_HORIZONTAL); ds.setMaxLines(2); ds.setPadding(0,dp(3),0,dp(6)); card.addView(ds)
      local ar=mkTV("\u2192",C.amberLight,16,false); ar.setGravity(Gravity.CENTER_HORIZONTAL); card.addView(ar)
      local ci=i; card.onClick=function() table.insert(navStack,"list"); activity.setContentView(buildStoryList(ci)) end
      row.addView(card)
      if i==to and (to-from+1)%2==1 then
        local sp=View(activity); local ls=lp_fw(1.0); ls.setMargins(dp(6),0,0,0); sp.setLayoutParams(ls); row.addView(sp)
      end
    end
  end

  local function addDiv()
    local d=View(activity); d.setBackgroundColor(subC())
    local ld=LinearLayout.LayoutParams(MATCH,dp(1)); ld.setMargins(dp(4),dp(12),dp(4),dp(12)); d.setLayoutParams(ld); grid.addView(d)
  end

  drawSection("\u1F4E1  kahanizone.com",1,9);        addDiv()
  drawSection("\u1F4DD  hindimoralstory.com",10,12);  addDiv()
  drawSection("\u1F4AA  kahanihindime.com",13,16);    addDiv()
  drawSection("\u2B50  daanitv.com",17,23);           addDiv()
  drawSection("\u1F47B  bhootkikahani.com",24,26);    addDiv()
  drawSection("\u1F480  horrorstoryhindi.com",27,31)

  sv.addView(grid); mainCol.addView(sv)

  local ft=mkTV("\u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u0940 App  \u2022  6 Sources  \u2022  "..#CATEGORIES.." Categories",0xaaffffff,10,false)
  ft.setGravity(Gravity.CENTER); ft.setBackgroundColor(C.purpleDeep); ft.setPadding(0,dp(8),0,dp(8)); mainCol.addView(ft)

  -- Add layers to frame: main content first, then drawer overlay, then drawer
  frame.addView(mainCol)
  frame.addView(drawerBg)
  frame.addView(drawer)
  root.addView(frame)

  -- Events
  menuBtn.onClick=function() openDrawer() end

  return root
end


-- ══════════════════════════════════════════════
--  SPLASH
-- ══════════════════════════════════════════════
local function addTo(parent,view) parent.addView(view); return view end
local function ctr(v) v.setGravity(Gravity.CENTER); return v end

local sp=mkCol(); sp.setGravity(Gravity.CENTER); sp.setBackground(gr(C.purple,C.purpleDeep,0))
addTo(sp, ctr(mkTV("\u1F4D6",C.white,80,false)))
addTo(sp, ctr(mkTV("\u0939\u093F\u0902\u0926\u0940 \u0915\u0939\u093E\u0928\u0940",C.white,36,true)))
do local v=ctr(mkTV("6 Sources  \u2022  "..#CATEGORIES.." Categories",0xccffffff,14,false)); v.setPadding(0,dp(6),0,0); addTo(sp,v) end
do local v=ctr(mkTV("bhootkikahani \u2022 horrorstoryhindi \u2022 daanitv \u2022 +more",0xaaffffff,10,false)); v.setPadding(0,dp(4),0,dp(40)); addTo(sp,v) end
do
  local pb=ProgressBar(activity); local lpb=lp_wh(180,4); lpb.gravity=Gravity.CENTER_HORIZONTAL; pb.setLayoutParams(lpb); pb.setIndeterminate(true); sp.addView(pb)
  local tip=mkTV("\u1F4A1 Tap \u2606 to bookmark any story",0x66ffffff,11,false); tip.setGravity(Gravity.CENTER); tip.setPadding(0,dp(16),0,0); addTo(sp,tip)
end

activity.setContentView(sp)
Handler().postDelayed(function() activity.setContentView(buildHome()) end,2200)