require "import"import "android.widget.*"
import "android.app.*"
import "android.os.*"
import "android.view.*"
import "android.view.accessibility.AccessibilityEvent"
import "android.content.*"
import "android.graphics.*"
import "android.graphics.drawable.GradientDrawable"
import "android.net.Uri"
import "java.net.URL"
import "java.io.*"
import "java.lang.Thread"
import "java.lang.Runnable"
API_HOST         = "https://downloader.sushil0.com.np"
API_ENDPOINT     = API_HOST .. "/api/all-in-one-downloader-api"
DEFAULT_API_KEY  = "drishti_live_90abcb9adf47f100b1c670de8582ce42"
PREFS_NAME       = "drishti_downloader_prefs"
PREFS_KEY_APIKEY = "api_key"
PREFS_KEY_HIST   = "download_history"

FIELD_SEP = string.char(30) -- record-separator, safe inside titles
ENTRY_SEP = "\n"

COLOR_BG        = "#121212"
COLOR_CARD      = "#1E1E1E"
COLOR_CARD_BRD  = "#2E2A20"
COLOR_PRIMARY   = "#D4AF37"  -- gold accent
COLOR_PRIMARY_D = "#0A0A0A"  -- near-black bars
COLOR_TEXT      = "#F1F1F1"
COLOR_MUTED     = "#9E9E9E"
COLOR_ERROR     = "#EF5350"
COLOR_OK        = "#66BB6A"
COLOR_ON_GOLD   = "#1A1A1A"  -- dark text used on top of the gold accent

availableMedias = {}
lastTitle = nil
activeDownloadRow = nil

function toast(m)
    Toast.makeText(activity, m, Toast.LENGTH_SHORT).show()
end

function announce(text)
    activity.runOnUiThread(function()
        local decor = activity.getWindow().getDecorView()
        local am = decor.getContext().getSystemService(Context.ACCESSIBILITY_SERVICE)
        if am and am.isEnabled() then
            local event = AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
            event.getText().add(text)
            decor.sendAccessibilityEventUnchecked(event)
        end
    end)
end

function setAccessible(view, description)
    view.setContentDescription(description)
    view.setFocusable(true)
    view.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES)
end

function roundedDrawable(colorHex, radiusDp, strokeHex, strokeWidthDp)
    local d = GradientDrawable()
    d.setShape(GradientDrawable.RECTANGLE)
    d.setColor(Color.parseColor(colorHex))
    d.setCornerRadius(radiusDp * activity.getResources().getDisplayMetrics().density)
    if strokeHex then
        d.setStroke(math.floor(strokeWidthDp * activity.getResources().getDisplayMetrics().density), Color.parseColor(strokeHex))
    end
    return d
end

function dp(v)
    return math.floor(v * activity.getResources().getDisplayMetrics().density)
end

function topRoundedDrawable(colorHex, radiusDp)
    local d = GradientDrawable()
    d.setShape(GradientDrawable.RECTANGLE)
    d.setColor(Color.parseColor(colorHex))
    local r = radiusDp * activity.getResources().getDisplayMetrics().density
    d.setCornerRadii({ r, r, r, r, 0, 0, 0, 0 })
    return d
end

function pillDrawable(colorHex)
    local d = GradientDrawable()
    d.setShape(GradientDrawable.RECTANGLE)
    d.setColor(Color.parseColor(colorHex))
    d.setCornerRadius(999 * activity.getResources().getDisplayMetrics().density)
    return d
end

function jsonGet(json, key)
    if not json then return nil end
    local pattern = '"' .. key .. '"%s*:%s*"(.-)"'
    local value = json:match(pattern)
    if value then
        value = value:gsub('\\/', '/'):gsub('\\"', '"')
        return value
    end
    pattern = '"' .. key .. '"%s*:%s*([%-%w%.]+)'
    return json:match(pattern)
end

