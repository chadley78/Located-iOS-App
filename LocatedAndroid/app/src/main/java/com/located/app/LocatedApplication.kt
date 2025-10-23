package com.located.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class LocatedApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize any global services here
        // Firebase will be auto-initialized via google-services.json
    }
}
