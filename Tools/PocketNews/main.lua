require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.content.*"
import "android.net.*"
import "android.util.*"
import "android.webkit.*"
import "android.graphics.*"
import "android.graphics.drawable.*"
import "java.lang.*"
import "com.androlua.Http"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognizerIntent"
import "android.speech.RecognitionListener"

-- ============================================================
-- App Constants
-- ============================================================
local APP_VERSION    = "2.3.0"
local APP_CHANGELOG  = {
    {"v2.3.0", "Home tab redesigned — clean dashboard\nNepal Markets as widgets (Gold, Forex, NEPSE, Fuel, Vegetables)\nCurrency Converter dialog — 20 currencies\nNepali Date + Tithi (quiktoolbox API)\nGoogle Translate — no API key needed, 10 languages\nChunk-based translation with retry and progress\nAI Model selector — Gemini 2.0/2.5/1.5 Flash/Pro\nAI Companion Chat — Girlfriend / Boyfriend mode\nSeparate News tab from Home tab\nArticle hash/nene garbage removed\nBug fixes — nav cleaned"},
    {"v2.0.0", "Patro tab — Tithimiti, Rashifal, Events\nVegetable & Fruit prices (Kalimati)\nAuto update checker\nCustom theme creator\nAuto dark mode (9 PM - 6 AM)\nReading time estimate\nCopy link on long press\nDuplicate & garbage content filter\nNewest news first\neSewa donate button\nOnline user guide\nRadio alphabetical sort"},
    {"v1.3.0", "Custom themes, Auto dark mode, Reading time, Copy link, Vegetable prices, Nepal Patro tab, Radio sorting, eSewa donate"},
    {"v1.2.0", "Markets tab: Gold/Silver, Forex (NRB), NEPSE index, Fuel prices (NOC)\nSleep timer for Radio\nShare article as card\nNo internet error screen\nArticle publish time\nOnboarding walkthrough\nDark status bar"},
    {"v1.1.0", "Radio inline tab with full player view\nBack button stops radio\nManage Radio Stations\nFirst launch welcome screen\nUser Guide via WebView\nCustom RSS feeds\nAccessibility support"},
    {"v1.0.0", "Initial release — News feed, AI Summary (Gemini), Live Radio, Offline reading, Bookmarks, History, Themes, Notifications"},
}

local last_refreshed_time = nil  -- track last news load time

-- ============================================================
-- Settings  (persisted to settings.lua)
-- ============================================================
local app_settings = {
    theme          = "light",
    gemini_api_key = "",
    translate_lang = "English",
    font_size      = 16,
    reader_bg      = "white",
    reader_mode    = "full",
    notif_interval = 0,
    ai_model       = "gemini-2.5-flash",
    ai_companion   = "none",   -- "none", "girlfriend", "boyfriend"
}

local function load_settings()
    local base = activity.getLuaDir()
    local f    = io.open(base.."/settings.lua","r")
    if not f then return end
    local content = f:read("*a"); f:close()
    if not content or content=="" then return end
    local fn,_ = loadstring(content)
    if not fn then return end
    local ok,res = pcall(fn)
    if ok and type(res)=="table" then
        for k,v in pairs(res) do app_settings[k]=v end
    end
end

local function save_settings()
    local base = activity.getLuaDir()
    local f    = io.open(base.."/settings.lua","w")
    if not f then return end
    f:write("return {\n")
    for k,v in pairs(app_settings) do
        if type(v)=="string" then
            f:write(string.format('  [%q]=%q,\n',k,v))
        elseif type(v)=="number" or type(v)=="boolean" then
            f:write(string.format('  [%q]=%s,\n',k,tostring(v)))
        end
    end
    f:write("}\n")
    f:close()
end

load_settings()

-- ============================================================
-- Theme Manager  (Material Design colour system)
-- ============================================================

-- Radio globals (declared here so create_main_ui can reference them)
radio_player   = nil
radio_playing  = false
radio_current  = nil
radio_stations = {}

ThemeManager = {}

-- Material You–inspired palettes
local THEMES = {
    light = {
        accent          = "#1976D2",
        accentDark      = "#0D47A1",
        background      = "#F0F4F8",
        cardBackground  = "#FFFFFF",
        primaryText     = "#1A1A2E",
        secondaryText   = "#5C6BC0",
        divider         = "#E0E6F0",
        buttonText      = "#FFFFFF",
        chip            = "#E3F2FD",
        chipText        = "#1565C0",
        searchBg        = "#FFFFFF",
        navActive       = "#E63946",
        navInactive     = "#7A7A9A",
        navBg           = "#1A1A2E",
    },
    dark  = {
        accent          = "#82B1FF",
        accentDark      = "#448AFF",
        background      = "#0F0F1A",
        cardBackground  = "#1A1A2E",
        primaryText     = "#E8EAF6",
        secondaryText   = "#9FA8DA",
        divider         = "#252540",
        buttonText      = "#0F0F1A",
        chip            = "#1A237E",
        chipText        = "#82B1FF",
        searchBg        = "#1A1A2E",
        navActive       = "#E63946",
        navInactive     = "#7A7A9A",
        navBg           = "#1A1A2E",
    },
}

local COLOR_NAMES = {
    -- Reds
    red="#FF0000", crimson="#DC143C", tomato="#FF6347", coral="#FF7F50",
    salmon="#FA8072", rose="#E63946", pink="#FFC0CB", hotpink="#FF69B4",
    -- Oranges
    orange="#FFA500", darkorange="#FF8C00", gold="#FFD700", amber="#FF6F00",
    peach="#FFCBA4", sunset="#FF4500",
    -- Yellows
    yellow="#FFFF00", lightyellow="#FFFFE0", khaki="#F0E68C", lemon="#FFF44F",
    -- Greens
    green="#008000", lime="#00FF00", forest="#228B22", olive="#808000",
    teal="#008080", mint="#98FF98", sage="#BCB88A", emerald="#50C878",
    -- Blues
    blue="#0000FF", navy="#1A1A2E", skyblue="#87CEEB", steelblue="#4682B4",
    dodgerblue="#1E90FF", royalblue="#4169E1", cyan="#00FFFF", azure="#F0FFFF",
    ocean="#0097A7", midnight="#191970",
    -- Purples
    purple="#800080", violet="#EE82EE", indigo="#4B0082", lavender="#E6E6FA",
    magenta="#FF00FF", plum="#DDA0DD", orchid="#DA70D6",
    -- Browns
    brown="#A52A2A", chocolate="#D2691E", tan="#D2B48C", beige="#F5F5DC",
    maroon="#800000", sienna="#A0522D",
    -- Grays
    white="#FFFFFF", black="#000000", gray="#808080", grey="#808080",
    silver="#C0C0C0", lightgray="#D3D3D3", darkgray="#A9A9A9", charcoal="#36454F",
    -- Special
    transparent="#00000000",
}

local function color_name_to_hex(input)
    if not input or input == "" then return nil end
    local t = input:gsub("%s",""):lower()
    -- Already a hex color
    if t:match("^#?%x%x%x%x%x%x$") then
        t = t:gsub("^#","")
        return "#"..t:upper()
    end
    -- 3-char hex shorthand → expand
    if t:match("^#?%x%x%x$") then
        t = t:gsub("^#","")
        return "#"..t:sub(1,1):rep(2)..t:sub(2,2):rep(2)..t:sub(3,3):rep(2)
    end
    -- Color name lookup
    return COLOR_NAMES[t] or nil
end
local function load_custom_theme()
    local base = activity.getLuaDir()
    local f = io.open(base.."/custom_theme.lua", "r")
    if not f then return end
    local content = f:read("*a"); f:close()
    if not content or content == "" then return end
    local fn = loadstring(content)
    if not fn then return end
    local ok, d = pcall(fn)
    if ok and type(d) == "table" and d.accent then
        THEMES["custom"] = d
    end
end

function ThemeManager.getCurrentTheme()
    return THEMES[app_settings.theme] or THEMES["light"]
end

-- Reader background presets
local READER_THEMES = {
    white = {bg="#FFFFFF",  text="#1A1A2E"},
    sepia = {bg="#FAF3E0",  text="#3E2723"},
    dark  = {bg="#121212",  text="#E8EAF6"},
}

local theme        = ThemeManager.getCurrentTheme()
local currentTheme = {}

local function refreshThemeColors()
    theme = ThemeManager.getCurrentTheme()
    currentTheme = {
        primary       = Color.parseColor(theme.accent),
        primaryDark   = Color.parseColor(theme.accentDark),
        background    = Color.parseColor(theme.background),
        surface       = Color.parseColor(theme.cardBackground),
        text          = Color.parseColor(theme.primaryText),
        secondaryText = Color.parseColor(theme.secondaryText),
        divider       = Color.parseColor(theme.divider),
        chip          = Color.parseColor(theme.chip),
        chipText      = Color.parseColor(theme.chipText),
        searchBg      = Color.parseColor(theme.searchBg),
        navActive     = Color.parseColor(theme.navActive),
        navInactive   = Color.parseColor(theme.navInactive),
        navBg         = Color.parseColor(theme.navBg),
    }
end
refreshThemeColors()

-- ============================================================
-- Permissions
-- ============================================================
local function check_permissions()
    local perms={
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.INTERNET",
    }
    for _,p in ipairs(perms) do
        if activity.checkSelfPermission(p)==-1 then activity.requestPermissions({p},1) end
    end
end
check_permissions()

-- ============================================================
-- Android class bindings
-- ============================================================
local ArrayAdapter   = luajava.bindClass("android.widget.ArrayAdapter")
local LinearLayout   = luajava.bindClass("android.widget.LinearLayout")
local RelativeLayout = luajava.bindClass("android.widget.RelativeLayout")
local EditText       = luajava.bindClass("android.widget.EditText")
local Toast          = luajava.bindClass("android.widget.Toast")
local Spinner        = luajava.bindClass("android.widget.Spinner")
local ListView       = luajava.bindClass("android.widget.ListView")
local Button         = luajava.bindClass("android.widget.Button")
local AlertDialog    = luajava.bindClass("android.app.AlertDialog")
local Intent         = luajava.bindClass("android.content.Intent")
local Uri            = luajava.bindClass("android.net.Uri")
local String         = luajava.bindClass("java.lang.String")
local ScrollView     = luajava.bindClass("android.widget.ScrollView")
local TextView       = luajava.bindClass("android.widget.TextView")
local Color          = luajava.bindClass("android.graphics.Color")
local ColorDrawable  = luajava.bindClass("android.graphics.drawable.ColorDrawable")
local GradientDrawable = luajava.bindClass("android.graphics.drawable.GradientDrawable")
local ClipboardManager = luajava.bindClass("android.content.ClipboardManager")
local ClipData         = luajava.bindClass("android.content.ClipData")

-- ============================================================
-- Global state
-- ============================================================
local selected_language = "Nepali"
local selected_category = "Health"
local news_data         = {}
local display_data      = {}
local bookmarks         = {}
local current_font_size = app_settings.font_size or 16
local base_dir          = activity.getLuaDir()
local offline_news_dir  = base_dir.."/offline_news/"
local history_dir       = base_dir.."/news_history/"
os.execute("mkdir -p "..offline_news_dir)
os.execute("mkdir -p "..history_dir)

-- ============================================================
-- Feed definitions
-- ============================================================
local user_feeds           = {}
local user_cats            = {}
local user_langs           = {}
local deleted_default_cats = {}  -- tracks which built-in categories user has hidden
local default_feeds = {
    Health={
        English={"https://rss.nytimes.com/services/xml/rss/nyt/Health.xml"},
        Nepali ={"https://swasthyakhabar.com/feed","https://healthnewsnepal.com/feed","https://www.nepalihealth.com/feed"},
        Hindi  ={"https://healthdivin.blogspot.com/feeds","https://gomedii.com/blogs/hindi/feed",
                 "https://www.healthshots.com/hindi/feed/","https://www.indiatv.in/rssnews/topstory-lifestyle.xml",
                 "https://www.myupchar.com/feed.rss"},
    },
    Tech={
        English={"https://feeds.feedburner.com/TechCrunch/","https://www.technewsworld.com/feed"},
        Nepali ={"https://techpana.com/feed","https://np.ictframe.com/feed",
                 "https://www.technologykhabar.com/feed","https://ictsamachar.com/rss"},
    },
    World={
        English={"https://rss.nytimes.com/services/xml/rss/nyt/World.xml"},
    },
}

local NEPALI_PATRO_API = "https://api-news.nepalipatro.com.np/api/feeds?lang=np&filter"


-- ============================================================
-- Unicode / HTML helpers
-- ============================================================
local function codepoint_to_utf8(cp)
    if cp<0x80 then return string.char(cp)
    elseif cp<0x800 then
        return string.char(0xC0+math.floor(cp/0x40), 0x80+(cp%0x40))
    elseif cp<0x10000 then
        return string.char(0xE0+math.floor(cp/0x1000),
                           0x80+math.floor((cp%0x1000)/0x40),
                           0x80+(cp%0x40))
    else
        return string.char(0xF0+math.floor(cp/0x40000),
                           0x80+math.floor((cp%0x40000)/0x1000),
                           0x80+math.floor((cp%0x1000)/0x40),
                           0x80+(cp%0x40))
    end
end

local function decode_unicode_escapes(s)
    if not s then return "" end
    s = s:gsub("\\u([Dd][89AaBb]%x%x)\\u([Dd][CcDdEeFf]%x%x)", function(hi,lo)
        return codepoint_to_utf8(0x10000+(tonumber(hi,16)-0xD800)*0x400+(tonumber(lo,16)-0xDC00))
    end)
    s = s:gsub("\\u(%x%x%x%x)", function(h) return codepoint_to_utf8(tonumber(h,16)) end)
    s = s:gsub("\\n","\n"):gsub("\\t","\t"):gsub("\\r",""):gsub('\\"','"'):gsub("\\\\","\\")
    return s
end

local function decode_html(text)
    if not text then return "" end
    -- Named entities
    local ent = {
        -- Basic
        ["&amp;"]="&", ["&lt;"]="<", ["&gt;"]=">", ["&quot;"]='"', ["&apos;"]="'",
        ["&nbsp;"]=" ", ["&shy;"]="",
        -- Punctuation & typography
        ["&ndash;"]="–", ["&mdash;"]="—", ["&minus;"]="−",
        ["&lsquo;"]="'", ["&rsquo;"]="'", ["&sbquo;"]="‚",
        ["&ldquo;"]="\xe2\x80\x9c", ["&rdquo;"]="\xe2\x80\x9d", ["&bdquo;"]="„",
        ["&laquo;"]="«", ["&raquo;"]="»",
        ["&hellip;"]="…", ["&bull;"]="•", ["&middot;"]="·",
        ["&prime;"]="′", ["&Prime;"]="″",
        -- Numeric named (common in WordPress/RSS)
        ["&#8216;"]="'", ["&#8217;"]="'", ["&#8218;"]="‚",
        ["&#8220;"]="\xe2\x80\x9c", ["&#8221;"]="\xe2\x80\x9d", ["&#8222;"]="„",
        ["&#8211;"]="–", ["&#8212;"]="—",
        ["&#8230;"]="…", ["&#8226;"]="•",
        ["&#8242;"]="′", ["&#8243;"]="″",
        ["&#39;"]="'", ["&#039;"]="'", ["&#34;"]='"', ["&#038;"]="&",
        ["&#160;"]=" ", ["&#173;"]="",
        -- Currency
        ["&pound;"]="£", ["&euro;"]="€", ["&yen;"]="¥", ["&cent;"]="¢",
        ["&#163;"]="£", ["&#8364;"]="€", ["&#165;"]="¥",
        -- Math / misc
        ["&copy;"]="©", ["&reg;"]="®", ["&trade;"]="™",
        ["&#169;"]="©", ["&#174;"]="®", ["&#8482;"]="™",
        ["&times;"]="×", ["&divide;"]="÷", ["&plusmn;"]="±",
        ["&frac12;"]="½", ["&frac14;"]="¼", ["&frac34;"]="¾",
        -- Arrows
        ["&rarr;"]="→", ["&larr;"]="←", ["&uarr;"]="↑", ["&darr;"]="↓",
        ["&harr;"]="↔", ["&raquo;"]="»",
    }
    for k,v in pairs(ent) do text = text:gsub(k, v) end
    -- Numeric decimal  &#NNN;  — handles any codepoint via UTF-8 encoding
    text = text:gsub("&#(%d+);", function(n)
        local cp = tonumber(n)
        if not cp then return "" end
        if cp < 128 then return string.char(cp) end
        if cp < 0x800 then
            return string.char(0xC0 + math.floor(cp/0x40), 0x80 + (cp % 0x40))
        end
        if cp < 0x10000 then
            return string.char(
                0xE0 + math.floor(cp/0x1000),
                0x80 + math.floor((cp % 0x1000)/0x40),
                0x80 + (cp % 0x40))
        end
        return string.char(
            0xF0 + math.floor(cp/0x40000),
            0x80 + math.floor((cp % 0x40000)/0x1000),
            0x80 + math.floor((cp % 0x1000)/0x40),
            0x80 + (cp % 0x40))
    end)
    -- Numeric hex  &#xHHH;
    text = text:gsub("&#[xX](%x+);", function(h)
        local cp = tonumber(h, 16)
        if not cp then return "" end
        if cp < 128 then return string.char(cp) end
        if cp < 0x800 then
            return string.char(0xC0 + math.floor(cp/0x40), 0x80 + (cp % 0x40))
        end
        if cp < 0x10000 then
            return string.char(
                0xE0 + math.floor(cp/0x1000),
                0x80 + math.floor((cp % 0x1000)/0x40),
                0x80 + (cp % 0x40))
        end
        return string.char(
            0xF0 + math.floor(cp/0x40000),
            0x80 + math.floor((cp % 0x40000)/0x1000),
            0x80 + math.floor((cp % 0x1000)/0x40),
            0x80 + (cp % 0x40))
    end)
    -- Strip remaining HTML tags
    text = text:gsub("<[^>]+>", "")
    -- Collapse multiple spaces/newlines
    text = text:gsub("[ \t]+", " ")
    return text:gsub("^%s*(.-)%s*$", "%1")
end

-- ============================================================
-- JSON helpers (Nepali Patro)
-- ============================================================
local function split_json_objects(str)
    local blocks,depth,start={},0,nil
    for i=1,#str do
        local c=str:sub(i,i)
        if c=="{" then if depth==0 then start=i end; depth=depth+1
        elseif c=="}" then
            depth=depth-1
            if depth==0 and start then table.insert(blocks,str:sub(start,i)); start=nil end
        end
    end
    return blocks
end

local function json_str(block,key)
    return block:match('"'..key..'"%s*:%s*"(.-[^\\])"')
        or (block:match('"'..key..'"%s*:%s*""') and "")
end

