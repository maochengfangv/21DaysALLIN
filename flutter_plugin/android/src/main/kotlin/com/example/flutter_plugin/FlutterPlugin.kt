package com.example.flutter_plugin

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.common.StringCodec
import org.json.JSONObject

open class FlutterPluginImpl :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var applicationContext: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var messageStringChannel: BasicMessageChannel<String>
    private lateinit var messageStandardChannel: BasicMessageChannel<Any?>

    private var eventSink: EventChannel.EventSink? = null
    private val ticker = Ticker { tickCount, timestampMs ->
        val sink = eventSink ?: return@Ticker
        val event = mapOf(
            "eventName" to "tick",
            "timestamp" to timestampMs,
            "payload" to mapOf(
                "count" to tickCount
            )
        )
        sink.success(event)
    }

    private var pendingPermissionResult: Result? = null
    private var pendingPermissionRequestId: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, FlutterPluginChannelNames.METHOD)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, FlutterPluginChannelNames.EVENTS)
        eventChannel.setStreamHandler(this)

        messageStringChannel = BasicMessageChannel(binding.binaryMessenger, FlutterPluginChannelNames.MESSAGE_STRING, StringCodec.INSTANCE)
        messageStringChannel.setMessageHandler { message, reply ->
            reply.reply(handleStringMessage(message))
        }

        messageStandardChannel = BasicMessageChannel(binding.binaryMessenger, FlutterPluginChannelNames.MESSAGE_STANDARD, StandardMessageCodec.INSTANCE)
        messageStandardChannel.setMessageHandler { message, reply ->
            reply.reply(handleStandardMessage(message))
        }
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: Result) {
        val args = call.arguments
        val requestMap = args as? Map<*, *>
        val requestId = requestMap?.get("requestId")?.toString() ?: ""

        try {
            when (call.method) {
                "getPlatformVersion" -> {
                    result.success(PluginResponse.ok(requestId, "Android ${Build.VERSION.RELEASE}"))
                }
                "getDeviceInfo" -> {
                    result.success(PluginResponse.ok(requestId, getDeviceInfo()))
                }
                "requestCameraPermission" -> {
                    handleCameraPermission(requestMap, result)
                }
                "startTicking" -> {
                    handleStartTicking(requestMap, requestId, result)
                }
                "stopTicking" -> {
                    ticker.stop()
                    result.success(PluginResponse.ok(requestId, null))
                }
                else -> {
                    result.success(PluginResponse.error(requestId, PluginErrorCodes.NOT_SUPPORTED, "Not supported: ${call.method}"))
                }
            }
        } catch (e: PluginException) {
            result.success(PluginResponse.error(requestId, e.code, e.message))
        } catch (e: Throwable) {
            result.success(PluginResponse.error(requestId, PluginErrorCodes.INTERNAL_ERROR, e.message ?: "internal_error"))
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        messageStringChannel.setMessageHandler(null)
        messageStandardChannel.setMessageHandler(null)
        ticker.stop()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        ticker.stop()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_CAMERA) return false
        val result = pendingPermissionResult ?: return true
        val requestId = pendingPermissionRequestId ?: ""

        pendingPermissionResult = null
        pendingPermissionRequestId = null

        val permission = permissions.firstOrNull().orEmpty()
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED

        val currentActivity = activity
        val status = when {
            granted -> "granted"
            currentActivity == null -> "denied"
            !currentActivity.shouldShowRequestPermissionRationale(permission) -> "permanentlyDenied"
            else -> "denied"
        }

        val responseCode = when (status) {
            "granted" -> PluginErrorCodes.OK
            "permanentlyDenied" -> PluginErrorCodes.PERMISSION_PERMANENTLY_DENIED
            else -> PluginErrorCodes.PERMISSION_DENIED
        }

        val responseMessage = when (status) {
            "granted" -> "ok"
            "permanentlyDenied" -> "permission permanently denied"
            else -> "permission denied"
        }

        val data = mapOf("status" to status)
        val response = if (responseCode == PluginErrorCodes.OK) {
            PluginResponse.ok(requestId, data)
        } else {
            PluginResponse.error(requestId, responseCode, responseMessage).toMutableMap().also {
                it["data"] = data
            }
        }

        result.success(response)

        eventSink?.success(
            mapOf(
                "eventName" to "permission",
                "timestamp" to System.currentTimeMillis(),
                "payload" to mapOf(
                    "permission" to permission,
                    "status" to status
                )
            )
        )

        return true
    }

    private fun getDeviceInfo(): Map<String, Any?> {
        val pm = applicationContext.packageManager
        val pkg = applicationContext.packageName
        val pkgInfo = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(pkg, 0)
            }
        } catch (_: Throwable) {
            null
        }
        val versionName = pkgInfo?.versionName
        val versionCode = pkgInfo?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) it.longVersionCode else @Suppress("DEPRECATION") it.versionCode.toLong()
        }

        return mapOf(
            "platform" to "android",
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "systemVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "appVersionName" to versionName,
            "appVersionCode" to versionCode
        )
    }

    private fun handleCameraPermission(requestMap: Map<*, *>?, result: Result) {
        if (requestMap == null) throw PluginException(PluginErrorCodes.BAD_ARGS, "Invalid arguments")
        val requestId = Args.getString(requestMap, "requestId")
        val currentActivity = activity ?: run {
            result.success(PluginResponse.error(requestId, PluginErrorCodes.NOT_SUPPORTED, "No Activity attached"))
            return
        }

        if (pendingPermissionResult != null) {
            result.success(PluginResponse.error(requestId, PluginErrorCodes.BAD_ARGS, "Permission request in progress"))
            return
        }

        val granted = currentActivity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(PluginResponse.ok(requestId, mapOf("status" to "granted")))
            return
        }

        pendingPermissionResult = result
        pendingPermissionRequestId = requestId
        currentActivity.requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CODE_CAMERA)
    }

    private fun handleStartTicking(
        requestMap: Map<*, *>?,
        requestId: String,
        result: Result
    ) {
        if (requestMap == null) throw PluginException(PluginErrorCodes.BAD_ARGS, "Invalid arguments")
        if (eventSink == null) {
            result.success(PluginResponse.error(requestId, PluginErrorCodes.NOT_SUPPORTED, "EventChannel not listened"))
            return
        }
        val payload = Args.getMap(requestMap, "payload")
        val intervalMs = Args.getInt(payload, "intervalMs").toLong()
        if (intervalMs <= 0) {
            result.success(PluginResponse.error(requestId, PluginErrorCodes.BAD_ARGS, "intervalMs must be > 0"))
            return
        }
        ticker.start(intervalMs)
        result.success(PluginResponse.ok(requestId, null))
    }

    private fun handleStringMessage(message: String?): String {
        val json = try {
            JSONObject(message ?: "")
        } catch (_: Throwable) {
            return JSONObject()
                .put("code", PluginErrorCodes.BAD_ARGS)
                .put("message", "Invalid JSON")
                .put("data", JSONObject.NULL)
                .put("requestId", "")
                .toString()
        }

        val requestId = json.optString("requestId", "")
        val payload = json.optJSONObject("payload")
        val text = payload?.optString("text", "") ?: ""
        val echoed = "Android echo: $text"
        return JSONObject(PluginResponse.ok(requestId, echoed)).toString()
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleStandardMessage(message: Any?): Any? {
        val requestMap = message as? Map<*, *> ?: return PluginResponse.error("", PluginErrorCodes.BAD_ARGS, "Invalid message")
        val requestId = requestMap["requestId"]?.toString() ?: ""
        return try {
            val payload = Args.getMap(requestMap, "payload")
            val data = mapOf(
                "platform" to "android",
                "receivedPayload" to payload,
                "bytes" to byteArrayOf(1, 2, 3, 4),
                "timestamp" to System.currentTimeMillis()
            )
            PluginResponse.ok(requestId, data)
        } catch (e: PluginException) {
            PluginResponse.error(requestId, e.code, e.message)
        } catch (e: Throwable) {
            PluginResponse.error(requestId, PluginErrorCodes.INTERNAL_ERROR, e.message ?: "internal_error")
        }
    }

    private companion object {
        const val REQUEST_CODE_CAMERA = 23101
    }
}
