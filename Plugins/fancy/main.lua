require "import"
import "android.speech.tts.TextToSpeech"
import "android.view.accessibility.AccessibilityNodeInfo"
import "android.content.Context"
import "java.text.Normalizer"
import "android.content.ClipData"

local context = this
local tts = TextToSpeech(context, nil)

-- Clean Unicode stylish text
local function cleanText(text)
  if not text then return "" end
  local normalized = Normalizer.normalize(text, Normalizer.Form.NFKD)
  normalized = normalized:gsub("[^\32-\126]", "")
  return normalized
end

-- Find focused node
local function findFocusedNode(node)
  if not node then return nil end

  if node.isAccessibilityFocused() or node.isFocused() then
    return node
  end

  for i = 0, node.getChildCount() - 1 do
    local child = node.getChild(i)
    local result = findFocusedNode(child)
    if result then return result end
  end
end

local root = this.getRootInActiveWindow()
local focusedNode = findFocusedNode(root)

if focusedNode then
  local selectedText = this.getText(focusedNode)

  if selectedText and tostring(selectedText) ~= "" then
    local cleaned = cleanText(tostring(selectedText))

    -- Speak using CRS voice
    this.speak(cleaned)

    -- Copy to clipboard
    local clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE)
    local clip = ClipData.newPlainText("Cleaned Text", cleaned)
    clipboard.setPrimaryClip(clip)
  else
    this.speak("Focused item has no text")
  end
else
  this.speak("No focused item found")
end