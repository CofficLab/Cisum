import SwiftUI

struct FileExpandButton: View {
    let isDirectory: Bool
    let initialExpanded: Bool  // 初始展开状态
    let onExpandedChange: (Bool) -> Void  // 状态改变时通知外部
    
    @State private var isHovering = false
    @State private var isExpanded: Bool  // 内部维护的展开状态
    
    init(isDirectory: Bool, initialExpanded: Bool = false, onExpandedChange: @escaping (Bool) -> Void) {
        self.isDirectory = isDirectory
        self.initialExpanded = initialExpanded
        self.onExpandedChange = onExpandedChange
        // 初始化 State
        _isExpanded = State(initialValue: initialExpanded)
    }
    
    var body: some View {
        Group {
            if isDirectory {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                        onExpandedChange(isExpanded)  // 通知外部状态变化
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(isHovering ? .primary : .secondary)
                        .frame(width: 16)
                        .scaleEffect(isHovering ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            } else {
                Spacer()
                    .frame(width: 16)
            }
        }
    }
} 
