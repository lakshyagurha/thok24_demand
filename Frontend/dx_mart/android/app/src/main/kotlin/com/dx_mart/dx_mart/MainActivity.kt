package com.dx_mart.dx_mart

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Must run before super.onCreate() — this is what makes the LaunchTheme
    // in values/styles.xml actually take effect via core-splashscreen, rather
    // than the OS falling back to its own default (unbranded, circle-masked
    // launcher icon) splash on Android 12+.
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
