import MagicKit
import SwiftUI

/**
 * App Store - 购买页面，用于创建订阅时的审核
 */
struct AppStorePurchaseView: View {
    var body: some View {
        PurchaseViewDemo()
            .background(
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.pink.opacity(0.15),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 500)
            .frame(width: 500)
            .inDesktop()
    }
}

// MARK: - PurchaseViewDemo

struct PurchaseViewDemo: View {
    var body: some View {
        VStack(spacing: 0) {
            // 订阅选项区域
            subscriptionSection

            Spacer().frame(height: 40)

            // 恢复购买区域
            restoreSection

            Spacer().frame(height: 40)

            // 法律条款区域
            legalSection
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }
}

// MARK: - Subscription Section

extension PurchaseViewDemo {
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cisum Pro")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("2个订阅选项")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("ID: CISUM001")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)

            // 订阅选项
            VStack(spacing: 16) {
                subscriptionOption(
                    title: "专业版按月订阅",
                    productId: "com.coffic.cisum.monthly",
                    offer: "首月免费",
                    price: "¥6.00/月"
                )

                subscriptionOption(
                    title: "专业版按年订阅",
                    productId: "com.coffic.cisum.annual",
                    offer: "首3月免费",
                    price: "¥58.00/年"
                )
            }
        }
        .padding(20)
        .background(Color(red: 0.95, green: 0.96, blue: 0.98))
        .cornerRadius(12)
    }

    private func subscriptionOption(title: String, productId: String, offer: String, price: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(productId)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(offer)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Spacer()

            Button(action: {}) {
                Text(price)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Restore Section

extension PurchaseViewDemo {
    private var restoreSection: some View {
        VStack(spacing: 16) {
            Text("恢复购买")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("如果您之前在其他设备上购买过订阅,可以通过点击下方的\"恢复购买\"按钮来恢复您的订阅。请确保您使用的是购买时所用的Apple ID 账号。")
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)

            Button(action: {}) {
                Text("恢复购买")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Legal Section

extension PurchaseViewDemo {
    private var legalSection: some View {
        HStack(spacing: 20) {
            Text("隐私政策")
                .font(.body)
                .foregroundColor(.primary)

            Text("许可协议")
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview("App Store PurchaseView") {
    AppStorePurchaseView()
        .inMagicContainer(.macBook13, scale: 0.5)
        .colorScheme(.light)
}
