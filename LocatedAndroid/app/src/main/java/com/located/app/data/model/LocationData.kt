package com.located.app.data.model

import java.util.Date

data class LocationData(
    val id: String,
    val userId: String,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val altitude: Double,
    val speed: Float,
    val bearing: Float,
    val timestamp: Date,
    val address: String? = null,
    val isBackgroundUpdate: Boolean = false
) {
    companion object {
        fun create(
            id: String,
            userId: String,
            latitude: Double,
            longitude: Double,
            accuracy: Float,
            altitude: Double = 0.0,
            speed: Float = 0f,
            bearing: Float = 0f,
            timestamp: Date = Date(),
            address: String? = null,
            isBackgroundUpdate: Boolean = false
        ): LocationData {
            return LocationData(
                id = id,
                userId = userId,
                latitude = latitude,
                longitude = longitude,
                accuracy = accuracy,
                altitude = altitude,
                speed = speed,
                bearing = bearing,
                timestamp = timestamp,
                address = address,
                isBackgroundUpdate = isBackgroundUpdate
            )
        }
    }
}
