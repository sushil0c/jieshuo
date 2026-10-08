require "import"
import "android.util.Base64"
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
import "android.content.ClipboardManager"
import "android.content.ClipData"
import "android.media.MediaRecorder"
import "android.app.AlertDialog"
import "android.content.pm.PackageManager"

-- ════════════════════════════════════════════════════════════════
--  CONSTANTS
-- ════════════════════════════════════════════════════════════════
local SAVE_DIR     = "/sdcard/Sushil/"
local CONFIG_FILE  = SAVE_DIR .. "voice_config.txt"
local AUDIO_FILE   = SAVE_DIR .. "voice_record.m4a"
local HISTORY_FILE = SAVE_DIR .. "voice_history.txt"
local HISTORY_MAX  = 20

local DEFAULT_PROMPT =
  "Transcribe the following audio recording verbatim, exactly as spoken. If the " ..
  "speaker mixes multiple languages in the same recording (code-switching), " ..
  "transcribe each word or phrase in the language and script it was actually " ..
  "spoken in - do not translate, and do not convert everything into a single " ..
  "language or script. Nepali words go in Nepali (Devanagari script). English " ..
  "words go in English (Latin script) - even common English words spoken with " ..
  "a Nepali accent inside a Nepali sentence, like 'hello', 'evening', 'office', " ..
  "or 'phone', must still be written in Latin letters exactly as English words " ..
  "(hello, evening, office, phone), NOT phonetically transliterated into " ..
  "Devanagari spelling (do not write हेलो, इभिनिङ, अफिस, or फोन). Only use " ..
  "Devanagari for words that are genuinely Nepali. Add natural punctuation " ..
  "based on the sentence structure, pauses, and intonation of the speech, the " ..
  "way a fluent human transcriber would - use commas, periods (or the " ..
  "Devanagari danda '।' for Nepali sentences), question marks for questions, " ..
  "and exclamation marks for exclamations, even though the speaker did not say " ..
  "the punctuation aloud. Where it fits naturally, add a relevant emoji that " ..
  "matches the tone, emotion, or content of a phrase, the way people naturally " ..
  "add emojis when texting - for example laughter sounds like 😂, a greeting " ..
  "like 👋, good news like 🎉. Use emojis sparingly and only where they " ..
  "genuinely fit, not after every sentence. Output ONLY the transcript as " ..
  "plain text - no introduction, labels, quotation marks, headers, or " ..
  "commentary of any kind."

-- ── Optional: paste your API key directly here (skips Settings) ──
local HARDCODED_API_KEY = ""  -- leave "" to use the key saved via Settings

local PROVIDERS = { "Gemini", "OpenAI", "Groq" }

local PROVIDER_INFO = {
  Gemini = { badge = "Multimodal", badgeColor = "#3d9be9" },
  OpenAI = { badge = "Whisper",    badgeColor = "#10a37f" },
  Groq   = { badge = "Fast",       badgeColor = "#f97316" },
}

local MODELS_BY_PROVIDER = {
  Gemini = { "gemini-2.5-flash", "gemini-2.5-pro", "gemini-3.6-flash" },
  OpenAI = { "gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1" },
  Groq   = { "whisper-large-v3", "whisper-large-v3-turbo" },
}

-- ════════════════════════════════════════════════════════════════
--  PALETTE  (same as OCR plugin)
-- ════════════════════════════════════════════════════════════════
local BG      = "#0f1923"
local CARD    = "#172030"
local CARD2   = "#1e2c40"
local BORDER  = "#253348"
local ACCENT  = "#3d9be9"
local GREEN   = "#22c55e"
local RED     = "#ef4444"
local TEXT    = "#e2e8f0"
local DIMTEXT = "#64748b"
local INBG    = "#0a1219"

-- ════════════════════════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════════════════════════
local overlay      = nil
local wmSvc         = nil
local recorder      = nil
local isRecording    = false

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
--  CONFIG   (line1=apiKey, line2=provider, line3=model, rest=prompt)
-- ════════════════════════════════════════════════════════════════
function readConfig()
  local f = io.open(CONFIG_FILE, "r")
  if not f then return nil, PROVIDERS[1], MODELS_BY_PROVIDER[PROVIDERS[1]][1], DEFAULT_PROMPT end
  local k = (f:read("*l") or ""):match("^%s*(.-)%s*$")
  local p = (f:read("*l") or ""):match("^%s*(.-)%s*$")
  local m = (f:read("*l") or ""):match("^%s*(.-)%s*$")
  local prompt = (f:read("*a") or ""):match("^%s*(.-)%s*$")
  f:close()
  if p == "" then p = PROVIDERS[1] end
  if m == "" then m = MODELS_BY_PROVIDER[p][1] end
  if prompt == "" then prompt = DEFAULT_PROMPT end
  if k == "" then return nil, p, m, prompt end
  return k, p, m, prompt
end

function writeConfig(k, p, m, prompt)
  os.execute("mkdir -p " .. SAVE_DIR)
  local f = io.open(CONFIG_FILE, "w")
  if f then f:write(k.."\n"..p.."\n"..m.."\n"..(prompt or DEFAULT_PROMPT).."\n"); f:close() end
end

-- ════════════════════════════════════════════════════════════════
--  HISTORY  (up to HISTORY_MAX entries, newest first)
--  Same format as the OCR plugin: entries separated by "\n===END===\n",
--  each entry's first line is the date, the rest is the transcript.
-- ════════════════════════════════════════════════════════════════
local ENTRY_SEP = "\n===END===\n"

