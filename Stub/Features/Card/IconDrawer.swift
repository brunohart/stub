import SwiftUI
import StoreKit
import OSLog

/// The icon drawer (ADR-028): the ten icons drawn for Stub, and the one payment that opens them. Torn is the app's own and
/// always there; the other nine are the person's to choose once they have bought the drawer, once, for good. No
/// subscription, nothing else for sale, nothing in the app that needs it. StoreKit 2: the purchase is the phone's own
/// record of it, checked when Your card opens and whenever the App Store says it changed.
@MainActor @Observable
final class IconDrawer {
    static let shared = IconDrawer()
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "icons")
    /// A non-consumable in App Store Connect (BEDIP-217's list), and in `Stub.storekit` for the simulator.
    static let productID = "com.designedbybruno.stub.icons"

    struct Icon: Identifiable, Equatable {
        let name: String
        /// The alternate icon's name in the asset catalogue; `nil` for the app's own.
        let alternate: String?
        var id: String { name }
        /// The small copy the chooser shows.
        var preview: String { "Icon-\(name)" }
    }

    /// In the order they were drawn (scripts/make-icons.swift): Torn first, the app's own.
    static let icons: [Icon] = ["Torn", "Roll", "Label", "Riso", "Punched", "Letterpress", "Edition", "Marquee", "Hand", "Scallop"]
        .enumerated().map { i, name in Icon(name: name, alternate: i == 0 ? nil : "AppIcon-\(name)") }

    private(set) var product: Product?
    private(set) var owned = false
    private(set) var current: String? = UIApplication.shared.alternateIconName
    private(set) var buying = false
    /// What went wrong, in words, when it did.
    var failure: String?
    @ObservationIgnored private var updates: Task<Void, Never>?

    /// The price as the App Store shows it here, or the price it is set at while the store has not answered.
    var price: String { product?.displayPrice ?? "$4.99" }

    var currentIcon: Icon { Self.icons.first { $0.alternate == current } ?? Self.icons[0] }

    /// Asks the store for the product and the phone for the purchase, and listens for a purchase made elsewhere (another
    /// phone, Ask to Buy, a refund).
    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update { await transaction.finish() }
                    await self?.refresh()
                }
            }
        }
        if product == nil {
            do { product = try await Product.products(for: [Self.productID]).first } catch {
                Self.log.error("Icons: the store did not answer: \(error.localizedDescription)")
            }
        }
        await refresh()
    }

    func refresh() async {
        var has = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.productID == Self.productID, transaction.revocationDate == nil {
                has = true
            }
        }
        #if DEBUG
        // `-icons`: the drawer open without a purchase, for screenshots in a simulator that has no store.
        if ProcessInfo.processInfo.arguments.contains("-icons") { has = true }
        #endif
        owned = has
    }

    func buy() async {
        guard let product else {
            failure = "The App Store cannot be reached just now. Try again in a moment."
            return
        }
        buying = true
        defer { buying = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                owned = true
                Self.log.info("Icons: bought")
            case .success(.unverified):
                failure = "The App Store could not confirm the purchase."
            case .pending:
                failure = "The purchase is waiting for approval."
            default:
                break
            }
        } catch {
            failure = "The purchase did not go through."
            Self.log.error("Icons: purchase failed: \(error.localizedDescription)")
        }
    }

    func restore() async {
        do { try await AppStore.sync() } catch { failure = "Your purchases could not be restored just now." }
        await refresh()
    }

    /// Puts the icon on the home screen. The app's own is always there; the others once the drawer is bought.
    func choose(_ icon: Icon) async {
        guard owned || icon.alternate == nil, icon.alternate != current else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternate)
            current = UIApplication.shared.alternateIconName
        } catch {
            failure = "The icon could not be changed."
            Self.log.error("Icons: \(error.localizedDescription)")
        }
    }
}
