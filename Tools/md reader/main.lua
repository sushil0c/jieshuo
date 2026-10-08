--[[
    Markdown Reader for AndroLua+
    --------------------------------
    A simple Android app that lets the user pick a .md file from storage,
    converts the Markdown to HTML using lightweight Lua pattern matching,
    and renders it in a WebView.

    Tested against the typical AndroLua+ API (activity, LinearLayout,
    Button, WebView, Toast, etc.). Copy this file onto the device and
    open it with AndroLua+ (or compile it with the AndroLua+ IDE).
]]
require "import"
import "android.widget.*"
import "android.view.*"
import "android.webkit.WebView"
import "android.webkit.WebViewClient"
import "android.graphics.Color"

-- Note: no `require "android"` here — Talkman's Lua runtime already
-- exposes `activity`, `import`, and `luajava` as globals; that module
-- only exists in AndroLua+ proper and isn't needed (or present) here.

-- ============================================================
-- 1. Basic UI layout
-- ============================================================

activity.setTitle("Markdown Reader")

local root = LinearLayout(activity);
root.setOrientation(luajava.int(1)) -- 1 = VERTICAL
root.setBackgroundColor(Color.WHITE)

local MATCH_PARENT = luajava.int(-1)
local WRAP_CONTENT = luajava.int(-2)

-- Row with a path field + Open button. We use a plain text path instead
-- of a system file-picker Intent, because that requires overriding
-- onActivityResult, which this Lua runtime does not allow assigning to
-- (it is a real compiled Java method, not an overridable Lua field).
local inputRow = LinearLayout(activity)
inputRow.setOrientation(luajava.int(1)) -- vertical: field above, button below
inputRow.setPadding(luajava.int(10),luajava.int(10),luajava.int(10),luajava.int(10))

local pathInput = EditText(activity)
pathInput.setHint("/sdcard/yourfile.md")
pathInput.setText("/sdcard/README.md")

local btnOpen = Button(activity)
btnOpen.setText("Open")

inputRow.addView(pathInput, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
inputRow.addView(btnOpen, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))

local statusLabel = TextView(activity)
statusLabel.setText("No file loaded")
statusLabel.setTextColor(Color.GRAY)
statusLabel.setPadding(luajava.int(10),luajava.int(0),luajava.int(10),luajava.int(10))

local webview = WebView(activity)
webview.getSettings().setDefaultFontSize(luajava.int(16))
webview.getSettings().setBuiltInZoomControls(true)
webview.setWebViewClient(WebViewClient())

