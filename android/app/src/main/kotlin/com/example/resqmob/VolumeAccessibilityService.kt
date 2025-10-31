package com.example.resqmob

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

class VolumeAccessibilityService : AccessibilityService() {

    private val sequence = mutableListOf<Int>()
    private val handler = Handler(Looper.getMainLooper())
    private val resetRunnable = Runnable { sequence.clear() }

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOWS_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        }
        serviceInfo = info
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN -> addKey(0)
                KeyEvent.KEYCODE_VOLUME_UP -> addKey(1)
            }
        }
        return false // let system handle volume normally
    }

    private fun addKey(key: Int) {
        sequence.add(key)

        handler.removeCallbacks(resetRunnable)
        handler.postDelayed(resetRunnable, 3000) // reset after 3s

        val expected = listOf(0, 0, 1, 0, 0) // down, down, up, down, down
        if (sequence.size >= expected.size && sequence.takeLast(expected.size) == expected) {
            triggerSOS()
            sequence.clear()
        }
    }

    private fun triggerSOS() {
        // 🔥 Relaunch your Flutter app
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = android.net.Uri.parse("yourapp://widget?data=ACTIVE")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}
}
