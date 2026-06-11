package com.ytmusic.yt_music_app

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "com.ytmusic.yt_music_app/speech"
    private val EVENT_CHANNEL = "com.ytmusic.yt_music_app/speech_events"
    private var pendingResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event channel สำหรับส่ง partial results กลับ Flutter แบบ real-time
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVoiceRecognition" -> {
                        val locale = call.argument<String>("locale") ?: "th-TH"
                        startInProcessRecognition(locale, result)
                    }
                    "stopVoiceRecognition" -> {
                        stopRecognition()
                        result.success(null)
                    }
                    "checkRecognizerAvailable" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this)
                        result.success(available)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * ใช้ SpeechRecognizer API โดยตรง (in-process)
     * วิธีนี้ไม่ต้องเปิด Activity ภายนอก ทำงานได้บนจอรถยนต์ที่มี
     * speech recognizer service ใดๆ ก็ได้ (ไม่จำเป็นต้องเป็น Google app)
     */
    private fun startInProcessRecognition(locale: String, result: MethodChannel.Result) {
        // ถ้ามี pending result จากครั้งก่อน ให้ cancel ก่อน
        pendingResult?.error("CANCELLED", "New request started", null)
        pendingResult = result

        // ทำลาย recognizer เดิมถ้ามี
        speechRecognizer?.destroy()

        // ลอง default recognizer ก่อน (network-based, ใช้ได้กับจอรถที่มี Google services)
        // ถ้าไม่ได้ค่อย fallback ไป on-device recognizer (Android 12+)
        speechRecognizer = try {
            SpeechRecognizer.createSpeechRecognizer(this)
        } catch (e: Exception) {
            // fallback ลอง on-device recognizer (Android 12+)
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                } else {
                    pendingResult = null
                    result.error("NO_RECOGNIZER", "ไม่สามารถสร้าง SpeechRecognizer ได้", null)
                    return
                }
            } catch (e2: Exception) {
                pendingResult = null
                result.error("NO_RECOGNIZER", "ไม่สามารถสร้าง SpeechRecognizer ได้", null)
                return
            }
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                runOnUiThread {
                    eventSink?.success(mapOf("event" to "ready"))
                }
            }

            override fun onBeginningOfSpeech() {
                runOnUiThread {
                    eventSink?.success(mapOf("event" to "speechStart"))
                }
            }

            override fun onRmsChanged(rmsdB: Float) {
                runOnUiThread {
                    eventSink?.success(mapOf("event" to "rms", "value" to rmsdB))
                }
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                runOnUiThread {
                    eventSink?.success(mapOf("event" to "speechEnd"))
                }
            }

            override fun onError(error: Int) {
                runOnUiThread {
                    val res = pendingResult
                    pendingResult = null

                    val errorMsg = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
                        SpeechRecognizer.ERROR_CLIENT -> "CLIENT_ERROR"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_ERROR"
                        SpeechRecognizer.ERROR_NETWORK -> "NETWORK_ERROR"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "NETWORK_TIMEOUT"
                        SpeechRecognizer.ERROR_NO_MATCH -> "NO_MATCH"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RECOGNIZER_BUSY"
                        SpeechRecognizer.ERROR_SERVER -> "SERVER_ERROR"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "SPEECH_TIMEOUT"
                        else -> "UNKNOWN_ERROR"
                    }

                    eventSink?.success(mapOf("event" to "error", "code" to errorMsg))

                    // NO_MATCH / SPEECH_TIMEOUT = ผู้ใช้ไม่ได้พูดอะไร → return null
                    if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                        error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                        res?.success(null)
                    } else {
                        res?.error("SPEECH_ERROR", errorMsg, null)
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                runOnUiThread {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull() ?: ""

                    eventSink?.success(mapOf(
                        "event" to "finalResult",
                        "text" to text
                    ))

                    val res = pendingResult
                    pendingResult = null
                    if (text.isNotEmpty()) {
                        res?.success(text)
                    } else {
                        res?.success(null)
                    }
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                runOnUiThread {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull() ?: ""
                    if (text.isNotEmpty()) {
                        eventSink?.success(mapOf(
                            "event" to "partialResult",
                            "text" to text
                        ))
                    }
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        // สร้าง Intent สำหรับ SpeechRecognizer
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        speechRecognizer?.startListening(intent)
    }

    private fun stopRecognition() {
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
        pendingResult?.success(null)
        pendingResult = null
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        super.onDestroy()
    }
}
