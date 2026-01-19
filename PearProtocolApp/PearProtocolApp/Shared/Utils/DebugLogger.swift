import Foundation

// MARK: - Debug Logger
/// Utility for writing debug logs to file (NDJSON format)
struct DebugLogger {
    private static let logPath = "/Users/aaronteklu/pearProtocolApp/.cursor/debug.log"
    
    static func log(
        location: String,
        message: String,
        data: [String: Any] = [:],
        hypothesisId: String = "",
        sessionId: String = "debug-session",
        runId: String = "run1"
    ) {
        let payload: [String: Any] = [
            "id": "log_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "location": location,
            "message": message,
            "data": data,
            "sessionId": sessionId,
            "runId": runId,
            "hypothesisId": hypothesisId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let line = jsonString + "\n"
        
        // Append to log file
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            // Create file if it doesn't exist
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8), attributes: nil)
        }
    }
}
