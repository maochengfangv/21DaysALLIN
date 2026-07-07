package com.example.flutter_plugin

object PluginErrorCodes {
    const val OK = 0
    const val BAD_ARGS = 1
    const val NOT_SUPPORTED = 2
    const val PERMISSION_DENIED = 3
    const val PERMISSION_PERMANENTLY_DENIED = 4
    const val INTERNAL_ERROR = 5
}

class PluginException(
    val code: Int,
    override val message: String
) : RuntimeException(message)

object PluginResponse {
    fun ok(
        requestId: String,
        data: Any?
    ): Map<String, Any?> {
        return mapOf(
            "code" to PluginErrorCodes.OK,
            "message" to "ok",
            "data" to data,
            "requestId" to requestId
        )
    }

    fun error(
        requestId: String,
        code: Int,
        message: String
    ): Map<String, Any?> {
        return mapOf(
            "code" to code,
            "message" to message,
            "data" to null,
            "requestId" to requestId
        )
    }
}

