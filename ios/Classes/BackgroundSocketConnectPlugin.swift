import Flutter
import UIKit
import Network

public class BackgroundSocketConnectPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var connection: NWConnection?
    private var host: NWEndpoint.Host?
    private var port: NWEndpoint.Port?
    private var isInBackground = false
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var currentUrl: String?
    private var currentHeaders: [String: String] = [:]
    private var isConnected = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "background_socket_connect", binaryMessenger: registrar.messenger())
        let instance = BackgroundSocketConnectPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Setup background task notification
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        print("App entered background")
        if isInBackground && isConnected {
            startBackgroundTask()
        }
    }

    @objc private func appWillEnterForeground() {
        print("App entered foreground")
        stopBackgroundTask()
    }

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopBackgroundTask()
        }
    }

    private func stopBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let arguments = call.arguments as? [String: Any],
                  let url = arguments["url"] as? String else {
                result(FlutterError(code: "INVALID_URL", message: "URL is required", details: nil))
                return
            }
            let headers = arguments["headers"] as? [String: String] ?? [:]
            connectToWebSocket(url: url, headers: headers, result: result)

        case "disconnect":
            disconnectWebSocket(result: result)

        case "sendMessage":
            guard let arguments = call.arguments as? [String: Any],
                  let message = arguments["message"] as? String else {
                result(FlutterError(code: "INVALID_MESSAGE", message: "Message is required", details: nil))
                return
            }
            sendMessage(message: message, result: result)

        case "setBackgroundMode":
            guard let arguments = call.arguments as? [String: Any],
                  let enabled = arguments["enabled"] as? Bool else {
                result(FlutterError(code: "INVALID_PARAM", message: "Enabled parameter is required", details: nil))
                return
            }
            setBackgroundMode(enabled: enabled, result: result)

        case "getConnectionStatus":
            getConnectionStatus(result: result)

        case "startBackgroundService":
            startBackgroundService(result: result)

        case "stopBackgroundService":
            stopBackgroundService(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func connectToWebSocket(url: String, headers: [String: String], result: @escaping FlutterResult) {
        // Clean up existing connection
        disconnectWebSocket { _ in }

        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid URL format", details: nil))
            return
        }

        self.currentUrl = url
        self.currentHeaders = headers
        self.host = NWEndpoint.Host(host)

        // Determine port
        if let port = urlComponents.port {
            self.port = NWEndpoint.Port(rawValue: UInt16(port))
        } else {
            self.port = urlComponents.scheme == "wss" ? NWEndpoint.Port.https : NWEndpoint.Port.http
        }

        let parameters: NWParameters
        if urlComponents.scheme == "wss" {
            parameters = NWParameters.tls
        } else {
            parameters = NWParameters.tcp
        }

        // Add custom headers to the request
        if let query = urlComponents.query {
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: self.host!, port: self.port!)
        }

        connection = NWConnection(host: self.host!, port: self.port!, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                print("WebSocket connection opened successfully")
                self.isConnected = true
                self.reconnectAttempts = 0
                self.stopReconnectTimer()
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onConnected", arguments: nil)
                }
                self.receiveMessage()

            case .failed(let error):
                print("WebSocket connection failed: \(error.localizedDescription)")
                self.isConnected = false
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                }
                self.handleConnectionFailure()

            case .cancelled:
                print("WebSocket connection cancelled")
                self.isConnected = false
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onDisconnected", arguments: ["code": 1000, "reason": "Cancelled"])
                }
                self.stopReconnectTimer()

            case .waiting(let error):
                print("WebSocket connection waiting: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onError", arguments: ["error": "Connection waiting: \(error.localizedDescription)"])
                }

            case .preparing:
                print("WebSocket connection preparing")

            default:
                break
            }
        }

        connection?.start(queue: .global())
        result(true)
    }

    private func handleConnectionFailure() {
        if isInBackground {
            startReconnectTimer()
        }
    }

    private func startReconnectTimer() {
        stopReconnectTimer()

        let delay = calculateReconnectDelay(attempt: reconnectAttempts)
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self,
                  self.isInBackground,
                  let url = self.currentUrl else { return }

            if self.reconnectAttempts <= 5 {
                print("Attempting to reconnect (attempt \(self.reconnectAttempts))")
                self.connectToWebSocket(url: url, headers: self.currentHeaders) { _ in }
            } else {
                print("Max reconnection attempts reached")
                self.stopReconnectTimer()
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func calculateReconnectDelay(attempt: Int) -> TimeInterval {
        switch attempt {
        case 0: return 5.0    // 5 seconds
        case 1: return 10.0   // 10 seconds
        case 2: return 15.0   // 15 seconds
        default: return 30.0  // 30 seconds max
        }
    }

    private func receiveMessage() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .utf8) {
                    print("WebSocket message received: \(message)")
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("onMessage", arguments: ["message": message])
                    }

                    // Ignore ping messages - don't respond
                    if message.contains("ping") || message.contains("\"type\":\"ping\"") {
                        // Server sends ping but doesn't expect response
                        print("Ignoring server ping message")
                    }
                }
            }

            if let error = error {
                print("WebSocket receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                }
                return
            }

            if isComplete {
                print("WebSocket connection completed")
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onDisconnected", arguments: ["code": 1000, "reason": "Connection completed"])
                }
                return
            }

            // Continue receiving messages
            if self.isConnected {
                self.receiveMessage()
            }
        }
    }

    private func disconnectWebSocket(result: @escaping FlutterResult) {
        stopReconnectTimer()
        reconnectAttempts = 0

        connection?.cancel()
        connection = nil
        isConnected = false

        stopBackgroundTask()

        result(true)
    }

    private func sendMessage(message: String, result: @escaping FlutterResult) {
        guard let connection = connection, isConnected else {
            result(FlutterError(code: "NOT_CONNECTED", message: "WebSocket is not connected", details: nil))
            return
        }

        let data = message.data(using: .utf8)
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        })
    }

    private func setBackgroundMode(enabled: Bool, result: @escaping FlutterResult) {
        isInBackground = enabled
        if !enabled {
            stopReconnectTimer()
        }
        result(true)
    }

    private func getConnectionStatus(result: @escaping FlutterResult) {
        result(isConnected)
    }

    private func startBackgroundService(result: @escaping FlutterResult) {
        // On iOS, we enable background mode
        isInBackground = true
        startBackgroundTask()
        result(true)
    }

    private func stopBackgroundService(result: @escaping FlutterResult) {
        isInBackground = false
        stopBackgroundTask()
        stopReconnectTimer()
        result(true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopReconnectTimer()
        disconnectWebSocket { _ in }
    }
}