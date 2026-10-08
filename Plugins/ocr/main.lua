require "import"
import "android.graphics.Bitmap"
import "android.util.Base64"
import "java.io.ByteArrayOutputStream"
import "com.androlua.*"
import "android.widget.Toast"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.EditText"
import "android.widget.Button"
import "android.widget.ScrollView"
import "android.view.WindowManager"
import "android.view.Gravity"
import "android.graphics.Color"
import "android.graphics.PixelFormat"
import "android.graphics.drawable.GradientDrawable"
import "android.content.Intent"
import "android.net.Uri"
import "android.content.ClipboardManager"
import "android.content.ClipData"

-- ════════════════════════════════════════════════════════════════
--  CONSTANTS
-- ════════════════════════════════════════════════════════════════
local SAVE_DIR      = "/sdcard/Sushil/"
local CONFIG_FILE   = SAVE_DIR .. "ocr_gemini_config.txt"
local TOKENS_FILE   = SAVE_DIR .. "ocr_gemini_tokens.txt"
local HISTORY_FILE  = SAVE_DIR .. "ocr_gemini_history.txt"
local LAUNCH_FILE   = SAVE_DIR .. "ocr_gemini_launch.txt"
-- Launch mode controls what happens when the plugin starts:
--   "menu"    → show the start menu (OCR / Solve Captcha) - default
--   "ocr"     → skip the menu, run OCR straight away
--   "captcha" → skip the menu, run Solve Captcha straight away
local LAUNCH_MODES = { "menu", "ocr", "captcha" }
local LAUNCH_MODE_LABELS = {
  menu    = "Show Menu",
  ocr     = "Direct OCR",
  captcha = "Direct Captcha",
}
local HISTORY_MAX   = 20          -- keep last 20 results
local WA_NUMBER     = "9779868890433"  -- +977 Nepal

-- ── Optional: paste your API key directly here ───────────────────
-- If set, this key is used without needing to open Settings.
-- Leave as "" to use the key saved via the Settings screen instead.
local HARDCODED_API_KEY   = ""
local HARDCODED_MODEL     = ""   -- e.g. "gemini-3.6-flash"  or "" for saved

local DEFAULT_PROMPT =
  "Extract all text from this image exactly as it appears. " ..
  "Preserve the original structure and line breaks. Return plain text only."

-- Prompt used by the "Solve Captcha" button on the start menu.
local CAPTCHA_PROMPT =
  "Look at this image and find any captcha or verification code shown on it. " ..
  "Read the distorted, rotated, or obscured characters carefully. " ..
  "Return ONLY the captcha text/code itself, with no extra words, quotes, " ..
  "explanation, or punctuation. If no captcha is visible, reply exactly: " ..
  "No captcha found."

-- Latest Gemini models (April 2026) — newest first
local MODELS = {
  "gemini-3.8-flash",
  "gemini-3.7-flash",
  "gemini-3.6-flash",
  "gemini-3-flash-preview",
  "gemini-3.1-pro-preview",
  "gemini-3.1-flash-lite-preview",
  "gemini-2.5-pro",
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite-preview",
}

-- Models that only work through Google's newer Interactions API
-- (v1beta/interactions) rather than the classic generateContent endpoint.
local NEW_API_MODELS = {
  ["gemini-3.8-flash"] = true,
  ["gemini-3.7-flash"] = true,
}

-- Friendly display names shown in the UI
local MODEL_INFO = {
  { name = "Gemini 3 .8 Flash",           badge = "Default",      badgeColor = "#16a34a" },
  { name = "Gemini 3 .7 Flash",           badge = "General",      badgeColor = "#16a34a" },
  { name = "Gemini 3 .6 Flash Preview",   badge = "General",      badgeColor = "#16a34a" },
  { name = "Gemini 3 Flash Preview",      badge = "Preview",      badgeColor = "#16a34a" },
  { name = "Gemini 3.1 Pro Preview",      badge = "Latest",       badgeColor = "#c0392b" },
  { name = "Gemini 3.1 Flash Lite",       badge = "Fast",         badgeColor = "#0891b2" },
  { name = "Gemini 2.5 Pro",              badge = "Stable Pro",   badgeColor = "#7c3aed" },
  { name = "Gemini 2.5 Flash",            badge = "Recommended",  badgeColor = "#059669" },
  { name = "Gemini 2.5 Flash Lite",       badge = "Free Tier",    badgeColor = "#2563eb" },
}

-- ════════════════════════════════════════════════════════════════
--  CHANGELOG  (shown in Settings — plain notes for users)
-- ════════════════════════════════════════════════════════════════
local CHANGELOG = {
  {
    version = "1.4",
    date    = "September 2026",
    notes   = {
      "Added a start menu with OCR and Solve Captcha options",
      "Added a Settings option to skip the menu and launch straight into OCR or Solve Captcha",
    },
  },
  {
    version = "1.3",
    date    = "September 2026",
    notes   = {
      "Added support for Gemini 3.8 Flash",
      "Fixed OCR failing on Gemini 3.7 Flash and Gemini 3.8 Flash",
      "Improved reliability when connecting to Google's servers",
    },
  },
  {
    version = "1.2",
    date    = "August 2026",
    notes   = {
      "Fixed an \"OCR failed\" error some users saw after a Google update",
    },
  },
  {
    version = "1.1",
    date    = "July 2026",
    notes   = {
      "Added Gemini 3.7 Flash support",
      "Added API usage tracking in Settings",
    },
  },
  {
    version = "1.0",
    date    = "June 2026",
    notes   = {
      "Initial release — OCR, Translate, Describe, History and Settings",
    },
  },
}

-- ════════════════════════════════════════════════════════════════
--  PALETTE
-- ════════════════════════════════════════════════════════════════
local BG      = "#0f1923"   -- very dark navy
local CARD    = "#172030"   -- card surface
local CARD2   = "#1e2c40"   -- elevated card
local BORDER  = "#253348"   -- subtle border
local ACCENT  = "#3d9be9"   -- primary blue
local PURPLE  = "#8b5cf6"   -- purple for settings
local GREEN   = "#22c55e"   -- success
local RED     = "#ef4444"   -- danger
local TEXT    = "#e2e8f0"   -- primary text
local DIMTEXT = "#64748b"   -- muted text
local INBG    = "#0a1219"   -- input bg

-- ════════════════════════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════════════════════════
local overlay = nil
local wmSvc   = nil
local _apiInputRef = nil  -- holds apiInput ref when settings is open

-- ════════════════════════════════════════════════════════════════
--  WINDOW MANAGER
-- ════════════════════════════════════════════════════════════════
function getWM()
  if not wmSvc then wmSvc = this.getSystemService("window") end
  return wmSvc
end

function removeOverlay()
  if overlay then
    pcall(function() getWM().removeView(overlay) end)
    overlay = nil
  end
end

function showOverlay(view)
  removeOverlay()
  local lp = WindowManager.LayoutParams(
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
    PixelFormat.TRANSLUCENT)
  lp.gravity = Gravity.TOP
  overlay = view
  getWM().addView(view, lp)
end

-- ════════════════════════════════════════════════════════════════
--  CONFIG
-- ════════════════════════════════════════════════════════════════
function readConfig()
  local f = io.open(CONFIG_FILE, "r")
  if not f then return nil, MODELS[1], DEFAULT_PROMPT end
  local k = (f:read("*l") or ""):match("^%s*(.-)%s*$")
  local m = (f:read("*l") or ""):match("^%s*(.-)%s*$")
  local p = (f:read("*a") or ""):match("^%s*(.-)%s*$")
  f:close()
  if m == "" then m = MODELS[1] end
  if p == "" then p = DEFAULT_PROMPT end
  if k == "" then return nil, m, p end
  return k, m, p
end

function writeConfig(k, m, p)
  os.execute("mkdir -p " .. SAVE_DIR)
  local f = io.open(CONFIG_FILE, "w")
  if f then f:write(k.."\n"..m.."\n"..p.."\n"); f:close() end
end

-- ── Launch mode (menu / direct OCR / direct Captcha) ─────────────
function readLaunchMode()
  local f = io.open(LAUNCH_FILE, "r")
  if not f then return "menu" end
  local mode = (f:read("*l") or "menu"):match("^%s*(.-)%s*$")
  f:close()
  if mode ~= "ocr" and mode ~= "captcha" and mode ~= "menu" then
    mode = "menu"
  end
  return mode
end

function writeLaunchMode(mode)
  os.execute("mkdir -p " .. SAVE_DIR)
  local f = io.open(LAUNCH_FILE, "w")
  if f then f:write((mode or "menu").."\n"); f:close() end
end

-- ════════════════════════════════════════════════════════════════
--  WHATSAPP  (remove overlay first, delay 200ms, then launch)
-- ════════════════════════════════════════════════════════════════
function openWA(msg)
  removeOverlay()
  local enc = msg:gsub("[^%w%s%.%,%;%:%-%(/]",""):gsub(" ","%%20")
  task(200, function()
    local i = Intent(Intent.ACTION_VIEW,
      Uri.parse("https://wa.me/"..WA_NUMBER.."?text="..enc))
    i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    this.startActivity(i)
  end)
end

-- ════════════════════════════════════════════════════════════════
--  CLIPBOARD
-- ════════════════════════════════════════════════════════════════
function copyToClipboard(text)
  local cm = this.getSystemService("clipboard")
  local clip = ClipData.newPlainText("OCR Result", text)
  cm.setPrimaryClip(clip)
  Toast.makeText(this, "Copied to clipboard", Toast.LENGTH_SHORT).show()
end

