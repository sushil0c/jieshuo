require "import"
import "android.widget.Toast"
import "android.content.Context"
import "android.content.Intent"
import "java.util.Locale"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.speech.RecognizerIntent"
import "android.speech.tts.TextToSpeech"
import "android.os.Bundle"
import "android.os.Handler"
import "android.media.AudioManager"
import "java.util.ArrayList"

-- Enhanced substitution table with more words and corrections
local substitutionTable = { 
    ["chino"] = "Jieshuo",
    ["google"] = "Google",
    ["facebook"] = "Facebook",
    ["whatsapp"] = "WhatsApp",
    ["youtube"] = "YouTube",
    ["instagram"] = "Instagram",
    ["twitter"] = "Twitter",
    ["linkedin"] = "LinkedIn",
    ["microsoft"] = "Microsoft",
    ["apple"] = "Apple",
    ["android"] = "Android",
    ["iphone"] = "iPhone",
    ["samsung"] = "Samsung"
}

-- Language settings
local currentLanguage = "ne-np"  -- Nepali only

-- Recognition settings
local recognitionTimeout = 10000  -- 10 seconds
local partialResultsEnabled = true
local continuousListening = false
local voiceCommandsEnabled = true

-- Statistics tracking
local recognitionStats = {
    totalRecognitions = 0,
    successfulRecognitions = 0,
    errors = 0,
    averageConfidence = 0
}

