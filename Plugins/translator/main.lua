require "import"
import "com.androlua.*"
import "android.net.Uri"
import "android.text.Html"
import "org.json.*"

local translationResult = ""

local textToTranslate = this.getText(node)

-- Your Gemini API key (replace with your actual API key)
local GEMINI_API_KEY = ""

-- Always translate to Nepali
local sourceLanguage = "Auto-detect"
local targetLanguage = "Nepali"

-- Show translation dialog
service.speak("Translation started. Converting text to Nepali...")

-- Function to preserve and restore special characters
function preserveSpecialChars(text)
    local placeholders = {}
    local counter = 0
    
    -- Replace special characters with placeholders
    local processedText = text:gsub("([%.%,%!%?%;%:%(%)\"%'%-%—%–%[%]%{%}%$%@%#%&%*%+%=%<%= >%/%\\%|%~%`%^]+)", function(match)
        counter = counter + 1
        local placeholder = "SPECIALCHAR" .. counter .. "PLACEHOLDER"
        placeholders[placeholder] = match
        return " " .. placeholder .. " "
    end)
    
    return processedText, placeholders
end

function restoreSpecialChars(text, placeholders)
    for placeholder, original in pairs(placeholders) do
        text = text:gsub(placeholder, original)
    end
    return text
end

-- Function to split text into chunks while preserving sentence boundaries
function splitIntoChunks(text, maxLength)
    local chunks = {}
    local length = #text
    local startIndex = 1

    while startIndex <= length do
        local endIndex = startIndex + maxLength - 1
        
        -- If we're not at the end, try to break at sentence or word boundary
        if endIndex < length then
            local lastPeriod = text:sub(startIndex, endIndex):find("[%.%!%?]%s+[^%s]", -50)
            local lastSpace = text:sub(startIndex, endIndex):find("%s+", -100)
            
            if lastPeriod then
                endIndex = startIndex + lastPeriod - 1
            elseif lastSpace then
                endIndex = startIndex + lastSpace - 1
            end
        else
            endIndex = length
        end
        
        local chunk = text:sub(startIndex, endIndex)
        table.insert(chunks, chunk)
        startIndex = endIndex + 1
    end

    return chunks
end

-- Maximum character limit per request
local maxChunkSize = 3500  -- Reduced to leave room for special char processing

-- Preserve special characters before chunking
local processedText, placeholders = preserveSpecialChars(textToTranslate)
local chunks = splitIntoChunks(processedText, maxChunkSize)

-- Function to create translation prompt with enhanced instructions
function createTranslationPrompt(text, fromLang, toLang)
    return string.format([[
You are a professional translator. Translate the following text to Nepali (नेपाली) language 
direct give output do not include your text

Text to translate to Nepali:
%s
]], text)
end

function showTranslationDialog(title, message)
    local success = pcall(function()
        -- Import required Android widget classes
        local AlertDialogBuilder = luajava.bindClass("android.app.AlertDialog$Builder")
        local TextView = luajava.bindClass("android.widget.TextView")
        local ScrollView = luajava.bindClass("android.widget.ScrollView")

local context = service
        if this and this.getContext then
            context = this.getContext()
        end

        local builder = luajava.new(AlertDialogBuilder, context)
        builder:setTitle(title)

        local scrollView = luajava.new(ScrollView, context)
        local textView = luajava.new(TextView, context)
        textView:setText(message)
        textView:setTextSize(16)
        textView:setPadding(20, 20, 20, 20)
        textView:setTextIsSelectable(true) -- Allow text selection
        scrollView:addView(textView)

        builder:setView(scrollView)

        builder:setNegativeButton("Close", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
            onClick = function(dialog, which)
                dialog:dismiss()
            end
        }))

        local dialog = builder:create()
        dialog:show()

        return true
    end)

    if not success then
        -- Fallback to simple output methods
        showSimpleOutput(title, message)
    end
end

-- Function to show toast message
function showToast(message)
    pcall(function()
        local Toast = luajava.bindClass("android.widget.Toast")
        local context = service
        if this and this.getContext then
            context = this.getContext()
        end
        
        local toast = Toast:makeText(context, message, Toast.LENGTH_LONG)
        toast:show()
    end)
end

-- Simple output function as fallback
function showSimpleOutput(title, message)
    -- Show toast notification
    showToast("Translation completed!")
    
    -- Speak the title and result
    service.speak(title)
    service.speak(message)
    
    -- Try to log the result for debugging
    if print then
        print("TRANSLATION RESULT:")
        print(message)
    end
end

-- Function to process chunks sequentially
function processChunks(index)
    if index > #chunks then
        -- All chunks processed; restore special characters and show result
        local finalResult = restoreSpecialChars(translationResult, placeholders)
        -- Clean up extra spaces
        finalResult = finalResult:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
        
        -- Show result in dialog box using android.widget components
        showTranslationDialog("नेपाली अनुवाद पूर्ण भयो | Nepali Translation Complete", finalResult)
        
        service.speak("Translation completed!")
        return
    end

    -- Show progress dialog
    service.speak("Translating part " .. index .. " of " .. #chunks .. "...")

    local chunk = chunks[index]
    local prompt = createTranslationPrompt(chunk, sourceLanguage, targetLanguage)
    
    -- Gemini API endpoint
    local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" .. GEMINI_API_KEY
    
    -- Request body for Gemini API with enhanced settings for better Hindi-Nepali translation
    local jsonBody = string.format([[{
        "contents": [{
            "parts": [{
                "text": %s
            }]
        }],
        "generationConfig": {
            "temperature": 0.1,
            "topK": 10,
            "topP": 0.9,
            "maxOutputTokens": 4096
        },
        "safetySettings": [
            {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_NONE"
            }
        ],
        "systemInstruction": {
            "parts": [{
                "text": "You are an expert Hindi-Nepali-English translator. Always translate to proper Nepali language using Devanagari script. Never mix Hindi and Nepali. Use authentic Nepali vocabulary and grammar."
            }]
        }
    }]], string.format("%q", prompt))
    
    -- Set headers
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    Http.post(url, jsonBody, headers, function(status, result)
        if status == 200 then
            local translation = nil
            
            -- Try JSON parsing first
            local success, response = pcall(function()
                local jsonResponse = JSONObject(result)
                local candidates = jsonResponse:getJSONArray("candidates")
                local candidate = candidates:getJSONObject(0)
                local content = candidate:getJSONObject("content")
                local parts = content:getJSONArray("parts")
                local part = parts:getJSONObject(0)
                return part:getString("text")
            end)
            
            if success and response then
                translation = response
            else
                -- Fallback to string parsing
                translation = result:match('"text"%s*:%s*"([^"]*)"')
            end
            
            if translation then
                -- Clean and process translation
                translation = translation:gsub("\\n", "\n"):gsub("\\\"", "\"")
                -- Remove any leading/trailing whitespace but preserve internal formatting
                translation = translation:gsub("^%s*(.-)%s*$", "%1")
                translationResult = translationResult .. translation
                
                -- Add space between chunks if needed
                if index < #chunks then
                    translationResult = translationResult .. " "
                end
                
                -- Show progress
                service.speak("Part " .. index .. " translated to Nepali successfully")
            else
                service.speak("Error: Could not extract translation from response for part " .. index)
                return
            end
        else
            service.speak("Network error for part " .. index .. ". Status code: " .. status .. ". Please check internet connection.")
            return
        end

        -- Process the next chunk
        processChunks(index + 1)
    end)
end

-- Start processing chunks
service.speak("Preparing text for translation...")
processChunks(1)