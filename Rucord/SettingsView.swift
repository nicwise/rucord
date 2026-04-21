import SwiftUI
import StoreKit

enum TipJar: String, CaseIterable {
    case coffee = "nz.fastchicken.rucord.tip.coffee"
    case lunch = "nz.fastchicken.rucord.tip.lunch"
    case dinner = "nz.fastchicken.rucord.tip.dinner"

    var name: String {
        switch self {
        case .coffee:
            return "Buy me a coffee"
        case .lunch:
            return "Buy me lunch"
        case .dinner:
            return "Buy me dinner"
        }
    }

    var emoji: String {
        switch self {
        case .coffee:
            return "☕️"
        case .lunch:
            return "🥪"
        case .dinner:
            return "🍽️"
        }
    }

    static func fetchProducts() async -> [Self: Product] {
        do {
            let productIDs = Self.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIDs)
            var results: [Self: Product] = [:]
            for product in products {
                if let tip = TipJar(rawValue: product.id) {
                    results[tip] = product
                }
            }
            return results
        } catch {
            print("Error fetching products: \(error)")
            return [:]
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let purchaseResult = try await product.purchase()
            switch purchaseResult {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    await transaction.finish()
                    return true
                default:
                    return false
                }
            default:
                return false
            }
        } catch {
            print("Purchase error: \(error)")
            return false
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tipProducts: [TipJar: Product] = [:]
    @State private var productsFetched = false
    @State private var pendingPurchase: TipJar?
    @State private var showingSuccessAlert = false

    private let websiteURL = URL(string: "https://fastchicken.co.nz/rucord")!

    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    HStack {
                        Image(systemName: "car.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rucord")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("RUC tracking made simple")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text("Created by")
                        Spacer()
                        Text("Nic Wise")
                            .foregroundStyle(.secondary)
                    }

                    Link("Rucord website", destination: websiteURL)
                        .foregroundStyle(.blue)
                }

                Section("Support Development") {
                    ForEach(TipJar.allCases, id: \.self) { tip in
                        Button(
                            action: { purchaseTip(tip) },
                            label: {
                                HStack {
                                    Text("\(tip.name) \(tip.emoji)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let product = tipProducts[tip] {
                                        if pendingPurchase == tip {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Text(product.displayPrice)
                                                .foregroundStyle(.blue)
                                        }
                                    } else if productsFetched {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                        )
                        .disabled(tipProducts[tip] == nil || pendingPurchase != nil)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                let products = await TipJar.fetchProducts()
                await MainActor.run {
                    withAnimation {
                        tipProducts = products
                        productsFetched = true
                    }
                }
            }
            .alert("Thank you!", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Thanks for supporting Rucord!")
            }
        }
    }

    private func purchaseTip(_ tip: TipJar) {
        guard pendingPurchase == nil,
              let product = tipProducts[tip] else {
            return
        }

        withAnimation {
            pendingPurchase = tip
        }

        Task {
            let success = await tip.purchase(product)
            await MainActor.run {
                withAnimation {
                    if success {
                        showingSuccessAlert = true
                    }
                    pendingPurchase = nil
                }
            }
        }
    }
}
