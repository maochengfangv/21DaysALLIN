package com.example.flutter_plugin

import android.os.Handler
import android.os.Looper

class Ticker(
    private val onTick: (
        tickCount: Long,
        timestampMs: Long
    ) -> Unit
) {
    private val handler = Handler(Looper.getMainLooper())
    private var intervalMs: Long = 0
    private var tickCount: Long = 0
    private var running = false

    private val runnable = object : Runnable {
        override fun run() {
            if (!running) return
            val ts = System.currentTimeMillis()
            tickCount += 1
            onTick(tickCount, ts)
            handler.postDelayed(this, intervalMs)
        }
    }

    fun start(intervalMs: Long) {
        stop()
        if (intervalMs <= 0) return
        this.intervalMs = intervalMs
        tickCount = 0
        running = true
        handler.post(runnable)
    }

    fun stop() {
        running = false
        handler.removeCallbacks(runnable)
    }
}

