package com.located.app.service

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.android.gms.tasks.CancellationTokenSource
import com.located.app.MainActivity
import com.located.app.data.model.LocationData
import com.located.app.data.repository.LocationRepository
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@AndroidEntryPoint
class LocationService : Service() {
    
    @Inject
    lateinit var locationRepository: LocationRepository
    
    private val binder = LocationBinder()
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private var serviceScope = CoroutineScope(Dispatchers.IO)
    private var locationUpdateJob: Job? = null
    
    // Location update settings - matching iOS implementation
    private val locationUpdateInterval: Long = 2000 // 2 seconds (for testing)
    private val significantLocationChangeThreshold = 1.0 // 1 meter (for testing)
    private var lastSignificantLocation: Location? = null
    private var lastFirestoreUpdateTime: Long = 0
    
    // Notification
    private val notificationId = 1001
    private val channelId = "location_tracking_channel"
    
    inner class LocationBinder : Binder() {
        fun getService(): LocationService = this@LocationService
    }
    
    override fun onCreate() {
        super.onCreate()
        println("📍 LocationService created")
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        println("📍 LocationService started")
        
        val notification = createNotification()
        startForeground(notificationId, notification)
        
        startLocationUpdates()
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder = binder
    
    override fun onDestroy() {
        super.onDestroy()
        println("📍 LocationService destroyed")
        stopLocationUpdates()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when Located is tracking your location"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Located is tracking your location")
            .setContentText("Keeping your family connected and safe")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun startLocationUpdates() {
        val hasFine = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine && !hasCoarse) {
            println("❌ Location permission not granted (fine/coarse missing)")
            return
        }
        
        println("📍 Starting location updates...")
        
        // Create location request
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            locationUpdateInterval
        ).apply {
            setMinUpdateIntervalMillis(locationUpdateInterval)
            setMaxUpdateDelayMillis(locationUpdateInterval * 2)
            setWaitForAccurateLocation(false)
            // Request updates even for small movements
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                setMinUpdateDistanceMeters(1f)
            }
        }.build()
        
        // Create location callback
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                println("📍 onLocationResult: ${'$'}{locationResult.lastLocation}")
                locationResult.lastLocation?.let { location ->
                    processLocationUpdate(location)
                }
            }
        }
        
        // Start location updates
        fusedLocationClient?.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            android.os.Looper.getMainLooper()
        )
        
        // Start significant location change monitoring
        val significantLocationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            10000 // 10 seconds
        ).apply {
            setMinUpdateIntervalMillis(10000)
            setMaxUpdateDelayMillis(20000)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                setMinUpdateDistanceMeters(5f)
            }
        }.build()
        
        fusedLocationClient?.requestLocationUpdates(
            significantLocationRequest,
            locationCallback!!,
            android.os.Looper.getMainLooper()
        )

        // Kickstart with a one-shot current location
        try {
            val token = com.google.android.gms.tasks.CancellationTokenSource()
            fusedLocationClient?.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, token.token)
                ?.addOnSuccessListener { loc ->
                    if (loc != null) {
                        println("📍 One-shot current location: lat=${'$'}{loc.latitude}, lng=${'$'}{loc.longitude}")
                        processLocationUpdate(loc)
                    } else {
                        println("⚠️ One-shot current location returned null")
                    }
                }
                ?.addOnFailureListener { e -> println("❌ One-shot current location failed: ${'$'}{e.message}") }
        } catch (e: Exception) {
            println("❌ One-shot current location exception: ${'$'}{e.message}")
        }
    }
    
    private fun stopLocationUpdates() {
        println("📍 Stopping location updates...")
        
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
        }
        
        locationUpdateJob?.cancel()
        locationUpdateJob = null
    }
    
    private fun processLocationUpdate(location: Location) {
        println("📍 Location update received: lat=${location.latitude}, lng=${location.longitude}, acc=${location.accuracy}, provider=${location.provider}, time=${location.time}")
        
        // Check if this is a significant location change
        val isSignificantChange = lastSignificantLocation?.let { lastLocation ->
            val distance = location.distanceTo(lastLocation)
            distance >= significantLocationChangeThreshold
        } ?: true
        
        // Check if enough time has passed since last Firestore update
        val currentTime = System.currentTimeMillis()
        val timeSinceLastUpdate = currentTime - lastFirestoreUpdateTime
        val shouldUpdateFirestore = timeSinceLastUpdate >= locationUpdateInterval
        
        if (isSignificantChange || shouldUpdateFirestore) {
            println("📍 Writing location to Firestore: lat=${location.latitude}, lng=${location.longitude}")
            
            lastSignificantLocation = location
            lastFirestoreUpdateTime = currentTime
            
            // Save location to Firestore
            saveLocationToFirestore(location)
        }
    }
    
    private fun saveLocationToFirestore(location: Location) {
        locationUpdateJob?.cancel()
        locationUpdateJob = serviceScope.launch {
            try {
                val userId = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid ?: return@launch
                
                val locationData = LocationData.create(
                    id = UUID.randomUUID().toString(),
                    userId = userId,
                    latitude = location.latitude,
                    longitude = location.longitude,
                    accuracy = location.accuracy,
                    altitude = location.altitude,
                    speed = location.speed,
                    bearing = location.bearing,
                    timestamp = java.util.Date(location.time),
                    isBackgroundUpdate = true
                )
                
                locationRepository.saveLocation(locationData).onSuccess {
                    println("✅ Location saved to Firestore successfully")
                }.onFailure { error ->
                    println("❌ Failed to save location to Firestore: ${error.message}")
                }
            } catch (e: Exception) {
                println("❌ Error saving location: ${e.message}")
            }
        }
    }
    
    fun forceLocationUpdate() {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        
        val cancellationTokenSource = CancellationTokenSource()
        fusedLocationClient?.getCurrentLocation(
            Priority.PRIORITY_HIGH_ACCURACY,
            cancellationTokenSource.token
        )?.addOnSuccessListener { location ->
            location?.let {
                println("📍 Force location update received")
                processLocationUpdate(it)
            }
        }
    }
}
