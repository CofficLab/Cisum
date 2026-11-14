import SwiftUI

extension AvatarView {
    /// 错误指示视图组件
    struct ErrorView: View {
        let error: Error
        let url: URL
        let shape: AvatarViewShape
        let size: CGSize
        let backgroundColor: Color
        @State private var showError = false
        @State private var errorCopied = false
        @State private var urlCopied = false
        @State private var isHovered = false

        var body: some View {
            let iconSize = size.width * 0.4  // 图标大小为容器大小的 40%

            return Image.warning
                .font(.system(size: iconSize))
                .foregroundStyle(.red.opacity(isHovered ? 0.7 : 1.0))
                .frame(width: size.width, height: size.height)
                .background(backgroundColor)
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(color: Color.red.opacity(0.5))
                }
                .onHover { hovering in
                    isHovered = hovering
                }
                .popover(isPresented: $showError) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Error Details", bundle: .module)
                            .font(.headline)

                        Divider()

                        Text(error.localizedDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)

                        Divider()

                        Text("File URL", bundle: .module)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(url.absoluteString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .textSelection(.enabled)

                        Divider()

                        HStack(spacing: 12) {
                            Button(action: {
                                error.copy()
                                errorCopied = true

                                // 2秒后重置复制状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    errorCopied = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: errorCopied ? .iconCheckmark : .iconCopy)
                                    Text(errorCopied ? "Copied" : "Copy Error")
                                }
                                .foregroundStyle(errorCopied ? .green : .accentColor)
                            }
                            .buttonStyle(.borderless)

                            Button(action: {
                                url.absoluteString.copy()
                                urlCopied = true

                                // 2秒后重置复制状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    urlCopied = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: urlCopied ? .iconCheckmark : .iconCopy)
                                    Text(urlCopied ? "Copied" : "Copy URL")
                                }
                                .foregroundStyle(urlCopied ? .green : .accentColor)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding()
                    .frame(minWidth: 250, maxWidth: 400)
                }
                .onTapGesture {
                    showError = true
                }
        }
    }
}