function parseMedias(json)
    local list = {}
    if not json then return list end
    local mediasBlock = json:match('"medias"%s*:%s*%[(.-)%]')
    if not mediasBlock then return list end

    for obj in mediasBlock:gmatch('%{(.-)%}') do
        local mUrl = obj:match('"url"%s*:%s*"(.-)"')
        local quality = obj:match('"quality"%s*:%s*"(.-)"')
        local ext = obj:match('"extension"%s*:%s*"(.-)"')
        local size = obj:match('"size"%s*:%s*"(.-)"')
        local mType = obj:match('"type"%s*:%s*"(.-)"')
        if mUrl then
            mUrl = mUrl:gsub('\\/', '/'):gsub('\\"', '"')
            table.insert(list, {
                url = mUrl,
                quality = quality or "Standard",
                extension = ext or "mp4",
                size = size or "",
                type = mType or "video"
            })
        end
    end
    return list
end

function httpPostJson(url, headers, bodyStr)
    local conn = URL(url).openConnection()
    conn.setRequestMethod("POST")
    conn.setDoOutput(true)
    conn.setConnectTimeout(15000)
    conn.setReadTimeout(30000)
    for k, v in pairs(headers) do
        conn.setRequestProperty(k, v)
    end
    local outStream = conn.getOutputStream()
    local writer = OutputStreamWriter(outStream, "UTF-8")
    writer.write(bodyStr)
    writer.flush()
    writer.close()

    local code = conn.getResponseCode()
    local stream
    if code >= 200 and code < 300 then
        stream = conn.getInputStream()
    else
        stream = conn.getErrorStream()
    end

    local reader = BufferedReader(InputStreamReader(stream, "UTF-8"))
    local sb = StringBuilder()
    local line = reader.readLine()
    while line ~= nil do
        sb.append(line)
        line = reader.readLine()
    end
    reader.close()
    conn.disconnect()
    return code, sb.toString()
end

function checkStreamContentType(url, apiKey)
    local ok, result = pcall(function()
        local conn = URL(url).openConnection()
        conn.setRequestMethod("HEAD")
        conn.setConnectTimeout(10000)
        conn.setReadTimeout(15000)
        if apiKey and apiKey ~= "" then
            conn.setRequestProperty("x-api-key", apiKey)
        end
        local code = conn.getResponseCode()
        local ctype = conn.getContentType()
        conn.disconnect()
        return { code = code, contentType = ctype }
    end)
    if not ok then
        -- Some servers reject HEAD entirely; treat as "unknown" rather
        -- than blocking the download outright.
        return { code = -1, contentType = nil }
    end
    return result
end

function isLikelyMediaType(contentType)
    if not contentType then return true end -- unknown: don't block
    contentType = contentType:lower()
    if contentType:find("text/html") or contentType:find("application/json") then
        return false
    end
    return true
end

function queryDownloadStatus(downloadId)
    local result = { status = "unknown", percent = 0, bytesDownloaded = 0, totalBytes = -1 }
    local targetId = tonumber(downloadId)
    if not targetId then return result end

    local ok = pcall(function()
        local dm = activity.getSystemService(Context.DOWNLOAD_SERVICE)
        local cursor = dm.query(DownloadManager.Query())
        local idIdx = cursor.getColumnIndex(DownloadManager.COLUMN_ID)
        local statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
        local downloadedIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
        local totalIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
        local found = false

        while cursor.moveToNext() do
            local rowId = cursor.getLong(idIdx)
            if rowId == targetId then
                found = true
                local statusCode = cursor.getInt(statusIdx)
                local downloaded = cursor.getLong(downloadedIdx)
                local total = cursor.getLong(totalIdx)
                result.bytesDownloaded = downloaded
                result.totalBytes = total
                if total and total > 0 then
                    result.percent = math.floor((downloaded / total) * 100)
                end
                if statusCode == DownloadManager.STATUS_SUCCESSFUL then
                    result.status = "success"
                    result.percent = 100
                elseif statusCode == DownloadManager.STATUS_FAILED then
                    result.status = "failed"
                elseif statusCode == DownloadManager.STATUS_RUNNING then
                    result.status = "running"
                elseif statusCode == DownloadManager.STATUS_PAUSED then
                    result.status = "paused"
                elseif statusCode == DownloadManager.STATUS_PENDING then
                    result.status = "pending"
                end
                break
            end
        end
        cursor.close()
        if not found then
            result.status = "missing" -- e.g. cleared from Downloads app, or history from a prior install
        end
    end)
    if not ok then
        result.status = "unknown"
    end
    return result
