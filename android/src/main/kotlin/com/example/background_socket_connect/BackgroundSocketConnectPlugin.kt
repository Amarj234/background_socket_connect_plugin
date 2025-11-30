package com.example.background_socket_connect

import android.content.Context
import androidx.work.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import okhttp3.*
import java.util.concurrent.TimeUnit
import javax.net.ssl.*

/** BackgroundSocketConnectPlugin */
class BackgroundSocketConnectPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var webSocket: WebSocket? = null
    private var client: OkHttpClient? = null
    private var isInBackground = false
    private var reconnectJob: Job? = null
    private var currentUrl: String? = null
    private var currentHeaders: Map<String, String> = emptyMap()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_socket_connect")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect" -> {
                val url = call.argument<String>("url")
                val headers = call.argument<Map<String, String>>("headers")
                if (url != null) {
                    currentUrl = url
                    currentHeaders = headers ?: emptyMap()
                    connectWebSocket(url, currentHeaders, result)
                } else {
                    result.error("INVALID_URL", "URL cannot be null", null)
                }
            }
            "disconnect" -> {
                disconnectWebSocket(result)
            }
            "sendMessage" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    sendMessage(message, result)
                } else {
                    result.error("INVALID_MESSAGE", "Message cannot be null", null)
                }
            }
            "setBackgroundMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setBackgroundMode(enabled, result)
            }
            "getConnectionStatus" -> {
                getConnectionStatus(result)
            }
            "startBackgroundService" -> {
                startBackgroundService(result)
            }
            "stopBackgroundService" -> {
                stopBackgroundService(result)
            }
            else -> result.notImplemented()
        }
    }

    private fun connectWebSocket(url: String, headers: Map<String, String>, result: Result) {
        try {
            // Clean up any existing connection first
            disconnectWebSocket(object : Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })

            // Create a custom client with proper configuration
            val clientBuilder = OkHttpClient.Builder()
                .readTimeout(0, TimeUnit.MILLISECONDS) // No timeout for WebSocket
                .connectTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .pingInterval(0, TimeUnit.SECONDS) // Disable OkHttp ping completely

            // For WS connections, configure to bypass security
            if (url.startsWith("ws://")) {
                configureUnsafeConnection(clientBuilder)
            }

            client = clientBuilder.build()

            val requestBuilder = Request.Builder().url(url)

            // Add custom headers
            headers.forEach { (key, value) ->
                requestBuilder.addHeader(key, value)
            }

            // Add WebSocket specific headers
            requestBuilder.addHeader("Sec-WebSocket-Protocol", "chat")
            requestBuilder.addHeader("Connection", "Upgrade")
            requestBuilder.addHeader("Upgrade", "websocket")

            val request = requestBuilder.build()

            webSocket = client?.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    println("WebSocket connection opened successfully")
                    CoroutineScope(Dispatchers.Main).launch {
                        channel.invokeMethod("onConnected", null)
                    }
                    // Don't start any keep-alive - server handles it
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    println("WebSocket message received: $text")
                    CoroutineScope(Dispatchers.Main).launch {
                        val messageMap = mapOf("message" to text)
                        channel.invokeMethod("onMessage", messageMap)
                    }

                    // Completely ignore ping messages - do NOT respond
                    // Server sends {"type":"ping"} but doesn't expect any response
                }

                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    println("WebSocket closing: $code - $reason")
                    CoroutineScope(Dispatchers.Main).launch {
                        val disconnectMap = mapOf("code" to code, "reason" to reason)
                        channel.invokeMethod("onDisconnected", disconnectMap)
                    }
                    stopAutoReconnect()
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    println("WebSocket failure: ${t.message}")
                    CoroutineScope(Dispatchers.Main).launch {
                        val errorMap = mapOf("error" to (t.message ?: "Unknown error"))
                        channel.invokeMethod("onError", errorMap)
                    }

                    // Auto-reconnect after delay if in background mode
                    if (isInBackground) {
                        startAutoReconnect()
                    }
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    println("WebSocket closed: $code - $reason")
                    CoroutineScope(Dispatchers.Main).launch {
                        val disconnectMap = mapOf("code" to code, "reason" to reason)
                        channel.invokeMethod("onDisconnected", disconnectMap)
                    }
                    stopAutoReconnect()
                }
            })

            result.success(true)
        } catch (e: Exception) {
            println("WebSocket connection error: ${e.message}")
            result.error("CONNECTION_FAILED", "Failed to connect: ${e.message}", null)
        }
    }

    private fun configureUnsafeConnection(builder: OkHttpClient.Builder) {
        try {
            // Create a trust manager that does not validate certificate chains
            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
                override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
                override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
            })

            // Install the all-trusting trust manager
            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(null, trustAllCerts, java.security.SecureRandom())

            // Create an ssl socket factory with our all-trusting manager
            val sslSocketFactory = sslContext.socketFactory

            builder.sslSocketFactory(sslSocketFactory, trustAllCerts[0] as X509TrustManager)
            builder.hostnameVerifier { _, _ -> true }
        } catch (e: Exception) {
            println("SSL configuration failed: ${e.message}")
        }
    }

    private fun startAutoReconnect() {
        stopAutoReconnect()
        reconnectJob = CoroutineScope(Dispatchers.IO).launch {
            var attempt = 0
            while (isActive && isInBackground && currentUrl != null) {
                delay(calculateReconnectDelay(attempt))
                attempt++

                println("Attempting to reconnect (attempt $attempt)")
                try {
                    connectWebSocket(currentUrl!!, currentHeaders, object : Result {
                        override fun success(result: Any?) {
                            println("Reconnection successful")
                            stopAutoReconnect()
                        }
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            println("Reconnection failed: $errorMessage")
                        }
                        override fun notImplemented() {}
                    })
                } catch (e: Exception) {
                    println("Reconnection error: ${e.message}")
                }

                // Stop trying after 5 attempts
                if (attempt >= 5) {
                    println("Max reconnection attempts reached")
                    break
                }
            }
        }
    }

    private fun stopAutoReconnect() {
        reconnectJob?.cancel()
        reconnectJob = null
    }

    private fun calculateReconnectDelay(attempt: Int): Long {
        return when (attempt) {
            0 -> 5000L // 5 seconds
            1 -> 10000L // 10 seconds
            2 -> 15000L // 15 seconds
            else -> 30000L // 30 seconds max
        }
    }

    private fun disconnectWebSocket(result: Result) {
        try {
            stopAutoReconnect()

            webSocket?.close(1000, "Normal closure")
            client?.dispatcher?.executorService?.shutdown()
            webSocket = null
            client = null

            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECT_FAILED", e.message, null)
        }
    }

    private fun sendMessage(message: String, result: Result) {
        try {
            if (webSocket != null) {
                webSocket?.send(message)
                result.success(true)
            } else {
                result.error("NOT_CONNECTED", "WebSocket is not connected", null)
            }
        } catch (e: Exception) {
            result.error("SEND_FAILED", e.message, null)
        }
    }

    private fun getConnectionStatus(result: Result) {
        result.success(webSocket != null)
    }

    private fun setBackgroundMode(enabled: Boolean, result: Result) {
        isInBackground = enabled
        if (!enabled) {
            stopAutoReconnect()
        }
        result.success(true)
    }

    private fun startBackgroundService(result: Result) {
        try {
            // For now, just enable background mode
            // You can enhance this with actual WorkManager logic later
            isInBackground = true
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_START_FAILED", e.message, null)
        }
    }

    private fun stopBackgroundService(result: Result) {
        try {
            // For now, just disable background mode
            isInBackground = false
            stopAutoReconnect()
            result.success(true)
        } catch (e: Exception) {
            result.error("SERVICE_STOP_FAILED", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        disconnectWebSocket(object : Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
    }
}

class SocketWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        // Background socket logic can be implemented here
        // For now, just return success
        return Result.success()
    }
}