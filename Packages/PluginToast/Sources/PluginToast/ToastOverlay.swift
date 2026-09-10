import ProviderToast
import SwiftUI

public struct ToastOverlay<Content: View>: View {
    private let content: Content
    @ObservedObject private var center: ToastProvider

    public init(content: Content, center: ToastProvider) {
        self.content = content
        self.center = center
    }

    public var body: some View {
        content
            .overlay(alignment: .top) {
                Group {
                    if let toast = center.currentToast {
                        ToastCard(toast: toast)
                    } else if let loading = center.currentLoading {
                        LoadingCard(notice: loading)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: center.currentToast)
                .animation(.spring(duration: 0.3), value: center.currentLoading)
                .allowsHitTesting(false)
            }
            .overlay {
                if let error = center.currentError {
                    ErrorNoticeOverlay(error: error, center: center)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
    }
}

public extension View {
    func withToastOverlay(center: ToastProvider) -> some View {
        ToastOverlay(content: self, center: center)
    }
}

private struct ToastCard: View {
    let toast: CisumToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.systemImage)
                .foregroundStyle(toast.style.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let detail = toast.detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct LoadingCard: View {
    let notice: CisumLoadingNotice

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let detail = notice.detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct ErrorNoticeOverlay: View {
    let error: CisumErrorNotice
    @ObservedObject var center: ToastProvider

    var body: some View {
        GeometryReader { geometry in
            let outerInset = min(28, max(16, min(geometry.size.width, geometry.size.height) * 0.06))
            let cardWidth = min(720, max(0, geometry.size.width - outerInset * 2))
            let cardHeight = min(520, max(0, geometry.size.height - outerInset * 2))
            let contentInset = min(24, max(12, cardWidth * 0.06))

            ZStack {
                Color.black.opacity(0.22).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        Text(error.title)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 12)
                    }
                    Divider().padding(.vertical, 16)
                    Text("Error details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                    ScrollView {
                        Text(error.message)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button("Copy error") { copy(error.message) }
                            .buttonStyle(.borderless)
                        Spacer()
                        Button("Close") { center.dismissError() }
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 18)
                }
                .padding(contentInset)
                .frame(width: cardWidth, height: cardHeight)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .zIndex(1)
    }

    private func copy(_ message: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message, forType: .string)
        #endif
    }
}

private extension CisumToastStyle {
    var systemImage: String {
        switch self {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    var tint: Color {
        switch self {
        case .info: .accentColor
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