-- ════════════════════════════════════════════════════════════════
--  TOKEN COUNTER
--  File format: line1=totalRequests, line2=totalInputTokens,
--               line3=totalOutputTokens, line4=lastUsedDate
-- ════════════════════════════════════════════════════════════════
function readTokenStats()
  local f = io.open(TOKENS_FILE, "r")
  if not f then return {req=0, inp=0, out=0, date="Never"} end
  local req  = tonumber(f:read("*l")) or 0
  local inp  = tonumber(f:read("*l")) or 0
  local out  = tonumber(f:read("*l")) or 0
  local date = (f:read("*l") or "Never"):match("^%s*(.-)%s*$")
  f:close()
  return {req=req, inp=inp, out=out, date=date}
end

function saveTokenStats(stats)
  os.execute("mkdir -p " .. SAVE_DIR)
  local f = io.open(TOKENS_FILE, "w")
  if f then
    f:write(tostring(stats.req)  .."\n")
    f:write(tostring(stats.inp)  .."\n")
    f:write(tostring(stats.out)  .."\n")
    f:write(tostring(stats.date) .."\n")
    f:close()
  end
end

function resetTokenStats()
  saveTokenStats({req=0, inp=0, out=0, date="Never"})
end

-- Called after each successful API response with token counts from JSON
function addTokenUsage(inputTokens, outputTokens)
  local stats = readTokenStats()
  stats.req  = stats.req + 1
  stats.inp  = stats.inp + (inputTokens  or 0)
  stats.out  = stats.out + (outputTokens or 0)
  -- Simple date: use os.date if available, otherwise increment only
  local ok, d = pcall(function() return os.date("%Y-%m-%d") end)
  stats.date = ok and d or "Unknown"
  saveTokenStats(stats)
end

-- Format large numbers nicely: 1234567 → "1,234,567"
function fmtNum(n)
  local s = tostring(math.floor(n))
  local result = ""
  local len = #s
  for i = 1, len do
    if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
    result = result .. s:sub(i, i)
  end
  return result
end

-- ════════════════════════════════════════════════════════════════
--  HISTORY  (up to HISTORY_MAX entries, newest first)
--  File format: entries separated by "\n===END===\n"
--  Each entry: first line = date, rest = OCR text
-- ════════════════════════════════════════════════════════════════
local ENTRY_SEP = "\n===END===\n"

function saveHistory(text, date)
  os.execute("mkdir -p " .. SAVE_DIR)
  -- Read existing entries
  local entries = readHistory()
  -- Prepend new entry
  table.insert(entries, 1, {date = date or "Unknown", text = text})
  -- Trim to max
  while #entries > HISTORY_MAX do
    table.remove(entries)
  end
  -- Write back
  local f = io.open(HISTORY_FILE, "w")
  if not f then return end
  for i, e in ipairs(entries) do
    f:write((e.date or "Unknown") .. "\n")
    f:write((e.text or "") .. ENTRY_SEP)
  end
  f:close()
end

function readHistory()
  local f = io.open(HISTORY_FILE, "r")
  if not f then return {} end
  local raw = f:read("*a")
  f:close()
  local entries = {}
  for chunk in (raw .. ENTRY_SEP):gmatch("(.-)" .. ENTRY_SEP) do
    if chunk:match("%S") then
      local date, text = chunk:match("^([^\n]+)\n(.*)$")
      if date then
        table.insert(entries, {
          date = date:match("^%s*(.-)%s*$"),
          text = (text or ""):match("^%s*(.-)%s*$")
        })
      end
    end
  end
  return entries
end

function clearHistory()
  local f = io.open(HISTORY_FILE, "w")
  if f then f:write(""); f:close() end
end

function deleteHistoryEntry(indexToDelete)
  local entries = readHistory()
  table.remove(entries, indexToDelete)
  os.execute("mkdir -p " .. SAVE_DIR)
  local f = io.open(HISTORY_FILE, "w")
  if not f then return end
  for _, e in ipairs(entries) do
    f:write((e.date or "Unknown") .. "\n")
    f:write((e.text or "") .. ENTRY_SEP)
  end
  f:close()
end

function exportHistory()
  local entries = readHistory()
  if #entries == 0 then return false, "No history to export" end
  os.execute("mkdir -p " .. SAVE_DIR)
  local exportFile = SAVE_DIR .. "ocr_history_export.txt"
  local f = io.open(exportFile, "w")
  if not f then return false, "Could not create export file" end
  f:write("OCR History Export\n")
  f:write(string.rep("=", 40) .. "\n\n")
  for i, e in ipairs(entries) do
    f:write("Entry #" .. i .. "  |  " .. (e.date or "Unknown") .. "\n")
    f:write(string.rep("-", 40) .. "\n")
    f:write((e.text or "") .. "\n\n")
  end
  f:close()
  return true, exportFile
end

-- ── History detail screen (view one entry) ───────────────────────
function showHistoryEntry(entry, entryIndex)
  local ctx = this
  local disp = cleanText(entry.text)

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  -- Header
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a2a45","#0d1828", 20))
  hCard.setPadding(18,14,18,12)
  local hLP = fLP(); hLP.setMargins(0,0,0,10); hCard.setLayoutParams(hLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx,
    "Entry #" .. (entryIndex or "?"),
    "History entry " .. (entryIndex or "unknown") .. " screen", 17, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local backBtn = mkBtn(ctx, "Back", "Back to history list",
    "#1e3a5a", BORDER, function() showHistory() end)
  backBtn.setTextSize(12); backBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(backBtn)
  hCard.addView(titleRow)

  local dateTV = lbl(ctx, entry.date, nil, 10, DIMTEXT)
  dateTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(dateTV)
  root.addView(hCard)

  -- Text card
  local rCard = mkCard(ctx, 14, 12)
  rCard.addView(sectionTitle(ctx, "Extracted Text"))
  local scroll = ScrollView(ctx)
  local rTV = lbl(ctx, disp, disp, 15, TEXT)
  rTV.setPadding(4,4,4,4); rTV.setLineSpacing(6,1.0)
  rTV.setTextIsSelectable(true)
  scroll.addView(rTV)
  local scrollLP = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT, 430)
  scroll.setLayoutParams(scrollLP)
  rCard.addView(scroll)
  root.addView(rCard)

  -- Action buttons
  local aCard = mkCard(ctx, 14, 12)

  -- Copy + Share row
  local csRow = hRow(ctx)
  local copyB = mkBtn(ctx, "Copy to Clipboard",
    "Copy this history entry to clipboard",
    "#0a3d2e", "#1a6b4a", function() copyToClipboard(disp) end)
  copyB.setBackground(gradDrawable("#0d4a35","#062a1e",14))
  copyB.setTextColor(Color.parseColor("#4ade80"))
  copyB.setLayoutParams(eLP(1, 0, 4, 0, 0))
  csRow.addView(copyB)

  local shareB = mkBtn(ctx, "Share Text",
    "Share this history entry with other apps",
    "#0a2a45", "#1a4a6b", function()
      removeOverlay()
      task(150, function()
        local si = Intent(Intent.ACTION_SEND)
        si.setType("text/plain")
        si.putExtra(Intent.EXTRA_TEXT, disp)
        si.putExtra(Intent.EXTRA_SUBJECT, "OCR Result")
        si.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        local ch = Intent.createChooser(si, "Share OCR Result")
        ch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        this.startActivity(ch)
      end)
    end)
  shareB.setBackground(gradDrawable("#0d3550","#061e30",14))
  shareB.setTextColor(Color.parseColor("#60a5fa"))
  shareB.setLayoutParams(eLP(1, 4, 0, 0, 0))
  csRow.addView(shareB)
  local csLP = fLP(); csLP.setMargins(0,0,0,8); csRow.setLayoutParams(csLP)
  aCard.addView(csRow)

  -- Delete + Close row
  local dcRow = hRow(ctx)
  local delB = mkBtn(ctx, "Delete Entry",
    "Delete this entry from history",
    "#3a0f0f", BORDER, function()
      if entryIndex then
        deleteHistoryEntry(entryIndex)
        Toast.makeText(ctx, "Entry #" .. entryIndex .. " deleted",
          Toast.LENGTH_SHORT).show()
      end
      showHistory()
    end)
  delB.setTextColor(Color.parseColor("#fca5a5"))
  delB.setLayoutParams(eLP(1, 0, 4, 0, 0))
  dcRow.addView(delB)

  local closeB = mkBtn(ctx, "Close", "Close history entry",
    CARD2, BORDER, function() removeOverlay() end)
  closeB.setLayoutParams(eLP(1, 4, 0, 0, 0))
  dcRow.addView(closeB)
  aCard.addView(dcRow)
  root.addView(aCard)

  showOverlay(root)
end

