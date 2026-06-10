package com.ytmusic.yt_music_app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "com.ytmusic.yt_music_app/speech"
    private val SPEECH_REQUEST_CODE = 9001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVoiceRecognition" -> {
                        val locale = call.argument<String>("locale") ?: "th-TH"
                        val prompt = call.argument<String>("prompt") ?: ""
                        startVoiceRecognition(locale, prompt, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startVoiceRecognition(
        locale: String,
        prompt: String,
        result: MethodChannel.Result
    ) {
        // ถ้ามี pending result จากครั้งก่อน ให้ cancel ก่อน
        pendingResult?.error("CANCELLED", "New request started", null)
        pendingResult = result

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            // ส่ง locale เพิ่มเพื่อให้แน่ใจว่า recognizer ใช้ภาษาที่ต้องการ
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            if (prompt.isNotEmpty()) {
                putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
            }
        }

        try {
            startActivityForResult(intent, SPEECH_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pendingResult = null
            result.error(
                "NO_RECOGNIZER",
                "ไม่พบบริการรู้จำเสียงบนอุปกรณ์นี้",
                e.message
            )
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == SPEECH_REQUEST_CODE) {
            val result = pendingResult
            pendingResult = null

            if (result == null) return

            when (resultCode) {
                Activity.RESULT_OK -> {
                    val matches = data?.getStringArrayListExtra(
                        RecognizerIntent.EXTRA_RESULTS
                    )
                    val recognizedText = matches?.firstOrNull() ?: ""
                    if (recognizedText.isNotEmpty()) {
                        result.success(recognizedText)
                    } else {
                        result.success(null) // ไม่มีผลลัพธ์
                    }
                }
                Activity.RESULT_CANCELED -> {
                    result.success(null) // ผู้ใช้ยกเลิก
                }
                else -> {
                    result.success(null)
                }
            }
        }
    }
}