end

function statusLabelFor(live)
    if live.status == "success" then return "Completed"
    elseif live.status == "failed" then return "Failed"
    elseif live.status == "running" then return "Downloading..."
    elseif live.status == "paused" then return "Paused"
    elseif live.status == "pending" then return "Queued"
    elseif live.status == "missing" then return "File removed"
    else return "Status unknown"
    end
end

function statusColorFor(status)
    if status == "success" then return COLOR_OK
    elseif status == "failed" then return COLOR_ERROR
    elseif status == "running" or status == "pending" or status == "paused" then return COLOR_PRIMARY
    else return COLOR_MUTED
    end
end

function isActiveStatus(status)
    return status == "running" or status == "pending" or status == "paused"
end

function makeProgressBar(percent)
    local p = math.max(0, math.min(100, percent))
    local track = LinearLayout(activity)
    track.setOrientation(LinearLayout.HORIZONTAL)
    track.setBackground(roundedDrawable(COLOR_CARD_BRD, 5))
    local trackLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(8))
    trackLp.setMargins(0, dp(6), 0, dp(4))
    track.setLayoutParams(trackLp)

    local filled = View(activity)
    filled.setBackground(roundedDrawable(COLOR_PRIMARY, 5))
    track.addView(filled, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, math.max(p, 1)))

    if p < 100 then
        local empty = View(activity)
        track.addView(empty, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 100 - p))
    end

    return track
end

function runInBackground(fn)
    local ok, err = pcall(function()
        local runnable = luajava.createProxy("java.lang.Runnable", { run = fn })
        local t = Thread(runnable)
        t.start()
    end)
    if not ok then
        -- Fallback: if this runtime doesn't support luajava.createProxy,
        -- run inline rather than crash -- UI will block, but the
        -- request still completes instead of failing outright.
        fn()
    end
end

function saveApiKey(key)
    local prefs = activity.getSharedPreferences(PREFS_NAME, 0)
    local editor = prefs.edit()
    editor.putString(PREFS_KEY_APIKEY, key)
    editor.commit()
end

function loadApiKey()
    local prefs = activity.getSharedPreferences(PREFS_NAME, 0)
    return prefs.getString(PREFS_KEY_APIKEY, DEFAULT_API_KEY)
end

function openApiSite()
    local intent = Intent(Intent.ACTION_VIEW)
    intent.setData(Uri.parse(API_HOST))
    activity.startActivity(intent)
end

function loadHistory()
    local prefs = activity.getSharedPreferences(PREFS_NAME, 0)
    local raw = prefs.getString(PREFS_KEY_HIST, "")
    local list = {}
    if raw == "" then return list end
    for line in tostring(raw):gmatch("[^\n]+") do
        local parts = {}
        for p in line:gmatch("([^" .. FIELD_SEP .. "]*)" .. FIELD_SEP .. "?") do
            table.insert(parts, p)
        end
        if #parts >= 5 then
            table.insert(list, {
                title = parts[1],
                quality = parts[2],
                extension = parts[3],
                downloadId = parts[4],
                timestamp = parts[5]
            })
        end
    end
    return list
end

function saveHistoryList(list)
    local lines = {}
    for _, e in ipairs(list) do
        table.insert(lines, table.concat({
            e.title, e.quality, e.extension, e.downloadId, e.timestamp
        }, FIELD_SEP))
    end
    local prefs = activity.getSharedPreferences(PREFS_NAME, 0)
    local editor = prefs.edit()
    editor.putString(PREFS_KEY_HIST, table.concat(lines, ENTRY_SEP))
    editor.commit()
