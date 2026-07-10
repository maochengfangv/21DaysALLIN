package com.myrnapp01.nativekit

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager
import com.myrnapp01.BuildConfig

class InterviewDemoPackage : BaseReactPackage() {
  override fun getModule(
    name: String,
    reactContext: ReactApplicationContext,
  ): NativeModule? {
    return when (name) {
      InterviewTurboModule.NAME -> InterviewTurboModule(reactContext)
      else -> null
    }
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
    val map =
      mapOf(
        InterviewTurboModule.NAME to
          ReactModuleInfo(
            InterviewTurboModule.NAME,
            InterviewTurboModule::class.java.name,
            false,
            false,
            false,
            BuildConfig.IS_NEW_ARCHITECTURE_ENABLED,
          ),
      )
    return ReactModuleInfoProvider { map }
  }

  override fun createViewManagers(
    reactContext: ReactApplicationContext,
  ): List<ViewManager<*, *>> = listOf(InterviewFabricCardManager())
}
