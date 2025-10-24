package com.located.app.data.repository

import com.google.firebase.firestore.FirebaseFirestore
import com.located.app.data.model.LocationData
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LocationRepository @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    
    suspend fun saveLocation(locationData: LocationData): Result<Unit> {
        return try {
            val locationMap = mapOf(
                "id" to locationData.id,
                "userId" to locationData.userId,
                "latitude" to locationData.latitude,
                "longitude" to locationData.longitude,
                "accuracy" to locationData.accuracy,
                "altitude" to locationData.altitude,
                "speed" to locationData.speed,
                "bearing" to locationData.bearing,
                "timestamp" to locationData.timestamp,
                "address" to locationData.address,
                "isBackgroundUpdate" to locationData.isBackgroundUpdate
            )
            
            // Firestore rules require locations to be stored at /locations/{uid}
            firestore.collection("locations").document(locationData.userId).set(locationMap).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun getRecentLocations(userId: String, limit: Int = 100): Result<List<LocationData>> {
        return try {
            val snapshot = firestore.collection("locations")
                .whereEqualTo("userId", userId)
                .orderBy("timestamp", com.google.firebase.firestore.Query.Direction.DESCENDING)
                .limit(limit.toLong())
                .get()
                .await()
            
            val locations = snapshot.documents.mapNotNull { document ->
                try {
                    val data = document.data ?: return@mapNotNull null
                    LocationData(
                        id = document.id,
                        userId = data["userId"] as? String ?: "",
                        latitude = (data["latitude"] as? Number)?.toDouble() ?: 0.0,
                        longitude = (data["longitude"] as? Number)?.toDouble() ?: 0.0,
                        accuracy = (data["accuracy"] as? Number)?.toFloat() ?: 0f,
                        altitude = (data["altitude"] as? Number)?.toDouble() ?: 0.0,
                        speed = (data["speed"] as? Number)?.toFloat() ?: 0f,
                        bearing = (data["bearing"] as? Number)?.toFloat() ?: 0f,
                        timestamp = (data["timestamp"] as? com.google.firebase.Timestamp)?.toDate() ?: java.util.Date(),
                        address = data["address"] as? String,
                        isBackgroundUpdate = data["isBackgroundUpdate"] as? Boolean ?: false
                    )
                } catch (e: Exception) {
                    println("❌ Error parsing location document: $e")
                    null
                }
            }
            
            Result.success(locations)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun getFamilyLocations(familyId: String, limit: Int = 100): Result<List<LocationData>> {
        return try {
            // First get all family members
            val familySnapshot = firestore.collection("families").document(familyId).get().await()
            val familyData = familySnapshot.data
            val members = familyData?.get("members") as? Map<String, Any> ?: emptyMap()
            val memberIds = members.keys.toList()
            
            if (memberIds.isEmpty()) {
                return Result.success(emptyList())
            }
            
            // Get locations for all family members
            val snapshot = firestore.collection("locations")
                .whereIn("userId", memberIds)
                .orderBy("timestamp", com.google.firebase.firestore.Query.Direction.DESCENDING)
                .limit(limit.toLong())
                .get()
                .await()
            
            val locations = snapshot.documents.mapNotNull { document ->
                try {
                    val data = document.data ?: return@mapNotNull null
                    LocationData(
                        id = document.id,
                        userId = data["userId"] as? String ?: "",
                        latitude = (data["latitude"] as? Number)?.toDouble() ?: 0.0,
                        longitude = (data["longitude"] as? Number)?.toDouble() ?: 0.0,
                        accuracy = (data["accuracy"] as? Number)?.toFloat() ?: 0f,
                        altitude = (data["altitude"] as? Number)?.toDouble() ?: 0.0,
                        speed = (data["speed"] as? Number)?.toFloat() ?: 0f,
                        bearing = (data["bearing"] as? Number)?.toFloat() ?: 0f,
                        timestamp = (data["timestamp"] as? com.google.firebase.Timestamp)?.toDate() ?: java.util.Date(),
                        address = data["address"] as? String,
                        isBackgroundUpdate = data["isBackgroundUpdate"] as? Boolean ?: false
                    )
                } catch (e: Exception) {
                    println("❌ Error parsing location document: $e")
                    null
                }
            }
            
            Result.success(locations)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
