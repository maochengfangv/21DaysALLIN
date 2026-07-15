package com.myrnmodule

import android.os.Build
import android.content.pm.PackageManager
import com.facebook.react.ReactApplication
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class HotUpdateBridgeModule(
    private val reactAppContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactAppContext) {

    override fun getName(): String = "HotUpdateBridge"

    @ReactMethod
    fun getCurrentBundlePath(promise: Promise) {
        promise.resolve(HotUpdateBundleStore.getCurrentBundlePath(reactAppContext.applicationContext))
    }

    @ReactMethod
    fun setCurrentBundlePath(bundlePath: String, promise: Promise) {
        HotUpdateBundleStore.setCurrentBundlePath(reactAppContext.applicationContext, bundlePath)
        promise.resolve(null)
    }

    @ReactMethod
    fun clearCurrentBundlePath(promise: Promise) {
        HotUpdateBundleStore.clearCurrentBundlePath(reactAppContext.applicationContext)
        promise.resolve(null)
    }

    @ReactMethod
    fun getEmbeddedBundlePath(promise: Promise) {
        promise.resolve("assets://index.android.bundle")
    }

    @ReactMethod
    fun reloadBundle(bundlePath: String?, promise: Promise) {
        if (BuildConfig.DEBUG) {
            promise.resolve(null)
            return
        }

        val app = reactAppContext.applicationContext as? ReactApplication
        val reactHost = app?.reactHost

        if (reactHost == null) {
            promise.reject("E_REACT_HOST", "ReactHost 尚未初始化")
            return
        }

        val nextBundlePath = bundlePath?.takeIf { it.isNotBlank() }
            ?: HotUpdateBundleStore.getCurrentBundlePath(reactAppContext.applicationContext)
            ?: "assets://index.android.bundle"

        if (nextBundlePath.startsWith("assets://")) {
            HotUpdateBundleStore.clearCurrentBundlePath(reactAppContext.applicationContext)
        } else {
            HotUpdateBundleStore.setCurrentBundlePath(reactAppContext.applicationContext, nextBundlePath)
        }

        reactHost.setBundleSource(nextBundlePath)
        promise.resolve(null)
    }

    @ReactMethod
    fun getAppVersion(promise: Promise) {
        try {
            val packageInfo =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    reactAppContext.packageManager.getPackageInfo(
                        reactAppContext.packageName,
                        PackageManager.PackageInfoFlags.of(0)
                    )
                } else {
                    @Suppress("DEPRECATION")
                    reactAppContext.packageManager.getPackageInfo(
                        reactAppContext.packageName,
                        0
                    )
                }
            promise.resolve(packageInfo.versionName ?: "0.0.0")
        } catch (error: Exception) {
            promise.reject("E_APP_VERSION", error)
        }
    }

    @ReactMethod
    fun getBuildNumber(promise: Promise) {
        promise.resolve(BuildConfig.VERSION_CODE.toString())
    }
}