end

function addHistoryEntry(title, quality, extension, downloadId)
    local list = loadHistory()
    table.insert(list, 1, {
        title = title,
        quality = quality,
        extension = extension,
        downloadId = tostring(downloadId),
        timestamp = os.date("%Y-%m-%d %H:%M")
    })
    -- cap history size
    while #list > 50 do table.remove(list) end
    saveHistoryList(list)
end

function clearHistory()
    saveHistoryList({})
end

activity.title = "DRISHTI Downloader"

rootLayout = LinearLayout(activity)
rootLayout.setOrientation(LinearLayout.VERTICAL)
rootLayout.setBackgroundColor(Color.parseColor(COLOR_BG))

screensContainer = FrameLayout(activity)

navBar = LinearLayout(activity)
navBar.setOrientation(LinearLayout.HORIZONTAL)
navBar.setBackground(topRoundedDrawable(COLOR_PRIMARY_D, 16))
navBar.setPadding(dp(8), dp(10), dp(8), dp(10))
local ok, err = pcall(function() navBar.setElevation(dp(12)) end)

-- Screens fill all remaining space; the nav bar sits fixed at the bottom.
rootLayout.addView(screensContainer, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1))
rootLayout.addView(navBar, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
activity.setContentView(rootLayout)

navButtons = {}

function makeNavButton(label)
    local wrap = LinearLayout(activity)
    wrap.setOrientation(LinearLayout.VERTICAL)
    wrap.setGravity(Gravity.CENTER)
    wrap.setPadding(dp(4), dp(4), dp(4), dp(4))

    local tv = TextView(activity)
    tv.setText(label)
    tv.setTextSize(13)
    tv.setGravity(Gravity.CENTER)
    tv.setTextColor(Color.parseColor(COLOR_MUTED))
    tv.setPadding(dp(18), dp(8), dp(18), dp(8))
    wrap.addView(tv)

    setAccessible(wrap, label .. " tab")
    local lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
    navBar.addView(wrap, lp)
    navButtons[label] = { wrap = wrap, label = tv }
    return wrap
end

function showScreen(name)
    for key, screen in pairs(screens) do
        screen.setVisibility(key == name and View.VISIBLE or View.GONE)
    end
    for key, nav in pairs(navButtons) do
        if key == name then
            nav.label.setTextColor(Color.parseColor(COLOR_ON_GOLD))
            nav.label.setBackground(pillDrawable(COLOR_PRIMARY))
        else
            nav.label.setTextColor(Color.parseColor(COLOR_MUTED))
            nav.label.setBackground(nil)
        end
    end
    announce(name .. " tab")
end

navDownloadBtn = makeNavButton("Download")
navHistoryBtn = makeNavButton("History")
navSettingsBtn = makeNavButton("Settings")

-- ------------------------------------------------------------
-- Card factory used across all three tabs
-- ------------------------------------------------------------
function makeCard()
    local card = LinearLayout(activity)
    card.setOrientation(LinearLayout.VERTICAL)
    card.setBackground(roundedDrawable(COLOR_CARD, 12, COLOR_CARD_BRD, 1))
    card.setPadding(dp(14), dp(12), dp(14), dp(12))
    local ok2, err2 = pcall(function() card.setElevation(dp(3)) end)
    local lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    lp.setMargins(dp(12), dp(8), dp(12), dp(8))
    card.setLayoutParams(lp)
    return card
end

function styledButton(text, primary)
    local b = Button(activity)
    b.setText(text)
    b.setAllCaps(false)
    if primary then
        b.setTextColor(Color.parseColor(COLOR_ON_GOLD))
        b.setBackground(roundedDrawable(COLOR_PRIMARY, 8))
    else
        b.setTextColor(Color.parseColor(COLOR_TEXT))
        b.setBackground(roundedDrawable(COLOR_CARD, 8, COLOR_CARD_BRD, 1))
    end
    return b
end

-- ============================================================
-- TAB 1: Download
-- ============================================================
downloadRoot = ScrollView(activity)

downloadInner = LinearLayout(activity)
downloadInner.setOrientation(LinearLayout.VERTICAL)
downloadInner.setPadding(dp(4), dp(16), dp(4), dp(24))
downloadRoot.addView(downloadInner)

local function dLabel(text, container)
    local tv = TextView(activity)
    tv.setText(text)
    tv.setTextSize(14)
    tv.setTextColor(Color.parseColor(COLOR_MUTED))
    tv.setPadding(dp(16), dp(6), dp(16), dp(4))
    setAccessible(tv, text)
    container.addView(tv)
    return tv
end

dLabel("Paste a link from YouTube, Instagram, TikTok, Facebook, Twitter, Pinterest, SoundCloud and more", downloadInner)

urlInput = EditText(activity)
urlInput.setHint("Media URL")
urlInput.setSingleLine(true)
urlInput.setTextColor(Color.parseColor(COLOR_TEXT))
urlInput.setHintTextColor(Color.parseColor(COLOR_MUTED))
urlInput.setBackground(roundedDrawable(COLOR_CARD, 8, COLOR_CARD_BRD, 1))
urlInput.setPadding(dp(14), dp(12), dp(14), dp(12))
setAccessible(urlInput, "Media URL input field. Paste the link you want to download.")
local urlLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
urlLp.setMargins(dp(16), dp(4), dp(16), dp(10))
downloadInner.addView(urlInput, urlLp)

fetchBtn = styledButton("Get download options", true)
setAccessible(fetchBtn, "Get download options button. Fetches available media streams for the pasted URL.")
local fetchLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
fetchLp.setMargins(dp(16), dp(4), dp(16), dp(10))
downloadInner.addView(fetchBtn, fetchLp)

statusText = TextView(activity)
statusText.setText("Ready.")
statusText.setTextColor(Color.parseColor(COLOR_MUTED))
statusText.setPadding(dp(16), dp(6), dp(16), dp(6))
setAccessible(statusText, "Status. Ready.")
downloadInner.addView(statusText)

resultsContainer = LinearLayout(activity)
resultsContainer.setOrientation(LinearLayout.VERTICAL)
downloadInner.addView(resultsContainer)

function setStatus(text, isError)
    statusText.setText(text)
    statusText.setTextColor(Color.parseColor(isError and COLOR_ERROR or COLOR_MUTED))
    statusText.setContentDescription(text)
    announce(text)
end

function clearResults()
    resultsContainer.removeAllViews()
end

function renderMediaCard(m, title)
    local card = makeCard()

    local qualityLine = TextView(activity)
    qualityLine.setText(string.upper(m.type) .. " \u2022 " .. m.quality)
    qualityLine.setTextSize(15)
    qualityLine.setTextColor(Color.parseColor(COLOR_TEXT))
    card.addView(qualityLine)

    local sizeLine = TextView(activity)
    sizeLine.setText((m.size ~= "" and m.size or "size unknown") .. " \u2022 ." .. m.extension)
    sizeLine.setTextSize(13)
    sizeLine.setTextColor(Color.parseColor(COLOR_MUTED))
    sizeLine.setPadding(0, dp(2), 0, dp(8))
    card.addView(sizeLine)

    local rowBtn = styledButton("Download", true)
    setAccessible(rowBtn, "Download " .. m.quality .. " " .. m.type .. " for " .. title)
    card.addView(rowBtn)

    rowBtn.onClick = function()
        startDownload(m, title, rowBtn)
    end

    resultsContainer.addView(card)
end

function startDownload(m, title, rowBtn)
    local apiKey = tostring(keyInput.getText())
    rowBtn.setEnabled(false)
    rowBtn.setText("Checking stream...")
    setStatus("Verifying stream before download...")

    runInBackground(function()
        local check = checkStreamContentType(m.url, apiKey)

        activity.runOnUiThread(function()
            if check.code ~= -1 and not isLikelyMediaType(check.contentType) then
                rowBtn.setEnabled(true)
                rowBtn.setText("Download")
                setStatus("Server returned an error page instead of the media file. Try again later or check your API status.", true)
                toast("Stream check failed: server did not return media data.")
                return
            end

            rowBtn.setText("Queuing...")

            local safeName = tostring(title):gsub('[\\/:%*%?"<>|]', "_")
            local fileName = safeName .. "_" .. m.quality:gsub("%s+", "_") .. "_" .. os.time() .. "." .. m.extension

            local uri = Uri.parse(m.url)
            local request = DownloadManager.Request(uri)
            request.setTitle(fileName)
            request.setDescription("Downloading via DRISHTI Downloader")
            request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI | DownloadManager.Request.NETWORK_MOBILE)
            request.setAllowedOverRoaming(true)
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            request.addRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
            if apiKey and apiKey ~= "" then
                request.addRequestHeader("x-api-key", apiKey)
            end

            local dm = activity.getSystemService(Context.DOWNLOAD_SERVICE)
            local ok, idOrErr = pcall(function() return dm.enqueue(request) end)

            rowBtn.setEnabled(true)
            rowBtn.setText("Download")

            if ok then
                addHistoryEntry(title, m.quality, m.extension, idOrErr)
                refreshHistoryUI()
                startPolling()
                setStatus("Download started: " .. fileName)
                toast("Download started in background.")
            else
                setStatus("Failed to queue download: " .. tostring(idOrErr), true)
            end
        end)
    end)