function saveHistory(text, date)
  os.execute("mkdir -p " .. SAVE_DIR)
  local entries = readHistory()
  table.insert(entries, 1, {date = date or "Unknown", text = text})
  while #entries > HISTORY_MAX do table.remove(entries) end
  local f = io.open(HISTORY_FILE, "w")
  if not f then return end
  for _, e in ipairs(entries) do
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

-- ════════════════════════════════════════════════════════════════
--  CLIPBOARD
-- ════════════════════════════════════════════════════════════════
function copyToClipboard(text)
  local cm = this.getSystemService("clipboard")
  local clip = ClipData.newPlainText("Transcript", text)
  cm.setPrimaryClip(clip)
  Toast.makeText(this, "Copied to clipboard", Toast.LENGTH_SHORT).show()
end

-- ════════════════════════════════════════════════════════════════
--  AUTO-PASTE  (split in two: capture the focused field EARLY — before
--  any interaction with our own overlay — then paste using that saved
--  reference later, since by the time transcription finishes our own
--  plugin window is the "active" one and a fresh query finds nothing)
-- ════════════════════════════════════════════════════════════════
function captureFocusedNode()
  local node, source, errMsg = nil, nil, nil

  local ok1, err1 = pcall(function() node = service.getEditText() end)
  if not ok1 then errMsg = "service.getEditText(): " .. tostring(err1) end
  if node ~= nil then source = "service" end

  if node == nil then
    local ok2, err2 = pcall(function() node = this.getEditText() end)
    if not ok2 then
      errMsg = (errMsg and (errMsg .. "  |  ") or "") .. "this.getEditText(): " .. tostring(err2)
    end
    if node ~= nil then source = "this" end
  end

  return node, source, errMsg
end

function pasteIntoNode(node, source, text)
  if node == nil then
    return false, "No field is focused (target app may not have regained focus yet)."
  end
  local ok, err = pcall(function()
    if source == "service" then
      service.insertText(node, text .. " ")
    else
      this.insertText(node, text .. " ")
    end
  end)
  if not ok then
    return false, "insertText failed: " .. tostring(err)
  end
  return true, nil
end
function showNoInputDialog(text)
  local ctx = this
  local msg = "No text field is focused right now, so the transcript could not be pasted.\n\n"
    .. "Transcript:\n" .. text
  local ok, err = pcall(function()
    local builder = AlertDialog.Builder(ctx)
    builder.setTitle("No Input Box Available")
    builder.setMessage(msg)
    builder.setCancelable(true)
    builder.setPositiveButton("Copy Transcript", luajava.createProxy(
      "android.content.DialogInterface$OnClickListener", {
        onClick = function(dialog, which) copyToClipboard(text) end
      }))
    builder.setNegativeButton("Close", luajava.createProxy(
      "android.content.DialogInterface$OnClickListener", {
        onClick = function(dialog, which) end
      }))
    local dlg = builder.create()
    -- This plugin runs as an overlay/service context, not a normal Activity,
    -- so the dialog's window must be set to an overlay type to be shown.
    pcall(function() dlg.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY) end)
    dlg.show()
  end)
  if not ok then
    -- Fallback if AlertDialog can't be shown in this context for any reason
    Toast.makeText(ctx, "No input box available. Transcript: " .. text, Toast.LENGTH_LONG).show()
  end
end

-- ════════════════════════════════════════════════════════════════
--  DRAWABLE / LAYOUT HELPERS  (same as OCR plugin)
-- ════════════════════════════════════════════════════════════════
function rRect(fill, r, stroke, sw)
  local d = GradientDrawable()
  d.setShape(GradientDrawable.RECTANGLE)
  d.setCornerRadius(r or 20)
  d.setColor(Color.parseColor(fill))
  if stroke then d.setStroke(sw or 2, Color.parseColor(stroke)) end
  return d
end

function gradDrawable(c1, c2, r)
  local cols = {Color.parseColor(c1), Color.parseColor(c2)}
  local d = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, cols)
  d.setCornerRadius(r or 20)
  return d
end

function fLP()
  return LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT)
end

function eLP(w, mL, mR, mT, mB)
  local p = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, w or 1)
  p.setMargins(mL or 4, mT or 0, mR or 4, mB or 0)
  return p
end

function wLP(mL, mR, mT, mB)
  local p = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
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

function hRow(ctx, gravity)
  local r = LinearLayout(ctx)
  r.setOrientation(LinearLayout.HORIZONTAL)
  r.setGravity(gravity or Gravity.CENTER_VERTICAL)
  return r
end

function lbl(ctx, text, desc, sz, col)
  local t = TextView(ctx)
  t.setText(text or "")
  if desc and desc ~= text then t.setContentDescription(desc) end
  t.setTextSize(sz or 14)
  t.setTextColor(Color.parseColor(col or TEXT))
  return t
end

function sectionTitle(ctx, text)
  local t = lbl(ctx, text, nil, 10, ACCENT)
  t.setAllCaps(true)
  local lp = fLP(); lp.setMargins(0,2,0,8); t.setLayoutParams(lp)
  return t
end

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

function mkEdit(ctx, hint, desc, multi)
  local e = EditText(ctx)
  e.setHint(hint or ""); e.setContentDescription(desc or hint or "")
  e.setTextColor(Color.parseColor(TEXT))
  e.setHintTextColor(Color.parseColor(DIMTEXT))
  e.setBackground(rRect(INBG, 12, BORDER))
  e.setPadding(16,12,16,12); e.setTextSize(14)
  if multi then e.setMinLines(3); e.setMaxLines(6); e.setGravity(Gravity.TOP) end
  e.setLayoutParams(fLP())
  return e
