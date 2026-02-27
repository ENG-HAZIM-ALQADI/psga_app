package com.example.psga_app

import android.util.Log
import io.flutter.app.FlutterApplication

class PSGAApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        
        // تعطيل Google Flogger verbose logs
        suppressFloggerLogs()
    }
    
    private fun suppressFloggerLogs() {
        try {
            // تعيين System properties لتقليل Flogger logs
            System.setProperty("flogger.backend_factory", 
                "com.google.common.flogger.backend.system.SimpleBackendFactory#getInstance")
            System.setProperty("flogger.logging_level", "WARNING")
            
            Log.d("PSGAApplication", "Flogger logs suppressed successfully")
        } catch (e: Exception) {
            Log.w("PSGAApplication", "Could not suppress Flogger logs: ${e.message}")
        }
    }
}
