package com.example.resqmob

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app_widget_channel"
    private var flutterEngineRef: FlutterEngine? = null

    // sequence tracking
    private val sequence = mutableListOf<Int>()
    private val handler = Handler(Looper.getMainLooper())
    private val resetRunnable = Runnable { sequence.clear() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineRef = flutterEngine

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialData") {
                    result.success(handleIntent(intent))
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sendDataToFlutter(intent)
    }

    // 🔑 Capture hardware button presses
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN -> addKey(0)
            KeyEvent.KEYCODE_VOLUME_UP -> addKey(1)
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun addKey(key: Int) {
        sequence.add(key)

        // reset after 3s of inactivity
        handler.removeCallbacks(resetRunnable)
        handler.postDelayed(resetRunnable, 3000)

        // Expected sequence = [0,0,1,0,0]
        val expected = listOf(0, 0, 1, 0, 0)
        if (sequence.size >= expected.size && sequence.takeLast(expected.size) == expected) {
            triggerAction()
            sequence.clear()
        }
    }

    private fun triggerAction() {
        // 🚀 Same as widget button action
        flutterEngineRef?.let { engine ->
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onWidgetDataReceived", "ACTIVE")
        }
    }

    private fun sendDataToFlutter(intent: Intent) {
        handleIntent(intent)?.let { data ->
            flutterEngineRef?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onWidgetDataReceived", data)
            }
        }
    }

    private fun handleIntent(intent: Intent?): String? {
        return if (intent?.action == Intent.ACTION_VIEW) {
            intent.data?.getQueryParameter("data")
        } else {
            null
        }
    }
}
