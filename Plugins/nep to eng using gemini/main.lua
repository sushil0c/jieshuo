require "import"
import "android.speech.RecognizerIntent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "com.androlua.*"
import "android.net.Uri"
import "android.content.Intent"
import "java.util.Locale"

local spokenText = ""
local attempt = 0
local maxRetries = 3

-- Replace with your actual Gemini API key
local GEMINI_API_KEY = ""

-- Function to decode common HTML entities
function htmlDecode(str)
    str = str:gsub("&#39;", "'")
    str = str:gsub("&amp;", "&")
    str = str:gsub("&quot;", '"')
    str = str:gsub("&lt;", "<")
    str = str:gsub("&gt;", ">")
    return str
end

-- Save recognized words
function saveWords(words)
    spokenText = words
end

-- Function to start listening with error handling and retries
function startListening()
    local verbalizationDetected = false

    local recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ne-np")  -- Nepali recognition
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, this.getPackageName())

    local speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

    local speechListener = RecognitionListener{
        onResults = function(results)
            local data = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if data ~= nil and data.size() > 0 then
                verbalizationDetected = true
                local recognizedText = data.get(0)
                saveWords(recognizedText)
                
                this.speak("You said: " .. recognizedText)  -- Confirm speech

                local node = service.getEditText()
                translateText(recognizedText, node)
            end
            if not verbalizationDetected then retryListening() end
        end,
        onError = function()
            retryListening()
        end
    }

    speechRecognizer.setRecognitionListener(speechListener)
    speechRecognizer.startListening(recognizerIntent)
end

-- Function to retry listening in case of failure
function retryListening()
    attempt = attempt + 1
    if attempt <= maxRetries then
        this.speak("Retrying...")
        startListening()
    else
        this.speak("Failed to recognize speech after multiple attempts.")
    end
end

-- Function to translate text using Gemini API
function translateText(wordsToTranslate, node)
    local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" .. GEMINI_API_KEY
    
    -- Create the request body for Gemini API
    local requestBody = {
        contents = {
            {
                parts = {
                    {
                        text = "Translate the following text from Nepali to English. Only provide the translation without any additional text or explanation: " .. wordsToTranslate
                    }
                }
            }
        }
    }
    
    -- Convert Lua table to JSON string (basic implementation)
    local function tableToJson(t)
        local json = "{"
        json = json .. '"contents":[{"parts":[{"text":"' .. requestBody.contents[1].parts[1].text:gsub('"', '\\"') .. '"}]}]'
        json = json .. "}"
        return json
    end
    
    local jsonBody = tableToJson(requestBody)
    
    -- Set headers for the request
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#jsonBody)
    }
    
    Http.post(url, jsonBody, headers, function(status, result)
        if status == 200 then
            -- Parse the Gemini API response
            local translatedText = parseGeminiResponse(result)
            if translatedText and translatedText ~= "" then
                service.insertText(node, translatedText .. " ")
                this.speak(translatedText)
            else
                service.insertText(node, "[Translation Error] ")
                this.speak("Translation failed to parse response.")
            end
        else
            service.insertText(node, "[Translation Error] ")
            this.speak("Translation failed with status: " .. tostring(status))
        end
    end)
end

-- Function to parse Gemini API response
function parseGeminiResponse(jsonResponse)
    -- Basic JSON parsing for Gemini response
    -- Look for the text content in the response
    local textPattern = '"text"%s*:%s*"([^"]*)"'
    local translatedText = jsonResponse:match(textPattern)
    
    if translatedText then
        -- Decode escaped characters
        translatedText = translatedText:gsub("\\n", "\n")
        translatedText = translatedText:gsub("\\\"", '"')
        translatedText = translatedText:gsub("\\\\", "\\")
        translatedText = htmlDecode(translatedText)
        
        -- Clean up the translation (remove any extra formatting)
        translatedText = translatedText:gsub("^%s*", ""):gsub("%s*$", "")
        
        return translatedText
    end
    
    return nil
end

startListening()
return true