-- Devanagari to Roman transliteration
function devanagariToRoman(text)
    -- Vowels (independent)
    local vowels = {
        ["अ"] = "a", ["आ"] = "aa", ["इ"] = "i", ["ई"] = "ee", ["उ"] = "u", ["ऊ"] = "oo",
        ["ऋ"] = "ri", ["ए"] = "e", ["ऐ"] = "ai", ["ओ"] = "o", ["औ"] = "au",
        ["अं"] = "am", ["अः"] = "ah", ["ँ"] = "n"
    }
    
    -- Consonants (with inherent 'a')
    local consonants = {
        ["क"] = "ka", ["ख"] = "kha", ["ग"] = "ga", ["घ"] = "gha", ["ङ"] = "nga",
        ["च"] = "cha", ["छ"] = "chha", ["ज"] = "ja", ["झ"] = "jha", ["ञ"] = "nya",
        ["ट"] = "ta", ["ठ"] = "tha", ["ड"] = "da", ["ढ"] = "dha", ["ण"] = "na",
        ["त"] = "ta", ["थ"] = "tha", ["द"] = "da", ["ध"] = "dha", ["न"] = "na",
        ["प"] = "pa", ["फ"] = "pha", ["ब"] = "ba", ["भ"] = "bha", ["म"] = "ma",
        ["य"] = "ya", ["र"] = "ra", ["ल"] = "la", ["व"] = "wa", ["ब"] = "ba",
        ["श"] = "sha", ["ष"] = "sha", ["स"] = "sa", ["ह"] = "ha",
        ["क्ष"] = "ksha", ["त्र"] = "tra", ["ज्ञ"] = "gya"
    }
    
    -- Vowel signs (matra) - these modify consonants
    local matras = {
        ["ा"] = "aa", ["ि"] = "i", ["ी"] = "ee", ["ु"] = "u", ["ू"] = "oo",
        ["ृ"] = "ri", ["े"] = "e", ["ै"] = "ai", ["ो"] = "o", ["ौ"] = "au",
        ["ं"] = "m", ["ः"] = "h", ["्"] = "", ["ँ"] = "n"
    }
    
    -- Numbers
    local numbers = {
        ["०"] = "0", ["१"] = "1", ["२"] = "2", ["३"] = "3", ["४"] = "4",
        ["५"] = "5", ["६"] = "6", ["७"] = "7", ["८"] = "8", ["९"] = "9"
    }
    
    -- Punctuation
    local punctuation = {
        ["।"] = ".", ["॥"] = "..", ["?"] = "?", ["!"] = "!"
    }
    
    local result = ""
    local i = 1
    local textLen = 0
    
    -- Calculate actual text length (UTF-8 aware)
    for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        textLen = textLen + 1
    end
    
    -- Convert to table for easier character access
    local chars = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, char)
    end
    
    local idx = 1
    while idx <= #chars do
        local char = chars[idx]
        local nextChar = chars[idx + 1] or ""
        local twoChar = char .. nextChar
        local threeChar = twoChar .. (chars[idx + 2] or "")
        
        local matched = false
        
        -- Check for three-character combinations
        if consonants[threeChar] then
            result = result .. consonants[threeChar]
            idx = idx + 3
            matched = true
        -- Check for two-character combinations
        elseif consonants[twoChar] then
            result = result .. consonants[twoChar]
            idx = idx + 2
            matched = true
        -- Check for vowels
        elseif vowels[char] then
            result = result .. vowels[char]
            idx = idx + 1
            matched = true
        -- Check for consonants
        elseif consonants[char] then
            local romanChar = consonants[char]
            
            -- Check if next character is a matra
            if matras[nextChar] then
                -- Remove inherent 'a' and add matra
                if matras[nextChar] == "" then
                    -- Halant - just remove the 'a'
                    romanChar = romanChar:sub(1, -2)
                else
                    -- Replace 'a' with the matra sound
                    romanChar = romanChar:sub(1, -2) .. matras[nextChar]
                end
                idx = idx + 2
            else
                idx = idx + 1
            end
            result = result .. romanChar
            matched = true
        -- Check for numbers
        elseif numbers[char] then
            result = result .. numbers[char]
            idx = idx + 1
            matched = true
        -- Check for punctuation
        elseif punctuation[char] then
            result = result .. punctuation[char]
            idx = idx + 1
            matched = true
        -- Keep spaces and other characters
        elseif char == " " or char == "\n" or char == "\t" then
            result = result .. char
            idx = idx + 1
            matched = true
        else
            -- Skip unknown characters (don't add them)
            idx = idx + 1
            matched = true
        end
    end
    
    -- Clean up double spaces
    result = result:gsub("  +", " ")
    
    return result
end

-- Text processing functions
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
    local punctuation = { ".", "!", "?" }
    local hasPunctuation = false
    for _, p in ipairs(punctuation) do
        if lastChar == p then
            hasPunctuation = true
            break
        end
    end
    if not hasPunctuation then
        text = text .. "."
    end
    return text
end

-- Enhanced filler word removal for Nepali (Roman script)
function removeFillerWords(text)
    local fillerWords = {
        "umm", "aah", "oh", "hmm", "er", "ani", "tyo", "yo", "ke bhanne",
        "um", "uh", "ah", "like", "you know", "kasto", "matlab"
    }
    for _, filler in ipairs(fillerWords) do
        text = text:gsub("%f[%a]" .. filler .. "%f[%A]", "")
    end
    return text:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")  -- Clean extra spaces
end

function autoCorrectCommonMistakes(text)
    local corrections = {
        ["teh"] = "the",
        ["adn"] = "and",
        ["recieve"] = "receive",
        ["definately"] = "definitely",
        ["seperate"] = "separate",
        ["occured"] = "occurred",
        ["neccessary"] = "necessary"
    }
    for mistake, correction in pairs(corrections) do
        text = text:gsub("%f[%a]" .. mistake .. "%f[%A]", correction)
    end
    return text
end

function hasInternetConnection()
    local connectivityManager = this.getSystemService(Context.CONNECTIVITY_SERVICE)
    local networkInfo = connectivityManager.getActiveNetworkInfo()
    return networkInfo ~= nil and networkInfo.isConnected()
end

-- Enhanced TTS with Nepali support
local tts = nil
local ttsSpeed = 1.0
local ttsPitch = 1.0

function initTTS()
    tts = TextToSpeech(this, TextToSpeech.OnInitListener{
        onInit = function(status)
            if status == TextToSpeech.SUCCESS then
                -- Try Nepali first
                local result = tts.setLanguage(Locale("ne", "NP"))
                if result == TextToSpeech.LANG_MISSING_DATA or result == TextToSpeech.LANG_NOT_SUPPORTED then
                    -- Try English as fallback
                    result = tts.setLanguage(Locale.ENGLISH)
                    if result == TextToSpeech.LANG_MISSING_DATA or result == TextToSpeech.LANG_NOT_SUPPORTED then
                        Toast.makeText(this, "TTS language not supported", Toast.LENGTH_SHORT).show()
                    else
                        Toast.makeText(this, "TTS initialized with English fallback", Toast.LENGTH_SHORT).show()
                    end
                else
                    Toast.makeText(this, "Nepali TTS initialized successfully", Toast.LENGTH_SHORT).show()
                end
                
                -- Set speech rate and pitch
                tts.setSpeechRate(ttsSpeed)
                tts.setPitch(ttsPitch)
            else
                Toast.makeText(this, "TTS Initialization Failed", Toast.LENGTH_SHORT).show()
            end
        end
    })
end

-- Enhanced TTS functions
function speakText(text, priority)
    if tts ~= nil then
        local queueMode = priority and TextToSpeech.QUEUE_FLUSH or TextToSpeech.QUEUE_ADD
        tts.speak(text, queueMode, nil, nil)
    end
end

function adjustTTSSpeed(speed)
    ttsSpeed = math.max(0.1, math.min(3.0, speed))
    if tts ~= nil then
        tts.setSpeechRate(ttsSpeed)
    end
end

function adjustTTSPitch(pitch)
    ttsPitch = math.max(0.5, math.min(2.0, pitch))
    if tts ~= nil then
        tts.setPitch(ttsPitch)
    end
end

function stopTTS()
    if tts ~= nil then
        tts.stop()
    end
end

function killTTS()
    if tts ~= nil then
        tts.stop()
        tts.shutdown()
        tts = nil
    end
end

-- Voice commands processing (Roman script)
function processVoiceCommands(text)
    local lowerText = text:lower()
    
    -- TTS control commands
    if lowerText:find("speak faster") or lowerText:find("chito bolnus") or lowerText:find("chito bola") then
        adjustTTSSpeed(ttsSpeed + 0.2)
        speakText("Speech speed increased", true)
        return true
    elseif lowerText:find("speak slower") or lowerText:find("bistarai bolnus") or lowerText:find("bistarai bola") then
        adjustTTSSpeed(ttsSpeed - 0.2)
        speakText("Speech speed decreased", true)
        return true
    elseif lowerText:find("higher pitch") or lowerText:find("aglo awaaj") or lowerText:find("uchha awaaj") then
        adjustTTSPitch(ttsPitch + 0.1)
        speakText("Pitch increased", true)
        return true
    elseif lowerText:find("lower pitch") or lowerText:find("tallo awaaj") or lowerText:find("thulo awaaj") then
        adjustTTSPitch(ttsPitch - 0.1)
        speakText("Pitch decreased", true)
        return true
    elseif lowerText:find("stop speaking") or lowerText:find("bolna band gara") or lowerText:find("chup laga") then
        stopTTS()
        return true
    end
    
    -- Recognition control commands
    if lowerText:find("start continuous listening") or lowerText:find("nirantar sunna suru gara") then
        continuousListening = true
        speakText("Continuous listening enabled", true)
        return true
    elseif lowerText:find("stop continuous listening") or lowerText:find("nirantar sunna band gara") then
        continuousListening = false
        speakText("Continuous listening disabled", true)
        return true
    elseif lowerText:find("show statistics") or lowerText:find("tathyank dekhau") or lowerText:find("stats dekhau") then
        showStatistics()
        return true
    elseif lowerText:find("reset statistics") or lowerText:find("tathyank reset gara") or lowerText:find("stats reset gara") then
        resetStatistics()
        speakText("Statistics reset", true)
        return true
    end
    
    return false
end

-- Language management (Nepali only)
function getSupportedLanguages()
    return "Nepali (ne-np)"
end

-- Statistics functions
function updateStatistics(success, confidence)
    recognitionStats.totalRecognitions = recognitionStats.totalRecognitions + 1
    if success then
        recognitionStats.successfulRecognitions = recognitionStats.successfulRecognitions + 1
        if confidence then
            local total = recognitionStats.averageConfidence * (recognitionStats.successfulRecognitions - 1)
            recognitionStats.averageConfidence = (total + confidence) / recognitionStats.successfulRecognitions
        end
    else
        recognitionStats.errors = recognitionStats.errors + 1
    end
end

function showStatistics()
    local successRate = recognitionStats.totalRecognitions > 0 and 
        (recognitionStats.successfulRecognitions / recognitionStats.totalRecognitions * 100) or 0
    
    local statsText = string.format(
        "Recognition Statistics:\nTotal: %d\nSuccessful: %d\nErrors: %d\nSuccess Rate: %.1f%%\nAverage Confidence: %.1f%%",
        recognitionStats.totalRecognitions,
        recognitionStats.successfulRecognitions,
        recognitionStats.errors,
        successRate,
        recognitionStats.averageConfidence * 100
    )
    
    Toast.makeText(this, statsText, Toast.LENGTH_LONG).show()
    speakText("Statistics displayed on screen", true)
end

function resetStatistics()
    recognitionStats = {
        totalRecognitions = 0,
        successfulRecognitions = 0,
        errors = 0,
        averageConfidence = 0
    }
end

-- Clean up speech recognizer
function kill()
    if speechRecognizer ~= nil then
        speechRecognizer.destroy()
        speechRecognizer = nil
    end
    return true
end

-- Enhanced text processing pipeline
function processRecognizedText(recognizedText, confidence)
    -- First, convert Devanagari to Roman if needed
    recognizedText = devanagariToRoman(recognizedText)
    
    -- Apply all text processing functions in sequence
    recognizedText = removeFillerWords(recognizedText)
    recognizedText = autoCorrectCommonMistakes(recognizedText)
    recognizedText = capitalizeFirstWord(recognizedText)
    recognizedText = substituteWords(recognizedText)
    recognizedText = capitalizeAfterPeriod(recognizedText)
    recognizedText = lowercaseAfterComma(recognizedText)
    recognizedText = addPunctuation(recognizedText)
    
    -- Check for voice commands first
    if voiceCommandsEnabled and processVoiceCommands(recognizedText) then
        updateStatistics(true, confidence)
        return recognizedText
    end
    
    -- Insert text into editor
    service.getEditText()
    local node = service.getEditText()
    service.insertText(node, recognizedText .. " ")
    service.speak(recognizedText)
    
    -- Use TTS to speak the recognized text
    speakText(recognizedText)
    
    -- Update statistics
    updateStatistics(true, confidence)
    
    return recognizedText
end

-- Enhanced online speech recognition with multiple language support
function startOnlineRecognition()
    if not hasInternetConnection() then
        service.asyncSpeak("No internet connection. Voice recognition is not available.")
        updateStatistics(false, nil)
        return false
    end
    
    local verbalizationDetected = false
    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
    
    speechListener = RecognitionListener{
        onReadyForSpeech = function(params)
            Toast.makeText(this, "Ready for speech - " .. currentLanguage, Toast.LENGTH_SHORT).show()
        end,
        
        onBeginningOfSpeech = function()
            -- Speech input started
        end,
        
        onRmsChanged = function(rmsdB)
            -- Voice volume updates - could be used for visual feedback
        end,
        
        onBufferReceived = function(buffer)
            -- Audio data received
        end,
        
        onEndOfSpeech = function()
            -- Speech input ended
        end,
        
        onPartialResults = function(partialResults)
            if partialResultsEnabled then
                local data = partialResults.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if data ~= nil and data.size() > 0 then
                    local partialText = data.get(0)
                    -- Could display partial results in real-time
                    -- Toast.makeText(this, "Partial: " .. partialText, Toast.LENGTH_SHORT).show()
                end
            end
        end,
        
        onResults = function(results)
            local data = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            local confidenceScores = results.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
            
            if data ~= nil and data.size() > 0 then
                verbalizationDetected = true
                local recognizedText = data.get(0)
                local confidence = confidenceScores and confidenceScores[0] or 0.0
                
                processRecognizedText(recognizedText, confidence)
                
                -- Show confidence level
                local confidencePercent = math.floor(confidence * 100)
                Toast.makeText(this, "Recognized: " .. recognizedText .. " (Confidence: " .. confidencePercent .. "%)", Toast.LENGTH_SHORT).show()
                
                -- Continue listening if continuous mode is enabled
                if continuousListening then
                    local handler = Handler()
                    handler.postDelayed(function()
                        startOnlineRecognition()
                    end, 1000)  -- 1 second delay before starting again
                end
            end
            
            if not verbalizationDetected then
                updateStatistics(false, nil)
                kill()
                return false
            end
        end,
        
        onError = function(errorCode)
            local errorMessage = getErrorMessage(errorCode)
            Toast.makeText(this, "Speech recognition error: " .. errorMessage, Toast.LENGTH_SHORT).show()
            updateStatistics(false, nil)
            
            -- Auto-retry on certain errors if continuous listening is enabled
            if continuousListening and (errorCode == SpeechRecognizer.ERROR_NO_MATCH or errorCode == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) then
                local handler = Handler()
                handler.postDelayed(function()
                    startOnlineRecognition()
                end, 2000)  -- 2 second delay before retry
            else
                kill()
            end
            return false
        end
    }

    recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, currentLanguage)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, this.getPackageName())
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResultsEnabled)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, recognitionTimeout)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)  -- Get multiple results
    
    speechRecognizer.setRecognitionListener(speechListener)
    speechRecognizer.startListening(recognizerIntent)
    return true
