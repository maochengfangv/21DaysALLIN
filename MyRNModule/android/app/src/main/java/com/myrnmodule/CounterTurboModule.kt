package com.myrnmodule

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext

/**
 * Turbo Module: Counter
 * JS 侧通过 NativeCounter 调用
 */
class CounterTurboModule(reactContext: ReactApplicationContext) : NativeCounterSpec(reactContext) {
    private var count: Double = 0.0

    override fun getValue(promise: Promise) {
        promise.resolve(count)
    }

    override fun increment(step: Double, promise: Promise) {
        count += step
        promise.resolve(count)
    }

    override fun decrement(step: Double, promise: Promise) {
        count -= step
        promise.resolve(count)
    }

    override fun reset(promise: Promise) {
        count = 0.0
        promise.resolve(null)
    }
}