-- ── Changelog screen ────────────────────────────────────────────
function showChangelog()
  local ctx = this

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  -- Header
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a2d50","#0d1a30", 20))
  hCard.setPadding(18,14,18,12)
  local hLP = fLP(); hLP.setMargins(0,0,0,10); hCard.setLayoutParams(hLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx, "What's New", "Changelog screen", 18, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local closeBtn = mkBtn(ctx, "Close", "Close changelog",
    "#1e3a5a", BORDER, function() removeOverlay() end)
  closeBtn.setTextSize(12); closeBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(closeBtn)
  hCard.addView(titleRow)

  local subTV = lbl(ctx, "Recent updates to this plugin", nil, 11, DIMTEXT)
  subTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(subTV)
  root.addView(hCard)

  -- Scrollable list of version cards
  local scroll = ScrollView(ctx)
  local inner = LinearLayout(ctx)
  inner.setOrientation(LinearLayout.VERTICAL)

  for vi, entry in ipairs(CHANGELOG) do
    local vCard = mkCard(ctx, 16, 12,
      vi == 1 and "#0d2440" or CARD,
      vi == 1 and "#1a4a80" or BORDER)

    local vRow = hRow(ctx, Gravity.CENTER_VERTICAL)
    local vBadge = mkBadge(ctx, "v"..entry.version, vi == 1 and GREEN or ACCENT)
    vRow.addView(vBadge)
    local vDateTV = lbl(ctx, entry.date, nil, 11, DIMTEXT)
    vDateTV.setLayoutParams(LinearLayout.LayoutParams(0,
      LinearLayout.LayoutParams.WRAP_CONTENT, 1))
    vDateTV.setGravity(Gravity.END)
    vRow.addView(vDateTV)
    local vRowLP = fLP(); vRowLP.setMargins(0,0,0,8); vRow.setLayoutParams(vRowLP)
    vCard.addView(vRow)

    for _, note in ipairs(entry.notes) do
      local noteRow = hRow(ctx)
      local dot = lbl(ctx, "•  ", nil, 13, ACCENT)
      dot.setImportantForAccessibility(4)
      noteRow.addView(dot)
      local noteTV = lbl(ctx, note, note, 13, TEXT)
      noteTV.setLayoutParams(LinearLayout.LayoutParams(0,
        LinearLayout.LayoutParams.WRAP_CONTENT, 1))
      noteRow.addView(noteTV)
      local noteLP = fLP(); noteLP.setMargins(0,0,0,4); noteRow.setLayoutParams(noteLP)
      vCard.addView(noteRow)
    end

    inner.addView(vCard)
  end

  scroll.addView(inner)
  local scrollLP = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT, 0)
  scrollLP.weight = 1
  scroll.setLayoutParams(scrollLP)
  root.addView(scroll)

  showOverlay(root)
end

-- ── History list screen ───────────────────────────────────────────
function showHistory(filterText)
  local ctx = this
  local allEntries = readHistory()
  filterText = filterText or ""

  -- Apply search filter
  local entries = {}
  local indexMap = {}  -- maps filtered index → original index
  for i, e in ipairs(allEntries) do
    if filterText == "" or
       (e.text or ""):lower():find(filterText:lower(), 1, true) or
       (e.date or ""):lower():find(filterText:lower(), 1, true) then
      table.insert(entries, e)
      table.insert(indexMap, i)
    end
  end

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  -- Header
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a2d50","#0d1a30", 20))
  hCard.setPadding(18,14,18,12)
  local hLP = fLP(); hLP.setMargins(0,0,0,10); hCard.setLayoutParams(hLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx,
    "OCR History  (" .. #allEntries .. ")",
    "OCR History screen, " .. #allEntries .. " total entries", 18, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local closeBtn = mkBtn(ctx, "Close", "Close history",
    "#1e3a5a", BORDER, function() removeOverlay() end)
  closeBtn.setTextSize(12); closeBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(closeBtn)
  hCard.addView(titleRow)

  local subTV = lbl(ctx, "Tap any entry to view full text", nil, 10, DIMTEXT)
  subTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(subTV)
  root.addView(hCard)

  -- Search bar
  local searchCard = mkCard(ctx, 12, 10)
  local searchRow = hRow(ctx)
  local searchInput = mkEdit(ctx, "Search history...",
    "Search history input field")
  searchInput.setSingleLine(true)
  searchInput.setText(filterText)
  searchInput.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  searchRow.addView(searchInput)

  local searchBtn = mkBtn(ctx, "Search", "Search history",
    CARD2, BORDER, function()
      local q = tostring(searchInput.getText()):match("^%s*(.-)%s*$")
      showHistory(q)
    end)
  searchBtn.setLayoutParams(wLP(8,0,0,0))
  searchRow.addView(searchBtn)

  if filterText ~= "" then
    local clearSBtn = mkBtn(ctx, "Clear", "Clear search",
      "#2a1a0a", BORDER, function() showHistory("") end)
    clearSBtn.setLayoutParams(wLP(4,0,0,0))
    searchRow.addView(clearSBtn)
  end
  searchCard.addView(searchRow)
  root.addView(searchCard)

  -- Action buttons: Export + Clear All
  local actRow = hRow(ctx)
  local exportB = mkBtn(ctx, "Export All",
    "Export all history to a text file",
    "#0a2a3a", BORDER, function()
      local ok, result = exportHistory()
      if ok then
        Toast.makeText(ctx,
          "Exported to Sushil/ocr_history_export.txt",
          Toast.LENGTH_LONG).show()
      else
        Toast.makeText(ctx, "Export failed: " .. result,
          Toast.LENGTH_LONG).show()
      end
    end)
  local clearB = mkBtn(ctx, "Clear All",
    "Delete all OCR history entries",
    "#2a0f0f", BORDER, function()
      clearHistory()
      Toast.makeText(ctx, "All history cleared", Toast.LENGTH_SHORT).show()
      showHistory()
    end)
  exportB.setLayoutParams(eLP(1, 0, 4, 0, 0))
  clearB.setLayoutParams(eLP(1, 4, 0, 0, 0))
  clearB.setTextColor(Color.parseColor("#fca5a5"))
  actRow.addView(exportB); actRow.addView(clearB)
  local actRowLP = fLP(); actRowLP.setMargins(0,0,0,10); actRow.setLayoutParams(actRowLP)
  root.addView(actRow)

  -- Entries list
  local listScroll = ScrollView(ctx)
  local listInner = LinearLayout(ctx)
  listInner.setOrientation(LinearLayout.VERTICAL)

  if #entries == 0 then
    local emptyTV = lbl(ctx,
      filterText ~= "" and
        "No entries match \"" .. filterText .. "\"" or
        "No history yet.\nRun OCR to start building history.",
      "No history entries", 14, DIMTEXT)
    emptyTV.setGravity(Gravity.CENTER)
    emptyTV.setPadding(20,40,20,40)
    listInner.addView(emptyTV)
  else
    for i, entry in ipairs(entries) do
      local origIdx = indexMap[i]

      local eCard = LinearLayout(ctx)
      eCard.setOrientation(LinearLayout.VERTICAL)
      eCard.setBackground(rRect(CARD, 14, BORDER, 1))
      eCard.setPadding(14,12,14,12)
      local eLP2 = fLP(); eLP2.setMargins(0,0,0,8); eCard.setLayoutParams(eLP2)

      -- Entry header: badge + date + View button
      local eHRow = hRow(ctx, Gravity.CENTER_VERTICAL)
      local numBadge = mkBadge(ctx, "#"..origIdx, ACCENT)
      numBadge.setLayoutParams(wLP(0,8,0,0))
      eHRow.addView(numBadge)

      local dateTV2 = lbl(ctx, entry.date, nil, 11, DIMTEXT)
      dateTV2.setLayoutParams(LinearLayout.LayoutParams(0,
        LinearLayout.LayoutParams.WRAP_CONTENT, 1))
      eHRow.addView(dateTV2)

      local viewBtn = mkBtn(ctx, "View", "View entry " .. origIdx,
        CARD2, BORDER, function()
          showHistoryEntry(entry, origIdx)
        end)
      viewBtn.setTextSize(11); viewBtn.setLayoutParams(wLP())
      eHRow.addView(viewBtn)
      eCard.addView(eHRow)

      -- Preview text
      local preview = cleanText(entry.text or "")
      if #preview > 90 then preview = preview:sub(1,90) .. "..." end
      local previewTV = lbl(ctx, preview, nil, 13, "#a0aec0")
      previewTV.setPadding(0,6,0,0); previewTV.setMaxLines(2)
      eCard.addView(previewTV)

      -- Tap whole card to view
      local entryRef = entry
      local idxRef   = origIdx
      eCard.setOnClickListener(luajava.createProxy(
        "android.view.View$OnClickListener", {
          onClick = function() showHistoryEntry(entryRef, idxRef) end
        }))

      listInner.addView(eCard)
    end
  end

  listScroll.addView(listInner)
  local listScrollLP = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT, 0)
  listScrollLP.weight = 1
  listScroll.setLayoutParams(listScrollLP)
  root.addView(listScroll)

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  DRAWABLE / LAYOUT HELPERS
-- ════════════════════════════════════════════════════════════════
function rRect(fill, r, stroke, sw)
  local d = GradientDrawable()
  d.setShape(GradientDrawable.RECTANGLE)
  d.setCornerRadius(r or 20)
  d.setColor(Color.parseColor(fill))
  if stroke then d.setStroke(sw or 2, Color.parseColor(stroke)) end
  return d
end

-- gradient top-to-bottom for header cards
function gradDrawable(c1, c2, r)
  local cols = {Color.parseColor(c1), Color.parseColor(c2)}
  local d = GradientDrawable(
    GradientDrawable.Orientation.TOP_BOTTOM, cols)
  d.setCornerRadius(r or 20)
  return d
end

function fLP()
  return LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT)
end

function eLP(w, mL, mR, mT, mB)
  local p = LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, w or 1)
  p.setMargins(mL or 4, mT or 0, mR or 4, mB or 0)
  return p
end

function wLP(mL, mR, mT, mB)
  local p = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.WRAP_CONTENT,
    LinearLayout.LayoutParams.WRAP_CONTENT)
  p.setMargins(mL or 0, mT or 0, mR or 0, mB or 0)
  return p
end

function sp(ctx, h)
  local v = TextView(ctx); v.setText(""); v.setHeight(h or 8)
  v.setImportantForAccessibility(4); return v
end

function divLine(ctx)
  local v = TextView(ctx); v.setText(""); v.setHeight(1)
  v.setBackgroundColor(Color.parseColor(BORDER))
  v.setImportantForAccessibility(4)
  local lp = fLP(); lp.setMargins(0,10,0,10); v.setLayoutParams(lp)
  return v
end

