package com.myrnmodule

import android.app.Application
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost

class MainApplication : Application(), ReactApplication {

  override val reactHost: ReactHost by lazy {
    val initialBundlePath =
      if (BuildConfig.DEBUG) {
        null
      } else {
        HotUpdateBundleStore.getCurrentBundlePath(applicationContext)
      }

    getDefaultReactHost(
      context = applicationContext,
      packageList =
        PackageList(this).packages.apply {
          // 注册自定义 Turbo Module / Fabric Component Package
          add(MyRNPackage())
        },
      jsBundleFilePath = initialBundlePath,
    )
  }

  override fun onCreate() {
    super.onCreate()
    loadReactNative(this)
  }
}
