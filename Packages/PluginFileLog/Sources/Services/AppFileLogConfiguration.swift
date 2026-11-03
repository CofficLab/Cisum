import Foundation

struct AppFileLogConfiguration: FileLogConfiguration {
    private let logsDir: URL

    init(logsDirectory: URL) {
        self.logsDir = logsDirectory
    }

    func logsDirectory() -> URL {
        logsDir
    }
}