root.addView(inputRow, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
root.addView(statusLabel, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
root.addView(webview, LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

activity.setContentView(root)

-- ============================================================
-- 2. Markdown -> HTML converter (lightweight, no external libs)
-- ============================================================

local function escapeHtml(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

-- inline-level replacements: bold, italic, inline code, links, images
local function inline(line)
    -- images: ![alt](url)
    line = line:gsub("!%[([^%]]*)%]%(([^%)]+)%)", '<img src="%2" alt="%1" style="max-width:100%%;"/>')
    -- links: [text](url)
    line = line:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<a href="%2">%1</a>')
    -- bold: **text** or __text__
    line = line:gsub("%*%*(.-)%*%*", "<b>%1</b>")
    line = line:gsub("__(.-)__", "<b>%1</b>")
    -- italic: *text* or _text_
    line = line:gsub("%*(.-)%*", "<i>%1</i>")
    line = line:gsub("_(.-)_", "<i>%1</i>")
    -- inline code: `code`
    line = line:gsub("`(.-)`", "<code>%1</code>")
    return line
end

local function markdownToHtml(md)
    local html = {}
    local inCodeBlock = false
    local inList = false
    local inOrderedList = false

    local function closeLists()
        if inList then html[#html+1] = "</ul>"; inList = false end
        if inOrderedList then html[#html+1] = "</ol>"; inOrderedList = false end
    end

    for line in (md.."\n"):gmatch("(.-)\n") do
        -- fenced code blocks ```
        if line:match("^```") then
            if inCodeBlock then
                html[#html+1] = "</pre>"
                inCodeBlock = false
            else
                closeLists()
                html[#html+1] = "<pre>"
                inCodeBlock = true
            end
            goto continue
        end

        if inCodeBlock then
            html[#html+1] = escapeHtml(line)
            goto continue
        end

        -- blank line
        if line:match("^%s*$") then
            closeLists()
            goto continue
        end

        -- headers
        local hashes, rest = line:match("^(#+)%s+(.*)$")
        if hashes then
            closeLists()
            local level = math.min(#hashes, 6)
            html[#html+1] = string.format("<h%d>%s</h%d>", level, inline(rest), level)
            goto continue
        end

        -- horizontal rule
        if line:match("^%-%-%-+%s*$") or line:match("^%*%*%*+%s*$") then
            closeLists()
            html[#html+1] = "<hr/>"
            goto continue
        end

        -- blockquote
        local quote = line:match("^>%s?(.*)$")
        if quote then
            closeLists()
            html[#html+1] = "<blockquote>"..inline(quote).."</blockquote>"
            goto continue
        end

        -- unordered list
        local item = line:match("^[%-%*%+]%s+(.*)$")
        if item then
            if inOrderedList then html[#html+1] = "</ol>"; inOrderedList = false end
            if not inList then html[#html+1] = "<ul>"; inList = true end
            html[#html+1] = "<li>"..inline(item).."</li>"
            goto continue
        end

        -- ordered list
        local numItem = line:match("^%d+%.%s+(.*)$")
        if numItem then
            if inList then html[#html+1] = "</ul>"; inList = false end
            if not inOrderedList then html[#html+1] = "<ol>"; inOrderedList = true end
            html[#html+1] = "<li>"..inline(numItem).."</li>"
            goto continue
        end

        -- plain paragraph
        closeLists()
        html[#html+1] = "<p>"..inline(line).."</p>"

        ::continue::
    end
    closeLists()
    if inCodeBlock then html[#html+1] = "</pre>" end

    local css = [[
        <style>
            body{font-family:sans-serif; padding:14px; line-height:1.5; color:#222;}
            h1,h2,h3,h4,h5,h6{color:#111; margin-top:1.1em;}
            code{background:#f2f2f2; padding:2px 5px; border-radius:4px; font-family:monospace;}
            pre{background:#f2f2f2; padding:10px; border-radius:6px; overflow-x:auto;}
            blockquote{border-left:4px solid #ccc; margin:8px 0; padding:4px 12px; color:#555;}
            a{color:#1a73e8;}
            hr{border:none; border-top:1px solid #ddd; margin:16px 0;}
            img{display:block; margin:8px 0;}
        </style>
    ]]

    return "<html><head><meta charset='utf-8'>"..css.."</head><body>"..table.concat(html, "\n").."</body></html>"
end

-- ============================================================
-- 3. File loading
-- ============================================================

local function loadMarkdownFile(path)
    local f = io.open(path, "r")
    if not f then
        activity.runOnUiThread(function()
            statusLabel.setText("Could not open: "..path)
            toast("Could not open: "..path)
        end)
        return
    end
    local content = f:read("*a")
    f:close()

    local html = markdownToHtml(content)
    activity.runOnUiThread(function()
        statusLabel.setText("Loaded: "..path)
        webview.loadDataWithBaseURL(nil, html, "text/html", "utf-8", nil)
    end)
end

btnOpen.onClick = function()
    local path = pathInput.getText().toString()
    if path == nil or path == "" then
        toast("Enter a file path first")
        return
    end
    loadMarkdownFile(path)
end

-- ============================================================
-- 4. Optional: load a default README.md on start if present
-- ============================================================

local defaultPath = "/sdcard/README.md"
local f = io.open(defaultPath, "r")
if f then
    f:close()
    loadMarkdownFile(defaultPath)
else
    webview.loadDataWithBaseURL(nil,
        "<html><body style='font-family:sans-serif;padding:20px;color:#666;'>"..
        "<h2>Markdown Reader</h2><p>Type a file path above and tap <b>Open</b>.</p></body></html>",
        "text/html", "utf-8", nil)
end