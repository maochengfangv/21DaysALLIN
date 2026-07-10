package com.myrnapp01.nativekit

import android.os.Build
import android.util.Log
import android.widget.Toast
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.myrnapp01.BuildConfig
import com.myrnapp01.codegen.NativeInterviewTurboModuleSpec

@ReactModule(name = InterviewTurboModule.NAME)
class InterviewTurboModule(reactContext: ReactApplicationContext) :
  NativeInterviewTurboModuleSpec(reactContext) {

  override fun getName(): String = NAME

  override fun getDeviceInfo() =
    Arguments.createMap().apply {
      putString("platform", "android")
      putString("systemVersion", Build.VERSION.RELEASE ?: "unknown")
      putString("model", "${Build.MANUFACTURER} ${Build.MODEL}")
      putString("appVersion", BuildConfig.VERSION_NAME)
      putBoolean("isHermes", true)
      putBoolean("isNewArchitecture", BuildConfig.IS_NEW_ARCHITECTURE_ENABLED)
    }

  override fun getTimestamp(): Double = System.currentTimeMillis().toDouble()

  override fun getTimestampAsync(promise: Promise) {
    promise.resolve(System.currentTimeMillis().toDouble())
  }

  override fun logNativeMessage(message: String) {
    Log.i(NAME, message)
    Toast.makeText(reactApplicationContext, message, Toast.LENGTH_SHORT).show()
  }

  companion object {
    const val NAME = "InterviewTurboModule"
  }
}