end

function mkCard(ctx, padH, padV, fill, br, bw)
  local c = LinearLayout(ctx)
  c.setOrientation(LinearLayout.VERTICAL)
  c.setBackground(rRect(fill or CARD, 18, br or BORDER, bw or 1))
  c.setPadding(padH or 18, padV or 14, padH or 18, padV or 14)
  local lp = fLP(); lp.setMargins(0,0,0,12); c.setLayoutParams(lp)
  return c
end

function mkBadge(ctx, text, bgHex)
  local b = TextView(ctx)
  b.setText(text)
  b.setTextSize(10); b.setTextColor(Color.WHITE)
  b.setBackground(rRect(bgHex or "#27ae60", 20))
  b.setPadding(10, 3, 10, 3)
  b.setImportantForAccessibility(4)
  b.setLayoutParams(wLP(8,0,0,0))
  return b
end

-- ════════════════════════════════════════════════════════════════
--  HISTORY SCREENS
-- ════════════════════════════════════════════════════════════════
function showHistoryEntry(entry, entryIndex)
  local ctx = this
  local disp = entry.text or ""

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a2a45","#0d1828", 20))
  hCard.setPadding(18,14,18,12)
  local hLP = fLP(); hLP.setMargins(0,0,0,10); hCard.setLayoutParams(hLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx, "Entry #" .. (entryIndex or "?"),
    "History entry " .. (entryIndex or "unknown"), 17, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local backBtn = mkBtn(ctx, "Back", "Back to history list", "#1e3a5a", BORDER,
    function() showHistory() end)
  backBtn.setTextSize(12); backBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(backBtn)
  hCard.addView(titleRow)

  local dateTV = lbl(ctx, entry.date, nil, 10, DIMTEXT)
  dateTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(dateTV)
  root.addView(hCard)

  local rCard = mkCard(ctx, 14, 12)
  rCard.addView(sectionTitle(ctx, "Transcript"))
  local scroll = ScrollView(ctx)
  local rTV = lbl(ctx, disp, disp, 15, TEXT)
  rTV.setPadding(4,4,4,4); rTV.setLineSpacing(6,1.0)
  rTV.setTextIsSelectable(true)
  scroll.addView(rTV)
  local scrollLP = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 430)
  scroll.setLayoutParams(scrollLP)
  rCard.addView(scroll)
  root.addView(rCard)

  local aCard = mkCard(ctx, 14, 12)
  local copyB = mkBtn(ctx, "Copy to Clipboard", "Copy this entry to clipboard",
    "#0a3d2e", "#1a6b4a", function() copyToClipboard(disp) end)
  copyB.setTextColor(Color.parseColor("#4ade80"))
  local copyLP = fLP(); copyLP.setMargins(0,0,0,8); copyB.setLayoutParams(copyLP)
  aCard.addView(copyB)

  local dcRow = hRow(ctx)
  local delB = mkBtn(ctx, "Delete Entry", "Delete this entry", "#3a0f0f", BORDER, function()
    if entryIndex then
      deleteHistoryEntry(entryIndex)
      Toast.makeText(ctx, "Entry #" .. entryIndex .. " deleted", Toast.LENGTH_SHORT).show()
    end
    showHistory()
  end)
  delB.setTextColor(Color.parseColor("#fca5a5"))
  delB.setLayoutParams(eLP(1, 0, 4, 0, 0))
  dcRow.addView(delB)
  local closeB = mkBtn(ctx, "Close", "Close", CARD2, BORDER, function() removeOverlay() end)
  closeB.setLayoutParams(eLP(1, 4, 0, 0, 0))
  dcRow.addView(closeB)
  aCard.addView(dcRow)
  root.addView(aCard)

  showOverlay(root)
end

