//
//  StoreManager.swift
//  ZapCal
//
//  Created by Harsh Kalra on 4/6/26.
//

import Foundation
import StoreKit
import Combine
import AppKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let productID = "spotlessmindsoftware.ZapCal.fullversion"

    @Published var product: Product?
    @Published var isPurchased: Bool = false
    @Published var purchaseInProgress: Bool = false
    @Published var purchaseError: String?
    @Published var justPurchased: Bool = false

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await checkPurchaseStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Product

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            print("Failed to load IAP products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase() async {
        // Retry loading product if it hasn't loaded yet
        if product == nil {
            print("[StoreManager] purchase() — product is nil, retrying loadProduct()...")
            await loadProduct()
        }
        guard let product else {
            print("[StoreManager] purchase() — product still nil after retry, aborting")
            purchaseError = "Unable to load product. Please check your internet connection and try again."
            return
        }
        purchaseInProgress = true
        purchaseError = nil

        // StoreKit needs .regular activation policy with a key window to
        // present its confirmation dialog. Switch policy but keep the menu
        // bar panel open so it serves as the window context.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Give the activation policy change time to take effect.
        try? await Task.sleep(nanoseconds: 300_000_000)

        print("[StoreManager] calling product.purchase()...")
        do {
            let result = try await product.purchase()
            print("[StoreManager] purchase result: \(result)")
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = true
                justPurchased = true
                TrialManager.shared.refreshState()
            case .userCancelled:
                print("[StoreManager] user cancelled")
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                print("[StoreManager] unknown result")
            }
        } catch {
            print("[StoreManager] purchase error: \(error)")
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        NSApp.setActivationPolicy(.accessory)
        purchaseInProgress = false
        print("[StoreManager] purchase() completed")

        if justPurchased {
            NotificationCenter.default.post(name: .dismissPopover, object: nil)
            try? await Task.sleep(nanoseconds: 300_000_000)
            NotificationCenter.default.post(name: .openPanel, object: nil)
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkPurchaseStatus()
            TrialManager.shared.refreshState()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Check Purchase Status

    func checkPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                isPurchased = true
                return
            }
        }
        isPurchased = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.productID == StoreManager.productID {
                        await MainActor.run {
                            self?.isPurchased = transaction.revocationDate == nil
                            TrialManager.shared.refreshState()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Verification Helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