-- Horizontal row helper
function hRow(ctx, gravity)
  local r = LinearLayout(ctx)
  r.setOrientation(LinearLayout.HORIZONTAL)
  r.setGravity(gravity or Gravity.CENTER_VERTICAL)
  return r
end

-- ── Text label
function lbl(ctx, text, desc, sz, col)
  local t = TextView(ctx)
  t.setText(text or "")
  if desc and desc ~= text then t.setContentDescription(desc) end
  t.setTextSize(sz or 14)
  t.setTextColor(Color.parseColor(col or TEXT))
  return t
end

-- ── Section title (small caps style)
function sectionTitle(ctx, text)
  local t = lbl(ctx, text, nil, 10, ACCENT)
  t.setAllCaps(true)
  local lp = fLP(); lp.setMargins(0,2,0,8); t.setLayoutParams(lp)
  return t
end

-- ── Styled button
function mkBtn(ctx, text, desc, fill, border, action)
  local b = Button(ctx)
  b.setText(text)
  b.setContentDescription(desc or text)
  b.setBackground(rRect(fill or CARD2, 16, border, 1))
  b.setTextColor(Color.parseColor(TEXT))
  b.setTextSize(13); b.setPadding(12,10,12,10); b.setAllCaps(false)
  b.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = action }))
  return b
end

-- ── Input field
function mkEdit(ctx, hint, desc, multi)
  local e = EditText(ctx)
  e.setHint(hint or ""); e.setContentDescription(desc or hint or "")
  e.setTextColor(Color.parseColor(TEXT))
  e.setHintTextColor(Color.parseColor(DIMTEXT))
  e.setBackground(rRect(INBG, 12, BORDER))
  e.setPadding(16,12,16,12); e.setTextSize(14)
  if multi then e.setMinLines(3); e.setMaxLines(6); e.setGravity(Gravity.TOP) end
  local lp = fLP(); lp.setMargins(0,0,0,0); e.setLayoutParams(lp)
  return e
end

-- ── Card container
function mkCard(ctx, padH, padV, fill, br, bw)
  local c = LinearLayout(ctx)
  c.setOrientation(LinearLayout.VERTICAL)
  c.setBackground(rRect(fill or CARD, 18, br or BORDER, bw or 1))
  c.setPadding(padH or 18, padV or 14, padH or 18, padV or 14)
  local lp = fLP(); lp.setMargins(0,0,0,12); c.setLayoutParams(lp)
  return c
end

-- ── Small badge pill (e.g. "Recommended")
function mkBadge(ctx, text, bgHex)
  local b = TextView(ctx)
  b.setText(text)
  b.setTextSize(10); b.setTextColor(Color.WHITE)
  b.setBackground(rRect(bgHex or "#27ae60", 20))
  b.setPadding(10, 3, 10, 3)
  b.setImportantForAccessibility(4)
  local lp = wLP(8,0,0,0); b.setLayoutParams(lp)
  return b
end

-- ════════════════════════════════════════════════════════════════
--  CLEAN TEXT  (strip markdown so screen reader is happy)
-- ════════════════════════════════════════════════════════════════
function cleanText(t)
  if not t then return "" end
  return t
    :gsub("%*%*(.-)%*%*","%1"):gsub("%*(.-)%*","%1")
    :gsub("`(.-)`","%1"):gsub("#+%s*",""):gsub("%-%-%-+","")
    :gsub("\n\n\n+","\n\n"):match("^%s*(.-)%s*$")
end

