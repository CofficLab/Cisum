import Foundation

public enum HttpError: Error, LocalizedError {
    case ShellError(output: String)
    case HttpNoResponse
    case HttpStatusError(Int)
    case HttpNoData
    case RequestCancelled
    
    public var errorDescription: String? {
        switch self {
        case .ShellError(let output):
            return output
        case .HttpNoResponse:
            return "HTTP request failed: no response"
        case .HttpStatusError(let code):
            return "HTTP request failed with status code: \(code)"
        case .HttpNoData:
            return "HTTP request failed: no data"
        case .RequestCancelled:
            return "HTTP request was cancelled"
        }
    }
}
