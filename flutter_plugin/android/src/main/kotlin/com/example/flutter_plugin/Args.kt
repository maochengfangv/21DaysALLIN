package com.example.flutter_plugin

object Args {
    fun getString(
        map: Map<*, *>,
        key: String
    ): String {
        val value = map[key] ?: throw PluginException(PluginErrorCodes.BAD_ARGS, "Missing $key")
        return value.toString()
    }

    fun getInt(
        map: Map<*, *>,
        key: String
    ): Int {
        val value = map[key] ?: throw PluginException(PluginErrorCodes.BAD_ARGS, "Missing $key")
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            else -> value.toString().toIntOrNull()
                ?: throw PluginException(PluginErrorCodes.BAD_ARGS, "Invalid int for $key")
        }
    }

    @Suppress("UNCHECKED_CAST")
    fun getMap(
        map: Map<*, *>,
        key: String
    ): Map<String, Any?> {
        val value = map[key] ?: throw PluginException(PluginErrorCodes.BAD_ARGS, "Missing $key")
        if (value is Map<*, *>) {
            return value as Map<String, Any?>
        }
        throw PluginException(PluginErrorCodes.BAD_ARGS, "Invalid map for $key")
    }
}