-- ════════════════════════════════════════════════════════════════
--  RESULT SCREEN
-- ════════════════════════════════════════════════════════════════
function showResult(rawText)
  local ctx  = this
  local disp = cleanText(rawText)

  -- Root
  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  -- ── Gradient header card ─────────────────────────────────────
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a3558","#0f1f38", 20))
  hCard.setPadding(18,14,18,12)
  local hCardLP = fLP(); hCardLP.setMargins(0,0,0,10)
  hCard.setLayoutParams(hCardLP)

  -- Title row: "OCR Result"  [Close]
  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx, "OCR Result", "OCR Result screen", 19, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local closeBtn = mkBtn(ctx, "Close", "Close OCR result",
    "#1e3a5a", BORDER, function() removeOverlay() end)
  closeBtn.setTextSize(12)
  local closeBtnLP = wLP(); closeBtn.setLayoutParams(closeBtnLP)
  titleRow.addView(titleTV); titleRow.addView(closeBtn)
  hCard.addView(titleRow)
  root.addView(hCard)

  -- ── Result card ───────────────────────────────────────────────
  local rCard = mkCard(ctx, 14, 12)
  rCard.addView(sectionTitle(ctx, "Extracted Text"))

  local scroll = ScrollView(ctx)
  local rTV = lbl(ctx, disp, disp, 15, TEXT)
  rTV.setPadding(4,4,4,4); rTV.setLineSpacing(6,1.0)
  rTV.setTextIsSelectable(true)
  scroll.addView(rTV)
  local scrollLP = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT, 500)
  scroll.setLayoutParams(scrollLP)
  rCard.addView(scroll)
  root.addView(rCard)

  -- ── Action card ───────────────────────────────────────────────
  local aCard = mkCard(ctx, 14, 14)
  aCard.addView(sectionTitle(ctx, "Actions"))

  -- Row 1: Copy + Share (equal width, both prominent)
  local row1 = hRow(ctx)

  local copyB = mkBtn(ctx, "Copy to Clipboard",
    "Copy extracted text to clipboard",
    "#0a3d2e", "#1a6b4a", function()
      copyToClipboard(disp)
    end)
  copyB.setTextSize(13)
  copyB.setBackground(gradDrawable("#0d4a35","#062a1e",14))
  copyB.setTextColor(Color.parseColor("#4ade80"))
  copyB.setLayoutParams(eLP(1, 0, 4, 0, 0))
  row1.addView(copyB)

  local shareB = mkBtn(ctx, "Share Text",
    "Share extracted text with other apps",
    "#0a2a45", "#1a4a6b", function()
      removeOverlay()
      task(150, function()
        local shareIntent = Intent(Intent.ACTION_SEND)
        shareIntent.setType("text/plain")
        shareIntent.putExtra(Intent.EXTRA_TEXT, disp)
        shareIntent.putExtra(Intent.EXTRA_SUBJECT, "OCR Result")
        shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        local chooser = Intent.createChooser(shareIntent, "Share OCR Result")
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        this.startActivity(chooser)
      end)
    end)
  shareB.setTextSize(13)
  shareB.setBackground(gradDrawable("#0d3550","#061e30",14))
  shareB.setTextColor(Color.parseColor("#60a5fa"))
  shareB.setLayoutParams(eLP(1, 4, 0, 0, 0))
  row1.addView(shareB)

  local row1LP = fLP(); row1LP.setMargins(0,0,0,8)
  row1.setLayoutParams(row1LP)
  aCard.addView(row1)

  -- Row 2: Translate | Describe | Settings | History
  local row2 = hRow(ctx)

  local transB2 = mkBtn(ctx, "Translate",
    "Translate extracted text to another language",
    "#0a2040", BORDER, function()
      showTranslateOptions(disp)
    end)
  transB2.setTextColor(Color.parseColor("#93c5fd"))

  local descB2 = mkBtn(ctx, "Describe",
    "Ask Gemini to describe this image and extract text",
    "#1a0a30", BORDER, function()
      local apiKey, model, _ = readConfig()
      if HARDCODED_API_KEY and HARDCODED_API_KEY ~= "" then apiKey = HARDCODED_API_KEY end
      if HARDCODED_MODEL and HARDCODED_MODEL ~= "" then model = HARDCODED_MODEL end
      removeOverlay()
      Toast.makeText(this, "Describing image...", Toast.LENGTH_SHORT).show()
      this.getScreenShot({
        onScreenCaptureDone = function(bitmap)
          local baos = ByteArrayOutputStream()
          bitmap.compress(Bitmap.CompressFormat.JPEG, 90, baos)
          local b64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
          local descPrompt = "Describe what you see in this image in detail. " ..
            "Then extract and list any text visible in the image."
          task(doOCRTask, b64, apiKey, model, descPrompt, onOCRDone)
        end
      })
    end)
  descB2.setTextColor(Color.parseColor("#c4b5fd"))

  local setB = mkBtn(ctx,"Settings","Open settings","#0d2644",BORDER,
    function() showSetupScreen(false) end)
  local histB = mkBtn(ctx,"History","View OCR history","#1a2a40",BORDER,
    function() showHistory() end)

  transB2.setLayoutParams(eLP(1)); descB2.setLayoutParams(eLP(1))
  setB.setLayoutParams(eLP(1));    histB.setLayoutParams(eLP(1))
  row2.addView(transB2); row2.addView(descB2)
  row2.addView(setB);    row2.addView(histB)
  aCard.addView(row2)

  -- Row 3: Say Hi | Report Bug
  local row3 = hRow(ctx)
  local hiB = mkBtn(ctx,"Say Hi","Say Hi on WhatsApp","#0f2d52",BORDER,
    function() openWA("Hi Sushil I am using your Jieshuo OCR plugin") end)
  local bugB = mkBtn(ctx,"Report Bug","Report bug on WhatsApp","#3b0f1a",BORDER,
    function() openWA("Bug Report Jieshuo OCR Plugin. Description: ") end)
  hiB.setLayoutParams(eLP(1)); bugB.setLayoutParams(eLP(1))
  row3.addView(hiB); row3.addView(bugB)
  aCard.addView(row3)
  root.addView(aCard)

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  START MENU  (shown when the plugin launches)
-- ════════════════════════════════════════════════════════════════
function showStartMenu()
  local ctx = this

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  -- Header card
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a3558","#0f1f38", 20))
  hCard.setPadding(18,16,18,14)
  local hCardLP = fLP(); hCardLP.setMargins(0,0,0,12); hCard.setLayoutParams(hCardLP)

  local titleTV = lbl(ctx, "Jieshuo OCR", "Jieshuo OCR main menu", 20, TEXT)
  titleTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(titleTV)

  hCard.addView(sp(ctx,4))
  local subTV = lbl(ctx, "What would you like to do?", nil, 12, DIMTEXT)
  subTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(subTV)
  root.addView(hCard)

  -- Main action card: OCR + Solve Captcha
  local mCard = mkCard(ctx, 16, 16)
  mCard.addView(sectionTitle(ctx, "Choose an Action"))

  local ocrB = Button(ctx)
  ocrB.setText("Run OCR")
  ocrB.setContentDescription("Extract text from the current screen")
  ocrB.setBackground(gradDrawable("#0d4a35","#062a1e",14))
  ocrB.setTextColor(Color.parseColor("#4ade80"))
  ocrB.setTextSize(15); ocrB.setPadding(0,16,0,16); ocrB.setAllCaps(false)
  local ocrLP = fLP(); ocrLP.setMargins(0,0,0,10); ocrB.setLayoutParams(ocrLP)
  ocrB.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      removeOverlay()
      runOCR()
    end}))
  mCard.addView(ocrB)

  local captchaB = Button(ctx)
  captchaB.setText("Solve Captcha")
  captchaB.setContentDescription("Solve the captcha visible on the current screen")
  captchaB.setBackground(gradDrawable("#5a3a0d","#3d2606",14))
  captchaB.setTextColor(Color.parseColor("#fdba74"))
  captchaB.setTextSize(15); captchaB.setPadding(0,16,0,16); captchaB.setAllCaps(false)
  local captchaLP = fLP(); captchaLP.setMargins(0,0,0,0); captchaB.setLayoutParams(captchaLP)
  captchaB.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      removeOverlay()
      runCaptchaSolve()
    end}))
  mCard.addView(captchaB)

  root.addView(mCard)

  -- Secondary actions: Settings / History
  local aCard = mkCard(ctx, 14, 12)
  local row2 = hRow(ctx)
  local setB = mkBtn(ctx,"Settings","Open settings","#0d2644",BORDER,
    function() showSetupScreen(false) end)
  local histB = mkBtn(ctx,"History","View OCR history","#1a2a40",BORDER,
    function() showHistory() end)
  setB.setLayoutParams(eLP(1)); histB.setLayoutParams(eLP(1))
  row2.addView(setB); row2.addView(histB)
  local row2LP = fLP(); row2LP.setMargins(0,0,0,10); row2.setLayoutParams(row2LP)
  aCard.addView(row2)

  local closeB = mkBtn(ctx,"Close","Close menu",CARD2,BORDER,
    function() removeOverlay() end)
  aCard.addView(closeB)
  root.addView(aCard)

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  SETUP / SETTINGS SCREEN
-- ════════════════════════════════════════════════════════════════
function showSetupScreen(firstTime)
  local ctx = this

  -- Root full-screen
  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#ff"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  local outerScroll = ScrollView(ctx)
  local inner = LinearLayout(ctx)
  inner.setOrientation(LinearLayout.VERTICAL)
  outerScroll.addView(inner)
  root.addView(outerScroll)

  -- ── Header card (gradient) ────────────────────────────────────
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#261a42","#0f1428", 20))
  hCard.setPadding(20,16,20,14)
  local hCardLP = fLP(); hCardLP.setMargins(0,0,0,12); hCard.setLayoutParams(hCardLP)

  local ttxt = firstTime and "OCR Plugin Setup" or "OCR Settings"
  local tTV = lbl(ctx, ttxt, ttxt.." screen", 20, TEXT)
  tTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(tTV)

  if firstTime then
    hCard.addView(sp(ctx,4))
    local subTV = lbl(ctx,"Enter your API key to get started",nil,12,DIMTEXT)
    subTV.setGravity(Gravity.CENTER_HORIZONTAL)
    hCard.addView(subTV)
  end
  inner.addView(hCard)

  -- ── API Key card ──────────────────────────────────────────────
  local apiCard = mkCard(ctx)
  apiCard.addView(sectionTitle(ctx,"Gemini API Key"))

  local usingHardcoded = HARDCODED_API_KEY and HARDCODED_API_KEY ~= ""

  if usingHardcoded then
    -- Key is hardcoded in code — show locked message, no input field
    local lockedRow = hRow(ctx, Gravity.CENTER_VERTICAL)
    local lockIcon = lbl(ctx, "  API key set in code  ", nil, 13, GREEN)
    lockIcon.setBackground(rRect("#0d2a1a", 10, "#1a6b3a"))
    lockIcon.setPadding(12, 8, 12, 8)
    local lockLP = fLP(); lockLP.setMargins(0,0,0,0)
    lockIcon.setLayoutParams(lockLP)
    lockedRow.addView(lockIcon)
    local lockedLP = fLP(); lockedLP.setMargins(0,0,0,6)
    lockedRow.setLayoutParams(lockedLP)
    apiCard.addView(lockedRow)

    local lockedNote = lbl(ctx,
      "To change the key, edit HARDCODED_API_KEY at the top of the code.",
      nil, 11, DIMTEXT)
    lockedNote.setPadding(0,4,0,0)
    apiCard.addView(lockedNote)
  else
    -- No hardcoded key — show normal input field
    local apiInput = mkEdit(ctx,"Paste your API key here",
      "API key input field. Paste your Gemini API key here.")
    apiInput.setInputType(0x81)  -- password hidden by default
    local apiLP = fLP(); apiLP.setMargins(0,0,0,8); apiInput.setLayoutParams(apiLP)
    apiCard.addView(apiInput)

    -- Show / Hide toggle
    local keyVisible = {v = false}
    local toggleKeyB = Button(ctx)
    toggleKeyB.setText("Show API Key")
    toggleKeyB.setContentDescription("Toggle API key visibility")
    toggleKeyB.setBackground(rRect(INBG, 16, BORDER, 1))
    toggleKeyB.setTextColor(Color.parseColor(TEXT))
    toggleKeyB.setTextSize(12); toggleKeyB.setAllCaps(false)
    toggleKeyB.setPadding(12,10,12,10)
    local toggleLP = fLP(); toggleLP.setMargins(0,0,0,8)
    toggleKeyB.setLayoutParams(toggleLP)
    toggleKeyB.setOnClickListener(luajava.createProxy(
      "android.view.View$OnClickListener", { onClick = function()
        keyVisible.v = not keyVisible.v
        if keyVisible.v then
          apiInput.setInputType(0x1)
          toggleKeyB.setText("Hide API Key")
        else
          apiInput.setInputType(0x81)
          toggleKeyB.setText("Show API Key")
        end
      end}))
    apiCard.addView(toggleKeyB)

    local hintRow = hRow(ctx)
    local dot = lbl(ctx,"  ", nil, 12, GREEN)
    local hintTV = lbl(ctx,"Free key at  aistudio.google.com",
      "Get a free API key at Google AI Studio",11,GREEN)
    hintRow.addView(dot); hintRow.addView(hintTV)
    apiCard.addView(hintRow)

    -- Load and show saved key
    local savedKey2, _, _ = readConfig()
    if savedKey2 then apiInput.setText(savedKey2) end

    -- Wire save into the model save button later via upvalue
    -- Store apiInput reference for the save button to read
    _apiInputRef = apiInput
  end
  inner.addView(apiCard)

  -- ── Launch behavior card ────────────────────────────────────────
  local lCard = mkCard(ctx)
  lCard.addView(sectionTitle(ctx,"On Launch"))

  local lNote = lbl(ctx,
    "Choose what happens when you open this plugin.",
    nil, 11, DIMTEXT)
  lNote.setPadding(0,0,0,8)
  lCard.addView(lNote)

  local currentMode = readLaunchMode()
  local launchBtns  = {}  -- mode -> button, so we can restyle on select

  local function styleLaunchBtn(btn, mode)
    if mode == currentMode then
      btn.setBackground(gradDrawable("#0d4a35","#062a1e",14))
      btn.setTextColor(Color.parseColor("#4ade80"))
    else
      btn.setBackground(rRect(CARD2, 14, BORDER, 1))
      btn.setTextColor(Color.parseColor(TEXT))
    end
  end

  local function selectLaunchMode(mode)
    currentMode = mode
    writeLaunchMode(mode)
    for m, btn in pairs(launchBtns) do styleLaunchBtn(btn, m) end
    Toast.makeText(ctx, "Launch action: " .. LAUNCH_MODE_LABELS[mode],
      Toast.LENGTH_SHORT).show()
  end

  for _, mode in ipairs(LAUNCH_MODES) do
    local b = Button(ctx)
    b.setText(LAUNCH_MODE_LABELS[mode])
    b.setContentDescription("Set launch action to " .. LAUNCH_MODE_LABELS[mode])
    b.setTextSize(12); b.setPadding(8,10,8,10); b.setAllCaps(false)
    styleLaunchBtn(b, mode)
    b.setOnClickListener(luajava.createProxy(
      "android.view.View$OnClickListener", { onClick = function()
        selectLaunchMode(mode)
      end}))
    launchBtns[mode] = b
    local bLP = fLP(); bLP.setMargins(0,0,0,6); b.setLayoutParams(bLP)
    lCard.addView(b)
  end

  local lHint = lbl(ctx,
    "\"Show Menu\" lets you pick OCR or Solve Captcha each time. " ..
    "\"Direct OCR\" or \"Direct Captcha\" skip the menu and run right away.",
    nil, 10, DIMTEXT)
  lHint.setPadding(0,4,0,0)
  lCard.addView(lHint)
  inner.addView(lCard)

  -- ── Model selector card ───────────────────────────────────────
  local mCard = mkCard(ctx)
  mCard.addView(sectionTitle(ctx,"Select Model"))

  local savedKey, savedModel, savedPrompt = readConfig()
  -- apiInput only exists when not using hardcoded key
  -- _apiInputRef was set above in that case
  local mIdx = {v=1}  -- default: gemini-3-flash-preview
  if savedModel then
    for i,m in ipairs(MODELS) do
      if m==savedModel then mIdx.v=i; break end
    end
  end

  -- Model display box: name + badge
  local mBox = LinearLayout(ctx)
  mBox.setOrientation(LinearLayout.HORIZONTAL)
  mBox.setGravity(Gravity.CENTER_VERTICAL)
  mBox.setBackground(rRect(INBG,14,BORDER))
  mBox.setPadding(14,10,14,10)
  local mBoxLP = fLP(); mBoxLP.setMargins(0,0,0,8); mBox.setLayoutParams(mBoxLP)

  local mNameTV = lbl(ctx, MODEL_INFO[mIdx.v].name,
    "Selected model "..MODEL_INFO[mIdx.v].name, 14, TEXT)
  mNameTV.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT,1))

  local mBadge = mkBadge(ctx,
    MODEL_INFO[mIdx.v].badge, MODEL_INFO[mIdx.v].badgeColor)

  mBox.addView(mNameTV); mBox.addView(mBadge)
  mCard.addView(mBox)

  -- Prev / Next buttons
  local mBtnRow = hRow(ctx)

  local prevB = mkBtn(ctx,"  Previous","Previous model",CARD2,BORDER,
    function()
      mIdx.v = mIdx.v - 1
      if mIdx.v < 1 then mIdx.v = #MODELS end
      local info = MODEL_INFO[mIdx.v]
      mNameTV.setText(info.name)
      mNameTV.setContentDescription("Selected model "..info.name)
      mBadge.setText(info.badge)
      mBadge.setBackground(rRect(info.badgeColor,20))
    end)

  local nextB = mkBtn(ctx,"Next  ","Next model",CARD2,BORDER,
    function()
      mIdx.v = mIdx.v + 1
      if mIdx.v > #MODELS then mIdx.v = 1 end
      local info = MODEL_INFO[mIdx.v]
      mNameTV.setText(info.name)
      mNameTV.setContentDescription("Selected model "..info.name)
      mBadge.setText(info.badge)
      mBadge.setBackground(rRect(info.badgeColor,20))
    end)

  prevB.setLayoutParams(eLP(1)); nextB.setLayoutParams(eLP(1))
  mBtnRow.addView(prevB); mBtnRow.addView(nextB)
  mCard.addView(mBtnRow)

  -- Model counter hint  "1 / 6"
  local mCountTV = lbl(ctx, "Model "..mIdx.v.." of "..#MODELS, nil, 10, DIMTEXT)
  mCountTV.setGravity(Gravity.CENTER_HORIZONTAL)
  mCountTV.setImportantForAccessibility(4)
  local mcLP = fLP(); mcLP.setMargins(0,6,0,0); mCountTV.setLayoutParams(mcLP)
  mCard.addView(mCountTV)

  -- Set final listeners that also update the counter label
  prevB.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      mIdx.v = mIdx.v - 1
      if mIdx.v < 1 then mIdx.v = #MODELS end
      local info = MODEL_INFO[mIdx.v]
      mNameTV.setText(info.name)
      mNameTV.setContentDescription("Selected model "..info.name)
      mBadge.setText(info.badge)
      mBadge.setBackground(rRect(info.badgeColor,20))
      mCountTV.setText("Model "..mIdx.v.." of "..#MODELS)
    end}))

  nextB.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      mIdx.v = mIdx.v + 1
      if mIdx.v > #MODELS then mIdx.v = 1 end
      local info = MODEL_INFO[mIdx.v]
      mNameTV.setText(info.name)
      mNameTV.setContentDescription("Selected model "..info.name)
      mBadge.setText(info.badge)
      mBadge.setBackground(rRect(info.badgeColor,20))
      mCountTV.setText("Model "..mIdx.v.." of "..#MODELS)
    end}))

  inner.addView(mCard)

  -- ── Prompt card ───────────────────────────────────────────────
  local pCard = mkCard(ctx)
  pCard.addView(sectionTitle(ctx,"Custom Prompt"))

  local pInput = mkEdit(ctx,
    "Prompt sent to Gemini with each image",
    "Custom prompt input field", true)
  local pLP = fLP(); pLP.setMargins(0,0,0,8); pInput.setLayoutParams(pLP)
  pInput.setText(savedPrompt or DEFAULT_PROMPT)
  pCard.addView(pInput)

  -- Preset prompt buttons
  local presetLabel = lbl(ctx, "Quick presets:", nil, 11, DIMTEXT)
  presetLabel.setPadding(0,0,0,6)
  pCard.addView(presetLabel)

  local DESCRIBE_PROMPT =
    "Describe what you see in this image in detail. " ..
    "Then extract and list any text visible in the image."

  local MATH_PROMPT =
    "Extract all mathematical equations, numbers, and calculations from this image. " ..
    "Show the extracted content clearly and solve any equations if present."

  local presetRow1 = hRow(ctx)

  local descB = mkBtn(ctx, "Describe + Extract",
    "Set prompt to describe image and extract text",
    INBG, "#6b3d9e", function()
      pInput.setText(DESCRIBE_PROMPT)
      Toast.makeText(ctx, "Describe prompt set", Toast.LENGTH_SHORT).show()
    end)
  descB.setTextSize(11); descB.setTextColor(Color.parseColor("#c4b5fd"))
  descB.setLayoutParams(eLP(1, 0, 4, 0, 0))
  presetRow1.addView(descB)

  local mathB = mkBtn(ctx, "Math / Numbers",
    "Set prompt to extract math and equations",
    INBG, "#6b5a0a", function()
      pInput.setText(MATH_PROMPT)
      Toast.makeText(ctx, "Math prompt set", Toast.LENGTH_SHORT).show()
    end)
  mathB.setTextSize(11); mathB.setTextColor(Color.parseColor("#fde68a"))
  mathB.setLayoutParams(eLP(1, 4, 0, 0, 0))
  presetRow1.addView(mathB)

  local p1LP = fLP(); p1LP.setMargins(0,0,0,8); presetRow1.setLayoutParams(p1LP)
  pCard.addView(presetRow1)

  local presetRow2 = hRow(ctx)
  local captchaPresetB = mkBtn(ctx, "Captcha Solver",
    "Set prompt to solve captchas",
    INBG, "#9e5a0a", function()
      pInput.setText(CAPTCHA_PROMPT)
      Toast.makeText(ctx, "Captcha prompt set", Toast.LENGTH_SHORT).show()
    end)
  captchaPresetB.setTextSize(11); captchaPresetB.setTextColor(Color.parseColor("#fdba74"))
  captchaPresetB.setLayoutParams(fLP())
  presetRow2.addView(captchaPresetB)
  local p2LP = fLP(); p2LP.setMargins(0,0,0,8); presetRow2.setLayoutParams(p2LP)
  pCard.addView(presetRow2)

  local noteTV = lbl(ctx,
    "Tip: Use the Translate button on the result screen for translations, " ..
    "or use \"Solve Captcha\" from the start menu directly.",
    nil, 10, DIMTEXT)
  noteTV.setPadding(0,0,0,6)
  pCard.addView(noteTV)

  local rstB = mkBtn(ctx,"Reset to Default","Reset prompt to default",
    INBG, BORDER, function()
      pInput.setText(DEFAULT_PROMPT)
      Toast.makeText(ctx,"Prompt reset to default",Toast.LENGTH_SHORT).show()
    end)
  rstB.setTextSize(12)
  local rstLP = fLP(); rstLP.setMargins(0,0,0,0); rstB.setLayoutParams(rstLP)
  pCard.addView(rstB)
  inner.addView(pCard)

  -- ── Save / Close / Contact card ───────────────────────────────
  local actCard = mkCard(ctx)

  -- Save button (full width, green gradient)
  local saveB = Button(ctx)
  saveB.setText("Save Settings")
  saveB.setContentDescription("Save model and prompt settings")
  saveB.setBackground(gradDrawable("#145a32","#0b3d22",14))
  saveB.setTextColor(Color.WHITE); saveB.setTextSize(15)
  saveB.setPadding(0,14,0,14); saveB.setAllCaps(false)
  local saveBLP = fLP(); saveBLP.setMargins(0,0,0,8)
  saveB.setLayoutParams(saveBLP)
  saveB.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      local key
      if usingHardcoded then
        key = HARDCODED_API_KEY
      else
        key = _apiInputRef and
          tostring(_apiInputRef.getText()):match("^%s*(.-)%s*$") or ""
        if key == "" then
          Toast.makeText(ctx,"Please enter your Gemini API key",
            Toast.LENGTH_LONG).show(); return
        end
      end
      local mdl    = MODELS[mIdx.v]
      local prompt = tostring(pInput.getText()):match("^%s*(.-)%s*$")
      if prompt == "" then prompt = DEFAULT_PROMPT end
      writeConfig(key, mdl, prompt)
      Toast.makeText(ctx,
        "Saved!  Model: "..MODEL_INFO[mIdx.v].name,
        Toast.LENGTH_LONG).show()
      _apiInputRef = nil
      removeOverlay()
      if firstTime then runLaunchAction() end
    end}))
  actCard.addView(saveB)

  -- Close button
  local closeB = mkBtn(ctx,"Close","Close settings without saving",
    CARD2, BORDER, function() removeOverlay() end)
  local closeBLP = fLP(); closeBLP.setMargins(0,0,0,10)
  closeB.setLayoutParams(closeBLP)
  actCard.addView(closeB)

  -- History button
  local histB = mkBtn(ctx, "View OCR History",
    "Open OCR history screen",
    "#0d1f38", BORDER, function() showHistory() end)
  local histBLP = fLP(); histBLP.setMargins(0,0,0,10)
  histB.setLayoutParams(histBLP)
  actCard.addView(histB)

  -- What's New / Changelog button
  local changelogB = mkBtn(ctx, "What's New",
    "Open changelog screen",
    "#0d1f38", BORDER, function() showChangelog() end)
  local changelogBLP = fLP(); changelogBLP.setMargins(0,0,0,10)
  changelogB.setLayoutParams(changelogBLP)
  actCard.addView(changelogB)

  actCard.addView(divLine(ctx))

  -- Hi / Bug row
  local contactRow = hRow(ctx)
  local hiB2 = mkBtn(ctx,"Say Hi","Say Hi to Sushil on WhatsApp",
    "#0a2040",BORDER,
    function() openWA("Hi Sushil I am using your Jieshuo OCR plugin") end)
  local bugB2 = mkBtn(ctx,"Report Bug","Report bug on WhatsApp",
    "#2a0a14",BORDER,
    function() openWA("Bug Report Jieshuo OCR Plugin. Description: ") end)
  hiB2.setLayoutParams(eLP(1)); bugB2.setLayoutParams(eLP(1))
  contactRow.addView(hiB2); contactRow.addView(bugB2)
  actCard.addView(contactRow)

  inner.addView(actCard)

  -- ── Token usage card ──────────────────────────────────────────
  local tokCard = mkCard(ctx, 16, 12, "#0d1a10", "#1a3a20")
  tokCard.addView(sectionTitle(ctx, "API Token Usage"))

  local tokStats = readTokenStats()

  local statRows = {
    {"Total Requests",    fmtNum(tokStats.req),  "#4ade80"},
    {"Input Tokens",      fmtNum(tokStats.inp),  "#60a5fa"},
    {"Output Tokens",     fmtNum(tokStats.out),  "#f9a8d4"},
    {"Last Used",         tokStats.date,          "#fbbf24"},
  }
  for _, row in ipairs(statRows) do
    local r = hRow(ctx, Gravity.CENTER_VERTICAL)
    local keyTV = lbl(ctx, row[1], nil, 12, DIMTEXT)
    keyTV.setLayoutParams(LinearLayout.LayoutParams(0,
      LinearLayout.LayoutParams.WRAP_CONTENT, 1))
    local valTV = lbl(ctx, row[2], nil, 13, row[3])
    valTV.setGravity(Gravity.END)
    r.addView(keyTV); r.addView(valTV)
    local rLP = fLP(); rLP.setMargins(0,4,0,4); r.setLayoutParams(rLP)
    tokCard.addView(r)
  end

  tokCard.addView(divLine(ctx))

  local resetTokB = mkBtn(ctx, "Reset Usage Counter",
    "Reset API token usage counter to zero",
    CARD2, BORDER, function()
      resetTokenStats()
      Toast.makeText(ctx, "Usage counter reset to zero", Toast.LENGTH_SHORT).show()
      removeOverlay()
      showSetupScreen(false)
    end)
  resetTokB.setTextSize(12)
  local rtLP = fLP(); resetTokB.setLayoutParams(rtLP)
  tokCard.addView(resetTokB)
  inner.addView(tokCard)

  inner.addView(sp(ctx,24))

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  TEXT FORMATTERS
-- ════════════════════════════════════════════════════════════════
function string:split(sep)
  local r={}; for m in (self..sep):gmatch("(.-)"..sep) do r[#r+1]=m end; return r
end

function formatTable(text)
  local lines={}; for l in text:gmatch("[^\r\n]+") do lines[#lines+1]=l end
  local hasTbl,sep=false,nil
  for _,l in ipairs(lines) do
    if l:match("|") then sep="|";hasTbl=true;break
    elseif l:match("\t") and #l:split("\t")>1 then sep="\t";hasTbl=true;break end
  end
  if not hasTbl then return nil end
  local out="Table:\n\n"
  for i,l in ipairs(lines) do
    local cells={}
    if sep=="|" then for c in l:gmatch("[^|]+") do cells[#cells+1]=c:match("^%s*(.-)%s*$") end
    else cells=l:split(sep) end
    out=out..table.concat(cells," | ").."\n"
    if i==1 then out=out..string.rep("-",38).."\n" end
  end
  return out
end

function formatList(text)
  local lines={}; for l in text:gmatch("[^\r\n]+") do lines[#lines+1]=l end
  local isList=false
  for _,l in ipairs(lines) do
    if l:match("^%s*[%-%*%+]%s") or l:match("^%s*%d+[%.%):]%s") then isList=true;break end
  end
  if not isList then return nil end
  local out="List:\n\n"
  for _,l in ipairs(lines) do out=out..(l:match("%S") and (l.."\n") or "\n") end
  return out
end

-- ════════════════════════════════════════════════════════════════
--  BACKGROUND OCR TASK
-- ════════════════════════════════════════════════════════════════
function doOCRTask(b64, apiKey, model, prompt)
  require "import"
  import "java.io.OutputStreamWriter"
  import "java.io.BufferedReader"
  import "java.io.InputStreamReader"
  import "java.net.URL"
  import "org.json.JSONObject"
  import "org.json.JSONArray"

  local FALLBACK_PROMPT =
    "Extract all text from this image exactly as it appears. " ..
    "Preserve the original structure and line breaks. Return plain text only."
  local safeP     = (prompt and prompt ~= "" and prompt or FALLBACK_PROMPT):gsub('"','\\"'):gsub("\n","\\n")
  local useNewApi = (model == "gemini-3.7-flash" or model == "gemini-3.8-flash")

  local url, body
  if useNewApi then
    -- Newer models (3.7 / 3.8) only work through the Interactions API.
    url = "https://generativelanguage.googleapis.com/v1beta/interactions"
    body = string.format(
      '{"model":"%s","input":[{"type":"text","text":"%s"},{"type":"image","data":"%s","mime_type":"image/jpeg"}]}',
      model, safeP, b64)
  else
    -- Older / stable models use the classic generateContent endpoint.
    url = "https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent"
    body = string.format(
      '{"contents":[{"parts":[{"text":"%s"},{"inline_data":{"mime_type":"image/jpeg","data":"%s"}}]}]}',
      safeP, b64)
  end

  local ok, res = pcall(function()
    local u    = URL(url)
    local conn = u.openConnection()
    conn.setRequestMethod("POST")
    conn.setRequestProperty("Content-Type","application/json")
    conn.setRequestProperty("x-goog-api-key", apiKey)
    conn.setDoOutput(true)
    conn.setConnectTimeout(40000); conn.setReadTimeout(120000)
    local w = OutputStreamWriter(conn.getOutputStream(),"UTF-8")
    w.write(body); w.flush(); w.close()
    local code = conn.getResponseCode()
    if code == 200 then
      local rd = BufferedReader(InputStreamReader(conn.getInputStream()))
      local sb = StringBuilder(); local ln = rd.readLine()
      while ln do sb.append(ln); ln=rd.readLine() end
      rd.close()
      local respJson = JSONObject(sb.toString())
      local text, inTok, outTok = "", "0", "0"

      if useNewApi then
        -- Interactions API response: { "steps": [ { "type":"model_output", "content":[{"type":"text","text":"..."}] } ] }
        local ok5, steps = pcall(function() return respJson.getJSONArray("steps") end)
        if ok5 and steps then
          for i = 0, steps.length() - 1 do
            local step = steps.getJSONObject(i)
            if step.optString("type","") == "model_output" then
              local content = step.getJSONArray("content")
              for j = 0, content.length() - 1 do
                local part = content.getJSONObject(j)
                if part.optString("type","") == "text" then
                  text = text .. part.getString("text")
                end
              end
            end
          end
        end
        -- Token usage field name/shape may vary — best effort only
        local ok2, usage = pcall(function() return respJson.getJSONObject("usage") end)
        if ok2 and usage then
          local ok3, iv = pcall(function() return usage.getInt("input_tokens") end)
          local ok4, ov = pcall(function() return usage.getInt("output_tokens") end)
          if ok3 and iv then inTok  = tostring(iv) end
          if ok4 and ov then outTok = tostring(ov) end
        end
      else
        -- Classic generateContent response
        text = respJson
          .getJSONArray("candidates").getJSONObject(0)
          .getJSONObject("content").getJSONArray("parts")
          .getJSONObject(0).getString("text")
        local ok2, meta = pcall(function()
          return respJson.getJSONObject("usageMetadata") end)
        if ok2 and meta then
          local ok3, iv = pcall(function() return meta.getInt("promptTokenCount") end)
          if not ok3 then ok3, iv = pcall(function() return meta.getInt("inputTokenCount") end) end
          local ok4, ov = pcall(function() return meta.getInt("candidatesTokenCount") end)
          if not ok4 then ok4, ov = pcall(function() return meta.getInt("outputTokenCount") end) end
          if ok3 and iv then inTok  = tostring(iv) end
          if ok4 and ov then outTok = tostring(ov) end
        end
      end

      -- Pack text + token counts — use ||| separator (safe across task() boundary)
      return text .. "|||TOK|||" .. inTok .. "|||" .. outTok
    else
      local rd = BufferedReader(InputStreamReader(conn.getErrorStream()))
      local sb = StringBuilder(); local ln = rd.readLine()
      while ln do sb.append(ln); ln=rd.readLine() end
      rd.close()
      error("HTTP "..code..": "..sb.toString())
    end
  end)
  if ok then return "ok",res else return "err",tostring(res) end
end

-- ════════════════════════════════════════════════════════════════
--  TRANSLATE TASK  (takes extracted text, sends to Gemini as text)
-- ════════════════════════════════════════════════════════════════
function doTranslateTask(extractedText, targetLang, apiKey, model)
  require "import"
  import "java.io.OutputStreamWriter"
  import "java.io.BufferedReader"
  import "java.io.InputStreamReader"
  import "java.net.URL"
  import "org.json.JSONObject"
  import "org.json.JSONArray"

  local prompt
  if targetLang == "nepali" then
    prompt = "Translate the following text to Nepali language. " ..
             "Return only the Nepali translation. Do not include the original text:\n\n" .. extractedText
  elseif targetLang == "english" then
    prompt = "Translate the following text to English language. " ..
             "Return only the English translation. Do not include the original text:\n\n" .. extractedText
  else
    prompt = "Translate the following text to " .. targetLang ..
             ". Return only the translation. Do not include the original text:\n\n" .. extractedText
  end

  local safePrompt = prompt:gsub('"','\\"'):gsub("\n","\\n")
  local useNewApi  = (model == "gemini-3.7-flash" or model == "gemini-3.8-flash")

  local url, body
  if useNewApi then
    -- Newer models (3.7 / 3.8) only work through the Interactions API.
    url  = "https://generativelanguage.googleapis.com/v1beta/interactions"
    body = string.format('{"model":"%s","input":"%s"}', model, safePrompt)
  else
    -- Older / stable models use the classic generateContent endpoint.
    url  = "https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent"
    body = string.format('{"contents":[{"parts":[{"text":"%s"}]}]}', safePrompt)
  end

  local ok, res = pcall(function()
    local u    = URL(url)
    local conn = u.openConnection()
    conn.setRequestMethod("POST")
    conn.setRequestProperty("Content-Type","application/json")
    conn.setRequestProperty("x-goog-api-key", apiKey)
    conn.setDoOutput(true)
    conn.setConnectTimeout(20000); conn.setReadTimeout(45000)
    local w = OutputStreamWriter(conn.getOutputStream(),"UTF-8")
    w.write(body); w.flush(); w.close()
    local code = conn.getResponseCode()
    if code == 200 then
      local rd = BufferedReader(InputStreamReader(conn.getInputStream()))
      local sb = StringBuilder(); local ln = rd.readLine()
      while ln do sb.append(ln); ln=rd.readLine() end
      rd.close()
      local respJson = JSONObject(sb.toString())

      if useNewApi then
        local text = ""
        local ok5, steps = pcall(function() return respJson.getJSONArray("steps") end)
        if ok5 and steps then
          for i = 0, steps.length() - 1 do
            local step = steps.getJSONObject(i)
            if step.optString("type","") == "model_output" then
              local content = step.getJSONArray("content")
              for j = 0, content.length() - 1 do
                local part = content.getJSONObject(j)
                if part.optString("type","") == "text" then
                  text = text .. part.getString("text")
                end
              end
            end
          end
        end
        return text
      else
        return respJson
          .getJSONArray("candidates").getJSONObject(0)
          .getJSONObject("content").getJSONArray("parts")
          .getJSONObject(0).getString("text")
      end
    else
      local rd = BufferedReader(InputStreamReader(conn.getErrorStream()))
      local sb = StringBuilder(); local ln = rd.readLine()
      while ln do sb.append(ln); ln=rd.readLine() end
      rd.close()
      error("HTTP "..code..": "..sb.toString())
    end
  end)
  if ok then return "ok", res else return "err", tostring(res) end
end

-- Called on main thread after translation completes
function onTranslateDone(status, data)
  if status == "ok" then
    showResult(data)
  else
    local err = tostring(data)
      :gsub("com%.luajava%.LuaException:%s*","")
      :gsub("Runtime error%s*%.?%s*","")
    Toast.makeText(this, "Translation failed: " .. err, Toast.LENGTH_LONG).show()
  end
end

-- Show language picker overlay then run translation
function showTranslateOptions(originalText)
  local ctx = this

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f5"..BG:sub(2)))
  root.setPadding(20, 60, 20, 20)

  -- Header card
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a3050","#0d1828",20))
  hCard.setPadding(18,14,18,14)
  local hLP = fLP(); hLP.setMargins(0,0,0,14); hCard.setLayoutParams(hLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx, "Translate Text", "Translate text screen", 18, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0,
    LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local backBtn = mkBtn(ctx, "Back", "Back to result",
    "#1e3a5a", BORDER, function() showResult(originalText) end)
  backBtn.setTextSize(12); backBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(backBtn)
  hCard.addView(titleRow)

  local subTV = lbl(ctx, "Choose a language to translate to", nil, 11, DIMTEXT)
  subTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(subTV)
  root.addView(hCard)

  -- Language buttons card
  local langCard = mkCard(ctx)
  langCard.addView(sectionTitle(ctx, "Select Language"))

  local apiKey, model, _ = readConfig()
  if HARDCODED_API_KEY and HARDCODED_API_KEY ~= "" then
    apiKey = HARDCODED_API_KEY
  end
  if HARDCODED_MODEL and HARDCODED_MODEL ~= "" then
    model = HARDCODED_MODEL
  end

  local function runTranslate(lang, label)
    removeOverlay()
    Toast.makeText(ctx, "Translating to " .. label .. "...", Toast.LENGTH_SHORT).show()
    task(doTranslateTask, originalText, lang, apiKey, model, onTranslateDone)
  end

  -- Language list with colors
  local langs = {
    { id="english",  label="English",           color="#1d4e89" },
    { id="nepali",   label="Nepali (नेपाली)",   color="#7b3f00" },
    { id="hindi",    label="Hindi (हिन्दी)",    color="#4a235a" },
    { id="chinese",  label="Chinese (中文)",     color="#922b21" },
    { id="arabic",   label="Arabic (عربي)",     color="#1a5276" },
    { id="french",   label="French",            color="#1f618d" },
    { id="spanish",  label="Spanish",           color="#196f3d" },
    { id="japanese", label="Japanese (日本語)",  color="#512e5f" },
  }

  for _, lang in ipairs(langs) do
    local langId    = lang.id
    local langLabel = lang.label
    local langB = mkBtn(ctx, langLabel,
      "Translate to " .. langLabel,
      lang.color, BORDER, function()
        runTranslate(langId, langLabel)
      end)
    local lbLP = fLP(); lbLP.setMargins(0,0,0,6); langB.setLayoutParams(lbLP)
    langCard.addView(langB)
  end

  root.addView(langCard)

  -- Close
  local closeB = mkBtn(ctx, "Close", "Close translate screen",
    CARD2, BORDER, function() removeOverlay() end)
  closeB.setLayoutParams(fLP())
  root.addView(closeB)

  showOverlay(root)
end

function onOCRDone(status, data)
  if status == "ok" then
    -- Unpack: text|||TOK|||inputTokens|||outputTokens
    local text, inTok, outTok = data:match("^(.-)|||TOK|||(%d+)|||(%d+)$")
    if not text then
      -- fallback: no token data packed (older call or parse fail)
      text = data; inTok = "0"; outTok = "0"
    end
    -- Save token usage
    addTokenUsage(tonumber(inTok) or 0, tonumber(outTok) or 0)
    -- Save to history
    local ok, dateStr = pcall(function() return os.date("%Y-%m-%d %H:%M") end)
    saveHistory(text, ok and dateStr or "Unknown date")
    local out = formatTable(text) or formatList(text) or text
    showResult(out)
  else
    local err = tostring(data)
      :gsub("com%.luajava%.LuaException:%s*","")
      :gsub("Runtime error%s*%.?%s*","")
    showResult("OCR failed.\n\n"..err..
      "\n\nTip: Check your API key and model in Settings.")
  end
end

-- ════════════════════════════════════════════════════════════════
--  ENTRY POINT
-- ════════════════════════════════════════════════════════════════

-- Shared helper: take a screenshot and run it through Gemini with the
-- given prompt (or the saved/default prompt if none is passed in).
function captureAndRun(promptOverride)
  local apiKey, model, prompt = readConfig()

  -- Hardcoded key overrides saved config (if user pasted one above)
  if HARDCODED_API_KEY and HARDCODED_API_KEY ~= "" then
    apiKey = HARDCODED_API_KEY
  end
  if HARDCODED_MODEL and HARDCODED_MODEL ~= "" then
    model = HARDCODED_MODEL
  end

  if not apiKey or apiKey == "" then
    showSetupScreen(true); return
  end

  local finalPrompt = promptOverride or prompt

  this.getScreenShot({
    onScreenCaptureDone = function(bitmap)
      Toast.makeText(this,"Reading screen, please wait",Toast.LENGTH_SHORT).show()
      local baos = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.JPEG,90,baos)
      local b64 = Base64.encodeToString(baos.toByteArray(),Base64.NO_WRAP)
      task(doOCRTask, b64, apiKey, model, finalPrompt, onOCRDone)
    end
  })
end

-- "Run OCR" button on the start menu — uses the saved/default prompt.
function runOCR()
  captureAndRun(nil)
end

-- "Solve Captcha" button on the start menu — uses the captcha prompt.
function runCaptchaSolve()
  captureAndRun(CAPTCHA_PROMPT)
end

-- Kept for backward compatibility with any code that still calls startOCR()
-- directly (e.g. after first-time setup completes).
function startOCR()
  runOCR()
end

-- Dispatch based on the saved launch-mode setting (Settings → On Launch).
function runLaunchAction()
  local mode = readLaunchMode()
  if mode == "ocr" then
    runOCR()
  elseif mode == "captcha" then
    runCaptchaSolve()
  else
    showStartMenu()
  end
end

task(500, function() runLaunchAction() end)