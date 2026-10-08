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