package com.example.flutter_demo

import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "demo/isolate_method_channel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "nativeEcho" -> {
                    val message = call.argument<String>("message") ?: "empty"
                    val timestamp = SimpleDateFormat(
                        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                        Locale.US
                    ).format(Date())
                    result.success(
                        mapOf(
                            "from" to "Android Native",
                            "echo" to "Native 收到: $message",
                            "thread" to if (Looper.myLooper() == Looper.getMainLooper()) {
                                "main-thread"
                            } else {
                                "background-thread"
                            },
                            "timestamp" to timestamp
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
