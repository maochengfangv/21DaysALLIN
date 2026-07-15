package com.myrnmodule

import android.content.Context
import java.io.File

object HotUpdateBundleStore {
    private const val PREFS_NAME = "hot_update_bundle_store"
    private const val KEY_BUNDLE_PATH = "current_bundle_path"

    fun getCurrentBundlePath(context: Context): String? {
        val path = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_BUNDLE_PATH, null)
            ?: return null

        return if (path.startsWith("assets://") || File(path).exists()) {
            path
        } else {
            clearCurrentBundlePath(context)
            null
        }
    }

    fun setCurrentBundlePath(context: Context, bundlePath: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_BUNDLE_PATH, bundlePath)
            .apply()
    }

    fun clearCurrentBundlePath(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_BUNDLE_PATH)
            .apply()
    }
}
