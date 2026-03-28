import Foundation

/// Simple logging service that writes to a log file
class LogService {
    static let shared = LogService()
    
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.copilot-accountant.logging", qos: .utility)
    
    private init() {
        // Create log file in Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CopilotAccountant")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        logFileURL = appDir.appendingPathComponent("copilot-accountant.log")
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Log startup
        log("=== Copilot Accountant Started ===", level: .info)
        log("Log file: \(logFileURL.path)", level: .info)
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)\n"
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Also print to console for debugging
            print(logMessage, terminator: "")
            
            // Append to log file
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }
        }
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    /// Get the log file path for display
    var logFilePath: String {
        return logFileURL.path
    }
    
    /// Read recent log entries
    func getRecentLogs(lines: Int = 100) -> String {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return "No logs available"
        }
        
        let allLines = content.components(separatedBy: "\n")
        let recentLines = allLines.suffix(lines)
        return recentLines.joined(separator: "\n")
    }
    
    /// Clear the log file
    func clearLogs() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        log("=== Logs Cleared ===", level: .info)
    }
}

// Convenience global function
func appLog(_ message: String, level: LogService.LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
    LogService.shared.log(message, level: level, file: file, function: function, line: line)
}