end

fetchBtn.onClick = function()
    local mediaUrl = tostring(urlInput.getText())
    local apiKey = tostring(keyInput.getText())

    if mediaUrl == "" then
        setStatus("Please paste a media URL first.", true)
        return
    end
    if apiKey == "" then
        setStatus("Please enter an API key in Settings.", true)
        return
    end

    clearResults()
    setStatus("Fetching media options, please wait...")
    fetchBtn.setEnabled(false)

    runInBackground(function()
        local headers = { ["x-api-key"] = apiKey, ["Content-Type"] = "application/json" }
        local escapedUrl = mediaUrl:gsub('"', '\\"')
        local payload = '{"url":"' .. escapedUrl .. '"}'

        local ok, code, body = pcall(httpPostJson, API_ENDPOINT, headers, payload)

        activity.runOnUiThread(function()
            fetchBtn.setEnabled(true)

            if not ok then
                setStatus("Network error: " .. tostring(code), true)
                return
            end
            if code ~= 200 then
                local errMsg = jsonGet(body, "message") or jsonGet(body, "error") or ("HTTP " .. tostring(code))
                setStatus("Request failed: " .. tostring(errMsg), true)
                return
            end

            local title = jsonGet(body, "title") or jsonGet(body, "caption") or "media_file"
            availableMedias = parseMedias(body)

            if #availableMedias == 0 then
                setStatus("No download streams found. Check the URL and try again.", true)
                return
            end

            lastTitle = title
            for _, m in ipairs(availableMedias) do
                renderMediaCard(m, title)
            end
            setStatus("Found " .. tostring(#availableMedias) .. " formats for " .. title)
        end)
    end)
end

-- ============================================================
-- TAB 2: History
-- ============================================================
historyRoot = ScrollView(activity)

historyInner = LinearLayout(activity)
historyInner.setOrientation(LinearLayout.VERTICAL)
historyInner.setPadding(dp(4), dp(16), dp(4), dp(24))
historyRoot.addView(historyInner)

refreshBtn = styledButton("Refresh", false)
setAccessible(refreshBtn, "Refresh download status button.")
local refreshLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
refreshLp.setMargins(dp(16), dp(0), dp(16), dp(6))
historyInner.addView(refreshBtn, refreshLp)
refreshBtn.onClick = function()
    refreshHistoryUI()
    startPolling()
end

historyEmptyLabel = TextView(activity)
historyEmptyLabel.setText("No downloads yet.")
historyEmptyLabel.setTextColor(Color.parseColor(COLOR_MUTED))
historyEmptyLabel.setPadding(dp(16), dp(20), dp(16), dp(10))
historyInner.addView(historyEmptyLabel)

historyListContainer = LinearLayout(activity)
historyListContainer.setOrientation(LinearLayout.VERTICAL)
historyInner.addView(historyListContainer)

function openHistoryFile(entry)
    local ok, err = pcall(function()
        local dm = activity.getSystemService(Context.DOWNLOAD_SERVICE)
        local id = tonumber(entry.downloadId)
        local uri = dm.getUriForDownloadedFile(id)
        if not uri then
            toast("File not found (it may have been deleted).")
            return
        end
        local intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, dm.getMimeTypeForDownloadedFile(id))
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    end)
    if not ok then
        toast("Could not open file: " .. tostring(err))
    end
end

-- anyActiveDownloads is read by the polling loop to decide whether
-- to keep rescheduling itself.
anyActiveDownloads = false

function refreshHistoryUI()
    historyListContainer.removeAllViews()
    local list = loadHistory()
    anyActiveDownloads = false

    if #list == 0 then
        historyEmptyLabel.setVisibility(View.VISIBLE)
        return
    end
    historyEmptyLabel.setVisibility(View.GONE)

    for _, entry in ipairs(list) do
        local live = queryDownloadStatus(entry.downloadId)
        if isActiveStatus(live.status) then
            anyActiveDownloads = true
        end

        local card = makeCard()

        local titleLine = TextView(activity)
        titleLine.setText(entry.title)
        titleLine.setTextSize(15)
        titleLine.setTextColor(Color.parseColor(COLOR_TEXT))
        card.addView(titleLine)

        local metaLine = TextView(activity)
        metaLine.setText(entry.quality .. " \u2022 " .. entry.timestamp)
        metaLine.setTextSize(12)
        metaLine.setTextColor(Color.parseColor(COLOR_MUTED))
        metaLine.setPadding(0, dp(2), 0, dp(4))
        card.addView(metaLine)

        local statusLine = TextView(activity)
        local statusText = statusLabelFor(live)
        if live.status == "running" and live.totalBytes and live.totalBytes > 0 then
            statusText = statusText .. " " .. tostring(live.percent) .. "%"
        end
        statusLine.setText(statusText)
        statusLine.setTextSize(13)
        statusLine.setTextColor(Color.parseColor(statusColorFor(live.status)))
        card.addView(statusLine)
        setAccessible(card, entry.title .. ". " .. statusText)

        if isActiveStatus(live.status) and live.totalBytes and live.totalBytes > 0 then
            card.addView(makeProgressBar(live.percent))
        end

        local openBtn = styledButton("Open", false)
        openBtn.setEnabled(live.status == "success")
        setAccessible(openBtn, "Open downloaded file: " .. entry.title)
        local openLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        openLp.setMargins(0, dp(8), 0, 0)
        card.addView(openBtn, openLp)
        openBtn.onClick = function() openHistoryFile(entry) end

        historyListContainer.addView(card)
    end
end

-- ------------------------------------------------------------
-- Polling loop: while any download is pending/running/paused,
-- re-check DownloadManager roughly every 1.2s and rebuild the
-- History cards so progress bars and status labels stay live.
-- Stops itself automatically once nothing is active; startDownload
-- restarts it whenever a new download is queued.
-- ------------------------------------------------------------
pollHandler = Handler()
pollingActive = false

function pollTick()
    refreshHistoryUI()
    if anyActiveDownloads then
        pollHandler.postDelayed(pollRunnable, 1200)
    else
        pollingActive = false
    end
end

pollRunnable = luajava.createProxy("java.lang.Runnable", { run = pollTick })

function startPolling()
    if pollingActive then return end
    pollingActive = true
    pollTick()
end

-- ============================================================
-- TAB 3: Settings
-- ============================================================
settingsRoot = ScrollView(activity)

settingsInner = LinearLayout(activity)
settingsInner.setOrientation(LinearLayout.VERTICAL)
settingsInner.setPadding(dp(4), dp(16), dp(4), dp(24))
settingsRoot.addView(settingsInner)

local function sLabel(text)
    local tv = TextView(activity)
    tv.setText(text)
    tv.setTextSize(14)
    tv.setTextColor(Color.parseColor(COLOR_MUTED))
    tv.setPadding(dp(16), dp(10), dp(16), dp(4))
    setAccessible(tv, text)
    settingsInner.addView(tv)
end

sLabel("Your DRISHTI API key")
keyInput = EditText(activity)
keyInput.setText(loadApiKey())
keyInput.setSingleLine(true)
keyInput.setTextColor(Color.parseColor(COLOR_TEXT))
keyInput.setHintTextColor(Color.parseColor(COLOR_MUTED))
keyInput.setBackground(roundedDrawable(COLOR_CARD, 8, COLOR_CARD_BRD, 1))
keyInput.setPadding(dp(14), dp(12), dp(14), dp(12))
setAccessible(keyInput, "API key input field. Paste your own DRISHTI API key here, or keep the default trial key.")
local keyLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
keyLp.setMargins(dp(16), dp(4), dp(16), dp(10))
settingsInner.addView(keyInput, keyLp)

saveKeyBtn = styledButton("Save API key", true)
setAccessible(saveKeyBtn, "Save API key button. Stores this key on the device so it is remembered next time.")
local sBtnLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
sBtnLp.setMargins(dp(16), dp(4), dp(16), dp(10))
settingsInner.addView(saveKeyBtn, sBtnLp)

getKeyBtn = styledButton("Get API key / Buy credit", false)
setAccessible(getKeyBtn, "Get API key or buy credit button. Opens the DRISHTI developer site in your browser.")
settingsInner.addView(getKeyBtn, sBtnLp)

clearHistBtn = styledButton("Clear download history", false)
setAccessible(clearHistBtn, "Clear download history button. Removes all saved history entries from this device.")
settingsInner.addView(clearHistBtn, sBtnLp)

saveKeyBtn.onClick = function()
    local key = tostring(keyInput.getText())
    if key == "" then
        toast("Enter a key first.")
        return
    end
    saveApiKey(key)
    setStatus("API key saved.")
    toast("API key saved.")
end

getKeyBtn.onClick = function() openApiSite() end

clearHistBtn.onClick = function()
    local builder = AlertDialog.Builder(activity)
    builder.setTitle("Clear history?")
    builder.setMessage("This removes the download history list on this device. Already downloaded files are not deleted.")
    builder.setPositiveButton("Clear", function()
        clearHistory()
        refreshHistoryUI()
        toast("History cleared.")
    end)
    builder.setNegativeButton("Cancel", nil)
    builder.show()
end

-- ============================================================
-- Wire screens together
-- ============================================================
screensContainer.addView(downloadRoot, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
screensContainer.addView(historyRoot, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
screensContainer.addView(settingsRoot, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))

screens = {
    Download = downloadRoot,
    History = historyRoot,
    Settings = settingsRoot
}

navDownloadBtn.onClick = function() showScreen("Download") end
navHistoryBtn.onClick = function() showScreen("History") end
navSettingsBtn.onClick = function() showScreen("Settings") end

showScreen("Download")
refreshHistoryUI()
startPolling() -- resume tracking any downloads still in-flight from a previous session

-- ------------------------------------------------------------
-- Back button handling
-- ------------------------------------------------------------
function onKeyDown(keyCode, event)
    if keyCode == 4 then
        activity.finish()
        return true
    end
    return false
end

announce("DRISHTI Downloader ready. Three tabs are available: Download, History and Settings. Paste a media link on the Download tab and press Get download options.")