package com.example.kmpdemo

actual fun getPlatformName(): String = "Android ${android.os.Build.VERSION.SDK_INT}"
