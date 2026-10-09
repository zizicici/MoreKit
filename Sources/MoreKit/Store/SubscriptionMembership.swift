import Foundation

/// A verified auto-renewable entitlement. Turning off renewal does not end access early.
public struct SubscriptionMembership: Codable, Equatable, Sendable {
    public let productID: String
    public let expirationDate: Date
    public let gracePeriodExpirationDate: Date?
    public let willAutoRenew: Bool?

    public var accessExpirationDate: Date { gracePeriodExpirationDate ?? expirationDate }

    public func isActive(at date: Date = Date()) -> Bool { accessExpirationDate > date }

    internal init(productID: String, expirationDate: Date,
                  gracePeriodExpirationDate: Date? = nil, willAutoRenew: Bool? = nil) {
        self.productID = productID
        self.expirationDate = expirationDate
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
        self.willAutoRenew = willAutoRenew
    }
}

/// Keep expiring access separate from the legacy lifetime Boolean, including in app extensions.
struct MembershipCache {
    let defaults: UserDefaults
    let key: String

    var subscriptions: [SubscriptionMembership] {
        guard let data = defaults.data(forKey: key + ".subscriptions.v1"),
              let values = try? JSONDecoder().decode([SubscriptionMembership].self, from: data) else { return [] }
        return values
    }

    func tier(at date: Date = Date()) -> ProTier {
        if defaults.bool(forKey: key) { return .lifetime }
        return subscriptions.contains { $0.isActive(at: date) } ? .subscription : .none
    }

    func write(lifetime: Bool, subscriptions: [SubscriptionMembership]) {
        defaults.set(lifetime, forKey: key)
        if let data = try? JSONEncoder().encode(subscriptions) {
            defaults.set(data, forKey: key + ".subscriptions.v1")
        }
    }
}

enum SubscriptionScanOutcome: Equatable {
    case active(SubscriptionMembership)
    case inactive
    case missing
}