end

-- Enhanced error handling
function getErrorMessage(errorCode)
    local errorMessages = {
        [SpeechRecognizer.ERROR_AUDIO] = "Audio recording error",
        [SpeechRecognizer.ERROR_CLIENT] = "Client side error",
        [SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS] = "Insufficient permissions",
        [SpeechRecognizer.ERROR_NETWORK] = "Network error",
        [SpeechRecognizer.ERROR_NETWORK_TIMEOUT] = "Network timeout",
        [SpeechRecognizer.ERROR_NO_MATCH] = "No speech match found",
        [SpeechRecognizer.ERROR_RECOGNIZER_BUSY] = "Recognition service busy",
        [SpeechRecognizer.ERROR_SERVER] = "Server error",
        [SpeechRecognizer.ERROR_SPEECH_TIMEOUT] = "No speech input detected"
    }
    return errorMessages[errorCode] or "Unknown error (" .. errorCode .. ")"
end

-- Main function to start listening (online only now)
function startListening()
    if not hasInternetConnection() then
        service.asyncSpeak("Internet connection required for speech recognition.")
        return false
    end
    
    return startOnlineRecognition()
end

-- Configuration functions
function enablePartialResults(enabled)
    partialResultsEnabled = enabled
    Toast.makeText(this, "Partial results " .. (enabled and "enabled" or "disabled"), Toast.LENGTH_SHORT).show()