function showHistory()
  local ctx = this
  local entries = readHistory()

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a2d50","#0d1a30", 20))
  hCard.setPadding(18,14,18,12)
  local hLP = fLP(); hLP.setMargins(0,0,0,10); hCard.setLayoutParams(hLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx, "Transcript History  (" .. #entries .. ")",
    "Transcript history, " .. #entries .. " entries", 18, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1))
  local closeBtn = mkBtn(ctx, "Close", "Close history", "#1e3a5a", BORDER,
    function() removeOverlay() end)
  closeBtn.setTextSize(12); closeBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(closeBtn)
  hCard.addView(titleRow)
  root.addView(hCard)

  local clearB = mkBtn(ctx, "Clear All", "Delete all history", "#2a0f0f", BORDER, function()
    clearHistory()
    Toast.makeText(ctx, "History cleared", Toast.LENGTH_SHORT).show()
    showHistory()
  end)
  clearB.setTextColor(Color.parseColor("#fca5a5"))
  local clearLP = fLP(); clearLP.setMargins(0,0,0,10); clearB.setLayoutParams(clearLP)
  root.addView(clearB)

  local listScroll = ScrollView(ctx)
  local listInner = LinearLayout(ctx)
  listInner.setOrientation(LinearLayout.VERTICAL)

  if #entries == 0 then
    local emptyTV = lbl(ctx, "No transcripts yet.\nRecord something to start building history.",
      "No history entries", 14, DIMTEXT)
    emptyTV.setGravity(Gravity.CENTER); emptyTV.setPadding(20,40,20,40)
    listInner.addView(emptyTV)
  else
    for i, entry in ipairs(entries) do
      local eCard = LinearLayout(ctx)
      eCard.setOrientation(LinearLayout.VERTICAL)
      eCard.setBackground(rRect(CARD, 14, BORDER, 1))
      eCard.setPadding(14,12,14,12)
      local eLP2 = fLP(); eLP2.setMargins(0,0,0,8); eCard.setLayoutParams(eLP2)

      local eHRow = hRow(ctx, Gravity.CENTER_VERTICAL)
      local numBadge = mkBadge(ctx, "#"..i, ACCENT)
      numBadge.setLayoutParams(wLP(0,8,0,0))
      eHRow.addView(numBadge)
      local dateTV2 = lbl(ctx, entry.date, nil, 11, DIMTEXT)
      dateTV2.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1))
      eHRow.addView(dateTV2)
      local viewBtn = mkBtn(ctx, "View", "View entry " .. i, CARD2, BORDER, function()
        showHistoryEntry(entry, i)
      end)
      viewBtn.setTextSize(11); viewBtn.setLayoutParams(wLP())
      eHRow.addView(viewBtn)
      eCard.addView(eHRow)

      local preview = entry.text or ""
      if #preview > 90 then preview = preview:sub(1,90) .. "..." end
      local previewTV = lbl(ctx, preview, nil, 13, "#a0aec0")
      previewTV.setPadding(0,6,0,0); previewTV.setMaxLines(2)
      eCard.addView(previewTV)

      listInner.addView(eCard)
    end
  end

  listScroll.addView(listInner)
  local listScrollLP = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0)
  listScrollLP.weight = 1
  listScroll.setLayoutParams(listScrollLP)
  root.addView(listScroll)

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  SETTINGS SCREEN  (API key + provider cycle + model cycle)
-- ════════════════════════════════════════════════════════════════
function showSetupScreen(firstTime)
  local ctx = this
  local savedKey, savedProvider, savedModel, savedPrompt = readConfig()

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#ff"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  local outerScroll = ScrollView(ctx)
  local inner = LinearLayout(ctx)
  inner.setOrientation(LinearLayout.VERTICAL)
  outerScroll.addView(inner)
  root.addView(outerScroll)

  -- Header
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#261a42","#0f1428", 20))
  hCard.setPadding(20,16,20,14)
  local hCardLP = fLP(); hCardLP.setMargins(0,0,0,12); hCard.setLayoutParams(hCardLP)
  local ttxt = firstTime and "Voice Transcriber Setup" or "Voice Transcriber Settings"
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

  -- API key card
  local apiCard = mkCard(ctx)
  apiCard.addView(sectionTitle(ctx,"API Key"))

  local usingHardcoded = HARDCODED_API_KEY and HARDCODED_API_KEY ~= ""
  local apiInputRef = nil

  if usingHardcoded then
    local lockedTV = lbl(ctx, "  API key set in code  ", nil, 13, GREEN)
    lockedTV.setBackground(rRect("#0d2a1a", 10, "#1a6b3a"))
    lockedTV.setPadding(12, 8, 12, 8)
    apiCard.addView(lockedTV)
  else
    local apiInput = mkEdit(ctx,"Paste your API key here",
      "API key input field. Paste your provider API key here.")
    apiInput.setInputType(0x81)
    local apiLP = fLP(); apiLP.setMargins(0,0,0,8); apiInput.setLayoutParams(apiLP)
    if savedKey then apiInput.setText(savedKey) end
    apiCard.addView(apiInput)

    local keyVisible = {v = false}
    local toggleKeyB = mkBtn(ctx,"Show API Key","Toggle API key visibility",
      INBG, BORDER, function()
        keyVisible.v = not keyVisible.v
        if keyVisible.v then apiInput.setInputType(0x1)
        else apiInput.setInputType(0x81) end
      end)
    apiCard.addView(toggleKeyB)
    apiInputRef = apiInput
  end
  inner.addView(apiCard)

  -- Provider selector card (prev/next cycle, same pattern as OCR model picker)
  local provCard = mkCard(ctx)
  provCard.addView(sectionTitle(ctx,"AI Provider"))

  local provIdx = {v = 1}
  for i, p in ipairs(PROVIDERS) do
    if p == savedProvider then provIdx.v = i; break end
  end

  local provBox = LinearLayout(ctx)
  provBox.setOrientation(LinearLayout.HORIZONTAL)
  provBox.setGravity(Gravity.CENTER_VERTICAL)
  provBox.setBackground(rRect(INBG,14,BORDER))
  provBox.setPadding(14,10,14,10)
  local provBoxLP = fLP(); provBoxLP.setMargins(0,0,0,8); provBox.setLayoutParams(provBoxLP)

  local provNameTV = lbl(ctx, PROVIDERS[provIdx.v], "Selected provider "..PROVIDERS[provIdx.v], 14, TEXT)
  provNameTV.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT,1))
  local provBadge = mkBadge(ctx, PROVIDER_INFO[PROVIDERS[provIdx.v]].badge,
    PROVIDER_INFO[PROVIDERS[provIdx.v]].badgeColor)
  provBox.addView(provNameTV); provBox.addView(provBadge)
  provCard.addView(provBox)

  -- Model selector card (depends on provider)
  local modCard = mkCard(ctx)
  modCard.addView(sectionTitle(ctx,"AI Model"))

  local modIdx = {v = 1}
  local currentModelList = MODELS_BY_PROVIDER[PROVIDERS[provIdx.v]]
  for i, m in ipairs(currentModelList) do
    if m == savedModel then modIdx.v = i; break end
  end

  local modBox = LinearLayout(ctx)
  modBox.setOrientation(LinearLayout.HORIZONTAL)
  modBox.setGravity(Gravity.CENTER_VERTICAL)
  modBox.setBackground(rRect(INBG,14,BORDER))
  modBox.setPadding(14,10,14,10)
  local modBoxLP = fLP(); modBoxLP.setMargins(0,0,0,8); modBox.setLayoutParams(modBoxLP)

  local modNameTV = lbl(ctx, currentModelList[modIdx.v], "Selected model "..currentModelList[modIdx.v], 14, TEXT)
  modNameTV.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT,1))
  local modCountTV0 = lbl(ctx, modIdx.v.." / "..#currentModelList, nil, 11, DIMTEXT)
  modBox.addView(modNameTV); modBox.addView(modCountTV0)
  modCard.addView(modBox)

  local function refreshModelBox()
    local list = MODELS_BY_PROVIDER[PROVIDERS[provIdx.v]]
    modIdx.v = 1
    modNameTV.setText(list[modIdx.v])
    modNameTV.setContentDescription("Selected model "..list[modIdx.v])
    modCountTV0.setText(modIdx.v.." / "..#list)
  end

  -- Provider prev/next buttons
  local provBtnRow = hRow(ctx)
  local provPrevB = mkBtn(ctx,"  Previous","Previous provider",CARD2,BORDER,function()
    provIdx.v = provIdx.v - 1; if provIdx.v < 1 then provIdx.v = #PROVIDERS end
    local pName = PROVIDERS[provIdx.v]
    provNameTV.setText(pName); provNameTV.setContentDescription("Selected provider "..pName)
    provBadge.setText(PROVIDER_INFO[pName].badge)
    provBadge.setBackground(rRect(PROVIDER_INFO[pName].badgeColor,20))
    refreshModelBox()
  end)
  local provNextB = mkBtn(ctx,"Next  ","Next provider",CARD2,BORDER,function()
    provIdx.v = provIdx.v + 1; if provIdx.v > #PROVIDERS then provIdx.v = 1 end
    local pName = PROVIDERS[provIdx.v]
    provNameTV.setText(pName); provNameTV.setContentDescription("Selected provider "..pName)
    provBadge.setText(PROVIDER_INFO[pName].badge)
    provBadge.setBackground(rRect(PROVIDER_INFO[pName].badgeColor,20))
    refreshModelBox()
  end)
  provPrevB.setLayoutParams(eLP(1)); provNextB.setLayoutParams(eLP(1))
  provBtnRow.addView(provPrevB); provBtnRow.addView(provNextB)
  provCard.addView(provBtnRow)
  inner.addView(provCard)

  -- Model prev/next buttons
  local modBtnRow = hRow(ctx)
  local modPrevB = mkBtn(ctx,"  Previous","Previous model",CARD2,BORDER,function()
    local list = MODELS_BY_PROVIDER[PROVIDERS[provIdx.v]]
    modIdx.v = modIdx.v - 1; if modIdx.v < 1 then modIdx.v = #list end
    modNameTV.setText(list[modIdx.v]); modNameTV.setContentDescription("Selected model "..list[modIdx.v])
    modCountTV0.setText(modIdx.v.." / "..#list)
  end)
  local modNextB = mkBtn(ctx,"Next  ","Next model",CARD2,BORDER,function()
    local list = MODELS_BY_PROVIDER[PROVIDERS[provIdx.v]]
    modIdx.v = modIdx.v + 1; if modIdx.v > #list then modIdx.v = 1 end
    modNameTV.setText(list[modIdx.v]); modNameTV.setContentDescription("Selected model "..list[modIdx.v])
    modCountTV0.setText(modIdx.v.." / "..#list)
  end)
  modPrevB.setLayoutParams(eLP(1)); modNextB.setLayoutParams(eLP(1))
  modBtnRow.addView(modPrevB); modBtnRow.addView(modNextB)
  modCard.addView(modBtnRow)
  inner.addView(modCard)

  -- Custom prompt card
  local pCard = mkCard(ctx)
  pCard.addView(sectionTitle(ctx,"Custom Prompt"))
  local pInput = mkEdit(ctx, "Instruction sent with each recording",
    "Custom transcription prompt input field", true)
  local pLP = fLP(); pLP.setMargins(0,0,0,8); pInput.setLayoutParams(pLP)
  pInput.setText(savedPrompt or DEFAULT_PROMPT)
  pCard.addView(pInput)

  local pNote = lbl(ctx,
    "Note: OpenAI/Groq (Whisper) treat this as a style hint, not a full instruction, and tend to force mixed-language speech into one script. Gemini follows this instruction directly and handles code-switching (e.g. Nepali/English in the same sentence) much better.",
    nil, 10, DIMTEXT)
  pNote.setPadding(0,0,0,8)
  pCard.addView(pNote)

  local rstB = mkBtn(ctx,"Reset to Default","Reset prompt to default", INBG, BORDER, function()
    pInput.setText(DEFAULT_PROMPT)
    Toast.makeText(ctx,"Prompt reset to default",Toast.LENGTH_SHORT).show()
  end)
  rstB.setTextSize(12)
  pCard.addView(rstB)
  inner.addView(pCard)

  -- Save / Close
  local actCard = mkCard(ctx)
  local saveB = Button(ctx)
  saveB.setText("Save Settings")
  saveB.setContentDescription("Save API key, provider and model settings")
  saveB.setBackground(gradDrawable("#145a32","#0b3d22",14))
  saveB.setTextColor(Color.WHITE); saveB.setTextSize(15)
  saveB.setPadding(0,14,0,14); saveB.setAllCaps(false)
  local saveBLP = fLP(); saveBLP.setMargins(0,0,0,8); saveB.setLayoutParams(saveBLP)
  saveB.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      local key
      if usingHardcoded then
        key = HARDCODED_API_KEY
      else
        key = apiInputRef and tostring(apiInputRef.getText()):match("^%s*(.-)%s*$") or ""
        if key == "" then
          Toast.makeText(ctx,"Please enter your API key", Toast.LENGTH_LONG).show(); return
        end
      end
      local providerName = PROVIDERS[provIdx.v]
      local modelName = MODELS_BY_PROVIDER[providerName][modIdx.v]
      local promptText = tostring(pInput.getText()):match("^%s*(.-)%s*$")
      if promptText == "" then promptText = DEFAULT_PROMPT end
      writeConfig(key, providerName, modelName, promptText)
      Toast.makeText(ctx, "Saved! "..providerName.." / "..modelName, Toast.LENGTH_LONG).show()
      removeOverlay()
      showMainScreen()
    end}))
  actCard.addView(saveB)

  local closeB = mkBtn(ctx,"Close","Close settings without saving", CARD2, BORDER, function()
    local k = readConfig()
    if k then removeOverlay(); showMainScreen() else removeOverlay() end
  end)
  actCard.addView(closeB)

  local histB = mkBtn(ctx, "View Transcript History", "Open transcript history screen",
    "#0d1f38", BORDER, function() removeOverlay(); showHistory() end)
  local histLP = fLP(); histLP.setMargins(0,10,0,0); histB.setLayoutParams(histLP)
  actCard.addView(histB)

  inner.addView(actCard)

  inner.addView(sp(ctx,24))

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  MIC PERMISSION CHECK
-- ════════════════════════════════════════════════════════════════
function hasMicPermission()
  local ok, granted = pcall(function()
    -- this.checkSelfPermission is inherited from android.content.Context,
    -- so it needs no androidx import — safer for plugin hosts that only
    -- bundle core android.* classes.
    return this.checkSelfPermission("android.permission.RECORD_AUDIO")
  end)
  if not ok then return false end
  return granted == PackageManager.PERMISSION_GRANTED
end

-- ════════════════════════════════════════════════════════════════
--  RECORDING
-- ════════════════════════════════════════════════════════════════
function startRecording()
  os.execute("mkdir -p " .. SAVE_DIR)

  -- Everything that can throw natively (setAudioSource in particular)
  -- now lives INSIDE this pcall, so a Samsung-style native crash is
  -- caught here instead of propagating out and killing the caller.
  local ok, err = pcall(function()
    recorder = MediaRecorder()
    recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
    recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
    recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
    recorder.setOutputFile(AUDIO_FILE)
    recorder.prepare()
    recorder.start()
  end)

  if not ok then
    local msg = tostring(err)
    if not hasMicPermission() then
      msg = "Microphone permission is not granted. Enable it in Settings > Apps > (host app) > Permissions."
    end
    Toast.makeText(this, "Could not start recording: "..msg, Toast.LENGTH_LONG).show()
    pcall(function() if recorder then recorder.release() end end)
    recorder = nil
    return false
  end

  isRecording = true
  return true
end

function stopRecording()
  if recorder then
    pcall(function() recorder.stop(); recorder.release() end)
    recorder = nil
  end
  isRecording = false
end

-- ════════════════════════════════════════════════════════════════
--  CLEAN TRANSCRIPT  (strips common AI preamble/quote wrapping that
--  slips through despite the prompt asking for raw text only)
-- ════════════════════════════════════════════════════════════════
function cleanTranscript(t)
  if not t then return "" end
  t = t:match("^%s*(.-)%s*$")
  -- strip leading labels like "Transcript:" / "Here is the transcription:"
  t = t:gsub("^[Hh]ere%s+is%s+the%s+transcri[bp]tion?:?%s*", "")
  t = t:gsub("^[Tt]ranscri[bp]t:?%s*", "")
  -- strip a single pair of wrapping quotes if the whole thing is quoted
  if t:sub(1,1) == '"' and t:sub(-1) == '"' then t = t:sub(2, -2) end
  if t:sub(1,1) == "'" and t:sub(-1) == "'" then t = t:sub(2, -2) end
  return t:match("^%s*(.-)%s*$")
end

-- ════════════════════════════════════════════════════════════════
--  BACKGROUND TRANSCRIBE TASKS
--  NOTE: task() runs these in an isolated environment — they cannot
--  see top-level functions/locals from the rest of the script. Every
--  helper each one needs (including base64 encoding) is defined
--  inside the function itself, and all data comes in as parameters.
-- ════════════════════════════════════════════════════════════════

-- Gemini: base64 inline_data, same request pattern as OCR's doOCRTask
function doGeminiTranscribeTask(audioPath, apiKey, model, prompt)
  require "import"
  import "java.io.OutputStreamWriter"
  import "java.io.BufferedReader"
  import "java.io.InputStreamReader"
  import "java.net.URL"
  import "org.json.JSONObject"

  -- Self-contained: task() runs this in an isolated environment, so
  -- helper functions defined at the top level of the script are NOT
  -- visible here. Everything needed must be local to this function.
  local function b64encode(data)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
      local r, b = '', x:byte()
      for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
      return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
      if (#x < 6) then return '' end
      local c = 0
      for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
      return chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
  end

  local ok, res = pcall(function()
    local lf = io.open(audioPath, "rb")
    if not lf then error("Could not open audio file: " .. tostring(audioPath)) end
    local bytes = lf:read("*a"); lf:close()
    local b64 = b64encode(bytes)

    local safePrompt = (prompt or "Transcribe this audio verbatim, plain text only."):gsub('"','\\"'):gsub("\n","\\n")
    local body = string.format(
      '{"contents":[{"parts":[{"text":"%s"},{"inline_data":{"mime_type":"audio/mp4","data":"%s"}}]}]}',
      safePrompt, b64)

    local u    = URL("https://generativelanguage.googleapis.com/v1beta/models/"..model..":generateContent?key="..apiKey)
    local conn = u.openConnection()
    conn.setRequestMethod("POST")
    conn.setRequestProperty("Content-Type","application/json")
    conn.setDoOutput(true)
    conn.setConnectTimeout(20000); conn.setReadTimeout(180000)
    local w = OutputStreamWriter(conn.getOutputStream(),"UTF-8")
    w.write(body); w.flush(); w.close()
    local code = conn.getResponseCode()
    local stream = (code == 200) and conn.getInputStream() or conn.getErrorStream()
    local rd = BufferedReader(InputStreamReader(stream))
    local sb = StringBuilder(); local ln = rd.readLine()
    while ln do sb.append(ln); ln = rd.readLine() end
    rd.close()
    if code == 200 then
      return JSONObject(sb.toString())
        .getJSONArray("candidates").getJSONObject(0)
        .getJSONObject("content").getJSONArray("parts")
        .getJSONObject(0).getString("text")
    else
      error("HTTP "..code..": "..sb.toString())
    end
  end)
  if ok then return "ok", res else return "err", tostring(res) end
end

-- OpenAI / Groq: multipart/form-data upload (Whisper-style endpoint)
function doWhisperTranscribeTask(audioPath, apiKey, model, endpoint, prompt)
  require "import"
  import "java.io.DataOutputStream"
  import "java.io.BufferedReader"
  import "java.io.InputStreamReader"
  import "java.net.URL"
  import "org.json.JSONObject"

  local ok, res = pcall(function()
    local boundary = "----VoiceTranscriberBoundary" .. tostring(os.time())
    local u    = URL(endpoint)
    local conn = u.openConnection()
    conn.setRequestMethod("POST")
    conn.setRequestProperty("Authorization", "Bearer " .. apiKey)
    conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=" .. boundary)
    conn.setDoOutput(true)
    conn.setConnectTimeout(20000); conn.setReadTimeout(180000)

    local dos = DataOutputStream(conn.getOutputStream())
    local CRLF = "\r\n"

    -- model field
    dos.writeBytes("--" .. boundary .. CRLF)
    dos.writeBytes('Content-Disposition: form-data; name="model"' .. CRLF .. CRLF)
    dos.writeBytes(model .. CRLF)

    -- optional prompt field (Whisper treats this as a style/vocabulary
    -- hint, not a full instruction — API limitation, not ours)
    if prompt and prompt ~= "" then
      dos.writeBytes("--" .. boundary .. CRLF)
      dos.writeBytes('Content-Disposition: form-data; name="prompt"' .. CRLF .. CRLF)
      dos.writeBytes(prompt .. CRLF)
    end

    -- audio file field
    dos.writeBytes("--" .. boundary .. CRLF)
    dos.writeBytes('Content-Disposition: form-data; name="file"; filename="record.m4a"' .. CRLF)
    dos.writeBytes("Content-Type: audio/mp4" .. CRLF .. CRLF)
    local lf = io.open(audioPath, "rb")
    if not lf then error("Could not open audio file: " .. tostring(audioPath)) end
    local bytes = lf:read("*a"); lf:close()
    dos.writeBytes(bytes)
    dos.writeBytes(CRLF)

    dos.writeBytes("--" .. boundary .. "--" .. CRLF)
    dos.flush(); dos.close()

    local code = conn.getResponseCode()
    local stream = (code == 200) and conn.getInputStream() or conn.getErrorStream()
    local rd = BufferedReader(InputStreamReader(stream))
    local sb = StringBuilder(); local ln = rd.readLine()
    while ln do sb.append(ln); ln = rd.readLine() end
    rd.close()
    if code == 200 then
      return JSONObject(sb.toString()).getString("text")
    else
      error("HTTP "..code..": "..sb.toString())
    end
  end)
  if ok then return "ok", res else return "err", tostring(res) end
end

-- ════════════════════════════════════════════════════════════════
--  MAIN RECORDER SCREEN
-- ════════════════════════════════════════════════════════════════
function showMainScreen()
  local ctx = this
  local apiKey, provider, model, prompt = readConfig()
  if HARDCODED_API_KEY and HARDCODED_API_KEY ~= "" then apiKey = HARDCODED_API_KEY end

  local root = LinearLayout(ctx)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setBackgroundColor(Color.parseColor("#f2"..BG:sub(2)))
  root.setPadding(14, 46, 14, 14)

  -- Header
  local hCard = LinearLayout(ctx)
  hCard.setOrientation(LinearLayout.VERTICAL)
  hCard.setBackground(gradDrawable("#1a3558","#0f1f38", 20))
  hCard.setPadding(18,14,18,12)
  local hCardLP = fLP(); hCardLP.setMargins(0,0,0,10); hCard.setLayoutParams(hCardLP)

  local titleRow = hRow(ctx, Gravity.CENTER_VERTICAL)
  local titleTV = lbl(ctx, "Voice Transcriber", "Voice Transcriber screen", 19, TEXT)
  titleTV.setLayoutParams(LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT,1))
  local histBtn = mkBtn(ctx,"History","Open transcript history","#1a2a40",BORDER,
    function() removeOverlay(); showHistory() end)
  histBtn.setTextSize(12); histBtn.setLayoutParams(wLP(0,6,0,0))
  local settingsBtn = mkBtn(ctx,"Settings","Open settings","#1e3a5a",BORDER,
    function() removeOverlay(); showSetupScreen(false) end)
  settingsBtn.setTextSize(12); settingsBtn.setLayoutParams(wLP())
  titleRow.addView(titleTV); titleRow.addView(histBtn); titleRow.addView(settingsBtn)
  hCard.addView(titleRow)

  local statusTV = lbl(ctx, "Ready · "..(provider or "").." / "..(model or ""), nil, 11, DIMTEXT)
  statusTV.setGravity(Gravity.CENTER_HORIZONTAL)
  hCard.addView(statusTV)
  root.addView(hCard)

  -- Record card
  local recCard = mkCard(ctx, 14, 18)
  local recordBtn = Button(ctx)
  recordBtn.setText("● Record")
  recordBtn.setContentDescription("Start voice recording")
  recordBtn.setBackground(gradDrawable("#8b1a2a","#4a0d14",50))
  recordBtn.setTextColor(Color.WHITE); recordBtn.setTextSize(16)
  recordBtn.setPadding(0,18,0,18); recordBtn.setAllCaps(false)
  recCard.addView(recordBtn)
  root.addView(recCard)

  -- Cancel row
  local cancelBtn = mkBtn(ctx, "Cancel", "Cancel and close", CARD2, BORDER, function()
    if isRecording then stopRecording() end
    removeOverlay()
  end)
  root.addView(cancelBtn)

  -- The overlay is closed immediately when Stop is pressed (see below),
  -- BEFORE the network call even starts. By the time the transcription
  -- result comes back, the target app has had the whole network round
  -- trip to naturally regain "active window" status on its own, so we
  -- query the focused field fresh here instead of relying on any
  -- earlier capture.
  local function onTranscribeDone(status, data)
    if status == "ok" then
      local text = cleanTranscript(data)

      local ok, dateStr = pcall(function() return os.date("%Y-%m-%d %H:%M") end)
      saveHistory(text, ok and dateStr or "Unknown date")

      local node, source = captureFocusedNode()
      local pasted = pasteIntoNode(node, source, text)

      if pasted then
        Toast.makeText(ctx, "Pasted into input box", Toast.LENGTH_SHORT).show()
        return
      else
        showNoInputDialog(text)
      end
    else
      local err = tostring(data)
        :gsub("com%.luajava%.LuaException:%s*","")
        :gsub("Runtime error%s*%.?%s*","")
      Toast.makeText(ctx, "Transcription failed: "..err, Toast.LENGTH_LONG).show()
    end
  end

  recordBtn.setOnClickListener(luajava.createProxy(
    "android.view.View$OnClickListener", { onClick = function()
      if not apiKey or apiKey == "" then
        Toast.makeText(ctx, "Please set up your API key first", Toast.LENGTH_LONG).show()
        removeOverlay(); showSetupScreen(true)
        return
      end
      if not isRecording then
        if startRecording() then
          recordBtn.setText("■ Stop")
          recordBtn.setContentDescription("Stop voice recording")
          statusTV.setText("Recording...")
        end
      else
        stopRecording()
        -- Close our overlay right away so the target app can become the
        -- "active" window again well before the network call finishes.
        removeOverlay()
        Toast.makeText(ctx, "Transcribing...", Toast.LENGTH_SHORT).show()
        if provider == "Gemini" then
          task(doGeminiTranscribeTask, AUDIO_FILE, apiKey, model, prompt, onTranscribeDone)
        elseif provider == "OpenAI" then
          task(doWhisperTranscribeTask, AUDIO_FILE, apiKey, model,
            "https://api.openai.com/v1/audio/transcriptions", prompt, onTranscribeDone)
        elseif provider == "Groq" then
          task(doWhisperTranscribeTask, AUDIO_FILE, apiKey, model,
            "https://api.groq.com/openai/v1/audio/transcriptions", prompt, onTranscribeDone)
        end
      end
    end}))

  showOverlay(root)
end

-- ════════════════════════════════════════════════════════════════
--  ENTRY POINT
-- ════════════════════════════════════════════════════════════════
function startTranscriber()
  local apiKey = readConfig()
  if HARDCODED_API_KEY and HARDCODED_API_KEY ~= "" then apiKey = HARDCODED_API_KEY end
  if not apiKey or apiKey == "" then
    showSetupScreen(true)
  else
    showMainScreen()
  end
end

-- Capture happens fresh in onTranscribeDone after the overlay is
-- closed on Stop, not here — see showMainScreen for details.
task(500, function() startTranscriber() end)