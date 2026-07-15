package com.example.kmpdemo

/**
 * expect: 声明平台相关的接口
 * 每个平台（Android/iOS）必须提供 actual 实现
 */
expect fun getPlatformName(): String

/**
 * 跨平台共享的业务逻辑
 * 这段代码在 Android 和 iOS 上完全一致
 */
class Greeting {
    private val platform: String = getPlatformName()

    fun greet(): String = "Hello from KMP on $platform"
}
