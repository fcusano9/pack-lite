package com.packlite.app

import android.app.backup.BackupManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val BACKUP_CHANNEL = "com.packlite.app/backup"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Tell Android this app's data changed so it schedules a
                    // backup pass soon instead of waiting for the next daily
                    // one. Without this, deleting everything in the app leaves
                    // a stale snapshot in the user's Google account that gets
                    // restored on the next reinstall, resurrecting the lists
                    // they just deleted.
                    "dataChanged" -> {
                        BackupManager(applicationContext).dataChanged()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
