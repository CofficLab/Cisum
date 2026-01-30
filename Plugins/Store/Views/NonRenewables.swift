import MagicKit
import OSLog
import StoreKit
import SwiftUI

struct NonRenewables: View {
    @EnvironmentObject var app: AppProvider

    @State private var nonRenewables: [ProductDTO] = []
    @State private var refreshing = false
    @State private var error: Error? = nil

    var body: some View {
        GroupBox {
            VStack {
                ZStack {
                    Text("一次性产品").font(.title3)
                    refreshButton
                }

                Divider()

                if refreshing == false && nonRenewables.isEmpty {
                    Text("☹️ 暂不能从App Store获取产品列表")
                } else {
                    VStack {
                        ForEach(nonRenewables) { product in
                            ProductCell(product: product)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(MagicBackground.aurora.opacity(0.1))
        .onAppear {
            getProducts("AllSubscription OnAppear")
        }
    }

    private var refreshButton: some View {
        HStack {
            Spacer()
            ZStack {
                if refreshing {
                    ProgressView().scaleEffect(0.4)
                } else {
                    Button(action: {
                        getProducts("点击了重试按钮")
                    }, label: {
                        Label("重试", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }).buttonStyle(.plain)
                }
            }.frame(width: 30, height: 10)
        }
    }

    // MARK: 获取可用的订阅

    private func getProducts(_ reason: String) {
        refreshing = true

        Task {
            do {
                let groups = try await StoreService.fetchAllProducts()
                self.nonRenewables = groups.nonRenewables
            } catch {
                self.error = error
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                refreshing = false
            })
        }
    }
}

// MARK: - Preview

#Preview("PurchaseView - All") {
    PurchaseView()
        .inRootView()
        .frame(height: 800)
}

#Preview("PurchaseView - Subscription Only") {
    PurchaseView(
                 showSubscription: true,
                 showOneTime: false,
                 showNonRenewable: false,
                 showConsumable: false)
        .inRootView()
        .frame(height: 800)
}

#Preview("Store Debug") {
    DebugView()
        .inRootView()
        .frame(width: 500, height: 700)
}

#Preview("Debug") {
    DebugView()
        .inRootView()
        .frame(height: 800)
}

#Preview("Buy") {
    PurchaseView()
        .inRootView()
        .frame(height: 800)
}

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
            .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif
