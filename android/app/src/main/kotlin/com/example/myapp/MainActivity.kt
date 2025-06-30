package com.example.myapp

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.example.myapp/notification"
    private val DOWNLOAD_CHANNEL = "com.example.myapp/download"
    private val INSTALLER_CHANNEL = "com.altijwal.app/installer"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Create notification channel for foreground service
        createNotificationChannel()
        
        // Notification channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "createNotificationChannel") {
                createNotificationChannel()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        
        // Download channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "saveToDownloads") {
                try {
                    val fileName = call.argument<String>("fileName")!!
                    val mimeType = call.argument<String>("mimeType")!!
                    val data = call.argument<ByteArray>("data")!!
                    
                    val filePath = saveToDownloads(fileName, mimeType, data)
                    result.success(filePath)
                } catch (e: Exception) {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Installer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "installApk") {
                try {
                    val filePath = call.argument<String>("path")!!
                    installApk(filePath)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    private fun installApk(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("APK file not found: $filePath")
        }
        
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ requires FileProvider
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
        } else {
            // Android 6.0 and below
            intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
        }
        
        startActivity(intent)
    }
    
    private fun saveToDownloads(fileName: String, mimeType: String, data: ByteArray): String {
        val isImage = mimeType.startsWith("image/")
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+) - Use MediaStore
            val contentResolver: ContentResolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                
                // Save images to Pictures/Downloads for better gallery visibility
                if (isImage) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Downloads")
                } else {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
            }
            
            val collection = if (isImage) {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Downloads.EXTERNAL_CONTENT_URI
            }
            
            val uri = contentResolver.insert(collection, contentValues)
            uri?.let {
                contentResolver.openOutputStream(it)?.use { outputStream ->
                    outputStream.write(data)
                }
                
                // For images, also add to gallery by copying to Downloads
                if (isImage) {
                    val downloadContentValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                        put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    }
                    
                    val downloadUri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, downloadContentValues)
                    downloadUri?.let { dlUri ->
                        contentResolver.openOutputStream(dlUri)?.use { outputStream ->
                            outputStream.write(data)
                        }
                    }
                }
                
                // Return a user-friendly path
                if (isImage) {
                    "${Environment.DIRECTORY_PICTURES}/Downloads/$fileName"
                } else {
                    "${Environment.DIRECTORY_DOWNLOADS}/$fileName"
                }
            } ?: throw Exception("Failed to create file")
        } else {
            // Android 9 and below - Use legacy storage with media scanning
            val targetDir = if (isImage) {
                // For images, save to Pictures/Downloads so gallery can find them
                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val downloadsSubDir = File(picturesDir, "Downloads")
                if (!downloadsSubDir.exists()) {
                    downloadsSubDir.mkdirs()
                }
                downloadsSubDir
            } else {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            }
            
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            
            val file = File(targetDir, fileName)
            FileOutputStream(file).use { outputStream ->
                outputStream.write(data)
            }
            
            // Also save to Downloads folder for easy access
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val downloadFile = File(downloadsDir, fileName)
            FileOutputStream(downloadFile).use { outputStream ->
                outputStream.write(data)
            }
            
            // Trigger media scan for gallery visibility
            if (isImage) {
                MediaScannerConnection.scanFile(
                    this,
                    arrayOf(file.absolutePath, downloadFile.absolutePath),
                    arrayOf(mimeType),
                    null
                )
                
                // Also trigger via broadcast (backup method)
                sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(file)))
                sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(downloadFile)))
            }
            
            file.absolutePath
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "al_tijwal_location_service"
            val channelName = "Al-Tijwal Location Service"
            val channelDescription = "Tracks agent location in background"
            val importance = NotificationManager.IMPORTANCE_LOW
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            
            val notificationManager: NotificationManager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