end

function enableVoiceCommands(enabled)
    voiceCommandsEnabled = enabled
    Toast.makeText(this, "Voice commands " .. (enabled and "enabled" or "disabled"), Toast.LENGTH_SHORT).show()
end

function setRecognitionTimeout(timeoutMs)
    recognitionTimeout = math.max(3000, math.min(30000, timeoutMs))  -- Between 3-30 seconds
    Toast.makeText(this, "Recognition timeout set to " .. (recognitionTimeout/1000) .. " seconds", Toast.LENGTH_SHORT).show()
end

-- Help function (Roman script)
function showHelp()
    local helpText = [[
Voice Commands Available (Nepali/English):
- "Speak faster/chito bola" - Increase TTS speed
- "Speak slower/bistarai bola" - Decrease TTS speed
- "Higher pitch/aglo awaaj" - Increase TTS pitch
- "Lower pitch/tallo awaaj" - Decrease TTS pitch
- "Stop speaking/bolna band gara" - Stop TTS
- "Start continuous listening/nirantar sunna suru gara" - Enable continuous mode
- "Stop continuous listening/nirantar sunna band gara" - Disable continuous mode
- "Show statistics/stats dekhau" - View recognition stats
- "Reset statistics/stats reset gara" - Reset stats

Common phrases:
- "hello" / "namaskar" / "namaste"
- "ke chha" (how are you)
- "khabar" (news/information)
- "ramro chha" (it's good)
- "dhanyabad" (thank you)

Language: Nepali (ne-np)]]
    
    Toast.makeText(this, helpText, Toast.LENGTH_LONG).show()
    speakText("Help information displayed on screen", true)
end

-- Initialize and start
initTTS()

-- Show initial status
Toast.makeText(this, "Enhanced Nepali Speech Recognition Ready", Toast.LENGTH_LONG).show()
speakText("Nepali speech recognition system ready", true)

-- Start listening
if hasInternetConnection() then
    startListening()
else
    Toast.makeText(this, "Internet connection required. Please connect and try again.", Toast.LENGTH_LONG).show()
    speakText("Internet connection required for speech recognition", true)
end

return true