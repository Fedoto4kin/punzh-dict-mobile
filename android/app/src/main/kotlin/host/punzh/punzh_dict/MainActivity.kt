package host.punzh.punzh_dict

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val installSourceChannel = "host.punzh.punzh_dict/install_source"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            installSourceChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "getInstallerPackageName") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(installerPackageName())
            } catch (e: Exception) {
                result.error("INSTALL_SOURCE", e.message, null)
            }
        }
    }

    private fun installerPackageName(): String? {
        val pm = applicationContext.packageManager
        val pkg = applicationContext.packageName
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(pkg).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(pkg)
        }
    }
}
