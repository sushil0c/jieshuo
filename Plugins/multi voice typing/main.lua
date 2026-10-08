require "import"
import "android.widget.*"
import "com.androlua.*"

layout = {
    GridView,
    id = "grid",
    numColumns = 4,
    layout_width = "fill",
    layout_height = "fill"
}

items = {"arabic", "bengali", "chinese", "french", "english", "hindi", "nepali", "portuguese", "russian", "spanish"}

dlg = LuaDialog(this)
dlg.View = loadlayout(layout)

grid.adapter = SingleLineAdapter(service, String(items))

dlg.setTitle("Multi voice typing")
dlg.setMessage("Welcome!")
dlg.setButton("cancel", nil)
dlg.setButton2("more info", function()
    LuaDialog(this).setTitle("नमस्कार!").setMessage([[
    यो एक्सटेन्सन सुशील चौधरीद्वारा डिजाइन गरिएको हो।
    यसको मद्दतले तपाईं नेपालीबाट विभिन्न भाषामा सजिलै टाइप गर्न सक्नुहुन्छ।
    यस एक्सटेन्सनले तपाईंलाई आवाजको माध्यमबाट छिटो र सही टाइपिङ गर्न सक्षम बनाउँछ।
    यस एक्सटेन्सनका बारेमा थप जानकारी र नयाँ अपडेटहरू पाउन मलाई फेसबुकमा फलो गर्नुहोस् https://www.facebook.com/sushil.connect1?mibextid=ZbWKwL।
    ]]).setButton("CANCEL", nil).show()
end)

dlg.show()

grid.onItemClick = function(l, v)
    dlg.dismiss()
    task(500, function()
if v.text=="nepali"
-- Import necessary modules for Android speech recognition and text manipulation
require "import"
import "android.widget.Toast"
import "android.content.Context"
import "android.content.Intent"
import "java.util.Locale"

import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.speech.RecognizerIntent"

local substitutionTable = {
    ["chino"] = "Jieshuo"
}

function capitalizeFirstWord(text)
    local firstChar = text:sub(1, 1)
    local restOfString = text:sub(2)
    return firstChar:upper() .. restOfString
end

function substituteWords(text)
    for word, substitution in pairs(substitutionTable) do
        text = text:gsub("%f[%a]" .. word .. "%f[%A]", substitution)
    end
    return text
end

function capitalizeAfterPeriod(text)
    return text:gsub("(%.[%s]*%a)", function(match)
        local char = match:sub(-1)
        local capitalizedChar = char:upper()
        return match:sub(1, -2) .. capitalizedChar
    end)
end

function lowercaseAfterComma(text)
    return text:gsub("(%,[%s]*%a)", function(match)
        local char = match:sub(-1)
        local lowercaseChar = char:lower()
        return match:sub(1, -2) .. lowercaseChar
    end)
end

function addPunctuation(text)
    local lastChar = text:sub(-1)
    local punctuation = { "।", "!", "?" }
    local hasPunctuation = false

    for _, p in ipairs(punctuation) do
        if lastChar == p then
            hasPunctuation = true
            break
        end
    end

    if not hasPunctuation then
        text = text .. "।"
    end

    return text
end

function hasInternetConnection()
    local connectivityManager = this.getSystemService(Context.CONNECTIVITY_SERVICE)
    local networkInfo = connectivityManager.getActiveNetworkInfo()
    return networkInfo ~= nil and networkInfo.isConnected()
end

function kill()
    if speechRecognizer ~= nil then
        speechRecognizer.destroy()
        speechRecognizer = nil
    end
    return true
end

function startListening()
    if not hasInternetConnection() then
        service.asyncSpeak("No internet connection. Voice recognition is not available.")
        return false
    end

    local verbalizationDetected = false
    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
    speechListener = RecognitionListener{
        onResults = function(results)
            data = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if data ~= nil and data.size() > 0 then
                verbalizationDetected = true
                local recognizedText = data.get(0)
                recognizedText = capitalizeFirstWord(recognizedText)
                recognizedText = substituteWords(recognizedText)
                recognizedText = capitalizeAfterPeriod(recognizedText)
                recognizedText = lowercaseAfterComma(recognizedText)
                recognizedText = addPunctuation(recognizedText)

                service.getEditText()
                local node = service.getEditText()
                service.insertText(node, recognizedText .. " ")
                service.speak(recognizedText)
            end

            if not verbalizationDetected then
                kill()
                return false
            end
        end,
        onError = function()
            kill()
            return false
        end
    }

    recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ne-np")
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, this.getPackageName())
    speechRecognizer.setRecognitionListener(speechListener)
    speechRecognizer.startListening(recognizerIntent)

    return true
end

startListening()
return true
elseif v.text=="english"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=en"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="hindi"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=hi"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="urdu"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=ur"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="russian"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=ru"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="portuguese"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=pt"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="bengali"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=bn"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="arabic"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=ar"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="french"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=fr"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="spanish"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=es"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
elseif v.text=="chinese"
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

-- Function to translate text to English
function translateText(wordsToTranslate, node)
    local defaultLanguage = Locale.getDefault().getLanguage()
    local url = "https://translate.google.com/m?sl=auto&hl=" .. defaultLanguage .. "&q=" .. Uri.encode(wordsToTranslate)
    url = url .. "&tl=gh"  -- Fixed target language: English

    Http.get(url, function(status, result)
        if status == 200 then
            local translatedWords = result:match('<div class="result%-container">([^<]+)</div>')
            if translatedWords then
                translatedWords = htmlDecode(translatedWords)
                service.insertText(node, translatedWords .. " ")
                this.speak(translatedWords)
            else
                service.insertText(node, "[Translation Error] ")
            end
        else
            this.speak("Translation failed.")
        end
    end)
end

startListening()
return true
end
    end)
end