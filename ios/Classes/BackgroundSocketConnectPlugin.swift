import Flutter
import UIKit
import Network

public class BackgroundSocketConnectPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var connection: NWConnection?
    private var host: NWEndpoint.Host?
    private var port: NWEndpoint.Port?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "background_socket_connect", binaryMessenger: registrar.messenger())
        let instance = BackgroundSocketConnectPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
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

        case "startBackgroundService":
            startBackgroundService(result: result)

        case "stopBackgroundService":
            stopBackgroundService(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func connectToWebSocket(url: String, headers: [String: String], result: @escaping FlutterResult) {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host,
              let port = urlComponents.port else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid URL format", details: nil))
            return
        }

        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: UInt16(port))!

        let parameters = NWParameters.tcp
        if urlComponents.scheme == "wss" {
            parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolTLS.Options(), at: 0)
        }

        connection = NWConnection(host: self.host!, port: self.port!, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.channel?.invokeMethod("onConnected", arguments: nil)
                self.receiveMessage()
            case .failed(let error):
                self.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
            case .cancelled:
                self.channel?.invokeMethod("onDisconnected", arguments: ["code": 1000, "reason": "Cancelled"])
            default:
                break
            }
        }

        connection?.start(queue: .global())
        result(true)
    }

    private func disconnectWebSocket(result: @escaping FlutterResult) {
        connection?.cancel()
        connection = nil
        result(true)
    }

    private func sendMessage(message: String, result: @escaping FlutterResult) {
        guard let connection = connection else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Socket not connected", details: nil))
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

    private func receiveMessage() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, let message = String(data: data, encoding: .utf8) {
                self.channel?.invokeMethod("onMessage", arguments: ["message": message])
            }

            if let error = error {
                self.channel?.invokeMethod("onError", arguments: ["error": error.localizedDescription])
                return
            }

            if isComplete {
                self.channel?.invokeMethod("onDisconnected", arguments: ["code": 1000, "reason": "Connection closed"])
                return
            }

            self.receiveMessage()
        }
    }

    private func startBackgroundService(result: @escaping FlutterResult) {
        // iOS background service implementation
        // Note: iOS has stricter background execution rules
        result(true)
    }

    private func stopBackgroundService(result: @escaping FlutterResult) {
        // Stop background service
        result(true)
    }
}