-- ============================================================
-- Parsers
-- ============================================================
local function clean_description(desc)
    if not desc or desc == "" then return "" end

    -- Strip scripts, styles, comments, HTML tags
    local t = desc:gsub("<script.->.-</script>", "")
                  :gsub("<style.->.-</style>", "")
                  :gsub("<!%-%-.-%%->", "")
                  :gsub("<[^>]+>", "")
    t = decode_html(t)
    t = t:gsub("\t", " "):gsub("[ ]+", " ")

    -- Split into lines and analyze
    local lines = {}
    local short_count = 0
    local total_count = 0
    for line in t:gmatch("[^\n]+") do
        local l = line:gsub("^%s*(.-)%s*$", "%1")
        if #l > 0 then
            total_count = total_count + 1
            if #l < 40 then short_count = short_count + 1 end
            table.insert(lines, l)
        end
    end

    -- Detect garbage: too many short lines = nav/listing page
    if total_count > 8 and (short_count / total_count) > 0.55 then
        -- Find first long meaningful sentence (article content)
        for _, l in ipairs(lines) do
            if #l >= 80
                and not l:match("@")
                and not l:match("^https?://")
                and not l:match("^[%d%s,]+$") then
                if #l > 300 then l = l:sub(1, 300).."..." end
                return l
            end
        end
        -- No long sentence found — return empty (show title only)
        return ""
    end

    -- Normal RSS — join and return
    local result = table.concat(lines, " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    if #result > 300 then result = result:sub(1, 300).."..." end
    return result
end

local function extract_article(body, fallback_desc)
    -- Remove noise blocks
    local clean = body
        :gsub("<script.->.-</script>", "")
        :gsub("<style.->.-</style>", "")
        :gsub("<!%-%-.-%%->", "")
        :gsub("<nav.->.-</nav>", "")
        :gsub("<header.->.-</header>", "")
        :gsub("<footer.->.-</footer>", "")
        :gsub("<aside.->.-</aside>", "")
        :gsub("<form.->.-</form>", "")
        :gsub("<noscript.->.-</noscript>", "")
        :gsub("<figure.->.-</figure>", "")
        -- Remove 32-char hex hashes (tracking IDs)
        :gsub("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x", "")
        -- Remove nene artifacts
        :gsub("nene", "")

    -- Insert newlines at block boundaries
    local blocked = clean
        :gsub("<br[^>]*>", "\n")
        :gsub("</?p[^>]*>", "\n")
        :gsub("</?div[^>]*>", "\n")
        :gsub("</?li[^>]*>", "\n")
        :gsub("</?h[1-6][^>]*>", "\n")
        :gsub("</?section[^>]*>", "\n")
        :gsub("</?article[^>]*>", "\n")

    -- Strip remaining tags and decode
    local plain = decode_html(blocked:gsub("<[^>]+>", " "))
    plain = plain:gsub("[ \t]+", " ")

    -- Score each line by word density
    local scored = {}
    for line in plain:gmatch("[^\n]+") do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if #line < 15 then
        else
            local words = 0
            for _ in line:gmatch("[%a\xE0-\xFF]+") do words = words + 1 end
            if words >= 3 then
                -- Base score = word count
                local score = words
                -- Boost longer lines (likely article paragraphs)
                if words >= 10 then score = score + 20 end
                if words >= 20 then score = score + 20 end
                -- Penalize nav/UI patterns
                if #line < 40 then score = score - 15 end
                if line:match("^%d") then score = score - 10 end
                if line:match("MHz") or line:match("FM") then score = score - 20 end
                table.insert(scored, {text=line, score=score, words=words})
            end
        end
    end

    if #scored == 0 then
        return (fallback_desc or "").."\n\n(Tap Browser to read online.)"
    end

    -- Find peak content window (sliding window of 5 blocks)
    local best_start = 1
    local best_sum = -999
    for i = 1, #scored do
        local s = 0
        for j = i, math.min(i+4, #scored) do s = s + scored[j].score end
        if s > best_sum then best_sum = s; best_start = i end
    end

    -- Expand outward from peak while score > threshold
    local rs, re = best_start, best_start
    for i = best_start - 1, 1, -1 do
        if scored[i].score > 5 then rs = i else break end
    end
    for i = best_start + 1, #scored do
        if scored[i].score > 5 then re = i else break end
    end

    -- Collect unique lines in range
    local parts, seen = {}, {}
    for i = rs, re do
        local t = scored[i].text
        local key = t:sub(1, 45)
        if scored[i].score > 0 and not seen[key] then
            seen[key] = true
            table.insert(parts, t)
        end
    end

    local full = table.concat(parts, "\n\n")
    if #full < 80 then
        full = (fallback_desc or "")..
            "\n\n(Full article extraction limited — tap Browser to read online.)"
    end
    return full
end

local function parse_rss(xml)
    local results = {}
    if not xml then return results end
    if not xml:match("<item>") and not xml:match("<item ") then return results end
    for item in xml:gmatch("<item.->(.-)</item>") do
        local title=item:match("<title><!%[CDATA%[(.-)%]%]></title>") or item:match("<title>(.-)</title>") or ""
        local link =item:match("<link>(.-)</link>") or item:match("<guid>(.-)</guid>") or ""
        local desc =item:match("<description><!%[CDATA%[(.-)%]%]></description>") or item:match("<description>(.-)</description>") or ""
        local date =item:match("<pubDate>(.-)</pubDate>") or ""
        title = title:gsub("<[^>]+>",""):gsub("&lt;","<"):gsub("&gt;",">")
        title = decode_html(title):gsub("^%s*(.-)%s*$","%1")
        link  = link:gsub("^%s*(.-)%s*$","%1")
        if title ~= "" and #title >= 4 and link:match("^https?://") then
            table.insert(results,{
                title=title,
                link=link,
                description=clean_description(desc),
                date=date
            })
        end
    end
    return results
end

local function parse_nepali_patro(json_body)
    local results={}
    if not json_body then return results end
    local feeds_str=json_body:match('"feeds"%s*:%s*(%[.+%])') or json_body
    for _,block in ipairs(split_json_objects(feeds_str)) do
        local title   =json_str(block,"title")
        local desc    =json_str(block,"description")
        local cont    =json_str(block,"content")
        local raw_link=json_str(block,"link")
        local date    =json_str(block,"pub_date") or json_str(block,"fetch_date") or ""
        local img     =json_str(block,"image") or ""
        if not title or title=="" then
        else
        local real_url=""
        if raw_link then
            local u=raw_link:gsub("\\/","/")
            real_url=u:match("[?&]url=(.+)$") or u
        end
        local d=clean_description(decode_unicode_escapes(desc or ""))
        local c=clean_description(decode_unicode_escapes(cont or ""))
        table.insert(results,{
            title=decode_unicode_escapes(title),link=real_url,
            description=(#c>#d) and c or d,content="",
            date=date,image=img:gsub("\\/","/"),
        })
        end
    end
    return results
end

-- ============================================================
-- Storage
-- ============================================================
local function serialize(obj)
    local t=type(obj)
    if t=="number" or t=="boolean" then return tostring(obj)
    elseif t=="string" then return string.format("%q",obj)
    elseif t=="table" then
        local s="{"
        for k,v in pairs(obj) do
            local key=(type(k)=="string") and string.format("[%q]",k) or string.format("[%d]",k)
            s=s..key.."="..serialize(v)..","
        end
        return s.."}"
    end
    return "nil"
end

local function save_data(path,data)
    local full=path:find("^/") and path or (base_dir.."/"..path)
    local f=io.open(full,"w")
    if f then f:write("return "..serialize(data)); f:close(); return true end
    return false
end

local function load_data(path)
    local full=path:find("^/") and path or (base_dir.."/"..path)
    local f=io.open(full,"r")
    if not f then return {} end
    local content=f:read("*a"); f:close()
    if not content or content=="" then return {} end
    local fn=loadstring(content)
    if not fn then return {} end
    local ok,res=pcall(fn)
    return ok and res or {}
end

-- ============================================================
-- Utility helpers (defined early so all sections can use them)
-- ============================================================
local function setBold(v) if v then pcall(function() v.getPaint().setFakeBoldText(true) end) end end
local function show_toast(msg) Toast.makeText(activity,msg,0).show() end

-- Show a system notification in the notification panel
local function show_notification(title, text)
    pcall(function()
        local context     = activity
        local nm          = context.getSystemService("notification")
        local CHANNEL_ID  = "pocketnews_channel"

        -- Android 13+ (API 33) requires POST_NOTIFICATIONS permission
        if android.os.Build.VERSION.SDK_INT >= 33 then
            local perm = "android.permission.POST_NOTIFICATIONS"
            local PackageManager = luajava.bindClass("android.content.pm.PackageManager")
            local granted = context.checkSelfPermission(perm)
            if granted ~= PackageManager.PERMISSION_GRANTED then
                activity.requestPermissions({perm}, 101)
                show_toast("Please allow notification permission and reload news")
                return
            end
        end

        -- Android 8+ requires a notification channel
        if android.os.Build.VERSION.SDK_INT >= 26 then
            local NotificationChannel = luajava.bindClass("android.app.NotificationChannel")
            local importance = luajava.bindClass("android.app.NotificationManager").IMPORTANCE_DEFAULT
            local channel = luajava.newInstance("android.app.NotificationChannel",
                CHANNEL_ID, "PocketNews", importance)
            nm.createNotificationChannel(channel)
        end

        local builder = luajava.newInstance("android.app.Notification$Builder", context, CHANNEL_ID)
        builder.setSmallIcon(17301543)   -- android.R.drawable.ic_dialog_info
        builder.setContentTitle(title)
        builder.setContentText(text)
        builder.setAutoCancel(true)
        local notif = builder.build()
        nm.notify(1001, notif)
        show_toast("Notification sent!")  -- debug: remove once confirmed working
    end)
end

-- ── Notification interval scheduler ──────────────────────────
local notif_handler  = luajava.newInstance("android.os.Handler")
local notif_runnable = nil

local function stop_notif_scheduler()
    if notif_runnable then
        notif_handler.removeCallbacks(notif_runnable)
        notif_runnable = nil
    end
end

local function start_notif_scheduler(interval_minutes)
    stop_notif_scheduler()
    if not interval_minutes or interval_minutes <= 0 then return end
    local ms = interval_minutes * 60 * 1000

    local function make_runnable()
        return luajava.createProxy("java.lang.Runnable", {
            run = function()
                -- Fetch latest headlines silently and notify
                pcall(function()
                    local settings = app_settings
                    local cat = settings.last_cat or "Health"
                    local lang = settings.last_lang or "English"
                    local feeds = {}
                    -- grab first feed URL for the current category/language
                    if type(user_feeds) == "table" then
                        for _, f in ipairs(user_feeds) do
                            if f.cat == cat and f.lang == lang then
                                table.insert(feeds, f.url)
                                break
                            end
                        end
                    end
                    local url = (feeds[1]) or "https://feeds.bbci.co.uk/news/rss.xml"
                    Http.get(url, function(status, body)
                        if status == 200 then
                            local items = parse_rss(body)
                            if items and #items > 0 then
                                local headline = items[1].title or "New articles available"
                                show_notification("PocketNews — New Headlines", headline)
                            end
                        end
                    end)
                end)
                -- reschedule
                notif_runnable = make_runnable()
                notif_handler.postDelayed(notif_runnable, ms)
            end
        })
    end

    notif_runnable = make_runnable()
    notif_handler.postDelayed(notif_runnable, ms)
    show_toast("News notifications every "..interval_minutes.." min")
end

local function show_notif_interval_dialog()
    local labels   = {"Off", "5 min", "10 min", "15 min", "30 min", "45 min", "1 hour", "12 hours", "24 hours"}
    local minutes  = {0,     5,       10,       15,       30,       45,       60,       720,        1440}
    local current  = app_settings.notif_interval or 0
    -- find current selection index
    local sel = 1
    for i, m in ipairs(minutes) do
        if m == current then sel = i; break end
    end
    AlertDialog.Builder(activity)
        .setTitle("News Notification Interval")
        .setSingleChoiceItems(labels, sel - 1, {onClick=function(_, which)
            local chosen = minutes[which + 1]
            app_settings.notif_interval = chosen
            save_settings()
            if chosen == 0 then
                stop_notif_scheduler()
                show_toast("Notifications disabled")
            else
                start_notif_scheduler(chosen)
            end
        end})
        .setPositiveButton("Close", nil)
        .show()
end

function table.find(t,v)
    for i,val in ipairs(t) do if val==v then return i end end
    return 1
end

-- ============================================================
-- News History  (auto-save title+link, browse by 7/14/28 days)
-- ============================================================

-- Returns today's date string YYYY-MM-DD using Java Calendar
local function today_str()
    local cal = luajava.bindClass("java.util.Calendar").getInstance()
    return string.format("%04d-%02d-%02d",
        cal.get(1),   -- YEAR
        cal.get(2)+1, -- MONTH (0-based)
        cal.get(5))   -- DAY_OF_MONTH
end

-- Returns a date string N days ago
local function date_str_ago(days)
    local cal = luajava.bindClass("java.util.Calendar").getInstance()
    cal.add(5, -days)   -- DAY_OF_MONTH - days
    return string.format("%04d-%02d-%02d",
        cal.get(1), cal.get(2)+1, cal.get(5))
end

-- File path for a given date key
local function history_file(date_key)
    return history_dir..date_key..".lua"
end

-- Append new items to today's history file (dedup by link)
local function history_save_items(items)
    local today = today_str()
    local path  = history_file(today)
    -- Load existing entries for today
    local existing = {}
    local f = io.open(path, "r")
    if f then
        local src = f:read("*a"); f:close()
        local fn = loadstring(src)
        if fn then
            local ok, res = pcall(fn)
            if ok and type(res) == "table" then existing = res end
        end
    end
    -- Build a set of existing links for fast dedup
    local seen = {}
    for _, v in ipairs(existing) do seen[v.link or ""] = true end
    -- Add new items not already stored
    local added = 0
    for _, item in ipairs(items) do
        local lnk = item.link or ""
        if lnk ~= "" and not seen[lnk] then
            table.insert(existing, {title = item.title or "No Title", link = lnk})
            seen[lnk] = true
            added = added + 1
        end
    end
    if added > 0 then
        -- Force create directory using Java
        pcall(function()
            luajava.newInstance("java.io.File", history_dir).mkdirs()
        end)
        save_data("news_history/"..today..".lua", existing)
    end
end

-- History purge: delete files older than max_days by checking known date filenames
local function history_purge(max_days)
    local cutoff = date_str_ago(max_days)
    -- Check last 60 days worth of possible files and delete old ones
    for d = max_days, max_days + 60 do
        local key = date_str_ago(d)
        if key < cutoff then
            local path = history_file(key)
            os.remove(path)
        end
    end
end

-- Load all items within the last N days by directly opening known date filenames
local function history_load(days)
    local all = {}
    for d = 0, days - 1 do
        local key  = date_str_ago(d)
        local path = history_file(key)
        local f    = io.open(path, "r")
        if f then
            f:close()
            local data = load_data("news_history/"..key..".lua")
            if type(data) == "table" then
                for _, item in ipairs(data) do
                    item._date = key
                    table.insert(all, item)
                end
            end
        end
    end
    return all
end

-- Show history browser dialog
function show_history_dialog()
    local range_opts = {"Last 7 days", "Last 14 days", "Last 28 days"}
    local range_days = {7, 14, 28}

    -- History browser with inline search bar
    local function open_history_list(days, label)
        local all_items = history_load(days)
        if #all_items == 0 then
            show_toast("No history found for "..label)
            return
        end

        local filtered   = all_items   -- current filtered result set
        local list_dlg

        local hist_layout = {
            LinearLayout, orientation="vertical",
            layout_width="fill", layout_height="fill",
            backgroundColor=currentTheme.surface,

            -- Header
            {LinearLayout, orientation="horizontal", layout_width="fill",
                layout_height="52dp", backgroundColor=currentTheme.primary,
                padding="8dp", gravity="center_vertical",
                {TextView, id="hist_title",
                    text=label.." ("..#all_items..")",
                    textColor=Color.parseColor(theme.buttonText),
                    textSize="15sp", layout_weight=1},
            },

            -- Search bar
            {EditText, id="hist_search",
                hint="Search history...",
                layout_width="fill",
                layout_marginLeft="8dp", layout_marginRight="8dp",
                layout_marginTop="6dp", layout_marginBottom="4dp",
                padding="10dp",
                backgroundColor=currentTheme.searchBg,
                textColor=currentTheme.text,
                hintTextColor=currentTheme.secondaryText},

            -- Results count label
            {TextView, id="hist_count",
                text=#all_items.." articles",
                textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginLeft="12dp", layout_marginBottom="4dp"},

            -- Article list
            {ListView, id="hist_list",
                layout_width="fill", layout_height="0dp", layout_weight=1,
                dividerHeight="1dp",
                divider=ColorDrawable(currentTheme.divider)},

            -- Bottom bar
            {LinearLayout, orientation="horizontal", layout_width="fill",
                layout_height="48dp", backgroundColor=currentTheme.surface,
                elevation="4dp", gravity="center",
                {Button, id="hist_clear", text="Clear History",
                    layout_weight=1, background=nil,
                    textColor=0xFFE53935, textSize="13sp"},
                {Button, id="hist_close", text="Close",
                    layout_weight=1, background=nil,
                    textColor=currentTheme.secondaryText, textSize="13sp"},
            },
        }

        local hv        = loadlayout(hist_layout)
        local list_view = hv.findViewById(hist_list.getId())
        local search_et = hv.findViewById(hist_search.getId())
        local count_tv  = hv.findViewById(hist_count.getId())
        local title_tv  = hv.findViewById(hist_title.getId())

        local function refresh_list(items)
            filtered = items
            local titles = {}
            for _, v in ipairs(items) do
                table.insert(titles, "["..( v._date or "?").."]  "..(v.title or "No Title"))
            end
            list_view.setAdapter(ArrayAdapter(activity,
                android.R.layout.simple_list_item_1, String(titles)))
            count_tv.setText(#items.." article"..(#items==1 and "" or "s"))
            title_tv.setText(label.." ("..#items..")")
        end

        refresh_list(all_items)

        list_dlg = AlertDialog.Builder(activity).create()
        list_dlg.setView(hv)
        list_dlg.show()

        -- Live search
        search_et.addTextChangedListener{onTextChanged=function(s)
            local q = tostring(s):lower():gsub("^%s*(.-)%s*$","%1")
            if q == "" then
                refresh_list(all_items)
            else
                local results = {}
                for _, v in ipairs(all_items) do
                    if (v.title or ""):lower():find(q, 1, true) then
                        table.insert(results, v)
                    end
                end
                refresh_list(results)
            end
        end}

        -- Open article in reader
        list_view.onItemClick = function(_, _, pos)
            show_reader_view(filtered[pos+1])
        end

        hv.findViewById(hist_clear.getId()).onClick = function()
            AlertDialog.Builder(activity)
                .setTitle("Clear All History")
                .setMessage("Are you sure you want to delete all news history?")
                .setPositiveButton("Clear", {onClick=function()
                    os.execute("rm -f "..history_dir.."*")
                    list_dlg.dismiss()
                    show_toast("History cleared")
                end})
                .setNegativeButton("Cancel", nil)
                .show()
        end

        hv.findViewById(hist_close.getId()).onClick = function()
            list_dlg.dismiss()
        end
    end

    -- First pick a range, then open the list
    AlertDialog.Builder(activity)
        .setTitle("News History")
        .setItems(range_opts, {onClick=function(_, which)
            open_history_list(range_days[which+1], range_opts[which+1])
        end})
        .setNegativeButton("Cancel", nil)
        .show()
end

-- ============================================================
-- Gemini AI
-- ============================================================
local GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models/"
local function get_gemini_url()
    local model = (app_settings.ai_model or "gemini-2.0-flash")
    return GEMINI_BASE..model..":generateContent"
end

local function json_escape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    s = s:gsub("[%z\1-\31]", function(c)
        return string.format("\\u%04x", string.byte(c))
    end)
    return s
end

local function clean_for_ai(text)
    if not text then return "" end
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&nbsp;"," "):gsub("&#%d+;","")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        line = line:gsub("^%s+",""):gsub("%s+$","")
        if #line > 20
          and not line:match("^Reading Time")
          and not line:match("^No Result")
          and not line:match("^View All Result")
          and not line:match("^SHARES$")
          and not line:match("^VIEWS$")
          and not line:match("^Reset$")
          and not line:match("Your email address will not be published")
          and not line:match("^Share to")
          and not line:match("^QR Code")
          and not line:match("^by%s")
        then
            table.insert(lines, line)
        end
    end
    text = table.concat(lines, "\n")
    text = text:gsub("\n\n\n+", "\n\n")
    text = text:gsub("[ \t]+", " ")
    return text:gsub("^%s*(.-)%s*$", "%1")
end

local function gemini_post_json(url, body, cb)
    local thread_code = [[
        local url, body = ...
        local s, r = 0, "Unknown error"
        local ok, err = pcall(function()
            local URL     = luajava.bindClass("java.net.URL")
            local Jstring = luajava.bindClass("java.lang.String")
            local Scanner = luajava.bindClass("java.util.Scanner")
            local conn = URL(url).openConnection()
            conn.setRequestMethod("POST")
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            conn.setRequestProperty("Accept", "application/json")
            conn.setDoOutput(true)
            conn.setConnectTimeout(30000)
            conn.setReadTimeout(45000)
            local out = conn.getOutputStream()
            out.write(Jstring(body).getBytes("UTF-8"))
            out.flush(); out.close()
            s = conn.getResponseCode()
            local stream = (s >= 200 and s < 300) and conn.getInputStream() or conn.getErrorStream()
            if stream then
                local sc = Scanner(stream, "UTF-8")
                sc.useDelimiter("\\A")
                r = sc.hasNext() and tostring(sc.next()) or "Empty response"
                sc.close()
            else
                r = "No stream (HTTP " .. tostring(s) .. ")"
            end
            conn.disconnect()
        end)
        if not ok then r = "Thread Error: " .. tostring(err) end
        call("gemini_callback", s, r)
    ]]
    _G.gemini_callback = function(status, resp)
        _G.gemini_callback = nil
        if cb then cb(status, resp) end
    end
    thread(thread_code, url, body)
end

local function gemini_request(prompt, on_result)
    local key = (app_settings.gemini_api_key or ""):gsub("^%s*(.-)%s*$","%1")
    if key == "" then
        on_result(nil, "No Gemini API key.\nGo to Settings > Gemini API Key.\nFree key: aistudio.google.com/app/apikey")
        return
    end
    local safe = clean_for_ai(prompt)
    if #safe > 25000 then safe = safe:sub(1,25000).."\n\n[Truncated]" end
    if #safe < 10 then on_result(nil,"Article text too short to process."); return end

    local url  = get_gemini_url().."?key="..key
    local body = '{"contents":[{"role":"user","parts":[{"text":"'..json_escape(safe)..'"}]}],"generationConfig":{"temperature":0.3}}'

    gemini_post_json(url, body, function(status, resp)
        if status ~= 200 then
            on_result(nil, "Gemini error "..tostring(status).."\n"..(resp or ""))
            return
        end
        local text = resp:match('"text"%s*:%s*"(.-)"%s*[,}]')
        if not text then text = resp:match('"text"%s*:%s*"(.-)"%s*]%s*}') end
        if not text then
            text = resp:match('"text"%s*:%s*"(.*)"')
            if text then
                text = text:gsub('"%s*,%s*"index".*$', ""):gsub('"%s*]%s*}.*$', "")
            end
        end
        if text then
            local final_text = decode_unicode_escapes(text)
            final_text = final_text:gsub("\\n", "\n"):gsub("\\t", "\t")
            on_result(final_text, nil)
        else
            on_result(nil, "Could not parse Gemini response. Raw output:\n"..resp:sub(1,400))
        end
    end)
end

local function gemini_companion_chat(article_context, user_message, chat_history, on_result)
    local key = (app_settings.gemini_api_key or ""):gsub("^%s*(.-)%s*$","%1")
    if key == "" then
        on_result(nil, "No Gemini API key in Settings.")
        return
    end
    local companion = app_settings.ai_companion or "none"
    local persona = ""
    if companion == "girlfriend" then
        persona = "You are a caring, sweet, and playful girlfriend. You speak warmly and affectionately. Use gentle, loving language. You are interested in the user's thoughts on the article they are reading. Be supportive and curious. Occasionally use terms of endearment. Keep responses concise (2-4 sentences). Don't be overly formal."
    elseif companion == "boyfriend" then
        persona = "You are a caring, cool, and supportive boyfriend. You speak confidently but warmly. You are genuinely interested in what the user thinks about the article. Be encouraging and thoughtful. Keep responses concise (2-4 sentences). Don't be overly formal."
    else
        persona = "You are a helpful AI assistant. Answer questions about the article concisely."
    end

    local sys = persona.."\n\nARTICLE CONTEXT:\n"..clean_for_ai(article_context):sub(1,3000)

    -- Build conversation history
    local history_json = ""
    for _, h in ipairs(chat_history or {}) do
        if h.role and h.text then
            history_json = history_json..'{"role":"'..h.role..'","parts":[{"text":"'..json_escape(h.text)..'"}]},'
        end
    end

    local body = '{"system_instruction":{"parts":[{"text":"'..json_escape(sys)..'"}]},"contents":['..
        history_json..
        '{"role":"user","parts":[{"text":"'..json_escape(user_message)..'"}]}],"generationConfig":{"temperature":0.8,"maxOutputTokens":300}}'

    local url = get_gemini_url().."?key="..key
    gemini_post_json(url, body, function(status, resp)
        if status ~= 200 then on_result(nil, "Error "..tostring(status)); return end
        local text = resp:match('"text"%s*:%s*"(.-)"%s*[,}]') or resp:match('"text"%s*:%s*"(.*)"')
        if text then
            text = decode_unicode_escapes(text):gsub("\\n","\n"):gsub("\\t"," ")
            on_result(text, nil)
        else
            on_result(nil, "Could not parse response.")
        end
    end)
end

local function gemini_summarize(article_text, on_result)
    gemini_request(
        "Summarize the following news article. Preserve the original article's tone and important details. Output ONLY the summarized text, no bullet points unless they were in the original.\n\nARTICLE:\n"..article_text,
        on_result)
end

local preferred_server_index = 1

local function aggressiveClean(text)
    return text
        :gsub("<[^>]+>","")          -- HTML tags
        :gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&nbsp;"," ")
        :gsub("&#%d+;","")           -- HTML entities
        :gsub("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x","") -- 32-char hex hashes
        :gsub("nene%s*","")          -- nene artifacts from \n\n encoding
        :gsub("\\n\\n","\n\n")
        :gsub("\\n","\n")
        :gsub("\n%s*\n%s*\n","\n\n") -- max double newline
        :gsub("%s+"," ")
        :gsub("^%s*(.-)%s*$","%1")
end

local function runCustomTranslateEngine(full_text, lang_code, status_view, status_prefix, final_callback)
    local safe_source = aggressiveClean(full_text)
    local chunks = {}
    local current_chunk = ""
    for word in safe_source:gmatch("%S+") do
        if (#current_chunk + #word + 1) > 1000 then
            table.insert(chunks, current_chunk)
            current_chunk = word
        else
            current_chunk = current_chunk == "" and word or (current_chunk .. " " .. word)
        end
    end
    if #current_chunk > 0 then table.insert(chunks, current_chunk) end
    if #chunks == 0 and #safe_source > 0 then table.insert(chunks, safe_source) end

    local total_chunks = #chunks
    if total_chunks == 0 then final_callback(full_text); return end

    local translated_text = ""
    local current_index   = 1
    local MAX_CHUNK_RETRIES = 1

    local function attemptTranslate(text_to_translate, retries, callback)
        local encoded_text = ""
        local ok, res = pcall(function() return URLEncoder.encode(text_to_translate, "UTF-8") end)
        encoded_text = ok and res or Uri.encode(text_to_translate)
        local url
        if preferred_server_index == 1 then
            url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl="..lang_code.."&dt=t&ie=UTF-8&oe=UTF-8&q="..encoded_text
        else
            url = "https://translate.googleapis.com/translate_a/single?client=tw-ob&sl=auto&tl="..lang_code.."&dt=t&ie=UTF-8&oe=UTF-8&q="..encoded_text
        end
        local headers = {["User-Agent"]="Mozilla/5.0",["Accept-Charset"]="UTF-8"}
        Http.get(url, nil, "UTF-8", headers, function(code, body)
            local success, result_txt = false, ""
            if code == 200 and body then
                local safe = String(body).toString()
                -- Google Translate: [[["translated","original",...],...],...]
                -- Extract first string from each inner array
                for t in safe:gmatch('%["([^"\\]*)') do
                    if #t > 0 then result_txt = result_txt..t; success = true end
                end
                -- Decode escapes
                result_txt = result_txt
                    :gsub("\\u(%x%x%x%x)", function(h)
                        local n = tonumber(h, 16) or 0
                        if n < 128 then return string.char(n)
                        elseif n < 2048 then return string.char(192+math.floor(n/64), 128+(n%64))
                        else return string.char(224+math.floor(n/4096), 128+math.floor((n%4096)/64), 128+(n%64)) end
                    end)
                    :gsub("\\n", "\n"):gsub("\\t", " "):gsub('\\"', '"')
                -- Remove hash artifacts that may survive translation
                result_txt = result_txt
                    :gsub("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x","")
                    :gsub("nene%s*","")
                    :gsub("\n%s*\n%s*\n","\n\n")
            end
            if success then
                callback(true, result_txt)
            elseif retries < MAX_CHUNK_RETRIES then
                preferred_server_index = preferred_server_index == 1 and 2 or 1
                pcall(function()
                    if status_view then
                        activity.runOnUiThread(function()
                            status_view.setText(status_prefix.." ("..current_index.."/"..total_chunks..") Retrying...")
                        end)
                    end
                end)
                Handler().postDelayed(Runnable{run=function()
                    attemptTranslate(text_to_translate, retries+1, callback)
                end}, 1500)
            else
                callback(false, text_to_translate)
            end
        end)
    end

    local function processNext()
        if current_index > total_chunks then
            final_callback(translated_text)
            return
        end
        pcall(function()
            if status_view then
                activity.runOnUiThread(function()
                    local pct = math.floor((current_index/total_chunks)*100)
                    status_view.setText(status_prefix.." "..pct.."% ("..current_index.."/"..total_chunks..")")
                end)
            end
        end)
        local chunk = chunks[current_index]
        attemptTranslate(chunk, 0, function(ok2, res2)
            translated_text = translated_text..res2.."\n\n"
            current_index = current_index + 1
            processNext()
        end)
    end

    preferred_server_index = 1
    processNext()
end

local function gemini_translate(article_text, target_lang, on_result)
    gemini_request(
        "Translate the following news article to "..target_lang..". Preserve paragraph breaks. Output ONLY the translation.\n\nARTICLE:\n"..article_text,
        on_result)
end

-- Make a rounded rectangle drawable (corner radius in dp)
local function rounded_bg(color_int, radius_dp)
    local d = GradientDrawable()
    d.setColor(color_int)
    d.setCornerRadius(radius_dp * activity.getResources().getDisplayMetrics().density)
    return d
end

-- ============================================================
-- Integrated Share Sheet
-- ============================================================
local function show_share_sheet(item)
    local title  = item.title   or "News"
    local link   = item.link    or ""
    local source = item._source or "PocketNews"
    local desc   = item.description or ""
    if link == "" then show_toast("No link to share"); return end

    local share_text = title.."\n\n"..link

    -- Share as card — formatted text card
    local share_card =
        "━━━━━━━━━━━━━━━━━━━━━━\n"..
        ""..title.."\n"..
        "━━━━━━━━━━━━━━━━━━━━━━\n"..
        (desc ~= "" and (desc:sub(1,120)..(#desc>120 and "…" or "").."\n\n") or "")..
        ""..link.."\n"..
        "Source: "..source.."\n"..
        "━━━━━━━━━━━━━━━━━━━━━━\n"..
        "Shared via PocketNews"

    -- Direct package intents for popular apps
    local function share_to_pkg(pkg, label)
        local intent = Intent(Intent.ACTION_SEND)
        intent.setType("text/plain")
        intent.putExtra(Intent.EXTRA_TEXT, share_text)
        intent.setPackage(pkg)
        local ok = pcall(function() activity.startActivity(intent) end)
        if not ok then show_toast(label.." is not installed") end
    end

    local function share_whatsapp()
        local intent = Intent(Intent.ACTION_SEND)
        intent.setType("text/plain")
        intent.putExtra(Intent.EXTRA_TEXT, share_text)
        intent.setPackage("com.whatsapp")
        local ok = pcall(function() activity.startActivity(intent) end)
        if ok then return end
        intent.setPackage("com.whatsapp.w4b")
        local ok2 = pcall(function() activity.startActivity(intent) end)
        if not ok2 then show_toast("WhatsApp is not installed") end
    end

    local function copy_link()
        pcall(function()
            local cm = activity.getSystemService("clipboard")
            cm.setPrimaryClip(ClipData.newPlainText("News link", link))
        end)
        show_toast("Link copied!")
    end

    local function system_share()
        local intent = Intent(Intent.ACTION_SEND)
        intent.setType("text/plain")
        intent.putExtra(Intent.EXTRA_TEXT, share_text)
        activity.startActivity(Intent.createChooser(intent, "Share via…"))
    end

    local function share_as_card()
        local intent = Intent(Intent.ACTION_SEND)
        intent.setType("text/plain")
        intent.putExtra(Intent.EXTRA_TEXT, share_card)
        activity.startActivity(Intent.createChooser(intent, "Share article card…"))
    end

    -- Build a custom share bottom-sheet style dialog
    local sheet_layout = {
        LinearLayout, orientation="vertical",
        layout_width="fill", layout_height="wrap",
        backgroundColor=currentTheme.surface,
        padding="16dp",

        -- Handle bar
        {LinearLayout, layout_width="fill", layout_height="wrap",
            gravity="center", layout_marginBottom="12dp",
            {TextView, text="---", textColor=currentTheme.secondaryText, textSize="10sp"},
        },

        -- Title
        {TextView, text="Share Article", textSize="18sp",
            textColor=currentTheme.text, layout_marginBottom="4dp"},
        {TextView, text=title:sub(1,80)..(#title>80 and "…" or ""),
            textSize="12sp", textColor=currentTheme.secondaryText,
            layout_marginBottom="20dp"},

        -- Row 1: social apps
        {LinearLayout, orientation="horizontal", layout_width="fill",
            layout_height="wrap", gravity="center", layout_marginBottom="12dp",

            {LinearLayout, orientation="vertical", gravity="center",
                layout_weight=1, layout_marginRight="4dp",
                {Button, id="btn_whatsapp", text="WA",
                    layout_width="56dp", layout_height="56dp",
                    backgroundColor=0xFF25D366, textColor=0xFFFFFFFF, textSize="22sp",
                    layout_marginBottom="4dp"},
                {TextView, text="WhatsApp", textSize="10sp",
                    textColor=currentTheme.secondaryText, gravity="center"},
            },

            {LinearLayout, orientation="vertical", gravity="center",
                layout_weight=1, layout_marginRight="4dp",
                {Button, id="btn_telegram", text="TG",
                    layout_width="56dp", layout_height="56dp",
                    backgroundColor=0xFF0088CC, textColor=0xFFFFFFFF, textSize="22sp",
                    layout_marginBottom="4dp"},
                {TextView, text="Telegram", textSize="10sp",
                    textColor=currentTheme.secondaryText, gravity="center"},
            },

            {LinearLayout, orientation="vertical", gravity="center",
                layout_weight=1, layout_marginRight="4dp",
                {Button, id="btn_twitter", text="X",
                    layout_width="56dp", layout_height="56dp",
                    backgroundColor=0xFF000000, textColor=0xFFFFFFFF, textSize="18sp",
                    layout_marginBottom="4dp"},
                {TextView, text="X / Twitter", textSize="10sp",
                    textColor=currentTheme.secondaryText, gravity="center"},
            },

            {LinearLayout, orientation="vertical", gravity="center",
                layout_weight=1,
                {Button, id="btn_facebook", text="f",
                    layout_width="56dp", layout_height="56dp",
                    backgroundColor=0xFF1877F2, textColor=0xFFFFFFFF, textSize="22sp",
                    layout_marginBottom="4dp"},
                {TextView, text="Facebook", textSize="10sp",
                    textColor=currentTheme.secondaryText, gravity="center"},
            },
        },

        -- Divider
        {TextView, layout_width="fill", layout_height="1dp",
            backgroundColor=currentTheme.divider, layout_marginBottom="12dp"},

        -- Row 2: utility actions
        {Button, id="btn_copy_link",
            text="Copy Link",
            layout_width="fill", layout_height="48dp",
            backgroundColor=currentTheme.chip,
            textColor=currentTheme.chipText,
            textSize="14sp", layout_marginBottom="8dp"},

        {Button, id="btn_share_card",
            text="Share as Card",
            layout_width="fill", layout_height="48dp",
            backgroundColor=Color.parseColor("#E63946"),
            textColor=Color.parseColor("#FFFFFF"),
            textSize="14sp", layout_marginBottom="8dp"},

        {Button, id="btn_more_apps",
            text="More Apps",
            layout_width="fill", layout_height="48dp",
            backgroundColor=currentTheme.background,
            textColor=currentTheme.text,
            textSize="14sp"},
    }

    local sheet_view = loadlayout(sheet_layout)
    local dlg = AlertDialog.Builder(activity).create()
    dlg.setView(sheet_view)
    dlg.show()

    sheet_view.findViewById(btn_whatsapp.getId()).onClick   = function() dlg.dismiss(); share_whatsapp() end
    sheet_view.findViewById(btn_telegram.getId()).onClick   = function() dlg.dismiss(); share_to_pkg("org.telegram.messenger","Telegram") end
    sheet_view.findViewById(btn_twitter.getId()).onClick    = function() dlg.dismiss(); share_to_pkg("com.twitter.android","Twitter/X") end
    sheet_view.findViewById(btn_facebook.getId()).onClick   = function() dlg.dismiss(); share_to_pkg("com.facebook.katana","Facebook") end
    sheet_view.findViewById(btn_copy_link.getId()).onClick  = function() dlg.dismiss(); copy_link() end
    sheet_view.findViewById(btn_share_card.getId()).onClick = function() dlg.dismiss(); share_as_card() end
    sheet_view.findViewById(btn_more_apps.getId()).onClick  = function() dlg.dismiss(); system_share() end
end

-- ============================================================
-- Settings Dialog
-- ============================================================
local function show_manage_list_dialog(title, user_list, save_key, on_change)
    local function refresh_dialog()
        local items = {}
        for _,v in ipairs(user_list) do table.insert(items, "[x] "..v) end
        table.insert(items, "+ Add new...")
        AlertDialog.Builder(activity)
            .setTitle(title)
            .setItems(items, {onClick=function(_,which)
                local idx = which+1
                if idx == #items then
                    local layout = {
                        LinearLayout, orientation="vertical", padding="16dp",
                        {EditText, id="et_new_item", hint="Enter name", layout_width="fill",
                            textColor=currentTheme.text, backgroundColor=currentTheme.surface},
                    }
                    local v = loadlayout(layout)
                    AlertDialog.Builder(activity)
                        .setTitle("Add to "..title)
                        .setView(v)
                        .setPositiveButton("Add", {onClick=function()
                            local name = tostring(v.findViewById(et_new_item.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
                            if name~="" then
                                local dup=false
                                for _,x in ipairs(user_list) do if x==name then dup=true end end
                                if not dup then
                                    table.insert(user_list, name)
                                    save_data(save_key, user_list)
                                    on_change()
                                    show_toast(name.." added")
                                else
                                    show_toast(name.." already exists")
                                end
                            end
                        end})
                        .setNegativeButton("Cancel", nil)
                        .show()
                else
                    local name = user_list[idx]
                    AlertDialog.Builder(activity)
                        .setTitle("Remove '"..name.."'?")
                        .setPositiveButton("Remove", {onClick=function()
                            table.remove(user_list, idx)
                            save_data(save_key, user_list)
                            on_change()
                            show_toast(name.." removed")
                        end})
                        .setNegativeButton("Cancel", nil)
                        .show()
                end
            end})
            .setNegativeButton("Close", nil)
            .show()
    end
    refresh_dialog()
end

-- ============================================================
-- User Guide (WebView)
-- ============================================================
function show_user_guide()
    local GUIDE_URL = "https://sushil.infinityfreeapp.com/Photo/user_guide.html"

    local FALLBACK_HTML =
        "<html><body style='font-family:sans-serif;padding:20px;background:#0f0f1a;color:#e8eaf6'>"..
        "<h2 style='color:#e63946'>PocketNews — User Guide</h2>"..
        "<p style='color:#9fa8da'>Could not load the online guide. Please check your internet connection.</p>"..
        "<h3 style='color:#e63946'>Quick Help</h3>"..
        "<b>Home</b> — Browse news by category and language.<br><br>"..
        "<b>Long press article</b> — Bookmark, Copy Link, Save Offline, Share.<br><br>"..
        "<b>Open article</b> — Tap to read. Use A+/A- for font size.<br><br>"..
        "<b>Sum.</b> — AI summary using Gemini API.<br><br>"..
        "<b>Radio tab</b> — Stream live Nepal FM stations. Sleep timer available.<br><br>"..
        "<b>Markets tab [M]</b> — Gold, Forex (NRB), NEPSE, Fuel prices.<br><br>"..
        "<b>Offline tab</b> — Read saved articles without internet.<br><br>"..
        "<b>Settings</b> — Theme, font, AI key, backup, custom themes.<br><br>"..
        "<p style='color:#5c6bc0;font-size:12px'>Full guide: sushil.infinityfreeapp.com/Photo/user_guide.html</p>"..
        "</body></html>"

    local dlg
    local layout = {
        LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill",
        backgroundColor=currentTheme.background,

        {LinearLayout, layout_width="fill", layout_height="56dp",
            backgroundColor=currentTheme.primary, gravity="center_vertical",
            paddingLeft="16dp", paddingRight="8dp",
            {TextView, text="User Guide", layout_weight=1,
                textSize="17sp", textColor=Color.parseColor(theme.buttonText)},
            {Button, id="guide_close_btn", text="X",
                layout_width="44dp", layout_height="44dp",
                background=nil, textSize="18sp",
                textColor=Color.parseColor(theme.buttonText)},
        },

        {WebView, id="guide_webview",
            layout_width="fill", layout_height="0dp", layout_weight=1},

        {LinearLayout, layout_width="fill", layout_height="48dp",
            backgroundColor=currentTheme.surface, gravity="center",
            {Button, id="guide_website_btn",
                text="sushil0.com.np",
                layout_weight=1, background=nil,
                textColor=currentTheme.primary, textSize="13sp"},
            {Button, id="guide_close_btn2",
                text="Close",
                layout_weight=1, background=nil,
                textColor=currentTheme.secondaryText, textSize="13sp"},
        },
    }

    local v = loadlayout(layout)
    local wv = v.findViewById(guide_webview.getId())

    pcall(function()
        local ws = wv.getSettings()
        ws.setJavaScriptEnabled(true)
        ws.setBuiltInZoomControls(true)
        ws.setDisplayZoomControls(false)
        ws.setLoadWithOverviewMode(true)
        ws.setUseWideViewPort(true)
    end)

    -- Try online first, fallback to local HTML on error
    pcall(function()
        wv.setWebViewClient(luajava.createProxy("android.webkit.WebViewClient", {
            onReceivedError = function(view, errorCode, description, failingUrl)
                view.loadData(FALLBACK_HTML, "text/html", "utf-8")
            end,
            onReceivedHttpError = function(view, request, errorResponse)
                view.loadData(FALLBACK_HTML, "text/html", "utf-8")
            end,
        }))
    end)
    wv.loadUrl(GUIDE_URL)

    dlg = AlertDialog.Builder(activity).create()
    dlg.setView(v)
    dlg.show()

    local function close_guide() dlg.dismiss() end
    v.findViewById(guide_close_btn.getId()).onClick  = close_guide
    v.findViewById(guide_close_btn2.getId()).onClick = close_guide
    v.findViewById(guide_website_btn.getId()).onClick = function()
        activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://sushil0.com.np")))
    end
end

-- ============================================================
-- First Launch Terms & Welcome
-- ============================================================
function show_terms_dialog()
    local GUIDE_URL = "https://sushil.infinityfreeapp.com/Photo/user_guide.html"

    local layout = {
        LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill",
        backgroundColor=currentTheme.background,

        -- Header
        {LinearLayout, layout_width="fill", layout_height="wrap",
            backgroundColor=currentTheme.primary, gravity="center",
            paddingTop="20dp", paddingBottom="20dp",
            {LinearLayout, orientation="vertical", gravity="center",
                {TextView, text="PocketNews", textSize="22sp",
                    textColor=Color.parseColor(theme.buttonText), gravity="center"},
                {TextView, text="Stay informed · Stay ahead",
                    textSize="12sp", textColor=Color.parseColor(theme.buttonText),
                    gravity="center"},
            },
        },

        -- WebView for user guide
        {WebView, id="terms_webview",
            layout_width="fill", layout_height="0dp", layout_weight=1},

        -- Divider
        {TextView, layout_width="fill", layout_height="1dp",
            backgroundColor=currentTheme.divider},

        -- Accept button
        {Button, id="terms_accept_btn",
            text="I Understand — Get Started",
            layout_width="fill", layout_height="56dp",
            backgroundColor=currentTheme.primary,
            textColor=Color.parseColor(theme.buttonText),
            textSize="15sp"},
    }

    local v  = loadlayout(layout)
    local wv = v.findViewById(terms_webview.getId())

    pcall(function()
        local ws = wv.getSettings()
        ws.setJavaScriptEnabled(true)
        ws.setBuiltInZoomControls(true)
        ws.setDisplayZoomControls(false)
        ws.setLoadWithOverviewMode(true)
        ws.setUseWideViewPort(true)
    end)

    wv.loadUrl(GUIDE_URL)

    local dlg = AlertDialog.Builder(activity).create()
    dlg.setCancelable(false)  -- must accept to proceed
    dlg.setView(v)
    dlg.show()

    v.findViewById(terms_accept_btn.getId()).onClick = function()
        save_data("first_launch.lua", {accepted=true, version=1})
        dlg.dismiss()
        -- Show feature walkthrough after accepting terms
        show_onboarding()
    end
end

function show_onboarding()
    local steps = {
        {icon="[News]", title="News Feed",       desc="Browse news from Nepal & world.\nFilter by category and language.\nTap any article to read."},
        {icon="[AI]", title="AI Summary",      desc="While reading, tap Summarize.\nGemini AI gives you a 5-line summary.\nTap Translate to read in Nepali."},
        {icon="[Radio]", title="Live Radio",       desc="Tap Radio in the bottom nav.\nStream Nepal's top FM stations.\nUse the sleep timer to auto-stop."},
        {icon="[Offline]", title="Offline Reading",  desc="Tap Save Offline on any article.\nRead it later without internet.\nFind saved articles in Offline tab."},
        {icon="[Bookmarks]", title="Bookmarks",        desc="Tap Bookmark while reading.\nAccess saved articles from nav bar.\nYour reading history is auto-saved."},
        {icon="[Markets]", title="Markets Tab",      desc="Tap [M] in the nav bar.\nSee gold prices, forex rates,\nNEPSE index and fuel prices."},
    }
    local current = {1}

    local function show_step(i)
        if i > #steps then return end
        local s = steps[i]
        local is_last = (i == #steps)
        AlertDialog.Builder(activity)
            .setTitle(s.icon.."  "..s.title.."  ("..i.."/"..#steps..")")
            .setMessage(s.desc)
            .setPositiveButton(is_last and "Get Started!" or "Next →", {onClick=function()
                show_step(i + 1)
            end})
            .setNegativeButton(i > 1 and "← Back" or "Skip", {onClick=function()
                if i > 1 then
                    show_step(i - 1)
                end
                -- Skip = just close
            end})
            .setCancelable(false)
            .show()
    end
    show_step(1)
end


function show_add_station_dialog(on_done)
    local al = {
        LinearLayout, orientation="vertical", padding="16dp",
        {TextView, text="Station Name:", textColor=currentTheme.text, layout_marginBottom="4dp"},
        {EditText, id="r_name_s", hint="e.g. My Local FM", layout_width="fill",
            textColor=currentTheme.text, layout_marginBottom="12dp"},
        {TextView, text="Stream URL:", textColor=currentTheme.text, layout_marginBottom="4dp"},
        {EditText, id="r_url_s", hint="http:// or https:// stream URL", layout_width="fill",
            textColor=currentTheme.text},
    }
    local av = loadlayout(al)
    AlertDialog.Builder(activity)
        .setTitle("Add Custom Station")
        .setView(av)
        .setPositiveButton("Add", {onClick=function()
            local nm  = tostring(av.findViewById(r_name_s.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
            local url = tostring(av.findViewById(r_url_s.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
            if nm ~= "" and url ~= "" then
                local custom = load_data("radio_custom.lua")
                if type(custom) ~= "table" then custom = {} end
                table.insert(custom, {id="custom_"..os.time(), name=nm, streamUrl=url, frequency=nil, address="Custom"})
                save_data("radio_custom.lua", custom)
                -- Also push into cached radio_stations list
                radio_stations = type(radio_stations)=="table" and radio_stations or {}
                show_toast("Added: "..nm)
                if on_done then on_done() end
            else
                show_toast("Please enter both name and URL")
            end
        end})
        .setNegativeButton("Cancel", nil)
        .show()
end

function show_manage_radio_dialog()
    local custom = load_data("radio_custom.lua")
    if type(custom) ~= "table" then custom = {} end

    if #custom == 0 then
        AlertDialog.Builder(activity)
            .setTitle("Manage Radio Stations")
            .setMessage("No custom stations saved yet.\n\nTap Add to create one.")
            .setPositiveButton("Add Station", {onClick=function() show_add_station_dialog(show_manage_radio_dialog) end})
            .setNegativeButton("Close", nil)
            .show()
        return
    end

    local labels = {}
    for _, s in ipairs(custom) do
        table.insert(labels, s.name..(s.address and s.address~="" and (" · "..s.address) or ""))
    end

    AlertDialog.Builder(activity)
        .setTitle("Custom Stations ("..#custom..")")
        .setItems(String(labels), {onClick=function(_, which)
            local s = custom[which+1]
            if not s then return end
            AlertDialog.Builder(activity)
                .setTitle(s.name)
                .setMessage("Tap Remove to delete this station.")
                .setPositiveButton("Remove", {onClick=function()
                    table.remove(custom, which+1)
                    save_data("radio_custom.lua", custom)
                    show_toast("Removed: "..s.name)
                    show_manage_radio_dialog()
                end})
                .setNegativeButton("Cancel", nil)
                .show()
        end})
        .setPositiveButton("+ Add Station", {onClick=function() show_add_station_dialog(show_manage_radio_dialog) end})
        .setNegativeButton("Close", nil)
        .show()
end


local function show_custom_theme_dialog()
    -- 5 preset palettes + custom hex entry
    local presets = {
        {name="Ocean",    accent="#0097A7", accentDark="#006064", background="#E0F7FA", cardBackground="#FFFFFF", primaryText="#00363A", secondaryText="#4DD0E1", divider="#B2EBF2", buttonText="#FFFFFF", chip="#E0F7FA", chipText="#00838F", searchBg="#FFFFFF", navActive="#FF4081", navInactive="#7A7A9A", navBg="#00363A"},
        {name="Forest",   accent="#388E3C", accentDark="#1B5E20", background="#F1F8E9", cardBackground="#FFFFFF", primaryText="#1B5E20", secondaryText="#66BB6A", divider="#DCEDC8", buttonText="#FFFFFF", chip="#F1F8E9", chipText="#2E7D32", searchBg="#FFFFFF", navActive="#FF6F00", navInactive="#7A7A9A", navBg="#1B5E20"},
        {name="Rose",     accent="#E91E63", accentDark="#880E4F", background="#FCE4EC", cardBackground="#FFFFFF", primaryText="#880E4F", secondaryText="#F48FB1", divider="#F8BBD0", buttonText="#FFFFFF", chip="#FCE4EC", chipText="#C2185B", searchBg="#FFFFFF", navActive="#FF6D00", navInactive="#7A7A9A", navBg="#880E4F"},
        {name="Midnight", accent="#7C4DFF", accentDark="#4527A0", background="#0A0A18", cardBackground="#12122A", primaryText="#E8E8FF", secondaryText="#9E9ECC", divider="#1E1E3A", buttonText="#E8E8FF", chip="#1A1A3A", chipText="#7C4DFF", searchBg="#12122A", navActive="#FF4081", navInactive="#5A5A8A", navBg="#06060F"},
        {name="Sunset",   accent="#FF6F00", accentDark="#E65100", background="#FFF8E1", cardBackground="#FFFFFF", primaryText="#3E2723", secondaryText="#FF8F00", divider="#FFE082", buttonText="#FFFFFF", chip="#FFF8E1", chipText="#E65100", searchBg="#FFFFFF", navActive="#E91E63", navInactive="#7A7A9A", navBg="#3E2723"},
    }

    local preset_names = {}
    for _, p in ipairs(presets) do table.insert(preset_names, p.name) end
    table.insert(preset_names, "Custom hex colors")

    local layout = {
        ScrollView, layout_width="fill", layout_height="fill",
        {LinearLayout, orientation="vertical", padding="16dp", layout_width="fill",

            {TextView, text="Choose a preset or enter custom colors:",
                textSize="13sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="12dp"},

            -- Preset swatches
            {LinearLayout, orientation="vertical", id="preset_list", layout_width="fill",
                layout_marginBottom="16dp"},

            -- Divider
            {TextView, layout_width="fill", layout_height="1dp",
                backgroundColor=currentTheme.divider, layout_marginBottom="16dp"},

            -- Custom hex inputs
            {TextView, text="Custom Colors (hex #RRGGBB):",
                textSize="13sp", textColor=currentTheme.text,
                layout_marginBottom="8dp"},

            {TextView, text="Accent Color", textSize="12sp", textColor=currentTheme.secondaryText},
            {EditText, id="ct_accent", hint="red / blue / E63946", layout_width="fill",
                textColor=currentTheme.text, backgroundColor=currentTheme.surface,
                layout_marginBottom="8dp"},

            {TextView, text="Background", textSize="12sp", textColor=currentTheme.secondaryText},
            {EditText, id="ct_bg", hint="white / navy / F0F4F8", layout_width="fill",
                textColor=currentTheme.text, backgroundColor=currentTheme.surface,
                layout_marginBottom="8dp"},

            {TextView, text="Card Background", textSize="12sp", textColor=currentTheme.secondaryText},
            {EditText, id="ct_card", hint="white / charcoal / FFFFFF", layout_width="fill",
                textColor=currentTheme.text, backgroundColor=currentTheme.surface,
                layout_marginBottom="8dp"},

            {TextView, text="Primary Text", textSize="12sp", textColor=currentTheme.secondaryText},
            {EditText, id="ct_text", hint="black / white / 1A1A2E", layout_width="fill",
                textColor=currentTheme.text, backgroundColor=currentTheme.surface,
                layout_marginBottom="8dp"},

            {TextView, text="Nav Bar Color", textSize="12sp", textColor=currentTheme.secondaryText},
            {EditText, id="ct_nav", hint="navy / black / 1A1A2E", layout_width="fill",
                textColor=currentTheme.text, backgroundColor=currentTheme.surface,
                layout_marginBottom="8dp"},

            {TextView, text="Nav Accent (active tab)", textSize="12sp", textColor=currentTheme.secondaryText},
            {EditText, id="ct_navactive", hint="red / gold / E63946", layout_width="fill",
                textColor=currentTheme.text, backgroundColor=currentTheme.surface,
                layout_marginBottom="16dp"},

            {Button, id="ct_apply_btn",
                text="Apply Custom Theme",
                layout_width="fill",
                backgroundColor=Color.parseColor("#E63946"),
                textColor=Color.parseColor("#FFFFFF"),
                layout_marginBottom="8dp"},

            {Button, id="ct_reset_btn",
                text="Reset to Default",
                layout_width="fill",
                backgroundColor=currentTheme.surface,
                textColor=currentTheme.text},
        }
    }

    local v   = loadlayout(layout)
    local dlg = AlertDialog.Builder(activity)
        .setTitle("Custom Theme")
        .setView(v)
        .create()
    dlg.show()

    -- Build preset buttons dynamically
    local pl = v.findViewById(preset_list.getId())
    for _, p in ipairs(presets) do
        local btn_layout = {
            LinearLayout, orientation="horizontal", layout_width="fill",
            layout_height="52dp",
            backgroundColor=Color.parseColor(p.cardBackground),
            gravity="center_vertical", padding="10dp",
            {TextView, layout_width="16dp", layout_height="fill",
                backgroundColor=Color.parseColor(p.accent)},
            {TextView, text="  "..p.name, textSize="14sp",
                textColor=Color.parseColor(p.primaryText), layout_weight=1,
                layout_marginLeft="8dp"},
            {TextView, layout_width="16dp", layout_height="fill",
                backgroundColor=Color.parseColor(p.navBg)},
        }
        local btn_v = loadlayout(btn_layout)
        -- add bottom margin via LayoutParams
        pcall(function()
            local lp = btn_v.getLayoutParams()
            lp.bottomMargin = 12
            btn_v.setLayoutParams(lp)
        end)
        btn_v.onClick = function()
            THEMES["custom"] = p
            save_data("custom_theme.lua", p)
            app_settings.theme = "custom"
            save_settings()
            refreshThemeColors()
            show_toast("Theme applied: "..p.name.." — restart app to see full effect")
            dlg.dismiss()
        end
        pl.addView(btn_v)
    end

    -- Apply custom hex
    v.findViewById(ct_apply_btn.getId()).onClick = function()
        local function hex(et_id)
            local t = tostring(v.findViewById(et_id.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
            return color_name_to_hex(t)
        end
        local accent = hex(ct_accent) or "#E63946"
        local bg     = hex(ct_bg)     or "#0F0F1A"
        local card   = hex(ct_card)   or "#1A1A2E"
        local txt    = hex(ct_text)   or "#E8EAF6"
        local nav    = hex(ct_nav)    or "#1A1A2E"
        local nava   = hex(ct_navactive) or "#E63946"

        -- Warn if any field unrecognized
        local fields = {ct_accent, ct_bg, ct_card, ct_text, ct_nav, ct_navactive}
        local bad = {}
        for _, fid in ipairs(fields) do
            local t = tostring(v.findViewById(fid.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
            if t ~= "" and not color_name_to_hex(t) then
                table.insert(bad, t)
            end
        end
        if #bad > 0 then
            show_toast("Unknown color(s): "..table.concat(bad,", ").."\nUsing defaults for those.")
        end

        -- auto-derive secondary colors
        local custom = {
            accent         = accent,
            accentDark     = accent,
            background     = bg,
            cardBackground = card,
            primaryText    = txt,
            secondaryText  = accent,
            divider        = card,
            buttonText     = bg,
            chip           = card,
            chipText       = accent,
            searchBg       = card,
            navActive      = nava,
            navInactive    = "#7A7A9A",
            navBg          = nav,
        }
        THEMES["custom"] = custom
        save_data("custom_theme.lua", custom)
        app_settings.theme = "custom"
        save_settings()
        refreshThemeColors()
        show_toast("Custom theme applied! Restart app to see full effect.")
        dlg.dismiss()
    end

    v.findViewById(ct_reset_btn.getId()).onClick = function()
        THEMES["custom"] = nil
        os.remove(base_dir.."/custom_theme.lua")
        app_settings.theme = "light"
        save_settings()
        refreshThemeColors()
        show_toast("Theme reset to Light")
        dlg.dismiss()
    end
end


local function show_settings_dialog()
    local theme_opts      = {"light","dark","custom"}
    local reader_bg_opts  = {"white","sepia","dark"}
    local font_size_opts  = {"12","14","16","18","20","22","24"}
    local translate_opts  = {"English","Nepali","Hindi","Chinese","Japanese","Korean","Arabic","French","Spanish","German"}
    local reader_mode_opts= {"full","paragraph"}

    local layout = {
        ScrollView, layout_width="fill", layout_height="fill",
        {LinearLayout, orientation="vertical", padding="20dp", layout_width="fill",

            -- Donate button
            {LinearLayout, id="btn_donate", orientation="horizontal",
                layout_width="fill", layout_height="wrap",
                backgroundColor=Color.parseColor("#1a1a2e"),
                padding="14dp", layout_marginBottom="16dp",
                gravity="center_vertical",
                {LinearLayout, orientation="vertical", layout_weight=1,
                    {TextView, text="Support the Developer",
                        textSize="14sp", textColor=Color.parseColor("#E63946")},
                    {TextView, text="PocketNews is free, open and ad-free. Your support keeps it alive.",
                        textSize="11sp", textColor=Color.parseColor("#8888aa")},
                },
                {TextView, text="→", textSize="18sp",
                    textColor=Color.parseColor("#E63946")},
            },

            {TextView, text="APPEARANCE", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginTop="4dp", layout_marginBottom="6dp"},

            {TextView, text="App Theme", textSize="15sp", textColor=currentTheme.text},
            {Spinner, id="sp_theme", layout_width="fill", layout_marginBottom="6dp"},
            {Button, id="btn_custom_theme",
                text="Create / Edit Custom Theme",
                layout_width="fill",
                backgroundColor=currentTheme.surface,
                textColor=currentTheme.text,
                textSize="13sp",
                layout_marginBottom="14dp"},

            {TextView, text="Reader Background", textSize="15sp", textColor=currentTheme.text},
            {Spinner, id="sp_readerbg", layout_width="fill", layout_marginBottom="14dp"},

            {TextView, text="Default Font Size", textSize="15sp", textColor=currentTheme.text},
            {Spinner, id="sp_fontsize", layout_width="fill", layout_marginBottom="14dp"},

            {TextView, text="Reader Mode", textSize="15sp", textColor=currentTheme.text},
            {TextView, text="full: all text at once  |  paragraph: one para at a time (screen reader friendly)",
                textSize="11sp", textColor=currentTheme.secondaryText, layout_marginBottom="4dp"},
            {Spinner, id="sp_readermode", layout_width="fill", layout_marginBottom="18dp"},

            {TextView, text="AI  (GEMINI)", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="6dp"},

            {TextView, text="Gemini Model", textSize="15sp", textColor=currentTheme.text},
            {Spinner, id="sp_ai_model", layout_width="fill", layout_marginBottom="4dp"},
            {TextView, text="gemini-2.0-flash = fast & free  |  gemini-2.5-flash = smarter",
                textSize="11sp", textColor=currentTheme.secondaryText, layout_marginBottom="14dp"},

            {TextView, text="AI Companion (Reader Chat)", textSize="15sp", textColor=currentTheme.text},
            {Spinner, id="sp_companion", layout_width="fill", layout_marginBottom="4dp"},
            {TextView, text="Chat with AI as Girlfriend / Boyfriend while reading news",
                textSize="11sp", textColor=currentTheme.secondaryText, layout_marginBottom="14dp"},

            {TextView, text="Gemini API Key", textSize="15sp", textColor=currentTheme.text},
            {EditText, id="et_apikey",
                hint="Paste API key here",
                layout_width="fill",
                inputType="textPassword",
                textColor=currentTheme.text,
                backgroundColor=currentTheme.surface,
                layout_marginBottom="4dp"},
            {TextView, text="Free key: aistudio.google.com/app/apikey",
                textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="14dp"},

            {TextView, text="Default Translation Language", textSize="15sp", textColor=currentTheme.text},
            {Spinner, id="sp_translate", layout_width="fill", layout_marginBottom="18dp"},

            {TextView, text="CATEGORIES & LANGUAGES", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_manage_cats",
                text="Manage Categories",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="8dp"},

            {Button, id="btn_manage_langs",
                text="Manage Languages",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="16dp"},

            {TextView, text="DATA", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_clear_offline",
                text="Clear All Offline News",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="8dp"},

            {Button, id="btn_clear_bookmarks",
                text="Clear All Bookmarks",
                layout_width="fill",
                backgroundColor=0xFFE53935,
                textColor=0xFFFFFFFF,
                layout_marginBottom="8dp"},

            {Button, id="btn_clear_feeds",
                text="Reset Custom Feeds",
                layout_width="fill",
                backgroundColor=0xFFFF6F00,
                textColor=0xFFFFFFFF,
                layout_marginBottom="16dp"},

            -- Notifications
            {TextView, text="NOTIFICATIONS", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_notif_interval",
                text="News Notification Interval",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="16dp"},

            -- Backup
            {TextView, text="BACKUP", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_backup",
                text="Export / Import Backup",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="8dp"},

            -- Feed tools
            {TextView, text="FEED TOOLS", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_manage_feeds",
                text="Manage Feeds (Add / Remove)",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="8dp"},

            {Button, id="btn_feed_health",
                text="Feed Health Checker",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="8dp"},

            {Button, id="btn_opml",
                text="OPML Import",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="16dp"},

            -- Radio
            {TextView, text="RADIO", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_manage_radio",
                text="Manage Radio Stations",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="16dp"},

            -- About
            {TextView, text="ABOUT", textSize="11sp", textColor=currentTheme.secondaryText,
                layout_marginBottom="8dp"},

            {Button, id="btn_whatsapp_suggest",
                text="Suggestions / Report Bug — WhatsApp",
                layout_width="fill",
                backgroundColor=Color.parseColor("#25D366"),
                textColor=Color.parseColor("#FFFFFF"),
                layout_marginBottom="8dp"},

            {Button, id="btn_about",
                text="User Guide",
                layout_width="fill",
                backgroundColor=currentTheme.primary,
                textColor=Color.parseColor(theme.buttonText),
                layout_marginBottom="8dp"},

            {Button, id="btn_changelog",
                text="What's New — v"..APP_VERSION,
                layout_width="fill",
                backgroundColor=currentTheme.surface,
                textColor=currentTheme.text,
                layout_marginBottom="8dp"},

            {Button, id="btn_check_update",
                text="Check for Update",
                layout_width="fill",
                backgroundColor=Color.parseColor("#E63946"),
                textColor=Color.parseColor("#FFFFFF"),
                layout_marginBottom="8dp"},

            {Button, id="btn_version_history",
                text="Version History",
                layout_width="fill",
                backgroundColor=currentTheme.surface,
                textColor=currentTheme.text,
                layout_marginBottom="8dp"},

            {TextView, id="tv_version",
                text="PocketNews v"..APP_VERSION.." — sushil0.com.np",
                textSize="11sp", textColor=currentTheme.secondaryText,
                gravity="center", layout_width="fill",
                layout_marginBottom="4dp"},
        }
    }

    local view = loadlayout(layout)

    local function spin_adapter(list)
        return ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, String(list))
    end

    local ai_model_opts = {
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite-preview",
        "gemini-2.5-pro",
        "gemini-3-flash-preview",
        "gemini-3.1-flash-lite-preview",
        "gemini-3.1-pro-preview",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
    }
    local companion_opts = {"None","Girlfriend","Boyfriend"}

    view.findViewById(sp_theme.getId()).setAdapter(spin_adapter(theme_opts))
    view.findViewById(sp_readerbg.getId()).setAdapter(spin_adapter(reader_bg_opts))
    view.findViewById(sp_fontsize.getId()).setAdapter(spin_adapter(font_size_opts))
    view.findViewById(sp_translate.getId()).setAdapter(spin_adapter(translate_opts))
    view.findViewById(sp_readermode.getId()).setAdapter(spin_adapter(reader_mode_opts))
    view.findViewById(sp_ai_model.getId()).setAdapter(spin_adapter(ai_model_opts))
    view.findViewById(sp_companion.getId()).setAdapter(spin_adapter(companion_opts))

    view.findViewById(sp_theme.getId()).setSelection(table.find(theme_opts, app_settings.theme)-1)
    view.findViewById(sp_readerbg.getId()).setSelection(table.find(reader_bg_opts, app_settings.reader_bg)-1)
    view.findViewById(sp_fontsize.getId()).setSelection(table.find(font_size_opts, tostring(app_settings.font_size))-1)
    view.findViewById(sp_translate.getId()).setSelection(table.find(translate_opts, app_settings.translate_lang)-1)
    view.findViewById(sp_readermode.getId()).setSelection(table.find(reader_mode_opts, app_settings.reader_mode)-1)
    view.findViewById(sp_ai_model.getId()).setSelection(math.max(0, table.find(ai_model_opts, app_settings.ai_model or "gemini-2.0-flash")-1))
    local comp_val = (app_settings.ai_companion or "none"):sub(1,1):upper()..(app_settings.ai_companion or "none"):sub(2)
    view.findViewById(sp_companion.getId()).setSelection(math.max(0, table.find(companion_opts, comp_val)-1))

    if app_settings.gemini_api_key~="" then
        view.findViewById(et_apikey.getId()).setText(app_settings.gemini_api_key)
    end

    view.findViewById(btn_manage_cats.getId()).onClick = function()
        local function refresh_cats_dialog()
            local DEFAULT_CATS = {"Health","Tech","World"}
            local items = {}
            -- Show active default cats (can be deleted)
            for _,v in ipairs(DEFAULT_CATS) do
                local deleted=false
                for _,d in ipairs(deleted_default_cats) do if d==v then deleted=true end end
                if not deleted then
                    table.insert(items, {label="[default] "..v, kind="default", name=v})
                end
            end
            -- Show deleted defaults (can be restored)
            for _,v in ipairs(deleted_default_cats) do
                table.insert(items, {label="[hidden] "..v.." (tap to restore)", kind="restore", name=v})
            end
            -- Show custom cats (can be deleted)
            for i,v in ipairs(user_cats) do
                table.insert(items, {label="[custom] "..v, kind="custom", idx=i, name=v})
            end
            -- Add new option
            table.insert(items, {label="+ Add new category...", kind="add"})

            local labels={}
            for _,it in ipairs(items) do table.insert(labels, it.label) end

            AlertDialog.Builder(activity)
                .setTitle("Manage Categories")
                .setItems(labels, {onClick=function(_,which)
                    local item = items[which+1]
                    if item.kind=="add" then
                        local layout={LinearLayout,orientation="vertical",padding="16dp",
                            {EditText,id="et_new_cat",hint="Category name",layout_width="fill",
                             textColor=currentTheme.text,backgroundColor=currentTheme.surface}}
                        local v2=loadlayout(layout)
                        AlertDialog.Builder(activity)
                            .setTitle("Add Category")
                            .setView(v2)
                            .setPositiveButton("Add",{onClick=function()
                                local name=tostring(v2.findViewById(et_new_cat.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
                                if name~="" then
                                    local dup=false
                                    for _,x in ipairs(user_cats) do if x==name then dup=true end end
                                    if not dup then
                                        table.insert(user_cats,name)
                                        save_data("user_cats.lua",user_cats)
                                        if _G.refresh_main_spinners then _G.refresh_main_spinners() end
                                        show_toast(name.." added")
                                    else show_toast(name.." already exists") end
                                end
                                refresh_cats_dialog()
                            end})
                            .setNegativeButton("Cancel",{onClick=function() refresh_cats_dialog() end})
                            .show()
                    elseif item.kind=="restore" then
                        for i,d in ipairs(deleted_default_cats) do
                            if d==item.name then table.remove(deleted_default_cats,i); break end
                        end
                        save_data("deleted_default_cats.lua", deleted_default_cats)
                        if _G.refresh_main_spinners then _G.refresh_main_spinners() end
                        show_toast(item.name.." restored")
                        refresh_cats_dialog()
                    elseif item.kind=="default" then
                        AlertDialog.Builder(activity)
                            .setTitle("Hide '"..item.name.."'?")
                            .setMessage("This will hide the '"..item.name.."' category and its built-in feeds. You can restore it anytime.")
                            .setPositiveButton("Hide", {onClick=function()
                                table.insert(deleted_default_cats, item.name)
                                save_data("deleted_default_cats.lua", deleted_default_cats)
                                if selected_category==item.name then
                                    selected_category="Health"
                                    -- fallback to first available cat
                                    local cats=get_cats()
                                    if #cats>0 then selected_category=cats[1] end
                                end
                                if _G.refresh_main_spinners then _G.refresh_main_spinners() end
                                show_toast(item.name.." hidden")
                                load_news()
                                refresh_cats_dialog()
                            end})
                            .setNegativeButton("Cancel",{onClick=function() refresh_cats_dialog() end})
                            .show()
                    elseif item.kind=="custom" then
                        AlertDialog.Builder(activity)
                            .setTitle("Remove '"..item.name.."'?")
                            .setPositiveButton("Remove",{onClick=function()
                                table.remove(user_cats, item.idx)
                                save_data("user_cats.lua",user_cats)
                                if _G.refresh_main_spinners then _G.refresh_main_spinners() end
                                show_toast(item.name.." removed")
                                load_news()
                                refresh_cats_dialog()
                            end})
                            .setNegativeButton("Cancel",{onClick=function() refresh_cats_dialog() end})
                            .show()
                    end
                end})
                .setNegativeButton("Close", nil)
                .show()
        end
        refresh_cats_dialog()
    end
    view.findViewById(btn_manage_langs.getId()).onClick = function()
        show_manage_list_dialog("Custom Languages", user_langs, "user_langs.lua", function()
            if _G.refresh_main_spinners then _G.refresh_main_spinners() end
        end)
    end
    view.findViewById(btn_clear_offline.getId()).onClick = function()
        AlertDialog.Builder(activity)
            .setTitle("Clear Offline News")
            .setMessage("Are you sure you want to delete all saved offline articles? This cannot be undone.")
            .setPositiveButton("Clear All", {onClick=function()
                os.execute("rm -f "..offline_news_dir.."*")
                show_toast("Offline news cleared")
            end})
            .setNegativeButton("Cancel", nil)
            .show()
    end
    view.findViewById(btn_clear_bookmarks.getId()).onClick = function()
        AlertDialog.Builder(activity)
            .setTitle("Clear Bookmarks")
            .setMessage("Are you sure you want to delete all bookmarks? This cannot be undone.")
            .setPositiveButton("Clear All", {onClick=function()
                bookmarks={}; save_data("bookmarks.lua",bookmarks)
                show_toast("Bookmarks cleared")
            end})
            .setNegativeButton("Cancel", nil)
            .show()
    end
    view.findViewById(btn_clear_feeds.getId()).onClick = function()
        AlertDialog.Builder(activity)
            .setTitle("Reset Custom Feeds")
            .setMessage("Are you sure you want to remove all custom RSS feeds? Default feeds will remain. This cannot be undone.")
            .setPositiveButton("Reset", {onClick=function()
                user_feeds={}; save_data("user_feeds.lua",user_feeds)
                show_toast("Custom feeds reset")
            end})
            .setNegativeButton("Cancel", nil)
            .show()
    end

    view.findViewById(btn_notif_interval.getId()).onClick = show_notif_interval_dialog
    view.findViewById(btn_manage_feeds.getId()).onClick   = show_manage_feeds_dialog
    view.findViewById(btn_backup.getId()).onClick         = show_backup_dialog
    view.findViewById(btn_feed_health.getId()).onClick    = show_feed_health_checker
    view.findViewById(btn_opml.getId()).onClick           = show_opml_import_dialog
    view.findViewById(btn_manage_radio.getId()).onClick   = show_manage_radio_dialog
    view.findViewById(btn_custom_theme.getId()).onClick   = show_custom_theme_dialog

    view.findViewById(btn_whatsapp_suggest.getId()).onClick = function()
        pcall(function()
            local uri = Uri.parse("https://wa.me/9779868890433?text="..
                Uri.encode("Hi! PocketNews app suggestion/bug report:\n\nApp version: v"..APP_VERSION.."\n\n"))
            local intent = Intent(Intent.ACTION_VIEW, uri)
            intent.setPackage("com.whatsapp")
            local ok = pcall(function() activity.startActivity(intent) end)
            if not ok then
                -- WhatsApp not installed, open in browser
                local intent2 = Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://wa.me/9779868890433"))
                activity.startActivity(intent2)
            end
        end)
    end

    view.findViewById(btn_about.getId()).onClick = function()
        show_user_guide()
    end

    -- Donate button
    view.findViewById(btn_donate.getId()).onClick = function()
        AlertDialog.Builder(activity)
            .setTitle("Support the Developer")
            .setMessage(
                "PocketNews is built by a solo developer and is completely free, ad-free, and open to everyone.\n\n"..
                "If PocketNews has been useful to you — for reading news, listening to radio, or staying updated on Nepal markets — please consider making a small donation.\n\n"..
                "Even a small amount means a lot and helps keep this app alive, updated, and free for everyone.\n\n"..
                "Send via eSewa or Khalti:\n9868890433\n\n"..
                "Open your eSewa/Khalti app → Send Money → Enter number above.\n\n"..
                "Thank you for your support!"
            )
            .setPositiveButton("Copy Number", {onClick=function()
                pcall(function()
                    local cm = activity.getSystemService("clipboard")
                    cm.setPrimaryClip(ClipData.newPlainText("eSewa number", "9868890433"))
                end)
                show_toast("Number copied — open eSewa or Khalti to send!")
            end})
            .setNegativeButton("Close", nil)
            .show()
    end

    view.findViewById(btn_changelog.getId()).onClick = function()
        local lines = {"PocketNews — What's New\n"}
        for _, entry in ipairs(APP_CHANGELOG) do
            table.insert(lines, entry[1]..":\n  "..entry[2])
        end
        AlertDialog.Builder(activity)
            .setTitle("Changelog — v"..APP_VERSION)
            .setMessage(table.concat(lines, "\n\n"))
            .setPositiveButton("OK", nil)
            .show()
    end

    view.findViewById(btn_check_update.getId()).onClick = function()
        show_toast("Checking for updates...")
        local url = "https://raw.githubusercontent.com/sushil0c/pocketnews-data/main/version.json"
        Http.get(url, function(status, body)
            if status ~= 200 or not body then
                AlertDialog.Builder(activity)
                    .setTitle("Check for Update")
                    .setMessage("Could not reach update server.\nStatus: "..tostring(status))
                    .setPositiveButton("OK", nil)
                    .show()
                return
            end
            local server_ver = body:match('"version"%s*:%s*"([^"]+)"')
            local apk_url    = body:match('"apk_url"%s*:%s*"([^"]+)"')
            local changelog  = body:match('"changelog"%s*:%s*"([^"]+)"') or ""
            if not server_ver then
                show_toast("Could not parse update info")
                return
            end
            if server_ver <= APP_VERSION then
                AlertDialog.Builder(activity)
                    .setTitle("Up to Date")
                    .setMessage("You are running the latest version.\n\nCurrent: v"..APP_VERSION)
                    .setPositiveButton("OK", nil)
                    .show()
            else
                AlertDialog.Builder(activity)
                    .setTitle("Update Available — v"..server_ver)
                    .setMessage("New version available!\n\nCurrent: v"..APP_VERSION.."\nLatest:  v"..server_ver.."\n\n"..(changelog ~= "" and "What's new:\n"..changelog or ""))
                    .setPositiveButton("Download Now", {onClick=function()
                        pcall(function()
                            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(apk_url)))
                        end)
                    end})
                    .setNegativeButton("Later", nil)
                    .show()
            end
        end)
    end

    view.findViewById(btn_version_history.getId()).onClick = function()
        show_version_history()
    end

    AlertDialog.Builder(activity)
        .setTitle("Settings")
        .setView(view)
        .setPositiveButton("Save & Apply", {onClick=function()
            local ti  = view.findViewById(sp_theme.getId()).getSelectedItemPosition()
            local ri  = view.findViewById(sp_readerbg.getId()).getSelectedItemPosition()
            local fi  = view.findViewById(sp_fontsize.getId()).getSelectedItemPosition()
            local li  = view.findViewById(sp_translate.getId()).getSelectedItemPosition()
            local mi  = view.findViewById(sp_readermode.getId()).getSelectedItemPosition()
            local ai  = view.findViewById(sp_ai_model.getId()).getSelectedItemPosition()
            local ci  = view.findViewById(sp_companion.getId()).getSelectedItemPosition()
            local k   = tostring(view.findViewById(et_apikey.getId()).getText()):gsub("^%s*(.-)%s*$","%1")

            app_settings.theme          = theme_opts[ti+1]
            app_settings.reader_bg      = reader_bg_opts[ri+1]
            app_settings.font_size      = tonumber(font_size_opts[fi+1]) or 16
            app_settings.translate_lang = translate_opts[li+1]
            app_settings.reader_mode    = reader_mode_opts[mi+1]
            app_settings.gemini_api_key = k
            app_settings.ai_model       = ai_model_opts[ai+1]
            app_settings.ai_companion   = companion_opts[ci+1]:lower()
            current_font_size           = app_settings.font_size

            save_settings()
            refreshThemeColors()
            show_toast("Settings saved! Theme applies on restart.")
        end})
        .setNegativeButton("Cancel", nil)
        .show()
end

-- ============================================================
-- Reader View  (full mode + paragraph/screen-reader mode)
-- ============================================================
function show_reader_view(item)
    if not item then return end

    local rt      = READER_THEMES[app_settings.reader_bg] or READER_THEMES.white
    local bg_col  = Color.parseColor(rt.bg)
    local txt_col = Color.parseColor(rt.text)

    local is_para_mode = (app_settings.reader_mode == "paragraph")
    local full_text    = ""   -- stored for summarize/translate

    local dialog = AlertDialog.Builder(activity).create()

    local reader_layout = {
        LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill",
        backgroundColor=bg_col,

        -- App bar
        {RelativeLayout, layout_width="fill", layout_height="60dp",
            backgroundColor=currentTheme.primary, elevation="6dp",
            {TextView, id="reader_header", text="Reader",
                textColor=Color.parseColor(theme.buttonText),
                textSize="17sp", layout_centerVertical=true, layout_marginLeft="16dp"},
            {Button, id="btn_share_header", text="Share",
                layout_alignParentRight=true, layout_marginRight="4dp",
                layout_centerVertical=true,
                layout_width="60dp", layout_height="48dp",
                background=nil, textColor=Color.parseColor(theme.buttonText), textSize="13sp"},
        },

        -- Scrollable body — content injected dynamically below
        {ScrollView, id="reader_scroll", layout_width="fill", layout_height="0dp", layout_weight=1,
            paddingLeft="18dp", paddingRight="18dp", paddingTop="14dp", paddingBottom="14dp",
            {LinearLayout, id="article_container", orientation="vertical",
                {TextView, id="reader_chip",
                    text=selected_category:upper(),
                    textSize="11sp", textColor=currentTheme.chipText,
                    backgroundColor=currentTheme.chip,
                    paddingLeft="10dp", paddingRight="10dp", paddingTop="4dp", paddingBottom="4dp",
                    layout_marginBottom="10dp"},
                {TextView, id="reader_title", text=item.title or "No Title",
                    textSize="21sp", textColor=txt_col,
                    layout_marginBottom="8dp"},
                {LinearLayout, orientation="horizontal", layout_width="fill",
                    layout_height="wrap", layout_marginBottom="14dp",
                    gravity="center_vertical",
                    {TextView, id="reader_source_tv",
                        text=(item._source or ""),
                        textSize="11sp", textColor=currentTheme.secondaryText,
                        layout_weight=1},
                    {TextView, id="reader_time_tv",
                        text="",
                        textSize="11sp", textColor=currentTheme.secondaryText},
                },
                {TextView, layout_width="fill", layout_height="1dp",
                    backgroundColor=currentTheme.divider, layout_marginBottom="14dp"},
                {TextView, id="reader_content", text="Loading article...",
                    textSize=current_font_size.."sp", textColor=txt_col},
            }
        },

        -- Bottom action bar
        {LinearLayout, orientation="horizontal", layout_width="fill", layout_height="56dp",
            backgroundColor=currentTheme.surface, elevation="10dp", gravity="center",
            {Button, text="A-",      id="font_dec",      layout_weight=1,
                background=nil, textColor=currentTheme.primary, textSize="16sp"},
            {Button, text="A+",      id="font_inc",      layout_weight=1,
                background=nil, textColor=currentTheme.primary, textSize="16sp"},
            {Button, text="Sum.",    id="btn_summarize", layout_weight=1,
                background=nil, textColor=currentTheme.primary, textSize="13sp"},
            {Button, text="Trans.",  id="btn_translate", layout_weight=1,
                background=nil, textColor=currentTheme.primary, textSize="13sp"},
            {Button, text="Chat",    id="btn_companion", layout_weight=1,
                background=nil, textColor=Color.parseColor("#E91E8C"), textSize="13sp"},
            {Button, text="Share",   id="btn_share_bar", layout_weight=1,
                background=nil, textColor=currentTheme.primary, textSize="13sp"},
            {Button, text="Browser", id="browser_btn",   layout_weight=1,
                background=nil, textColor=currentTheme.primary, textSize="13sp"},
            {Button, text="Close",   id="close_btn",     layout_weight=1,
                background=nil, textColor=currentTheme.secondaryText, textSize="13sp"},
        },
    }

    local view           = loadlayout(reader_layout)
    local content_view   = view.findViewById(reader_content.getId())
    local title_view     = view.findViewById(reader_title.getId())
    local container      = view.findViewById(article_container.getId())
    local original_text  = ""   -- saved before AI modifies content
    local original_paras = nil  -- saved paragraphs if in para mode
    local ai_active      = false -- true when AI has replaced content

    pcall(function() content_view.setLineSpacing(0, 1.6) end)
    setBold(view.findViewById(reader_header.getId()))
    setBold(title_view)
    dialog.setView(view)
    dialog.show()

    -- ── Paragraph helpers ─────────────────────────────────────
    local function split_paragraphs(text)
        local paras = {}
        for p in (text.."\n\n"):gmatch("(.-)\n\n+") do
            p = p:gsub("^%s*(.-)%s*$", "%1")
            if #p > 0 then table.insert(paras, p) end
        end
        if #paras <= 1 then
            paras = {}
            for p in text:gmatch("[^\n]+") do
                p = p:gsub("^%s*(.-)%s*$", "%1")
                if #p > 0 then table.insert(paras, p) end
            end
        end
        if #paras == 0 then paras = {text} end
        return paras
    end

    -- Dynamically add one TextView per paragraph into the container
    local function render_paragraphs(paras)
        content_view.setVisibility(8)   -- GONE
        local dp = activity.getResources().getDisplayMetrics().density
        local margin = math.floor(14 * dp)
        for i, p in ipairs(paras) do
            local tv = TextView(activity)
            tv.setText(p)
            tv.setTextSize(current_font_size)
            tv.setTextColor(txt_col)
            pcall(function() tv.setLineSpacing(0, 1.6) end)
            local lp = luajava.newInstance("android.widget.LinearLayout$LayoutParams",
                -1, -2)   -- MATCH_PARENT, WRAP_CONTENT
            pcall(function() lp.setMargins(0, 0, 0, margin) end)
            tv.setLayoutParams(lp)
            container.addView(tv)
            -- Divider between paragraphs
            if i < #paras then
                local div = TextView(activity)
                div.setText("")
                local dlp = luajava.newInstance("android.widget.LinearLayout$LayoutParams",
                    -1, math.floor(1 * dp))
                pcall(function() dlp.setMargins(0, 0, 0, margin) end)
                div.setLayoutParams(dlp)
                div.setBackgroundColor(currentTheme.divider)
                container.addView(div)
            end
        end
    end

    -- Container has 5 static children: chip(0), title(1), source_row(2), divider(3), content(4)
    -- Keep all 5, remove only dynamically added paragraph views beyond that
    local STATIC_CHILDREN = 5
    local function clear_para_views()
        local count = container.getChildCount()
        if count > STATIC_CHILDREN then
            container.removeViews(STATIC_CHILDREN, count - STATIC_CHILDREN)
        end
        content_view.setVisibility(0)   -- VISIBLE
    end

    local function restore_original()
        if not ai_active or original_text == "" then return end
        clear_para_views()
        content_view.setVisibility(0)
        content_view.setText(original_text)
        -- Re-render paragraphs if para mode
        if is_para_mode then
            content_view.setVisibility(8)
            local paras = split_paragraphs(original_text)
            render_paragraphs(paras)
        end
        ai_active = false
        show_toast("Original article restored")
    end

    -- ── Load content into reader ──────────────────────────────
    local function load_content_into_reader(text)
        full_text = text
        -- Calculate reading time (avg 200 words/min)
        local word_count = 0
        for _ in text:gmatch("%S+") do word_count = word_count + 1 end
        local mins = math.max(1, math.ceil(word_count / 200))
        pcall(function()
            local time_tv = view.findViewById(reader_time_tv.getId())
            if time_tv then
                time_tv.setText(tostring(mins).." min read")
            end
        end)
        if is_para_mode then
            content_view.setText("")
            local paras = split_paragraphs(text)
            render_paragraphs(paras)
        else
            content_view.setText(text)
        end
    end

    -- ── Font size controls ────────────────────────────────────
    view.findViewById(font_inc.getId()).onClick = function()
        current_font_size = math.min(current_font_size + 2, 30)
        content_view.setTextSize(current_font_size)
        title_view.setTextSize(current_font_size + 5)
        app_settings.font_size = current_font_size
        save_settings()
    end
    view.findViewById(font_dec.getId()).onClick = function()
        current_font_size = math.max(current_font_size - 2, 12)
        content_view.setTextSize(current_font_size)
        title_view.setTextSize(current_font_size + 5)
        app_settings.font_size = current_font_size
        save_settings()
    end

    -- ── Browser ───────────────────────────────────────────────
    view.findViewById(browser_btn.getId()).onClick = function()
        if item.link and item.link~="" then
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(item.link)))
        else
            show_toast("No link available")
        end
    end

    -- ── Share ─────────────────────────────────────────────────
    local function do_share() show_share_sheet(item) end
    view.findViewById(btn_share_header.getId()).onClick = do_share
    view.findViewById(btn_share_bar.getId()).onClick    = do_share

    -- ── AI Companion Chat ─────────────────────────────────────
    view.findViewById(btn_companion.getId()).onClick = function()
        local companion = app_settings.ai_companion or "none"
        local key = (app_settings.gemini_api_key or ""):gsub("^%s*(.-)%s*$","%1")
        if key == "" then
            show_toast("Add Gemini API key in Settings first!")
            return
        end
        -- Determine name and color
        local name, accent
        if companion == "girlfriend" then
            name = "Saathi (GF)"; accent = "#E91E8C"
        elseif companion == "boyfriend" then
            name = "Saathi (BF)"; accent = "#2196F3"
        else
            name = "AI Assistant"; accent = "#9C27B0"
        end

        local chat_history = {}
        local article_ctx = (#full_text > 0) and full_text or tostring(content_view.getText())

        -- Build chat dialog layout
        local chat_layout = {
            LinearLayout, orientation="vertical", layout_width="fill",
            layout_height="fill", backgroundColor=currentTheme.background,
            -- Header
            {LinearLayout, orientation="horizontal", layout_width="fill",
                layout_height="wrap", padding="12dp",
                backgroundColor=Color.parseColor(accent), gravity="center_vertical",
                {TextView, text=name, textSize="16sp", layout_weight=1,
                    textColor=Color.parseColor("#FFFFFF")},
                {Button, id="chat_close_btn", text="X", layout_width="36dp",
                    layout_height="36dp", background=nil,
                    textColor=Color.parseColor("#FFFFFF"), textSize="14sp"},
            },
            -- Chat messages scroll area
            {ScrollView, id="chat_scroll", layout_width="fill",
                layout_height="0dp", layout_weight=1,
                backgroundColor=currentTheme.background,
                {LinearLayout, id="chat_messages", orientation="vertical",
                    layout_width="fill", layout_height="wrap",
                    padding="10dp"},
            },
            -- Typing indicator
            {TextView, id="chat_typing", text="", textSize="12sp",
                textColor=Color.parseColor(accent),
                paddingLeft="14dp", paddingBottom="2dp"},
            -- Input row
            {LinearLayout, orientation="horizontal", layout_width="fill",
                layout_height="wrap", padding="8dp",
                backgroundColor=currentTheme.surface, gravity="center_vertical",
                {EditText, id="chat_input", layout_weight=1,
                    hint="Ask something...", textSize="14sp",
                    textColor=currentTheme.text,
                    backgroundColor=currentTheme.background,
                    padding="10dp"},
                {Button, id="chat_voice_btn", text="🎤",
                    layout_width="44dp", layout_height="44dp",
                    textSize="18sp", background=nil,
                    textColor=Color.parseColor(accent)},
                {Button, id="chat_send_btn", text="Send",
                    layout_width="70dp", layout_height="44dp",
                    textSize="13sp", textColor=Color.parseColor("#FFFFFF"),
                    backgroundColor=Color.parseColor(accent)},
            },
        }

        local cv = loadlayout(chat_layout)
        local chat_dlg = AlertDialog.Builder(activity).create()
        chat_dlg.setView(cv)
        chat_dlg.setCancelable(true)
        chat_dlg.show()

        -- Get views
        local msgs_layout  = cv.findViewById(chat_messages.getId())
        local scroll_view  = cv.findViewById(chat_scroll.getId())
        local input_et     = cv.findViewById(chat_input.getId())
        local typing_tv    = cv.findViewById(chat_typing.getId())
        local voice_btn    = cv.findViewById(chat_voice_btn.getId())

        -- Store globally so voice callbacks can access
        _G._chat_input_et  = input_et
        _G._chat_typing_tv = typing_tv

        -- Voice input — RecognitionListener pattern (AndroLua compatible)
        local is_listening = false
        local speech_recognizer = nil

        local function stop_listening()
            pcall(function()
                if speech_recognizer then
                    speech_recognizer.stopListening()
                    speech_recognizer.cancel()
                    speech_recognizer.destroy()
                    speech_recognizer = nil
                end
            end)
            is_listening = false
            pcall(function() voice_btn.setText("🎤") end)
            pcall(function()
                if _G._chat_typing_tv then
                    _G._chat_typing_tv.setText("")
                end
            end)
        end

        local function start_voice_input(lang_code)
            if is_listening then stop_listening(); return end

            pcall(function()
                local RecognizerIntent = luajava.bindClass("android.speech.RecognizerIntent")
                local recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE,
                    lang_code or "en-US")
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE,
                    activity.getPackageName())
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)

                speech_recognizer = SpeechRecognizer.createSpeechRecognizer(activity)

                local speechListener = RecognitionListener{
                    onReadyForSpeech = function(_)
                        activity.runOnUiThread(function()
                            voice_btn.setText("🔴")
                            pcall(function() _G._chat_typing_tv.setText("Listening...") end)
                            is_listening = true
                        end)
                    end,
                    onBeginningOfSpeech = function(_)
                        activity.runOnUiThread(function()
                            pcall(function() _G._chat_typing_tv.setText("Hearing you...") end)
                        end)
                    end,
                    onEndOfSpeech = function(_)
                        activity.runOnUiThread(function()
                            pcall(function() _G._chat_typing_tv.setText("Processing...") end)
                        end)
                    end,
                    onResults = function(_, results)
                        local recognized = ""
                        pcall(function()
                            local data = results.getParcelableArrayList(
                                SpeechRecognizer.RESULTS_RECOGNITION)
                            if data ~= nil and data.size() > 0 then
                                recognized = tostring(data.get(0))
                            end
                        end)
                        activity.runOnUiThread(function()
                            if recognized ~= "" and _G._chat_input_et ~= nil then
                                _G._chat_input_et.setText(recognized)
                            end
                            pcall(function() _G._chat_typing_tv.setText("") end)
                            stop_listening()
                        end)
                    end,
                    onPartialResults = function(_, results)
                        activity.runOnUiThread(function()
                            pcall(function()
                                local data = results.getParcelableArrayList(
                                    SpeechRecognizer.RESULTS_RECOGNITION)
                                if data ~= nil and data.size() > 0 then
                                    local t = data.get(0)
                                    if t ~= nil then
                                        _G._chat_typing_tv.setText(
                                            "Hearing: "..String(t).toString())
                                    end
                                end
                            end)
                        end)
                    end,
                    onError = function(_, code)
                        activity.runOnUiThread(function()
                            local msgs = {
                                [1]="Network error — check internet",
                                [2]="Network timeout",
                                [3]="Audio error — check mic",
                                [4]="Server error",
                                [5]="Client error",
                                [6]="No speech — speak louder",
                                [7]="No match — try again",
                                [8]="Recognizer busy",
                                [9]="Mic permission needed",
                            }
                            show_toast(msgs[code] or "Voice error "..tostring(code))
                            stop_listening()
                        end)
                    end,
                    onRmsChanged     = function(_, rms) end,
                    onBufferReceived = function(_, buf) end,
                    onEvent          = function(_, type, params) end,
                }

                speech_recognizer.setRecognitionListener(speechListener)
                speech_recognizer.startListening(recognizerIntent)
            end)
        end

        voice_btn.onClick = function()
            if is_listening then
                stop_listening()
                return
            end
            start_voice_input("en-US")
        end

        -- Cleanup on dialog dismiss
        chat_dlg.setOnDismissListener(luajava.createProxy(
            "android.content.DialogInterface$OnDismissListener",{
            onDismiss=function(_)
                stop_listening()
                _G._chat_input_et  = nil
                _G._chat_typing_tv = nil
            end
        }))

        -- Helper: add bubble
        local function add_bubble(text, is_user)
            local bg_color  = is_user and Color.parseColor(accent) or currentTheme.surface
            local txt_color = is_user and Color.parseColor("#FFFFFF") or currentTheme.text
            local bubble_layout = {
                LinearLayout, orientation="vertical",
                layout_width="fill", layout_height="wrap",
                paddingBottom="6dp",
                {TextView, text=text, textSize="13sp",
                    textColor=txt_color,
                    layout_gravity= is_user and 5 or 3,
                    backgroundColor=bg_color,
                    paddingLeft="12dp", paddingRight="12dp",
                    paddingTop="8dp", paddingBottom="8dp"},
            }
            local bv = loadlayout(bubble_layout)
            msgs_layout.addView(bv)
            scroll_view.post(Runnable{run=function()
                scroll_view.fullScroll(130)
            end})
        end

        -- Welcome message
        local welcome
        if companion == "girlfriend" then
            welcome = "Hey! I saw you're reading something interesting. What do you think about it? Tell me everything! "
        elseif companion == "boyfriend" then
            welcome = "Hey! What's up? Reading some news? Tell me what caught your eye."
        else
            welcome = "Hi! I'm your AI assistant. Ask me anything about this article."
        end
        add_bubble(welcome, false)
        table.insert(chat_history, {role="model", text=welcome})

        -- Send handler
        local function send_message()
            local user_msg = tostring(input_et.getText()):gsub("^%s*(.-)%s*$","%1")
            if #user_msg < 1 then return end
            input_et.setText("")
            add_bubble(user_msg, true)
            table.insert(chat_history, {role="user", text=user_msg})
            typing_tv.setText(name.." is typing...")
            gemini_companion_chat(article_ctx, user_msg, chat_history, function(reply, err)
                activity.runOnUiThread(function()
                    typing_tv.setText("")
                    local response = err and ("Sorry, something went wrong. "..err) or reply
                    add_bubble(response, false)
                    table.insert(chat_history, {role="model", text=response})
                end)
            end)
        end

        cv.findViewById(chat_send_btn.getId()).onClick = send_message
        cv.findViewById(chat_close_btn.getId()).onClick = function()
            chat_dlg.dismiss()
        end
        -- Send on keyboard action
        pcall(function()
            input_et.setOnEditorActionListener(luajava.createProxy(
                "android.widget.TextView$OnEditorActionListener",{
                onEditorAction=function(_,_,_) send_message(); return true end
            }))
        end)
    end

    -- ── Summarize ─────────────────────────────────────────────
    view.findViewById(btn_summarize.getId()).onClick = function()
        local text = (#full_text > 0) and full_text or tostring(content_view.getText())
        if #text < 30 then show_toast("Wait for article to load first."); return end
        original_text = text
        clear_para_views()
        content_view.setVisibility(0)
        content_view.setText("Summarizing with Gemini AI...")
        gemini_summarize(text, function(result, err)
            clear_para_views()
            content_view.setVisibility(0)
            if err then
                content_view.setText("Summary error:\n\n"..err)
            else
                content_view.setText(result or "")
                ai_active = true
                show_toast("Summarized! Back to restore original.")
            end
        end)
    end

    -- ── Translate ─────────────────────────────────────────────
    view.findViewById(btn_translate.getId()).onClick = function()
        local text = (#full_text > 0) and full_text or tostring(content_view.getText())
        if #text < 30 then show_toast("Wait for article to load first."); return end
        local langs = {"English","Nepali","Hindi","Chinese","Japanese","Korean","Arabic","French","Spanish","German"}
        local lang_codes = {en="en",ne="ne",hi="hi",zh="zh",ja="ja",ko="ko",ar="ar",fr="fr",es="es",de="de"}
        local code_map = {English="en",Nepali="ne",Hindi="hi",Chinese="zh-CN",Japanese="ja",Korean="ko",Arabic="ar",French="fr",Spanish="es",German="de"}
        AlertDialog.Builder(activity)
            .setTitle("Translate (Google Translate)")
            .setItems(langs, {onClick=function(_,which)
                local target = langs[which+1]
                local lang_code = code_map[target] or "en"
                original_text = text
                clear_para_views()
                content_view.setVisibility(0)
                content_view.setText("Translating to "..target.."...")
                -- Try Google Translate first, fallback to Gemini
                runCustomTranslateEngine(text, lang_code, content_view, "Translating", function(result)
                    clear_para_views()
                    content_view.setVisibility(0)
                    if result and #result > 30 then
                        content_view.setText(result)
                        ai_active = true
                        show_toast("Translated to "..target.."! Back to restore.")
                    else
                        -- Fallback to Gemini
                        local key = (app_settings.gemini_api_key or ""):gsub("^%s*(.-)%s*$","%1")
                        if key ~= "" then
                            content_view.setText("Google Translate failed. Trying Gemini...")
                            gemini_translate(text, target, function(res2, err)
                                clear_para_views()
                                content_view.setVisibility(0)
                                if err then
                                    content_view.setText("Translation failed:\n\n"..err)
                                else
                                    content_view.setText(res2 or "")
                                    ai_active = true
                                    show_toast("Translated to "..target.."! Back to restore.")
                                end
                            end)
                        else
                            content_view.setText("Translation failed. Add Gemini key in Settings as backup.")
                        end
                    end
                end)
            end})
            .setNegativeButton("Cancel", nil)
            .show()
    end

    -- ── Close button: restore original if AI active, else dismiss ─
    view.findViewById(close_btn.getId()).onClick = function()
        if ai_active then
            restore_original()
        else
            dialog.dismiss()
        end
    end

    -- ── Back button: same logic ────────────────────────────────
    dialog.setOnKeyListener({onKey=function(_, keyCode, event)
        if keyCode == 4 and event.getAction() == 0 then  -- KEYCODE_BACK, ACTION_DOWN
            if ai_active then
                restore_original()
                return true  -- consume event, don't dismiss
            end
        end
        return false
    end})

    -- ── Fetch and render article ──────────────────────────────
    if item.content and item.content~="" then
        load_content_into_reader(item.content)
    elseif item.link and item.link~="" then
        Http.get(item.link, function(status, body)
            if status==200 then
                local full = extract_article(body, item.description or "")
                load_content_into_reader(full)
            else
                load_content_into_reader((item.description or "")..
                    "\n\n(Could not load full article — HTTP "..tostring(status)..". Tap Browser.)")
            end
        end)
    else
        load_content_into_reader(item.description or "No content available.")
    end
end

-- ============================================================
-- Radio — Live Stream Player (declared before create_main_ui)
-- ============================================================

RADIO_API = "https://raw.githubusercontent.com/2shrestha22/radio/main/assets/radio_list.json"

function radio_stop()
    if radio_player then
        pcall(function() radio_player.stop() end)
        pcall(function() radio_player.release() end)
        radio_player = nil
    end
    radio_playing = false
    radio_current = nil
end

function radio_play(station, on_status)
    radio_stop()
    if on_status then on_status("Connecting to "..station.name.."...") end
    pcall(function()
        radio_player = luajava.newInstance("android.media.MediaPlayer")
        radio_player.setAudioStreamType(3)
        radio_player.setDataSource(station.streamUrl)
        radio_player.setOnPreparedListener(luajava.createProxy("android.media.MediaPlayer$OnPreparedListener",{
            onPrepared = function(mp)
                mp.start()
                radio_playing = true
                radio_current = station
                if on_status then on_status("Now Playing: "..station.name) end
            end
        }))
        radio_player.setOnErrorListener(luajava.createProxy("android.media.MediaPlayer$OnErrorListener",{
            onError = function(mp, what, extra)
                radio_stop()
                if on_status then on_status("Stream error. Try another station.") end
                return true
            end
        }))
        radio_player.prepareAsync()
    end)
end

function parse_radio_json(json_str)
    local stations = {}
    for obj in json_str:gmatch("{(.-)%s*}") do
        if not obj:find('"disabled"%s*:%s*true') then
            local id   = obj:match('"id"%s*:%s*"([^"]+)"')
            local name = obj:match('"name"%s*:%s*"([^"]+)"')
            local url  = obj:match('"streamUrl"%s*:%s*"([^"]+)"')
            local freq = obj:match('"frequency"%s*:%s*([%d%.]+)')
            local addr = obj:match('"address"%s*:%s*"([^"]*)"')
            if id and name and url then
                table.insert(stations, {
                    id        = id,
                    name      = name,
                    streamUrl = url,
                    frequency = freq and tonumber(freq) or nil,
                    address   = addr or "",
                })
            end
        end
    end
    return stations
end

-- ============================================================
-- Main UI  (modern Material layout)
-- ============================================================
function create_main_ui()
    local main_layout = {
        LinearLayout, orientation="vertical", layout_width="fill", layout_height="fill",
        backgroundColor=currentTheme.background,

        -- - Material top app bar -
        {RelativeLayout, layout_width="fill", layout_height="64dp",
            backgroundColor=currentTheme.primary, elevation="6dp",
            {LinearLayout, orientation="vertical",
                layout_centerVertical=true, layout_marginLeft="18dp",
                {TextView, id="app_title", text="PocketNews",
                    textColor=Color.parseColor(theme.buttonText),
                    textSize="20sp"},
                {TextView, text="Stay informed · Stay ahead",
                    textColor=Color.parseColor(theme.buttonText),
                    textSize="11sp"},
            },
            {Button, text="Set", id="btn_settings",
                layout_alignParentRight=true, layout_marginRight="8dp",
                layout_centerVertical=true, textSize="20sp",
                layout_width="48dp", layout_height="48dp",
                background=nil, textColor=Color.parseColor(theme.buttonText)},
        },

        -- - Filter chips row (category + language) -
        {LinearLayout, orientation="horizontal", layout_width="fill",
            layout_height="52dp", paddingLeft="8dp", paddingRight="8dp",
            backgroundColor=currentTheme.surface, elevation="2dp", gravity="center_vertical",
            {Spinner, id="cat_spin",  layout_weight=1, layout_marginRight="6dp"},
            {Spinner, id="lang_spin", layout_weight=1},
        },

        -- - Search bar with rounded corners -
        {LinearLayout, layout_width="fill", layout_height="wrap",
            paddingLeft="12dp", paddingRight="12dp", paddingTop="8dp", paddingBottom="8dp",
            backgroundColor=currentTheme.background,
            {EditText, id="search_bar",
                hint="Search news...",
                layout_width="fill", padding="12dp",
                backgroundColor=currentTheme.searchBg,
                textColor=currentTheme.text,
                hintTextColor=currentTheme.secondaryText,
                elevation="2dp"},
        },

        -- - Content area (news list / radio tab / radio player) -
        {FrameLayout, layout_width="fill", layout_height="0dp", layout_weight=1,

            -- ═══ HOME DASHBOARD VIEW ═══
            {ScrollView, id="home_view", layout_width="fill", layout_height="fill",
                backgroundColor=currentTheme.background,
                {LinearLayout, orientation="vertical", layout_width="fill",
                    layout_height="wrap", padding="14dp",

                    -- Greeting + Date card
                    {LinearLayout, orientation="vertical", layout_width="fill",
                        layout_height="wrap", layout_marginBottom="14dp",
                        backgroundColor=currentTheme.surface, padding="16dp",
                        {TextView, id="home_greeting_tv",
                            text="PocketNews", textSize="22sp",
                            textColor=currentTheme.primary, paddingBottom="6dp"},
                        {TextView, id="info_date_tv",
                            text="", textSize="14sp", textColor=currentTheme.text,
                            paddingBottom="2dp"},
                        {TextView, id="info_tithi_tv",
                            text="", textSize="12sp",
                            textColor=currentTheme.secondaryText},
                    },

                    -- Nepal Markets heading
                    {TextView, text="NEPAL MARKETS",
                        textSize="11sp", textColor=currentTheme.secondaryText,
                        paddingBottom="8dp"},

                    -- Market grid row 1
                    {LinearLayout, orientation="horizontal", layout_width="fill",
                        layout_height="wrap", layout_marginBottom="8dp",
                        {LinearLayout, id="home_gold_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            layout_marginRight="6dp",
                            backgroundColor=Color.parseColor("#1A1500"),
                            {TextView, text="Gold", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#F5A623")},
                            {TextView, text="Silver", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#A09060")},
                        },
                        {LinearLayout, id="home_forex_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            layout_marginRight="6dp",
                            backgroundColor=Color.parseColor("#001525"),
                            {TextView, text="Forex", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#29ABE2")},
                            {TextView, text="NRB Rates", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#446688")},
                        },
                        {LinearLayout, id="home_nepse_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            layout_marginRight="6dp",
                            backgroundColor=Color.parseColor("#001508"),
                            {TextView, text="NEPSE", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#27AE60")},
                            {TextView, text="Stock Index", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#2A5A30")},
                        },
                        {LinearLayout, id="home_fuel_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            backgroundColor=Color.parseColor("#1A0A00"),
                            {TextView, text="Fuel", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#E67E22")},
                            {TextView, text="NOC Price", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#6A3A10")},
                        },
                    },

                    -- Market grid row 2
                    {LinearLayout, orientation="horizontal", layout_width="fill",
                        layout_height="wrap", layout_marginBottom="14dp",
                        {LinearLayout, id="home_veg_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            layout_marginRight="6dp",
                            backgroundColor=Color.parseColor("#001A00"),
                            {TextView, text="Vegetables", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#2ECC71")},
                            {TextView, text="Kalimati", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#1A5A20")},
                        },
                        {LinearLayout, id="home_currency_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            layout_marginRight="6dp",
                            backgroundColor=Color.parseColor("#001520"),
                            {TextView, text="Converter", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#00BCD4")},
                            {TextView, text="NPR / USD", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#1A4A55")},
                        },
                        {LinearLayout, id="home_nepse2_btn", orientation="vertical",
                            layout_weight=1, gravity="center", padding="14dp",
                            backgroundColor=Color.parseColor("#001508"),
                            {TextView, text="NEPSE", textSize="13sp", gravity="center",
                                textColor=Color.parseColor("#4CAF50")},
                            {TextView, text="Chart", textSize="10sp", gravity="center",
                                textColor=Color.parseColor("#1A5A20")},
                        },
                        {TextView, layout_weight=1},
                    },

                },
            },

            -- ═══ NEWS LIST VIEW ═══
            {ListView, id="news_list_view", layout_width="fill", layout_height="fill",
                dividerHeight="1dp", divider=ColorDrawable(currentTheme.divider),
                paddingTop="4dp", paddingBottom="4dp",
                visibility="gone"},

            -- No Internet / Error screen
            {LinearLayout, id="error_view", orientation="vertical",
                layout_width="fill", layout_height="fill",
                backgroundColor=currentTheme.background,
                gravity="center", visibility="gone",
                {TextView, text="No Signal", textSize="18sp", gravity="center",
                    paddingBottom="12dp"},
                {TextView, id="error_title",
                    text="No Internet Connection",
                    textSize="18sp", textColor=currentTheme.text,
                    gravity="center", paddingBottom="8dp"},
                {TextView, id="error_msg",
                    text="Please check your connection and try again.",
                    textSize="13sp", textColor=currentTheme.secondaryText,
                    gravity="center",
                    paddingLeft="32dp", paddingRight="32dp",
                    paddingBottom="28dp"},
                {LinearLayout, id="error_retry_btn", orientation="vertical",
                    layout_width="160dp", gravity="center", padding="12dp",
                    backgroundColor=Color.parseColor("#E63946"),
{TextView, text="Retry", textSize="13sp", gravity="center",
                        textColor=Color.parseColor("#FFFFFF")},
                },
            },

            {LinearLayout, id="radio_tab_view", orientation="vertical",
                layout_width="fill", layout_height="fill",
                backgroundColor=currentTheme.background, visibility="gone",

                {LinearLayout, id="radio_now_bar", orientation="vertical",
                    layout_width="fill", layout_height="wrap",
                    backgroundColor=currentTheme.surface, elevation="4dp",
                    paddingLeft="16dp", paddingRight="16dp",
                    paddingTop="12dp", paddingBottom="12dp",
                    {TextView, id="radio_tab_icon", text="Radio",
                        textSize="28sp", gravity="center", layout_marginBottom="2dp"},
                    {TextView, id="radio_tab_status",
                        text="Not playing",
                        textSize="14sp", textColor=currentTheme.primary,
                        gravity="center", layout_marginBottom="4dp"},
                    {Button, id="radio_tab_stop_btn",
                        text="Stop",
                        layout_width="120dp", layout_height="36dp",
                        gravity="center",
                        backgroundColor=currentTheme.primary,
                        textColor=Color.parseColor(theme.buttonText),
                        textSize="13sp",
                        visibility="gone"},
                },

                {LinearLayout, layout_width="fill", layout_height="wrap",
                    paddingLeft="12dp", paddingRight="12dp",
                    paddingTop="8dp", paddingBottom="4dp",
                    backgroundColor=currentTheme.background,
                    {EditText, id="radio_tab_search",
                        hint="Search stations...",
                        layout_width="fill", padding="10dp",
                        backgroundColor=currentTheme.searchBg,
                        textColor=currentTheme.text,
                        hintTextColor=currentTheme.secondaryText,
                        elevation="2dp"},
                },

                {TextView, id="radio_tab_count",
                    text="Loading...",
                    textSize="11sp", textColor=currentTheme.secondaryText,
                    paddingLeft="16dp", paddingBottom="4dp"},

                -- Favorites filter row
                {LinearLayout, orientation="horizontal", layout_width="fill",
                    layout_height="wrap", paddingLeft="12dp", paddingRight="12dp",
                    paddingBottom="6dp", gravity="center_vertical",
                    {LinearLayout, id="radio_fav_btn", orientation="horizontal",
                        layout_width="wrap", layout_height="wrap",
                        padding="8dp", gravity="center",
                        backgroundColor=Color.parseColor("#1A1A2E"),
                        {TextView, text="★ ", textSize="13sp",
                            textColor=Color.parseColor("#FFD700")},
                        {TextView, id="radio_fav_label", text="Favorites",
                            textSize="12sp", textColor=currentTheme.text},
                    },
                    {TextView, layout_weight=1},
                    {TextView, id="radio_fav_count", text="",
                        textSize="11sp", textColor=currentTheme.secondaryText,
                        paddingRight="4dp"},
                },

                {ListView, id="radio_tab_lv",
                    layout_width="fill", layout_height="0dp", layout_weight=1,
                    dividerHeight="1dp", divider=ColorDrawable(currentTheme.divider)},

                -- Radio list bottom bar
                {LinearLayout, orientation="horizontal", layout_width="fill",
                    layout_height="52dp", backgroundColor=currentTheme.surface,
                    elevation="4dp", gravity="center",
                    {TextView, layout_weight=1},  -- spacer
                    {LinearLayout, id="radio_tab_add_btn", orientation="vertical",
                        layout_weight=1, gravity="center", padding="6dp",
                        {TextView, text="+", textSize="20sp", gravity="center",
                            textColor=currentTheme.primary},
                        {TextView, text="Add", textSize="10sp", gravity="center",
                            textColor=currentTheme.primary},
                    },
                },
            },

            -- Markets / Nepal Patro data view

            -- Radio Player view (full screen when station tapped)
            {LinearLayout, id="radio_player_view", orientation="vertical",
                layout_width="fill", layout_height="fill",
                backgroundColor=currentTheme.background, visibility="gone",
                gravity="center",

                {TextView, text="[ Radio ]", textSize="20sp", gravity="center",
                    layout_marginBottom="16dp"},

                {TextView, id="rp_name",
                    text="", textSize="20sp", textColor=currentTheme.text,
                    gravity="center", layout_marginLeft="24dp", layout_marginRight="24dp",
                    layout_marginBottom="8dp"},

                {TextView, id="rp_freq",
                    text="", textSize="14sp", textColor=currentTheme.secondaryText,
                    gravity="center", layout_marginBottom="6dp"},

                {TextView, id="rp_addr",
                    text="", textSize="13sp", textColor=currentTheme.secondaryText,
                    gravity="center", layout_marginLeft="24dp", layout_marginRight="24dp",
                    layout_marginBottom="32dp"},

                {TextView, id="rp_status",
                    text="Connecting...",
                    textSize="15sp", textColor=currentTheme.primary,
                    gravity="center", layout_marginBottom="8dp"},

                {LinearLayout, id="rp_sleep_btn", orientation="horizontal",
                    layout_width="wrap", layout_height="wrap",
                    gravity="center", padding="8dp",
                    layout_marginTop="8dp",
                    backgroundColor=Color.parseColor("#22223a"),
                    {TextView, id="rp_sleep_icon", text="Timer", textSize="12sp",
                        textColor=currentTheme.secondaryText},
                    {TextView, id="rp_sleep_label", text=" Sleep Timer: Off",
                        textSize="12sp", textColor=currentTheme.secondaryText},
                },
            },
        },

        -- - Bottom nav (FrameLayout so player nav can overlay) -
        {FrameLayout, layout_width="fill", layout_height="60dp",

            -- Main navigation bar
            {LinearLayout, id="main_nav_bar", orientation="horizontal", layout_width="fill",
                layout_height="fill", backgroundColor=currentTheme.navBg,
                elevation="12dp", gravity="center",

                {LinearLayout, id="nav_home", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="Home tab",
                    {TextView, text="[H]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navActive, importantForAccessibility="no"},
                    {TextView, text="Home", textSize="10sp", gravity="center",
                        textColor=currentTheme.navActive, importantForAccessibility="no"},
                },

                {LinearLayout, id="nav_news", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="News tab",
                    {TextView, text="[N]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                    {TextView, text="News", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                },

                {LinearLayout, id="nav_add", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="Manage Feeds tab",
                    {TextView, text="[+]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                    {TextView, text="Add Feed", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                },

                {LinearLayout, id="nav_offline", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="Offline News tab",
                    {TextView, text="[S]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                    {TextView, text="Offline", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                },

                {LinearLayout, id="nav_book", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="Saved Bookmarks tab",
                    {TextView, text="[B]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                    {TextView, text="Saved", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                },

                {LinearLayout, id="nav_history", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="News History tab",
                    {TextView, text="[T]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                    {TextView, text="History", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                },

                {LinearLayout, id="nav_radio", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp", contentDescription="Radio tab",
                    {TextView, text="[R]", textSize="14sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                    {TextView, text="Radio", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive, importantForAccessibility="no"},
                },
            },

            -- Radio player nav bar (shown only when in player view)
            {LinearLayout, id="radio_player_nav", orientation="horizontal", layout_width="fill",
                layout_height="fill", backgroundColor=currentTheme.navBg,
                elevation="12dp", gravity="center", visibility="gone",

                {LinearLayout, id="rp_nav_back", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp",
                    {TextView, text="←", textSize="20sp", gravity="center",
                        textColor=currentTheme.navActive},
                    {TextView, text="Back", textSize="10sp", gravity="center",
                        textColor=currentTheme.navActive},
                },

                {LinearLayout, id="rp_nav_prev", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp",
                    {TextView, text="|<", textSize="20sp", gravity="center",
                        textColor=currentTheme.navInactive},
                    {TextView, text="Prev", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive},
                },

                {LinearLayout, id="rp_nav_play", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp",
                    {TextView, id="rp_play_icon", text="Play", textSize="16sp", gravity="center",
                        textColor=currentTheme.primary},
                    {TextView, id="rp_play_label", text="Play", textSize="10sp", gravity="center",
                        textColor=currentTheme.primary},
                },

                {LinearLayout, id="rp_nav_next", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp",
                    {TextView, text=">|", textSize="20sp", gravity="center",
                        textColor=currentTheme.navInactive},
                    {TextView, text="Next", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive},
                },

                {LinearLayout, id="rp_nav_list", orientation="vertical", layout_weight=1,
                    gravity="center", padding="6dp",
                    {TextView, text="Menu", textSize="20sp", gravity="center",
                        textColor=currentTheme.navInactive},
                    {TextView, text="List", textSize="10sp", gravity="center",
                        textColor=currentTheme.navInactive},
                },
            },
        },
    }

    activity.setContentView(loadlayout(main_layout))

    -- Dark status bar to match app theme
    pcall(function()
        local window = activity.getWindow()
        -- Draw behind status bar
        window.addFlags(luajava.bindClass("android.view.WindowManager$LayoutParams").FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.clearFlags(luajava.bindClass("android.view.WindowManager$LayoutParams").FLAG_TRANSLUCENT_STATUS)
        -- Set status bar color to match primary (navy)
        window.setStatusBarColor(Color.parseColor("#1A1A2E"))
        -- Light icons = false (white icons on dark bg)
        local View = luajava.bindClass("android.view.View")
        local decorView = window.getDecorView()
        local flags = decorView.getSystemUiVisibility()
        -- Clear SYSTEM_UI_FLAG_LIGHT_STATUS_BAR to get white icons
        flags = flags & ~0x2000  -- 0x2000 = SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        decorView.setSystemUiVisibility(flags)
    end)
    setBold(activity.findViewById(app_title.getId()))

    -- ── Info Bar: Date + Weather + Rashi ─────────────────────
    local _info_date_tv        = activity.findViewById(info_date_tv.getId())
    local _info_tithi_tv       = activity.findViewById(info_tithi_tv.getId())

    -- Fetch Nepali date + tithi from free API
    local function load_nepali_date()
        Http.get("https://nepalidate.quiktoolbox.com/today", function(status, body)
            if status ~= 200 or not body then
                -- Fallback: English date only
                pcall(function() _info_date_tv.setText(os.date("%A, %d %B %Y")) end)
                return
            end
            local year_np  = body:match('"yearNp"%s*:%s*"([^"]+)"')  or ""
            local month_np = body:match('"monthNp"%s*:%s*"([^"]+)"') or ""
            local day_np   = body:match('"dayNp"%s*:%s*"([^"]+)"')   or ""
            local dow_np   = body:match('"dayOfWeekNp"%s*:%s*"([^"]+)"') or ""
            local tithi_np = body:match('"nameNp"%s*:%s*"([^"]+)"')  or ""
            local paksha   = body:match('"pakshaNp"%s*:%s*"([^"]+)"') or ""
            local nakshatra= body:match('"name"%s*:%s*"([^"]+)"')    or ""
            local sunrise  = body:match('"sunrise"%s*:%s*"([^"]+)"') or ""
            local sunset   = body:match('"sunset"%s*:%s*"([^"]+)"')  or ""

            local np_date = year_np.." "..month_np.." "..day_np
            local en_date = os.date("%A, %d %B %Y")

            pcall(function()
                _info_date_tv.setText(np_date.." ("..en_date..")")
                _info_tithi_tv.setText(
                    dow_np..
                    (tithi_np ~= "" and "  |  "..paksha.." "..tithi_np or "")..
                    (nakshatra ~= "" and "  |  "..nakshatra or "")..
                    (sunrise ~= "" and "\n☀ "..sunrise.."  🌙 "..sunset or "")
                )
            end)
        end)
    end
    load_nepali_date()

    -- Hide keyboard on startup and prevent search bar auto-focus
    pcall(function()
        local sb = activity.findViewById(search_bar.getId())
        sb.setFocusable(false)
        sb.setFocusableInTouchMode(false)
        -- Re-enable on tap so user can still type
        sb.setOnClickListener(luajava.createProxy("android.view.View$OnClickListener", {
            onClick = function(v)
                v.setFocusable(true)
                v.setFocusableInTouchMode(true)
                v.requestFocus()
                local imm = activity.getSystemService("input_method")
                imm.showSoftInput(v, 0)
            end
        }))
    end)

    -- Explicitly resolve radio tab views (nested layout IDs need findViewById)
    local _error_view       = activity.findViewById(error_view.getId())
    local _error_title      = activity.findViewById(error_title.getId())
    local _error_msg        = activity.findViewById(error_msg.getId())
    local _error_retry_btn  = activity.findViewById(error_retry_btn.getId())
    error_view      = _error_view
    error_title     = _error_title
    error_msg       = _error_msg
    error_retry_btn = _error_retry_btn
    local _radio_tab_view    = activity.findViewById(radio_tab_view.getId())
    local _radio_tab_lv      = activity.findViewById(radio_tab_lv.getId())
    local _radio_tab_search  = activity.findViewById(radio_tab_search.getId())
    local _radio_tab_count   = activity.findViewById(radio_tab_count.getId())
    local _radio_tab_status  = activity.findViewById(radio_tab_status.getId())
    local _radio_tab_stop_btn= activity.findViewById(radio_tab_stop_btn.getId())
    local _radio_tab_add_btn = activity.findViewById(radio_tab_add_btn.getId())
    -- Reassign globals so functions below can use them
    radio_tab_view    = _radio_tab_view
    radio_tab_lv      = _radio_tab_lv
    radio_tab_search  = _radio_tab_search
    radio_tab_count   = _radio_tab_count
    radio_tab_status  = _radio_tab_status
    radio_tab_stop_btn= _radio_tab_stop_btn
    radio_tab_add_btn = _radio_tab_add_btn

    -- Resolve player view + player nav views
    local _radio_player_view = activity.findViewById(radio_player_view.getId())
    local _radio_player_nav  = activity.findViewById(radio_player_nav.getId())
    local _main_nav_bar      = activity.findViewById(main_nav_bar.getId())
    local _rp_name           = activity.findViewById(rp_name.getId())
    local _rp_freq           = activity.findViewById(rp_freq.getId())
    local _rp_addr           = activity.findViewById(rp_addr.getId())
    local _rp_status         = activity.findViewById(rp_status.getId())
    local _rp_play_icon      = activity.findViewById(rp_play_icon.getId())
    local _rp_play_label     = activity.findViewById(rp_play_label.getId())
    local _rp_nav_back       = activity.findViewById(rp_nav_back.getId())
    local _rp_nav_prev       = activity.findViewById(rp_nav_prev.getId())
    local _rp_nav_play       = activity.findViewById(rp_nav_play.getId())
    local _rp_nav_next       = activity.findViewById(rp_nav_next.getId())
    local _rp_nav_list       = activity.findViewById(rp_nav_list.getId())
    local _rp_sleep_btn      = activity.findViewById(rp_sleep_btn.getId())
    local _rp_sleep_label    = activity.findViewById(rp_sleep_label.getId())
    radio_player_view = _radio_player_view
    radio_player_nav  = _radio_player_nav
    main_nav_bar      = _main_nav_bar
    rp_name           = _rp_name
    rp_freq           = _rp_freq
    rp_addr           = _rp_addr
    rp_status         = _rp_status
    rp_play_icon      = _rp_play_icon
    rp_play_label     = _rp_play_label
    rp_nav_back       = _rp_nav_back
    rp_nav_prev       = _rp_nav_prev
    rp_nav_play       = _rp_nav_play
    rp_nav_next       = _rp_nav_next
    rp_nav_list       = _rp_nav_list
    rp_sleep_btn      = _rp_sleep_btn
    rp_sleep_label    = _rp_sleep_label

    -- Resolve markets views
    local _home_view            = activity.findViewById(home_view.getId())
    local _nav_news             = activity.findViewById(nav_news.getId())
    local _home_greeting_tv     = activity.findViewById(home_greeting_tv.getId())
    local _home_gold_btn        = activity.findViewById(home_gold_btn.getId())
    local _home_forex_btn       = activity.findViewById(home_forex_btn.getId())
    local _home_nepse_btn       = activity.findViewById(home_nepse_btn.getId())
    local _home_fuel_btn        = activity.findViewById(home_fuel_btn.getId())
    local _home_veg_btn         = activity.findViewById(home_veg_btn.getId())
    local _home_nepse2_btn      = activity.findViewById(home_nepse2_btn.getId())
    local _home_currency_btn    = activity.findViewById(home_currency_btn.getId())
    home_view           = _home_view
    nav_news            = _nav_news
    home_greeting_tv    = _home_greeting_tv



    -- Currency converter dialog
    local function show_currency_dialog()
        local currencies = {"NPR","USD","EUR","GBP","INR","CNY","AUD","CAD","JPY","SGD","AED","SAR","QAR","KWD","CHF","HKD","KRW","MYR","THB","BDT"}
        local dlg_layout = {
            LinearLayout, orientation="vertical", layout_width="fill",
            backgroundColor=currentTheme.background, padding="20dp",
            {TextView, text="💱 Currency Converter",
                textSize="18sp", textColor=Color.parseColor("#00BCD4"),
                paddingBottom="16dp"},
            {EditText, id="dlg_amount_et",
                hint="Enter amount", layout_width="fill",
                textSize="18sp", textColor=currentTheme.text,
                backgroundColor=currentTheme.surface, padding="12dp",
                inputType="numberDecimal", layout_marginBottom="12dp"},
            {LinearLayout, orientation="horizontal", layout_width="fill",
                gravity="center_vertical", layout_marginBottom="16dp",
                {Spinner, id="dlg_from_spin", layout_weight=1,
                    backgroundColor=currentTheme.surface},
                {TextView, text=" ⇄ ", textSize="20sp",
                    textColor=Color.parseColor("#00BCD4"),
                    paddingLeft="8dp", paddingRight="8dp"},
                {Spinner, id="dlg_to_spin", layout_weight=1,
                    backgroundColor=currentTheme.surface},
            },
            {LinearLayout, id="dlg_convert_btn", layout_width="fill",
                layout_height="48dp", gravity="center",
                backgroundColor=Color.parseColor("#00BCD4"), layout_marginBottom="14dp",
                {TextView, text="Convert", textSize="15sp", gravity="center",
                    textColor=Color.parseColor("#000000")},
            },
            {TextView, id="dlg_result_tv",
                text="", textSize="20sp", gravity="center",
                textColor=Color.parseColor("#00BCD4"),
                layout_marginBottom="4dp"},
            {TextView, id="dlg_rate_tv",
                text="", textSize="11sp", gravity="center",
                textColor=currentTheme.secondaryText},
        }
        local v = loadlayout(dlg_layout)
        local adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, String(currencies))
        v.findViewById(dlg_from_spin.getId()).setAdapter(adapter)
        v.findViewById(dlg_to_spin.getId()).setAdapter(adapter)
        v.findViewById(dlg_from_spin.getId()).setSelection(0)  -- NPR
        v.findViewById(dlg_to_spin.getId()).setSelection(1)    -- USD

        local dlg = AlertDialog.Builder(activity).create()
        dlg.setView(v)
        dlg.show()

        v.findViewById(dlg_convert_btn.getId()).onClick = function()
            local amt = tonumber(tostring(v.findViewById(dlg_amount_et.getId()).getText()))
            if not amt or amt <= 0 then show_toast("Enter a valid amount"); return end
            local from = currencies[v.findViewById(dlg_from_spin.getId()).getSelectedItemPosition()+1]
            local to   = currencies[v.findViewById(dlg_to_spin.getId()).getSelectedItemPosition()+1]
            if from == to then
                v.findViewById(dlg_result_tv.getId()).setText(string.format("%.4f %s", amt, to))
                return
            end
            v.findViewById(dlg_result_tv.getId()).setText("Converting...")
            Http.get("https://api.exchangerate-api.com/v4/latest/"..from, function(s, b)
                if s ~= 200 or not b then
                    v.findViewById(dlg_result_tv.getId()).setText("Could not fetch rate")
                    return
                end
                local rate = b:match('"'..to..'"%s*:%s*([%d%.]+)')
                if rate then
                    local res = amt * tonumber(rate)
                    pcall(function()
                        v.findViewById(dlg_result_tv.getId()).setText(
                            string.format("%.2f %s = %.4f %s", amt, from, res, to))
                        v.findViewById(dlg_rate_tv.getId()).setText(
                            "1 "..from.." = "..rate.." "..to)
                    end)
                else
                    v.findViewById(dlg_result_tv.getId()).setText("Rate not found for "..to)
                end
            end)
        end
    end

    _home_currency_btn.onClick = show_currency_dialog

    local function show_market_dialog(title, color, load_fn)
        local tv_id = "dlg_mkt_tv"
        local layout = {
            LinearLayout, orientation="vertical", layout_width="fill",
            backgroundColor=currentTheme.background, padding="20dp",
            {TextView, text=title, textSize="16sp",
                textColor=Color.parseColor(color), paddingBottom="12dp"},
            {TextView, id="dlg_mkt_tv", text="Loading...",
                textSize="12sp", textColor=currentTheme.text,
                paddingBottom="4dp"},
        }
        local v = loadlayout(layout)
        local tv = v.findViewById(dlg_mkt_tv.getId())
        local dlg = AlertDialog.Builder(activity)
            .setView(v)
            .setPositiveButton("Close", nil)
            .create()
        dlg.show()
        load_fn(tv)
    end

    _home_gold_btn.onClick = function()
        show_market_dialog("🥇 Gold & Silver", "#F5A623", function(tv)
            Http.get("https://www.ashesh.com.np/gold/widget.php?api=622227j343&header_color=0077e5", function(s, b)
                if s ~= 200 or not b then pcall(function() tv.setText("Could not load") end); return end
                -- Strip CSS/JS/HTML, extract meaningful lines
                local clean = b:gsub("<style.->.-</style>","")
                               :gsub("<script.->.-</script>","")
                               :gsub("<[^>]+>","")
                               :gsub("&nbsp;"," ")
                               :gsub("&#%d+;","")
                local lines = {}
                for line in clean:gmatch("[^\n]+") do
                    line = line:gsub("^%s*(.-)%s*$","%1")
                    if #line >= 5 and not line:match("^var ") and
                       not line:match("font%-") and not line:match("^%.") and
                       not line:match("^@") and not line:match("^body") then
                        table.insert(lines, line)
                    end
                end
                pcall(function() tv.setText(table.concat(lines, "\n")) end)
            end)
        end)
    end

    _home_forex_btn.onClick = function()
        show_market_dialog("Forex Rates — NRB", "#29ABE2", function(tv)
            local today = os.date("%Y-%m-%d")
            local url = "https://www.nrb.org.np/api/forex/v1/rates?from="..today.."&to="..today.."&per_page=40&page=1"
            Http.get(url, function(s, b)
                if s ~= 200 or not b then
                    pcall(function() tv.setText("Could not load NRB forex rates") end)
                    return
                end
                local rows = {}
                -- JSON: {"data":{"payload":[{"date":"...","rates":[{"currency":{"iso3":"USD","unit":1},"buy":"135.00","sell":"135.60"},...]}]}}
                for iso, unit, buy, sell in b:gmatch('"iso3"%s*:%s*"([^"]+)".-"unit"%s*:%s*(%d+).-"buy"%s*:%s*"([^"]+)".-"sell"%s*:%s*"([^"]+)"') do
                    local u = unit ~= "1" and "/"..unit or ""
                    table.insert(rows, string.format("%-6s%s  Buy:%-9s Sell:%s", iso, u, buy, sell))
                end
                if #rows > 0 then
                    pcall(function() tv.setText(table.concat(rows, "\n")) end)
                else
                    -- Fallback: show raw snippet for debug
                    pcall(function() tv.setText("Parse failed.\n"..b:sub(1,200)) end)
                end
            end)
        end)
    end

    local function load_nepse_dialog()
        show_market_dialog("📈 NEPSE Index", "#27AE60", function(tv)
            Http.get("https://www.merolagani.com/Indices.aspx", function(s, b)
                if s ~= 200 or not b then pcall(function() tv.setText("Could not load") end); return end
                local lines = {}
                -- Extract index rows from table
                for row in b:gmatch("<tr[^>]*>(.-)</tr>") do
                    local cells = {}
                    for cell in row:gmatch("<t[dh][^>]*>(.-)</t[dh]>") do
                        local text = cell:gsub("<[^>]+>",""):gsub("&nbsp;"," "):gsub("^%s*(.-)%s*$","%1")
                        if #text > 0 then table.insert(cells, text) end
                    end
                    if #cells >= 2 then
                        table.insert(lines, table.concat(cells, "  "))
                    end
                end
                if #lines == 0 then
                    pcall(function() tv.setText("Could not parse NEPSE data") end)
                else
                    pcall(function() tv.setText(table.concat(lines, "\n")) end)
                end
            end)
        end)
    end
    _home_nepse_btn.onClick  = load_nepse_dialog
    _home_nepse2_btn.onClick = load_nepse_dialog

    _home_fuel_btn.onClick = function()
        show_market_dialog("Fuel Prices — NOC", "#E67E22", function(tv)
            -- Use widget endpoint (same as gold widget, gives clean data)
            Http.get("https://www.ashesh.com.np/fuel/widget.php?api=622227j343", function(s, b)
                if s ~= 200 or not b then
                    pcall(function() tv.setText("Could not load fuel data") end); return
                end
                local clean = b
                    :gsub("<script.->.-</script>", "")
                    :gsub("<style.->.-</style>", "")
                    :gsub("<[^>]+>", "\n")
                    :gsub("&nbsp;", " ")
                    :gsub("&#%d+;", "")
                    :gsub("[ \t]+", " ")
                local lines, seen = {}, {}
                for line in clean:gmatch("[^\n]+") do
                    line = line:gsub("^%s*(.-)%s*$", "%1")
                    if #line >= 3 and not seen[line]
                        and not line:match("^var ") and not line:match("function")
                        and not line:match("privacy") and not line:match("google")
                        and not line:match("^{") and not line:match("^}") then
                        seen[line] = true
                        table.insert(lines, line)
                    end
                end
                pcall(function()
                    tv.setText(#lines > 0 and table.concat(lines, "\n") or "No fuel data")
                end)
            end)
        end)
    end

    _home_veg_btn.onClick = function()
        show_market_dialog("Vegetable Prices — Kalimati", "#2ECC71", function(tv)
            Http.get("https://www.ashesh.com.np/vegetable/widget.php?api=622227j343", function(s, b)
                if s ~= 200 or not b then
                    pcall(function() tv.setText("Could not load vegetable data") end); return
                end
                local clean = b
                    :gsub("<script.->.-</script>", "")
                    :gsub("<style.->.-</style>", "")
                    :gsub("<[^>]+>", "\n")
                    :gsub("&nbsp;", " ")
                    :gsub("&#%d+;", "")
                    :gsub("[ \t]+", " ")
                local lines, seen = {}, {}
                for line in clean:gmatch("[^\n]+") do
                    line = line:gsub("^%s*(.-)%s*$", "%1")
                    if #line >= 3 and not seen[line]
                        and not line:match("^var ") and not line:match("function")
                        and not line:match("privacy") and not line:match("google")
                        and not line:match("^{") and not line:match("^}") then
                        seen[line] = true
                        table.insert(lines, line)
                    end
                end
                pcall(function()
                    tv.setText(#lines > 0 and table.concat(lines, "\n") or "No vegetable data")
                end)
            end)
        end)
    end


    local function setup_webview(wv, url)
        pcall(function()
            local ws = wv.getSettings()
            ws.setJavaScriptEnabled(true)
            ws.setLoadWithOverviewMode(true)
            ws.setUseWideViewPort(true)
            ws.setBuiltInZoomControls(true)
            ws.setDisplayZoomControls(false)
        end)
        wv.loadUrl(url)
    end

    -- Player state
    local player_all_stations = {}   -- full list while player is open
    local player_index        = 1    -- current station index in player_all_stations

    local function rp_update_play_btn()
        if radio_playing then
            rp_play_icon.setText("Stop")
            rp_play_label.setText("Stop")
        else
            rp_play_icon.setText("Play")
            rp_play_label.setText("Play")
        end
    end

    local function open_player(station, all_stations, idx)
        player_all_stations = all_stations
        player_index        = idx
        -- Show player view, hide list
        radio_tab_view.setVisibility(8)
        radio_player_view.setVisibility(0)
        -- Swap nav bars
        main_nav_bar.setVisibility(8)
        radio_player_nav.setVisibility(0)
        -- Fill station info
        local freq = station.frequency and (station.frequency.." MHz") or ""
        local addr = (station.address and station.address ~= "" and station.address ~= "null") and station.address or ""
        rp_name.setText(station.name)
        rp_freq.setText(freq)
        rp_addr.setText(addr)
        rp_status.setText("Connecting...")
        rp_update_play_btn()
        -- Start playing
        radio_play(station, function(msg)
            rp_status.setText(msg)
            rp_update_play_btn()
        end)
    end

    local function close_player()
        radio_stop()
        radio_player_view.setVisibility(8)
        radio_tab_view.setVisibility(0)
        main_nav_bar.setVisibility(0)
        radio_player_nav.setVisibility(8)
        if _G.set_active_nav then _G.set_active_nav(nav_radio) end
        if _G.cancel_sleep_timer then _G.cancel_sleep_timer() end
        -- Update list status bar
        if _G.radio_tab_update_status then _G.radio_tab_update_status() end
    end

    -- Wire player nav buttons
    rp_nav_back.onClick = function()
        close_player()
    end

    rp_nav_play.onClick = function()
        if radio_playing then
            radio_stop()
            rp_status.setText("Stopped")
            rp_update_play_btn()
        else
            local st = player_all_stations[player_index]
            if st then
                rp_status.setText("Connecting...")
                radio_play(st, function(msg)
                    rp_status.setText(msg)
                    rp_update_play_btn()
                end)
            end
        end
    end

    rp_nav_prev.onClick = function()
        if #player_all_stations == 0 then return end
        player_index = player_index - 1
        if player_index < 1 then player_index = #player_all_stations end
        open_player(player_all_stations[player_index], player_all_stations, player_index)
    end

    rp_nav_next.onClick = function()
        if #player_all_stations == 0 then return end
        player_index = player_index + 1
        if player_index > #player_all_stations then player_index = 1 end
        open_player(player_all_stations[player_index], player_all_stations, player_index)
    end

    rp_nav_list.onClick = function()
        close_player()
    end

    -- ── Sleep Timer ──────────────────────────────────────────
    local sleep_handler   = luajava.newInstance("android.os.Handler")
    local sleep_runnable  = nil
    local sleep_timer_mins = 0

    local function cancel_sleep_timer()
        if sleep_runnable then
            pcall(function() sleep_handler.removeCallbacks(sleep_runnable) end)
            sleep_runnable = nil
        end
        sleep_timer_mins = 0
        pcall(function() rp_sleep_label.setText(" Sleep Timer: Off") end)
    end

    local function set_sleep_timer(mins)
        cancel_sleep_timer()
        if mins == 0 then return end
        sleep_timer_mins = mins
        rp_sleep_label.setText(" Stops in "..tostring(mins).." min")
        local ms = mins * 60 * 1000
        sleep_runnable = luajava.createProxy("java.lang.Runnable", {
            run = function()
                radio_stop()
                pcall(function()
                    if _G.radio_close_player then _G.radio_close_player() end
                end)
                show_toast("Sleep timer — radio stopped")
                sleep_runnable  = nil
                sleep_timer_mins = 0
                pcall(function() rp_sleep_label.setText(" Sleep Timer: Off") end)
            end
        })
        sleep_handler.postDelayed(sleep_runnable, ms)
    end

    rp_sleep_btn.onClick = function()
        local opts = {"15 minutes","30 minutes","60 minutes","90 minutes","Cancel Timer"}
        AlertDialog.Builder(activity)
            .setTitle("Sleep Timer")
            .setItems(opts, {onClick=function(_, which)
                local choices = {15, 30, 60, 90, 0}
                local m = choices[which + 1]
                set_sleep_timer(m)
                if m > 0 then
                    show_toast("Sleep timer set: "..m.." min")
                else
                    show_toast("Sleep timer cancelled")
                end
            end})
            .show()
    end
    _G.cancel_sleep_timer = cancel_sleep_timer

    -- Expose open_player so radio list tap can call it
    _G.radio_open_player = open_player
    _G.radio_close_player = close_player

    local function get_cats()
        local base={}
        for _,v in ipairs({"Health","Tech","World"}) do
            local deleted=false
            for _,d in ipairs(deleted_default_cats) do if d==v then deleted=true end end
            if not deleted then table.insert(base,v) end
        end
        for _,v in ipairs(user_cats) do table.insert(base,v) end
        return base
    end
    local function get_langs()
        local base={"English","Hindi","Nepali"}
        for _,v in ipairs(user_langs) do table.insert(base,v) end
        return base
    end

    local function refresh_spinners()
        local cats  = get_cats()
        local langs = get_langs()
        cat_spin.setAdapter(ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, String(cats)))
        lang_spin.setAdapter(ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, String(langs)))
        cat_spin.setSelection(math.max(0, table.find(cats, selected_category)-1))
        lang_spin.setSelection(math.max(0, table.find(langs, selected_language)-1))
        cat_spin.onItemSelected  = function(_,_,pos)
            local c=get_cats(); selected_category=c[pos+1]; load_news()
        end
        lang_spin.onItemSelected = function(_,_,pos)
            local l=get_langs(); selected_language=l[pos+1]; load_news()
        end
    end
    refresh_spinners()
    _G.refresh_main_spinners = refresh_spinners

    search_bar.addTextChangedListener{onTextChanged=function(s)
        local q,filtered=tostring(s):lower(),{}
        for _,v in ipairs(news_data) do
            if v.title:lower():find(q,1,true) then table.insert(filtered,v) end
        end
        update_list(filtered)
    end}

    btn_settings.onClick = show_settings_dialog

    -- Helper to announce tab selection to screen reader
    local function announce(view, msg)
        pcall(function() view.announceForAccessibility(msg) end)
    end

    -- Show/hide radio tab vs news list
    local radio_tab_open = false
    local radio_tab_stations = {}  -- filtered list currently shown

    local function show_news_tab()
        radio_tab_open = false
        home_view.setVisibility(8)
        news_list_view.setVisibility(0)
        radio_tab_view.setVisibility(8)
        pcall(function() error_view.setVisibility(8) end)
        pcall(function() cat_spin.setVisibility(0) end)
        pcall(function() lang_spin.setVisibility(0) end)
        pcall(function() search_bar.setVisibility(0) end)
        pcall(function() main_nav_bar.setVisibility(0) end)
        pcall(function() radio_player_nav.setVisibility(8) end)
        pcall(function() radio_player_view.setVisibility(8) end)
    end

    local function show_home_tab()
        radio_tab_open = false
        home_view.setVisibility(0)
        news_list_view.setVisibility(8)
        radio_tab_view.setVisibility(8)
        pcall(function() error_view.setVisibility(8) end)
        pcall(function() cat_spin.setVisibility(8) end)
        pcall(function() lang_spin.setVisibility(8) end)
        pcall(function() search_bar.setVisibility(8) end)
        pcall(function() main_nav_bar.setVisibility(0) end)
        pcall(function() radio_player_nav.setVisibility(8) end)
        pcall(function() radio_player_view.setVisibility(8) end)
        -- Update greeting
        local hour = tonumber(os.date("%H")) or 12
        local greeting = hour < 12 and "शुभ प्रभात" or
                         hour < 17 and "नमस्ते" or
                         hour < 20 and "शुभ सन्ध्या" or "शुभ रात्री"
        pcall(function() home_greeting_tv.setText(greeting) end)
    end
    _G.show_news_tab_fn = show_home_tab

    local function radio_tab_refresh_list(all_stations, query)
        local q = (query or ""):lower()
        local fav_ids = load_data("radio_favs.lua")
        if type(fav_ids) ~= "table" then fav_ids = {} end
        -- Build fav id set
        local fav_set = {}
        for _, id in ipairs(fav_ids) do fav_set[tostring(id)] = true end

        local res = {}
        for _, s in ipairs(all_stations) do
            if q == "" or s.name:lower():find(q,1,true) or
               (s.address and s.address:lower():find(q,1,true)) then
                table.insert(res, s)
            end
        end
        -- Sort: favorites first, then alphabetical
        table.sort(res, function(a, b)
            local af = fav_set[tostring(a.id)] and 1 or 0
            local bf = fav_set[tostring(b.id)] and 1 or 0
            if af ~= bf then return af > bf end
            return (a.name or "") < (b.name or "")
        end)
        radio_tab_stations = res
        local labels = {}
        local fav_count = 0
        for _, s in ipairs(res) do
            local freq = s.frequency and (" · "..s.frequency.." MHz") or ""
            local addr = (s.address and s.address ~= "" and s.address ~= "null") and (" · "..s.address) or ""
            local playing = radio_playing and radio_current and radio_current.id == s.id
            local fav = fav_set[tostring(s.id)] and "★ " or ""
            if fav ~= "" then fav_count = fav_count + 1 end
            table.insert(labels, (playing and "▶ " or "")..fav..s.name..freq..addr)
        end
        radio_tab_lv.setAdapter(ArrayAdapter(activity, android.R.layout.simple_list_item_1, String(labels)))
        radio_tab_count.setText(#res.." stations")
        pcall(function()
            local fav_count_tv = activity.findViewById(radio_fav_count.getId())
            fav_count_tv.setText(fav_count > 0 and (fav_count.." ★") or "")
        end)
        return fav_set
    end

    local function radio_tab_update_status()
        if radio_playing and radio_current then
            radio_tab_status.setText("Now Playing: "..radio_current.name)
            radio_tab_stop_btn.setVisibility(0)
        else
            radio_tab_status.setText("Not playing")
            radio_tab_stop_btn.setVisibility(8)
        end
    end
    _G.radio_tab_update_status = radio_tab_update_status

    local function open_radio_tab(all_stations)
        radio_tab_open = true
        news_list_view.setVisibility(8)   -- GONE
        radio_tab_view.setVisibility(0)   -- VISIBLE
        -- hide news filter/search (not needed in radio tab)
        pcall(function() cat_spin.setVisibility(8) end)
        pcall(function() lang_spin.setVisibility(8) end)
        pcall(function() search_bar.setVisibility(8) end)

        radio_tab_update_status()
        radio_tab_refresh_list(all_stations, "")

        radio_tab_search.addTextChangedListener{onTextChanged=function(s)
            radio_tab_refresh_list(all_stations, tostring(s))
        end}

        radio_tab_lv.onItemClick = function(_, _, which)
            local station = radio_tab_stations[which + 1]
            if not station then return end
            -- Find index in all_stations for prev/next
            local idx = 1
            for i, s in ipairs(all_stations) do
                if s.id == station.id then idx = i; break end
            end
            if _G.radio_open_player then
                _G.radio_open_player(station, all_stations, idx)
            end
        end

        radio_tab_lv.onItemLongClick = function(_, _, which)
            local station = radio_tab_stations[which + 1]
            if not station then return true end

            -- Check fav status
            local fav_ids = load_data("radio_favs.lua")
            if type(fav_ids) ~= "table" then fav_ids = {} end
            local is_fav = false
            local fav_idx = nil
            for i, id in ipairs(fav_ids) do
                if tostring(id) == tostring(station.id) then
                    is_fav = true; fav_idx = i; break
                end
            end

            -- Check if custom
            local custom = load_data("radio_custom.lua")
            if type(custom) ~= "table" then custom = {} end
            local is_custom = false
            for _, s in ipairs(custom) do
                if s.id == station.id then is_custom = true; break end
            end

            local opts = {is_fav and "★ Remove from Favorites" or "☆ Add to Favorites"}
            if is_custom then table.insert(opts, "Remove Station") end

            AlertDialog.Builder(activity)
                .setTitle(station.name)
                .setItems(opts, {onClick=function(_, opt_which)
                    local opt = opts[opt_which + 1]
                    if opt:find("Favorites") then
                        if is_fav and fav_idx then
                            table.remove(fav_ids, fav_idx)
                            show_toast("Removed from favorites")
                        else
                            table.insert(fav_ids, tostring(station.id))
                            show_toast("★ Added to favorites: "..station.name)
                        end
                        save_data("radio_favs.lua", fav_ids)
                        radio_tab_refresh_list(all_stations, tostring(radio_tab_search.getText()))
                    elseif opt == "Remove Station" then
                        local new_custom = {}
                        for _, s in ipairs(custom) do
                            if s.id ~= station.id then table.insert(new_custom, s) end
                        end
                        save_data("radio_custom.lua", new_custom)
                        show_toast("Removed: "..station.name)
                        for i = #all_stations, 1, -1 do
                            if all_stations[i].id == station.id then
                                table.remove(all_stations, i)
                            end
                        end
                        radio_tab_refresh_list(all_stations, tostring(radio_tab_search.getText()))
                    end
                end})
                .setNegativeButton("Cancel", nil)
                .show()
            return true
        end

        -- Favorites filter button
        local show_favs_only = false
        pcall(function()
            local fav_btn = activity.findViewById(radio_fav_btn.getId())
            local fav_label = activity.findViewById(radio_fav_label.getId())
            fav_btn.onClick = function()
                show_favs_only = not show_favs_only
                if show_favs_only then
                    fav_label.setText("All Stations")
                    fav_btn.setBackgroundColor(Color.parseColor("#FFD700"))
                    -- Filter to favs only
                    local fav_ids = load_data("radio_favs.lua")
                    if type(fav_ids) ~= "table" then fav_ids = {} end
                    local fav_set = {}
                    for _, id in ipairs(fav_ids) do fav_set[tostring(id)] = true end
                    local fav_stations = {}
                    for _, s in ipairs(all_stations) do
                        if fav_set[tostring(s.id)] then table.insert(fav_stations, s) end
                    end
                    if #fav_stations == 0 then
                        show_toast("No favorites yet! Long press a station to add.")
                        show_favs_only = false
                        fav_label.setText("Favorites")
                        fav_btn.setBackgroundColor(Color.parseColor("#1A1A2E"))
                    else
                        radio_tab_refresh_list(fav_stations, "")
                    end
                else
                    fav_label.setText("Favorites")
                    fav_btn.setBackgroundColor(Color.parseColor("#1A1A2E"))
                    radio_tab_refresh_list(all_stations, tostring(radio_tab_search.getText()))
                end
            end
        end)

        radio_tab_stop_btn.onClick = function()
            radio_stop()
            radio_tab_update_status()
            radio_tab_refresh_list(all_stations, tostring(radio_tab_search.getText()))
        end

        radio_tab_add_btn.onClick = function()
            show_add_station_dialog(function()
                -- reload to pick up new station
                local new_custom = load_data("radio_custom.lua")
                if type(new_custom) == "table" then
                    for _, s in ipairs(new_custom) do
                        -- add to all_stations if not already there
                        local found = false
                        for _, ex in ipairs(all_stations) do if ex.id == s.id then found=true; break end end
                        if not found then table.insert(all_stations, s) end
                    end
                end
                radio_tab_refresh_list(all_stations, tostring(radio_tab_search.getText()))
            end)
        end
    end

    local function load_radio_tab()
        local custom = load_data("radio_custom.lua")
        if type(custom) ~= "table" then custom = {} end
        if type(radio_stations) == "table" and #radio_stations > 0 then
            local all = {}
            for _, s in ipairs(radio_stations) do table.insert(all, s) end
            for _, s in ipairs(custom)         do table.insert(all, s) end
            open_radio_tab(all)
        else
            radio_tab_count.setText("Loading stations...")
            Http.get(RADIO_API, function(status, body)
                if status == 200 then
                    radio_stations = parse_radio_json(body)
                    local all = {}
                    for _, s in ipairs(radio_stations) do table.insert(all, s) end
                    for _, s in ipairs(custom)         do table.insert(all, s) end
                    open_radio_tab(all)
                else
                    radio_tab_count.setText("Could not load stations (HTTP "..tostring(status)..")")
                end
            end)
        end
    end

    -- Bottom nav click handlers
    -- Highlight active nav button by updating child TextView colors
    local nav_buttons = {nav_home, nav_news, nav_add, nav_offline, nav_book, nav_history, nav_radio}
    local function set_active_nav(active)
        for _, btn in ipairs(nav_buttons) do
            local is_active = (btn == active)
            local col = is_active and currentTheme.navActive or currentTheme.navInactive
            local bg  = is_active and Color.parseColor("#2A1A2E") or Color.parseColor("#00000000")
            btn.setBackgroundColor(bg)
            -- update both child TextViews (icon + label)
            local count = btn.getChildCount()
            for i = 0, count - 1 do
                btn.getChildAt(i).setTextColor(col)
            end
        end
    end
    -- Wire home dashboard rashi button
    -- Show home tab on startup
    set_active_nav(nav_home)
    show_home_tab()
    _G.set_active_nav = set_active_nav
    _G.nav_home_btn   = nav_home

    nav_home.onClick = function()
        announce(nav_home, "Home tab selected")
        set_active_nav(nav_home)
        show_home_tab()
    end

    nav_news.onClick = function()
        announce(nav_news, "News tab selected")
        set_active_nav(nav_news)
        show_news_tab()
        load_news()
    end
    nav_add.onClick     = function()
        announce(nav_add, "Manage Feeds tab selected")
        show_manage_feeds_dialog()
    end
    nav_offline.onClick = function()
        announce(nav_offline, "Offline News tab selected")
        set_active_nav(nav_offline)
        show_offline_news()
    end
    nav_book.onClick    = function()
        announce(nav_book, "Saved Bookmarks tab selected")
        set_active_nav(nav_book)
        if #bookmarks == 0 then
            AlertDialog.Builder(activity)
                .setTitle("No Bookmarks Yet")
                .setMessage("You haven't bookmarked any articles yet.\n\nWhile reading an article, tap 'Bookmark' to save it here for quick access.")
                .setPositiveButton("OK", nil)
                .show()
            return
        end
        show_news_tab()
        update_list(bookmarks,"bookmark")
    end
    nav_history.onClick = function()
        announce(nav_history, "News History tab selected")
        set_active_nav(nav_history)
        show_history_dialog()
    end
    nav_radio.onClick   = function()
        announce(nav_radio, "Radio tab selected")
        set_active_nav(nav_radio)
        load_radio_tab()
    end


    news_list_view.onItemClick = function(_,_,pos)
        show_reader_view(display_data[pos+1])
    end

    -- Long-press context menu with integrated Share option
    news_list_view.onItemLongClick = function(_,_,pos)
        local item=display_data[pos+1]
        local options
        if display_data.is_bookmark then
            options={"Remove Bookmark","Copy Link","Share","Open in Browser"}
        else
            options={"Bookmark","Copy Link","Save Offline","Share","Open in Browser"}
        end
        AlertDialog.Builder(activity)
            .setTitle("Article Options")
            .setItems(options, {onClick=function(_,which)
                local opt=options[which+1]
                if opt=="Bookmark" then
                    table.insert(bookmarks,item); save_data("bookmarks.lua",bookmarks)
                    show_toast("Bookmarked")
                elseif opt=="Remove Bookmark" then
                    for i, b in ipairs(bookmarks) do
                        if b.link == item.link then
                            table.remove(bookmarks, i); break
                        end
                    end
                    save_data("bookmarks.lua",bookmarks)
                    update_list(bookmarks,"bookmark"); show_toast("Removed")
                elseif opt=="Copy Link" then
                    pcall(function()
                        local cm = activity.getSystemService("clipboard")
                        cm.setPrimaryClip(ClipData.newPlainText("Article link", item.link or ""))
                    end)
                    show_toast("Link copied!")
                elseif opt=="Save Offline" then
                    save_offline(item)
                elseif opt=="Share" then
                    show_share_sheet(item)
                elseif opt=="Open in Browser" then
                    if item.link and item.link~="" then
                        activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(item.link)))
                    else show_toast("No link available") end
                end
            end})
            .show()
        return true
    end
end

-- ============================================================
-- Update list
-- ============================================================
-- ============================================================
-- Format article publish date as relative time
-- ============================================================
local function format_pub_date(date_str)
    if not date_str or date_str == "" then return "" end

    -- Parse RFC 2822 pubDate: "Mon, 14 Mar 2026 10:30:00 +0545"
    local months = {Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,
                    Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}

    local day, mon_s, year, h, m, s =
        date_str:match("(%d+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)")

    if not day then
        -- Try ISO format: "2026-03-14T10:30:00"
        year, mon_s, day, h, m = date_str:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d)")
        if year then
            mon_s = tonumber(mon_s)  -- already numeric
        end
    end

    if not day then return date_str:sub(1, 16) end  -- fallback: raw string trim

    local mon_n = type(mon_s) == "number" and mon_s or (months[mon_s] or 1)

    -- Build timestamp
    local pub_t = os.time({
        year  = tonumber(year),
        month = mon_n,
        day   = tonumber(day),
        hour  = tonumber(h) or 0,
        min   = tonumber(m) or 0,
        sec   = tonumber(s) or 0,
    })

    local now   = os.time()
    local diff  = now - pub_t

    if diff < 0 then diff = 0 end

    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        local mins = math.floor(diff / 60)
        return mins.."m ago"
    elseif diff < 86400 then
        local hrs = math.floor(diff / 3600)
        return hrs.."h ago"
    elseif diff < 172800 then
        return "Yesterday"
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return days.."d ago"
    else
        -- Older: show "Mar 14"
        local mon_names = {"Jan","Feb","Mar","Apr","May","Jun",
                           "Jul","Aug","Sep","Oct","Nov","Dec"}
        return (mon_names[mon_n] or "").." "..tostring(day)
    end
end

function update_list(data, list_type)
    display_data=data
    display_data.is_bookmark=(list_type=="bookmark")
    local titles={}
    for _,v in ipairs(data) do
        local src  = v._source and (" ["..v._source.."]") or ""
        local t    = format_pub_date(v.date or "")
        local time = t ~= "" and ("  · "..t) or ""
        table.insert(titles, (v.title or "No Title")..src..time)
    end
    news_list_view.setAdapter(ArrayAdapter(activity, android.R.layout.simple_list_item_1, String(titles)))
end

local function offline_index_add(title, filename)
    local index = load_data("offline_news/_index.lua")
    if type(index) ~= "table" then index = {} end
    -- Avoid duplicates
    for _, e in ipairs(index) do
        if e.file == filename then return end
    end
    table.insert(index, {title=title, file=filename})
    save_data("offline_news/_index.lua", index)
end

-- ============================================================
-- Auto-save top N articles offline on each news load
-- ============================================================
local AUTO_SAVE_COUNT = 5   -- how many top articles to auto-save

local function auto_save_top_articles(items)
    local saved = 0
    for i, item in ipairs(items) do
        if saved >= AUTO_SAVE_COUNT then break end
        if not item.link or item.link == "" then
        else
        local filename = item.title:gsub("[%s%p/]","_")..".lua"
        local full = offline_news_dir..filename
        local f = io.open(full, "r")
        if f then f:close()
        else
            local lnk = item.link
            local ttl = item.title
            local dsc = item.description or ""
            Http.get(lnk, function(status, body)
                if status == 200 then
                    local text = extract_article(body, dsc)
                    save_data("offline_news/"..filename, {title=ttl, content=text, link=lnk})
                    offline_index_add(ttl, filename)
                end
            end)
            saved = saved + 1
        end
        end
    end
end

-- ============================================================
-- Load News
-- ============================================================
function load_news()
    local urls={}
    local is_deleted_default=false
    for _,d in ipairs(deleted_default_cats) do if d==selected_category then is_deleted_default=true end end
    local cat_defaults= (not is_deleted_default) and (default_feeds[selected_category] and default_feeds[selected_category][selected_language] or {}) or {}
    local cat_user    =user_feeds[selected_category]    and user_feeds[selected_category][selected_language]    or {}
    for _,u in ipairs(cat_defaults) do table.insert(urls,u) end
    for _,u in ipairs(cat_user)     do table.insert(urls,u) end

    -- Remember for notification scheduler
    app_settings.last_cat  = selected_category
    app_settings.last_lang = selected_language

    local use_np=(selected_language=="Nepali")
    if #urls==0 and not use_np then update_list({}); return end

    -- Only show news list if news tab is currently active
    pcall(function()
        error_view.setVisibility(8)
        if home_view and home_view.getVisibility() == 8 then
            news_list_view.setVisibility(0)
        end
    end)

    show_toast("Loading…")
    local all_items,completed,failed={},0,0
    local total=#urls+(use_np and 1 or 0)

    local function on_done(success)
        completed=completed+1
        if not success then failed=failed+1 end
        if completed==total then
            if #all_items==0 then
                -- All failed — show error screen
                pcall(function()
                    if failed == total then
                        news_list_view.setVisibility(8)
                        error_view.setVisibility(0)
                        error_title.setText("No Internet Connection")
                        error_msg.setText("Could not load news.\nPlease check your connection and tap Retry.")
                        error_retry_btn.onClick = function()
                            error_view.setVisibility(8)
                            news_list_view.setVisibility(0)
                            load_news()
                        end
                    else
                        show_toast("No items found")
                    end
                end)
            else
                pcall(function() error_view.setVisibility(8) end)
                -- Update last refreshed time
                last_refreshed_time = os.time()
            end
            -- Sort by actual publish timestamp (newest first)
            local function date_to_ts(date_str)
                if not date_str or date_str == "" then return 0 end
                local months = {Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,
                                Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
                -- RFC 2822: "Mon, 20 Mar 2026 10:30:00 +0545"
                local d,ms,y,h,m,s = date_str:match("(%d+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)")
                if d then
                    local mn = months[ms] or 1
                    local ok, ts = pcall(os.time, {year=tonumber(y),month=mn,day=tonumber(d),
                        hour=tonumber(h),min=tonumber(m),sec=tonumber(s)})
                    return ok and ts or 0
                end
                -- ISO: "2026-03-20T10:30:00"
                local y2,m2,d2,h2,mi2 = date_str:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d)")
                if y2 then
                    local ok, ts = pcall(os.time, {year=tonumber(y2),month=tonumber(m2),
                        day=tonumber(d2),hour=tonumber(h2),min=tonumber(mi2),sec=0})
                    return ok and ts or 0
                end
                return 0
            end
            table.sort(all_items, function(a,b)
                return date_to_ts(a.date) > date_to_ts(b.date)
            end)
            news_data=all_items
            history_save_items(all_items)
            auto_save_top_articles(all_items)
            update_list(news_data)
            if #all_items > 0 then
                local top = all_items[1].title or "New articles available"
                show_notification("PocketNews — "..#all_items.." articles loaded", top)
            end
        end
    end

    local seen_links  = {}  -- dedup by URL
    local seen_titles = {}  -- dedup by title similarity

    local function is_valid_item(item)
        -- Must have a real title (not garbage HTML)
        local t = item.title or ""
        if #t < 5 then return false end
        if t:match("^%s*$") then return false end
        -- Reject if title looks like raw HTML
        if t:match("^<!") or t:match("^<html") or t:match("^<body") then return false end
        if t:match("^{") or t:match("^%[") then return false end
        -- Must have a valid link
        local l = item.link or ""
        if not l:match("^https?://") then return false end
        return true
    end

    local function try_insert(item)
        if not is_valid_item(item) then return end
        -- Dedup by exact link
        local link = item.link or ""
        if seen_links[link] then return end
        seen_links[link] = true
        -- Dedup by title (first 40 chars)
        local title_key = (item.title or ""):sub(1,40):lower():gsub("%s+","")
        if seen_titles[title_key] then return end
        seen_titles[title_key] = true
        table.insert(all_items, item)
    end

    for _,url in ipairs(urls) do
        local src_domain = url:match("https?://([^/]+)") or url
        Http.get(url,function(status,body)
            if status==200 then
                for _,item in ipairs(parse_rss(body)) do
                    item._source = src_domain
                    try_insert(item)
                end
                on_done(true)
            else
                on_done(false)
            end
        end)
    end

    if use_np then
        Http.get(NEPALI_PATRO_API,function(status,body)
            if status==200 then
                for _,item in ipairs(parse_nepali_patro(body)) do
                    item._source = "nepalipatro.com.np"
                    try_insert(item)
                end
                on_done(true)
            else
                on_done(false)
            end
        end)
    end
end

-- ============================================================
-- Add Custom Feed
-- ============================================================
function show_add_feed_dialog()
    local cats = {}
    for _,v in ipairs({"Health","Tech","World"}) do
        local deleted=false
        for _,d in ipairs(deleted_default_cats) do if d==v then deleted=true end end
        if not deleted then table.insert(cats,v) end
    end
    for _,v in ipairs(user_cats)  do table.insert(cats,v)  end
    local langs= {"English","Hindi","Nepali"}
    for _,v in ipairs(user_langs) do table.insert(langs,v) end
    local layout={
        LinearLayout, orientation="vertical", padding="16dp",
        {EditText, id="url_edit", hint="RSS Feed URL https://…", layout_width="fill", textColor=currentTheme.text},
        {TextView, text="Category:", layout_marginTop="10dp", textColor=currentTheme.text},
        {Spinner, id="cat_spin_d", layout_width="fill"},
        {TextView, text="Language:", layout_marginTop="10dp", textColor=currentTheme.text},
        {Spinner, id="lang_spin_d", layout_width="fill"},
    }
    local view=loadlayout(layout)
    view.findViewById(cat_spin_d.getId()).setAdapter(ArrayAdapter(activity,android.R.layout.simple_spinner_dropdown_item,String(cats)))
    view.findViewById(lang_spin_d.getId()).setAdapter(ArrayAdapter(activity,android.R.layout.simple_spinner_dropdown_item,String(langs)))
    AlertDialog.Builder(activity)
        .setTitle("Add Custom RSS Feed")
        .setView(view)
        .setPositiveButton("Add",{onClick=function()
            local url =tostring(view.findViewById(url_edit.getId()).getText()):gsub("^%s*(.-)%s*$","%1")
            local cat =cats[view.findViewById(cat_spin_d.getId()).getSelectedItemPosition()+1]
            local lang=langs[view.findViewById(lang_spin_d.getId()).getSelectedItemPosition()+1]
            if url~="" then
                user_feeds[cat]      =user_feeds[cat]      or {}
                user_feeds[cat][lang]=user_feeds[cat][lang] or {}
                table.insert(user_feeds[cat][lang],url)
                save_data("user_feeds.lua",user_feeds)
                load_news()
                show_toast("Feed added to "..cat.." / "..lang)
            end
        end})
        .setNegativeButton("Cancel",nil)
        .show()
end

function show_manage_feeds_dialog()
    -- Build flat list of all user feeds with their cat/lang info
    local flat = {}
    for cat, langs in pairs(user_feeds) do
        if type(langs) == "table" then
            for lang, urls in pairs(langs) do
                if type(urls) == "table" then
                    for i, url in ipairs(urls) do
                        table.insert(flat, {cat=cat, lang=lang, url=url, idx=i})
                    end
                end
            end
        end
    end

    if #flat == 0 then
        AlertDialog.Builder(activity)
            .setTitle("No Custom Feeds")
            .setMessage("You have not added any custom RSS feeds yet.\n\nTap Add Feed to add your first feed.")
            .setPositiveButton("Add Feed", {onClick=function()
                show_add_feed_dialog()
            end})
            .setNegativeButton("Close", nil)
            .show()
        return
    end

    -- Build display labels
    local labels = {}
    for _, f in ipairs(flat) do
        local domain = f.url:match("https?://([^/]+)") or f.url
        table.insert(labels, domain.."\n["..f.cat.." / "..f.lang.."]")
    end

    AlertDialog.Builder(activity)
        .setTitle("Manage Feeds ("..#flat..")")
        .setItems(labels, {onClick=function(_, which)
            local feed = flat[which + 1]
            local domain = feed.url:match("https?://([^/]+)") or feed.url
            AlertDialog.Builder(activity)
                .setTitle(domain)
                .setMessage(feed.url.."\n\nCategory: "..feed.cat.."\nLanguage: "..feed.lang)
                .setPositiveButton("Remove", {onClick=function()
                    -- Remove from user_feeds
                    local list = user_feeds[feed.cat] and user_feeds[feed.cat][feed.lang]
                    if list then
                        for i, u in ipairs(list) do
                            if u == feed.url then
                                table.remove(list, i)
                                break
                            end
                        end
                    end
                    save_data("user_feeds.lua", user_feeds)
                    show_toast("Removed: "..domain)
                    load_news()
                    -- Reopen with updated list
                    show_manage_feeds_dialog()
                end})
                .setNegativeButton("Cancel", nil)
                .show()
        end})
        .setNeutralButton("Add New", {onClick=function()
            show_add_feed_dialog()
        end})
        .setNegativeButton("Close", nil)
        .show()
end

-- ============================================================
-- Save Offline
-- ============================================================
-- Update the offline news index file
function save_offline(item)
    show_toast("Saving…")
    Http.get(item.link,function(status,body)
        if status==200 then
            local paragraphs={}
            local clean=body:gsub("<script.-</script>",""):gsub("<style.-</style>","")
            for p in clean:gmatch("<p[^>]*>(.-)</p>") do
                local t=decode_html(p); if #t>30 then table.insert(paragraphs,t) end
            end
            local content=table.concat(paragraphs,"\n\n")
            if #content<50 then content=item.description or "" end
            local filename=item.title:gsub("[%s%p/]","_")..".lua"
            save_data("offline_news/"..filename,{title=item.title,content=content,link=item.link})
            offline_index_add(item.title, filename)
            show_toast("Saved offline")
        else
            show_toast("Could not save – HTTP "..tostring(status))
        end
    end)
end

-- ============================================================
-- Offline News List
-- ============================================================
function show_offline_news()
    local index = load_data("offline_news/_index.lua")
    if type(index) ~= "table" then index = {} end
    local valid = {}
    for _, entry in ipairs(index) do
        local f = io.open(offline_news_dir..entry.file, "r")
        if f then f:close(); table.insert(valid, entry) end
    end
    if #valid == 0 then
        AlertDialog.Builder(activity)
            .setTitle("No Offline Articles")
            .setMessage("You haven't saved any articles offline yet.\n\nWhile reading an article, tap 'Save Offline' to keep it for reading without internet.")
            .setPositiveButton("OK", nil)
            .show()
        return
    end

    local display = {}
    for _, entry in ipairs(valid) do
        table.insert(display, (entry.title or entry.file))
    end

    local function do_delete(entry)
        AlertDialog.Builder(activity)
            .setTitle("Delete Article?")
            .setMessage(entry.title or entry.file)
            .setPositiveButton("Delete", {onClick=function()
                os.remove(offline_news_dir..entry.file)
                local new_index = {}
                for _, e in ipairs(valid) do
                    if e.file ~= entry.file then
                        table.insert(new_index, e)
                    end
                end
                save_data("offline_news/_index.lua", new_index)
                show_toast("Deleted")
                show_offline_news()
            end})
            .setNegativeButton("Cancel", nil)
            .show()
    end

    local dlg = AlertDialog.Builder(activity).create()

    local lv = ListView(activity)
    lv.setAdapter(ArrayAdapter(activity, android.R.layout.simple_list_item_1, String(display)))

    lv.onItemClick = function(_, _, which)
        dlg.dismiss()
        local data = load_data("offline_news/"..valid[which+1].file)
        if data and data.title then
            show_reader_view(data)
        else
            show_toast("Error loading file")
        end
    end

    lv.onItemLongClick = function(_, _, which)
        dlg.dismiss()
        do_delete(valid[which + 1])
        return true
    end

    dlg.setTitle("Offline News ("..#valid..")  |  Hold to delete")
    dlg.setView(lv)
    dlg.setButton(-2, "Delete All", {onClick=function()
        AlertDialog.Builder(activity)
            .setTitle("Delete All?")
            .setMessage("Remove all "..#valid.." offline saved articles?")
            .setPositiveButton("Delete All", {onClick=function()
                for _, entry in ipairs(valid) do
                    os.remove(offline_news_dir..entry.file)
                end
                save_data("offline_news/_index.lua", {})
                show_toast("All offline news deleted")
            end})
            .setNegativeButton("Cancel", nil)
            .show()
    end})
    dlg.setButton(-1, "Close", {onClick=function() dlg.dismiss() end})
    dlg.show()
end

-- ============================================================
-- Feature 1: Export / Import Settings Backup
-- ============================================================
-- Backup path: /storage/emulated/0/pocketnews/
local BACKUP_PATH = ""
pcall(function()
    local Environment = luajava.bindClass("android.os.Environment")
    local root = Environment.getExternalStorageDirectory().getAbsolutePath()
    local dir  = root .. "/pocketnews"
    -- create folder if not exists
    local File = luajava.bindClass("java.io.File")
    local folder = File(dir)
    if not folder.exists() then folder.mkdirs() end
    BACKUP_PATH = dir .. "/pocketnews_backup.lua"
end)
if BACKUP_PATH == "" then BACKUP_PATH = base_dir .. "/pocketnews_backup.lua" end

local function export_backup()
    local backup = {
        settings   = app_settings,
        user_feeds = user_feeds,
        user_cats  = user_cats,
        user_langs = user_langs,
        bookmarks  = bookmarks,
    }
    local f = io.open(BACKUP_PATH, "w")
    if not f then show_toast("Could not write to: "..BACKUP_PATH); return end
    f:write("return "..serialize(backup))
    f:close()
    show_toast("Backup saved to: "..BACKUP_PATH)
end

local function import_backup()
    local f = io.open(BACKUP_PATH, "r")
    if not f then
        show_toast("No backup file found at: "..BACKUP_PATH)
        return
    end
    local src = f:read("*a"); f:close()
    local fn  = loadstring(src)
    if not fn then show_toast("Backup file is corrupted"); return end
    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then show_toast("Could not load backup"); return end

    AlertDialog.Builder(activity)
        .setTitle("Import Backup")
        .setMessage("This will overwrite your current settings, feeds, categories, languages and bookmarks. Continue?")
        .setPositiveButton("Import", {onClick=function()
            if type(data.settings)   == "table" then
                for k,v in pairs(data.settings) do app_settings[k]=v end
                save_settings()
                refreshThemeColors()
                current_font_size = app_settings.font_size
            end
            if type(data.user_feeds) == "table" then
                user_feeds = data.user_feeds
                save_data("user_feeds.lua", user_feeds)
            end
            if type(data.user_cats)  == "table" then
                user_cats = data.user_cats
                save_data("user_cats.lua", user_cats)
            end
            if type(data.user_langs) == "table" then
                user_langs = data.user_langs
                save_data("user_langs.lua", user_langs)
            end
            if type(data.bookmarks)  == "table" then
                bookmarks = data.bookmarks
                save_data("bookmarks.lua", bookmarks)
            end
            if _G.refresh_main_spinners then _G.refresh_main_spinners() end
            show_toast("Backup imported successfully!")
        end})
        .setNegativeButton("Cancel", nil)
        .show()
end

function show_backup_dialog()
    local opts = {"Export backup", "Import backup"}
    AlertDialog.Builder(activity)
        .setTitle("Settings Backup")
        .setItems(opts, {onClick=function(_, which)
            if which == 0 then export_backup()
            else import_backup() end
        end})
        .setNegativeButton("Cancel", nil)
        .show()
end

-- ============================================================
-- Feature 2: Feed Health Checker
-- ============================================================
function show_feed_health_checker()
    local layout = {
        LinearLayout, orientation="vertical", padding="16dp",
        {TextView, text="Enter RSS URL to test:",
            textSize="14sp", textColor=currentTheme.text,
            layout_marginBottom="8dp"},
        {EditText, id="fhc_url",
            hint="https://example.com/feed",
            layout_width="fill",
            textColor=currentTheme.text,
            backgroundColor=currentTheme.searchBg,
            layout_marginBottom="8dp"},
        {Button, id="fhc_btn", text="Test Feed",
            layout_width="fill",
            backgroundColor=currentTheme.primary,
            textColor=Color.parseColor(theme.buttonText),
            layout_marginBottom="12dp"},
        {TextView, id="fhc_result", text="",
            textSize="13sp", textColor=currentTheme.text,
            layout_marginBottom="8dp"},
        {Button, id="fhc_close", text="Close",
            layout_width="fill", background=nil,
            textColor=currentTheme.secondaryText},
    }
    local v       = loadlayout(layout)
    local result_tv = v.findViewById(fhc_result.getId())
    local url_et    = v.findViewById(fhc_url.getId())

    local dlg = AlertDialog.Builder(activity).create()
    dlg.setView(v)
    dlg.show()

    v.findViewById(fhc_btn.getId()).onClick = function()
        local url = tostring(url_et.getText()):gsub("^%s*(.-)%s*$","%1")
        if url == "" then result_tv.setText("Please enter a URL first."); return end
        result_tv.setText("Testing... please wait.")
        Http.get(url, function(status, body)
            if status ~= 200 then
                result_tv.setText("FAILED  -  HTTP "..tostring(status)..
                    "\nCould not reach this feed.")
                return
            end
            local count = 0
            for _ in (body or ""):gmatch("<item>") do count = count + 1 end
            if count == 0 then
                for _ in (body or ""):gmatch("<entry>") do count = count + 1 end
            end
            local feed_title = body:match("<title><!%[CDATA%[(.-)%]%]></title>")
                or body:match("<title>(.-)</title>") or "Unknown Feed"
            feed_title = decode_html(feed_title:sub(1,60))
            if count > 0 then
                result_tv.setText(
                    "OK  -  Feed is working\n"..
                    "Title: "..feed_title.."\n"..
                    "Articles found: "..count)
            else
                result_tv.setText(
                    "WARNING  -  URL reachable (HTTP 200)\n"..
                    "But no RSS/Atom items found.\n"..
                    "This may not be a valid RSS/Atom feed.")
            end
        end)
    end

    v.findViewById(fhc_close.getId()).onClick = function()
        dlg.dismiss()
    end
end

-- ============================================================
-- Feature 3: OPML Import
-- ============================================================
function show_opml_import_dialog()
    local cats = {}
    for _,v in ipairs({"Health","Tech","World"}) do
        local deleted=false
        for _,d in ipairs(deleted_default_cats) do if d==v then deleted=true end end
        if not deleted then table.insert(cats,v) end
    end
    for _,v in ipairs(user_cats) do table.insert(cats,v) end
    local langs = {"English","Hindi","Nepali"}
    for _,v in ipairs(user_langs) do table.insert(langs,v) end

    local layout = {
        LinearLayout, orientation="vertical", padding="16dp",
        {TextView,
            text="Paste OPML content below.\n(Export from your RSS reader and paste here.)",
            textSize="13sp", textColor=currentTheme.secondaryText,
            layout_marginBottom="10dp"},
        {EditText, id="opml_text",
            hint="<opml version=..>...</opml>",
            layout_width="fill", layout_height="160dp",
            gravity="top",
            textColor=currentTheme.text,
            backgroundColor=currentTheme.searchBg,
            layout_marginBottom="10dp"},
        {TextView, text="Import into Category:", textSize="14sp",
            textColor=currentTheme.text, layout_marginBottom="4dp"},
        {Spinner, id="opml_cat_spin", layout_width="fill", layout_marginBottom="10dp"},
        {TextView, text="Import into Language:", textSize="14sp",
            textColor=currentTheme.text, layout_marginBottom="4dp"},
        {Spinner, id="opml_lang_spin", layout_width="fill"},
    }
    local v = loadlayout(layout)
    v.findViewById(opml_cat_spin.getId()).setAdapter(
        ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, String(cats)))
    v.findViewById(opml_lang_spin.getId()).setAdapter(
        ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, String(langs)))

    AlertDialog.Builder(activity)
        .setTitle("OPML Import")
        .setView(v)
        .setPositiveButton("Import", {onClick=function()
            local opml = tostring(v.findViewById(opml_text.getId()).getText())
            local cat  = cats[v.findViewById(opml_cat_spin.getId()).getSelectedItemPosition()+1]
            local lang = langs[v.findViewById(opml_lang_spin.getId()).getSelectedItemPosition()+1]
            -- Parse all xmlUrl attributes from OPML
            local urls = {}
            for url in opml:gmatch('xmlUrl%s*=%s*"([^"]+)"') do
                table.insert(urls, url)
            end
            -- Also try single-quoted xmlUrl values
            for url in opml:gmatch("xmlUrl%s*=%s*'([^']+)'") do
                table.insert(urls, url)
            end
            if #urls == 0 then
                show_toast("No feed URLs found in OPML")
                return
            end
            user_feeds[cat]       = user_feeds[cat]       or {}
            user_feeds[cat][lang] = user_feeds[cat][lang] or {}
            local added = 0
            for _, url in ipairs(urls) do
                -- Avoid duplicates
                local dup = false
                for _, ex in ipairs(user_feeds[cat][lang]) do
                    if ex == url then dup = true; break end
                end
                if not dup then
                    table.insert(user_feeds[cat][lang], url)
                    added = added + 1
                end
            end
            save_data("user_feeds.lua", user_feeds)
            show_toast(added.." feed(s) imported into "..cat.." / "..lang)
            if added > 0 then load_news() end
        end})
        .setNegativeButton("Cancel", nil)
        .show()
end

-- ============================================================
-- (radio functions moved to before create_main_ui)

-- (show_radio_list removed — now inline in radio tab)

-- (show_radio_dialog removed — radio now opens as inline tab via nav_radio.onClick)

-- ============================================================
-- Markets Tab  (Gold/Silver, Forex, Events)
-- ============================================================
-- Bootstrap
-- ============================================================
user_feeds             = load_data("user_feeds.lua")
bookmarks              = load_data("bookmarks.lua")
user_cats              = load_data("user_cats.lua")
user_langs             = load_data("user_langs.lua")
deleted_default_cats   = load_data("deleted_default_cats.lua")
if type(user_cats)            ~= "table" then user_cats            = {} end
if type(user_langs)           ~= "table" then user_langs           = {} end
if type(deleted_default_cats) ~= "table" then deleted_default_cats = {} end
load_custom_theme()  -- load after load_data is available
history_purge(28)   -- remove entries older than 28 days at startup

-- Auto dark mode: 9 PM to 6 AM
pcall(function()
    local hour = tonumber(os.date("%H"))
    if hour and (hour >= 21 or hour < 6) then
        if app_settings.theme == "light" then
            app_settings.theme = "dark"
            refreshThemeColors()
        end
    end
end)

create_main_ui()
load_news()

-- ── Auto Update Check ─────────────────────────────────────
local UPDATE_URL   = "https://raw.githubusercontent.com/sushil0c/pocketnews-data/main/version.json"
local VERSIONS_URL = "https://raw.githubusercontent.com/sushil0c/pocketnews-data/main/versions.json"

function show_version_history()
    show_toast("Loading version history...")
    Http.get(VERSIONS_URL, function(status, body)
        if status ~= 200 or not body or body == "" then
            AlertDialog.Builder(activity)
                .setTitle("Version History")
                .setMessage("Could not load version history.\nCheck your internet connection.")
                .setPositiveButton("OK", nil)
                .show()
            return
        end

        -- Extract the versions array content
        local arr = body:match('"versions"%s*:%s*(%b[])')
        if not arr then
            show_toast("Could not parse versions")
            return
        end

        -- Parse each version object
        local blocks = {}
        for obj in arr:gmatch('%b{}') do
            local ver  = obj:match('"version"%s*:%s*"([^"]+)"')
            local url  = obj:match('"apk_url"%s*:%s*"([^"]+)"')
            local date = obj:match('"date"%s*:%s*"([^"]+)"')
            local size = obj:match('"size"%s*:%s*"([^"]+)"')
            local log  = obj:match('"changelog"%s*:%s*"([^"]*)"')
            if ver and url then
                table.insert(blocks, {
                    version   = ver,
                    apk_url   = url,
                    date      = date or "",
                    size      = size or "",
                    changelog = log and log:gsub("\\n", "\n") or "",
                })
            end
        end

        if #blocks == 0 then
            show_toast("No version data found")
            return
        end

        -- Build list labels
        local labels = {}
        for _, v in ipairs(blocks) do
            local current = (v.version == APP_VERSION) and " (current)" or ""
            table.insert(labels, "v"..v.version..current.."  "..v.date.."  ["..v.size.."]")
        end

        AlertDialog.Builder(activity)
            .setTitle("Version History")
            .setItems(labels, {onClick=function(_, which)
                local v = blocks[which + 1]
                if not v then return end

                local is_current = (v.version == APP_VERSION)
                local action_btn = is_current and "Reinstall" or
                    (v.version < APP_VERSION and "Downgrade" or "Upgrade")

                AlertDialog.Builder(activity)
                    .setTitle("v"..v.version.."  —  "..v.date)
                    .setMessage(
                        "Size: "..v.size.."\n"..
                        (is_current and "(This is your current version)\n" or "")..
                        "\nWhat's new:\n"..v.changelog
                    )
                    .setPositiveButton(action_btn, {onClick=function()
                        pcall(function()
                            activity.startActivity(Intent(Intent.ACTION_VIEW,
                                Uri.parse(v.apk_url)))
                        end)
                    end})
                    .setNegativeButton("Cancel", nil)
                    .show()
            end})
            .show()
    end)
end

function check_for_update()

    Http.get(UPDATE_URL, function(status, body)
        if status ~= 200 or not body then return end
        local server_ver  = body:match('"version"%s*:%s*"([^"]+)"')
        local apk_url     = body:match('"apk_url"%s*:%s*"([^"]+)"')
        local changelog   = body:match('"changelog"%s*:%s*"([^"]+)"') or ""
        local force       = body:match('"force_update"%s*:%s*true') ~= nil
        if not server_ver or not apk_url then return end

        -- Compare versions (simple string compare works for x.y.z)
        if server_ver <= APP_VERSION then return end

        -- New version available!
        local msg = "New version available!\n\n"..
            "Current: v"..APP_VERSION.."\n"..
            "Latest:  v"..server_ver.."\n\n"..
            (changelog ~= "" and ("What's new:\n"..changelog.."\n\n") or "")..
            "Download and install the new APK?"

        local builder = AlertDialog.Builder(activity)
            .setTitle("Update Available — v"..server_ver)
            .setMessage(msg)
            .setPositiveButton("Download Now", {onClick=function()
                pcall(function()
                    activity.startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse(apk_url)))
                end)
            end})

        if not force then
            builder.setNegativeButton("Later", nil)
        end
        builder.setCancelable(not force)
        builder.show()
    end)
end

-- Check for update 3 seconds after app loads
pcall(function()
    local h = luajava.newInstance("android.os.Handler")
    local r = luajava.createProxy("java.lang.Runnable", {
        run = function() check_for_update() end
    })
    h.postDelayed(r, 3000)
end)

-- Show terms/welcome on very first launch
local fl = load_data("first_launch.lua")
if type(fl) ~= "table" or not fl.accepted then
    show_terms_dialog()
end

-- Start notification scheduler if user had one set
if (app_settings.notif_interval or 0) > 0 then
    start_notif_scheduler(app_settings.notif_interval)
end

-- Global back button handler (AndroLua calls this automatically)
function onKeyDown(keyCode, event)
    if keyCode == 4 then  -- KEYCODE_BACK
        if type(radio_player_view) == "userdata" and radio_player_view.getVisibility() == 0 then
            if _G.radio_close_player then _G.radio_close_player() end
            return true
        elseif type(radio_tab_view) == "userdata" and radio_tab_view.getVisibility() == 0 then
            if _G.show_news_tab_fn then _G.show_news_tab_fn() end
            if _G.set_active_nav and _G.nav_home_btn then _G.set_active_nav(_G.nav_home_btn) end
            return true
        elseif type(markets_view) == "userdata" and markets_view.getVisibility() == 0 then
            if _G.show_news_tab_fn then _G.show_news_tab_fn() end
            if _G.set_active_nav and _G.nav_home_btn then _G.set_active_nav(_G.nav_home_btn) end
            return true        end
    end
    return false
end