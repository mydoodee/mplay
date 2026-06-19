package com.ytmusic.yt_music_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    private val TAG = "MPlaySpeech"
    private val CHANNEL = "com.ytmusic.yt_music_app/speech"
    private val EVENT_CHANNEL = "com.ytmusic.yt_music_app/speech_events"
    private val SPEECH_ACTIVITY_REQUEST_CODE = 19283

    private var pendingResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null
    @Volatile private var eventSink: EventChannel.EventSink? = null
    private var isRecognizerListening = false
    private var retryCount = 0
    private var currentLocale = "th-TH"

    // ── Watchdog timer ──
    // ตรวจจับกรณี SpeechRecognizer สร้างสำเร็จแต่ startListening() ไม่ตอบอะไรเลย
    private val watchdogHandler = Handler(android.os.Looper.getMainLooper())
    private var watchdogRunnable: Runnable? = null
    private var gotAnyCallback = false

    // ── Track ว่าใช้ recognizer แบบไหนอยู่ ──
    private var usingOnDeviceRecognizer = false
    // ── Track ว่า Activity-based ลองแล้วหรือยัง ──
    private var triedActivityApproach = false

    // ─────────────────────────────────────────────────
    //  Safe helpers
    // ─────────────────────────────────────────────────

    private fun safeSendEvent(data: Map<String, Any>) {
        runOnUiThread {
            try {
                eventSink?.success(data)
            } catch (e: Exception) {
                Log.w(TAG, "safeSendEvent: failed to send event", e)
            }
        }
    }

    private fun safeSuccess(value: Any?) {
        cancelWatchdog()
        val res = pendingResult
        pendingResult = null
        try {
            res?.success(value)
        } catch (e: Exception) {
            Log.w(TAG, "safeSuccess: Reply already submitted", e)
        }
    }

    private fun safeError(code: String, message: String?, details: Any?) {
        cancelWatchdog()
        val res = pendingResult
        pendingResult = null
        try {
            res?.error(code, message, details)
        } catch (e: Exception) {
            Log.w(TAG, "safeError: Reply already submitted", e)
        }
    }

    private fun safeDestroyRecognizer() {
        val recognizer = speechRecognizer
        speechRecognizer = null
        isRecognizerListening = false
        if (recognizer != null) {
            try {
                recognizer.cancel()
            } catch (e: Exception) {
                Log.w(TAG, "safeDestroyRecognizer: cancel() failed", e)
            }
            try {
                recognizer.destroy()
            } catch (e: Exception) {
                Log.w(TAG, "safeDestroyRecognizer: destroy() failed", e)
            }
        }
    }

    // ─────────────────────────────────────────────────
    //  Watchdog — ตรวจจับ recognizer ที่ค้างไม่ตอบ
    // ─────────────────────────────────────────────────

    private fun startWatchdog(locale: String, timeoutMs: Long = 5000L) {
        cancelWatchdog()
        gotAnyCallback = false
        watchdogRunnable = Runnable {
            if (!gotAnyCallback && pendingResult != null) {
                Log.w(TAG, "⏰ Watchdog fired! No callback after ${timeoutMs}ms. " +
                        "onDevice=$usingOnDeviceRecognizer, triedActivity=$triedActivityApproach")
                safeSendEvent(mapOf("event" to "error", "code" to "WATCHDOG_TIMEOUT"))

                safeDestroyRecognizer()

                // ── Fallback chain ──
                if (!usingOnDeviceRecognizer && !triedActivityApproach) {
                    // Step 1: ลอง on-device ก่อน (ถ้า Android 12+)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                        Log.d(TAG, "Watchdog → trying on-device recognizer...")
                        val retryResult = pendingResult ?: return@Runnable
                        pendingResult = null
                        startWithOnDeviceRecognizer(locale, retryResult)
                    } else {
                        // Android < 12 → ลอง Activity-based เลย
                        Log.d(TAG, "Watchdog → trying Activity-based (YouTube style)...")
                        tryActivityBasedRecognition(locale)
                    }
                } else if (usingOnDeviceRecognizer && !triedActivityApproach) {
                    // Step 2: on-device ก็ไม่ได้ → ลอง Activity-based (แบบ YouTube)
                    Log.d(TAG, "Watchdog → trying Activity-based (YouTube style)...")
                    tryActivityBasedRecognition(locale)
                } else {
                    // ลองทุกอย่างแล้ว
                    Log.e(TAG, "Watchdog: all approaches failed")
                    safeSuccess(null)
                }
            }
        }
        watchdogHandler.postDelayed(watchdogRunnable!!, timeoutMs)
    }

    private fun cancelWatchdog() {
        watchdogRunnable?.let { watchdogHandler.removeCallbacks(it) }
        watchdogRunnable = null
    }

    // ─────────────────────────────────────────────────
    //  Activity-based recognition (แบบ YouTube)
    //  ใช้ startActivityForResult กับ Google Speech Dialog
    //  ทำงานได้บนทุกอุปกรณ์ที่ YouTube ค้นหาด้วยเสียงได้
    // ─────────────────────────────────────────────────

    private fun tryActivityBasedRecognition(locale: String) {
        triedActivityApproach = true
        safeDestroyRecognizer()

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // Prompt ที่แสดงใน Google Speech Dialog
            putExtra(
                RecognizerIntent.EXTRA_PROMPT,
                if (locale.startsWith("th")) "พูดเพื่อค้นหาเพลง..." else "Speak to search..."
            )
        }

        try {
            Log.d(TAG, "🎤 Launching Activity-based speech recognition (YouTube style)")
            safeSendEvent(mapOf("event" to "activityLaunched"))
            startActivityForResult(intent, SPEECH_ACTIVITY_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            Log.e(TAG, "No speech recognition Activity found", e)
            safeSendEvent(mapOf("event" to "error", "code" to "NO_SPEECH_ACTIVITY"))
            safeError("NO_RECOGNIZER", "ไม่พบ Activity สำหรับค้นหาด้วยเสียง", null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch speech Activity", e)
            safeError("NO_RECOGNIZER", "ไม่สามารถเปิดระบบค้นหาด้วยเสียงได้: ${e.message}", null)
        }
    }

    /**
     * รับผลลัพธ์จาก Google Speech Dialog (Activity-based)
     */
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == SPEECH_ACTIVITY_REQUEST_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val text = results?.firstOrNull() ?: ""
                Log.d(TAG, "Activity result: text='$text'")

                if (text.isNotEmpty()) {
                    safeSendEvent(mapOf("event" to "finalResult", "text" to text))
                    safeSuccess(text)
                } else {
                    safeSuccess(null)
                }
            } else {
                Log.d(TAG, "Activity result: cancelled (resultCode=$resultCode)")
                safeSuccess(null)
            }
        }
    }

    // ─────────────────────────────────────────────────
    //  Flutter Engine setup
    // ─────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                        retryCount = 0
                        triedActivityApproach = false
                        startInProcessRecognition(locale, result)
                    }
                    "stopVoiceRecognition" -> {
                        stopRecognition()
                        result.success(null)
                    }
                    "checkRecognizerAvailable" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this)
                        val onDeviceAvailable = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            try { SpeechRecognizer.isOnDeviceRecognitionAvailable(this) } catch (e: Exception) { false }
                        } else false

                        // เช็คว่ามี Activity สำหรับ speech recognition ไหม
                        val activityAvailable = try {
                            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                            intent.resolveActivity(packageManager) != null
                        } catch (e: Exception) { false }

                        Log.d(TAG, "checkAvailable: default=$available, onDevice=$onDeviceAvailable, activity=$activityAvailable")
                        result.success(available || onDeviceAvailable || activityAvailable)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────────────────
    //  In-process recognition (ลองก่อน Activity-based)
    // ─────────────────────────────────────────────────

    /**
     * กลยุทธ์ลำดับการลอง:
     *
     * Android 12+ (head unit):
     *   1. on-device recognizer (ทำงานได้แม้ไม่มี Google app)
     *   2. default recognizer (network-based, Google services)
     *   3. Activity-based (เปิด Google Speech Dialog — แบบ YouTube) ← fallback สุดท้าย
     *
     * Android < 12:
     *   1. default recognizer
     *   2. Activity-based ← fallback สุดท้าย
     */
    private fun startInProcessRecognition(locale: String, result: MethodChannel.Result) {
        // ถ้ามี pending result จากครั้งก่อน ให้ cancel ก่อน
        safeError("CANCELLED", "New request started", null)
        pendingResult = result
        currentLocale = locale

        safeDestroyRecognizer()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // Android 12+ → ลอง on-device ก่อน (head unit มักไม่มี Google speech ที่ bind ได้)
            val onDeviceAvailable = try {
                SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
            } catch (e: Exception) { false }

            if (onDeviceAvailable) {
                Log.d(TAG, "Android 12+ → trying on-device recognizer first")
                startWithOnDeviceRecognizer(locale, result)
            } else {
                Log.d(TAG, "Android 12+ but on-device not available → trying default")
                startWithDefaultRecognizer(locale, result)
            }
        } else {
            startWithDefaultRecognizer(locale, result)
        }
    }

    private fun startWithOnDeviceRecognizer(locale: String, result: MethodChannel.Result) {
        pendingResult = result
        currentLocale = locale
        usingOnDeviceRecognizer = true
        safeDestroyRecognizer()

        speechRecognizer = try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            } else {
                // ไม่ควรมาถึงจุดนี้
                tryActivityBasedRecognition(locale)
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "createOnDeviceSpeechRecognizer failed", e)
            // Fallback → default recognizer
            startWithDefaultRecognizer(locale, result)
            return
        }

        Log.d(TAG, "On-device SpeechRecognizer created OK")
        setupRecognitionListenerAndStart(locale)
    }

    private fun startWithDefaultRecognizer(locale: String, result: MethodChannel.Result) {
        pendingResult = result
        currentLocale = locale
        usingOnDeviceRecognizer = false
        safeDestroyRecognizer()

        speechRecognizer = try {
            SpeechRecognizer.createSpeechRecognizer(this)
        } catch (e: Exception) {
            Log.e(TAG, "createSpeechRecognizer (default) failed", e)
            // Fallback → Activity-based (YouTube style)
            tryActivityBasedRecognition(locale)
            return
        }

        Log.d(TAG, "Default SpeechRecognizer created OK")
        setupRecognitionListenerAndStart(locale)
    }

    // ─────────────────────────────────────────────────
    //  Recognition listener + start listening
    // ─────────────────────────────────────────────────

    private fun setupRecognitionListenerAndStart(locale: String) {
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                gotAnyCallback = true
                cancelWatchdog() // ได้ callback แล้ว → ยกเลิก watchdog
                isRecognizerListening = true
                Log.d(TAG, "✅ onReadyForSpeech (onDevice=$usingOnDeviceRecognizer)")
                safeSendEvent(mapOf("event" to "ready"))
            }

            override fun onBeginningOfSpeech() {
                gotAnyCallback = true
                Log.d(TAG, "onBeginningOfSpeech")
                safeSendEvent(mapOf("event" to "speechStart"))
            }

            override fun onRmsChanged(rmsdB: Float) {
                gotAnyCallback = true
                safeSendEvent(mapOf("event" to "rms", "value" to rmsdB))
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                gotAnyCallback = true
                isRecognizerListening = false
                Log.d(TAG, "onEndOfSpeech")
                safeSendEvent(mapOf("event" to "speechEnd"))
            }

            override fun onError(error: Int) {
                gotAnyCallback = true
                cancelWatchdog()
                isRecognizerListening = false
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
                    12 -> "LANGUAGE_NOT_SUPPORTED" // SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED
                    13 -> "LANGUAGE_UNAVAILABLE"   // SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE
                    else -> "UNKNOWN_ERROR"
                }

                Log.d(TAG, "onError: $errorMsg (code=$error), onDevice=$usingOnDeviceRecognizer, triedActivity=$triedActivityApproach")

                // Destroy the current failing recognizer immediately to avoid further late callbacks
                safeDestroyRecognizer()

                val isUserCancelOrTimeout = error == SpeechRecognizer.ERROR_NO_MATCH ||
                                           error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT

                // ── Fallback logic on error ──
                if (!isUserCancelOrTimeout && !triedActivityApproach) {
                    Log.d(TAG, "Error fallback ($errorMsg): initiating fallback chain...")
                    
                    // Try fallback after a short delay
                    android.os.Handler(mainLooper).postDelayed({
                        if (pendingResult != null) {
                            if (usingOnDeviceRecognizer) {
                                // on-device failed → ลอง default ก่อน
                                val retryResult = pendingResult ?: return@postDelayed
                                pendingResult = null
                                Log.d(TAG, "Error fallback: on-device failed ($errorMsg) → trying default")
                                startWithDefaultRecognizer(currentLocale, retryResult)
                            } else {
                                // default failed → ลอง Activity-based (YouTube style)
                                Log.d(TAG, "Error fallback: default failed ($errorMsg) → trying Activity-based (YouTube style)")
                                tryActivityBasedRecognition(currentLocale)
                            }
                        }
                    }, 300)
                    return
                }

                // If no fallback is possible, send final error event and finish the Flutter call
                safeSendEvent(mapOf("event" to "error", "code" to errorMsg))

                runOnUiThread {
                    if (isUserCancelOrTimeout) {
                        safeSuccess(null)
                    } else {
                        safeError("SPEECH_ERROR", errorMsg, null)
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                gotAnyCallback = true
                cancelWatchdog()
                isRecognizerListening = false
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""

                Log.d(TAG, "✅ onResults: text='$text' (onDevice=$usingOnDeviceRecognizer)")
                safeSendEvent(mapOf("event" to "finalResult", "text" to text))

                runOnUiThread {
                    safeSuccess(text.ifEmpty { null })
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                gotAnyCallback = true
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull() ?: ""
                if (text.isNotEmpty()) {
                    safeSendEvent(mapOf("event" to "partialResult", "text" to text))
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        // สร้าง Intent
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // silence thresholds สำหรับรถยนต์
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000L)
        }

        try {
            speechRecognizer?.startListening(intent)
            Log.d(TAG, "startListening() called (onDevice=$usingOnDeviceRecognizer, locale=$locale)")

            // เริ่ม watchdog — ถ้าไม่มี callback ภายใน 5 วิ → fallback อัตโนมัติ
            startWatchdog(locale, 5000L)

        } catch (e: Exception) {
            Log.e(TAG, "startListening failed", e)
            safeDestroyRecognizer()

            if (!triedActivityApproach) {
                // Fallback → Activity-based (YouTube style)
                Log.d(TAG, "startListening exception → trying Activity-based")
                tryActivityBasedRecognition(locale)
            } else {
                safeError("NO_RECOGNIZER", "ไม่สามารถเริ่มฟังเสียงได้: ${e.message}", null)
            }
        }
    }

    private fun stopRecognition() {
        cancelWatchdog()
        safeDestroyRecognizer()
        safeSuccess(null)
    }

    override fun onDestroy() {
        cancelWatchdog()
        safeDestroyRecognizer()
        super.onDestroy()
    }
}
