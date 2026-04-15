//
//  SettingsOption.swift
//  MoreKit
//

import Foundation

extension Notification.Name {
    public static let SettingsUpdate = Notification.Name(rawValue: "com.zizicici.common.settings.updated")
}

// MARK: - SettingsOption

public protocol SettingsOption: Hashable, Equatable {
    func getName() -> String
    static func getTitle() -> String
    static func getHeader() -> String?
    static func getFooter() -> String?
    static func getOptions() -> [Self]
    static var current: Self { get }
    static func setCurrent(_ value: Self) throws
}

extension SettingsOption {
    public static func getHeader() -> String? { nil }
    public static func getFooter() -> String? { nil }
}

extension SettingsOption {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if type(of: lhs) != type(of: rhs) {
            return false
        } else {
            return lhs.getName() == rhs.getName()
        }
    }
}

// MARK: - UserDefaultSettable

public protocol UserDefaultSettable: SettingsOption {
    static func getKey() -> String
    static var defaultOption: Self { get }
    static var userDefaults: UserDefaults { get }
}

extension UserDefaultSettable {
    public static var userDefaults: UserDefaults {
        MoreKit.appGroupUserDefaults ?? .standard
    }
}

extension UserDefaultSettable where Self: RawRepresentable, Self.RawValue == Int {
    public static func getValue() -> Self {
        if let raw = userDefaults.object(forKey: getKey()) as? Int,
           let value = Self(rawValue: raw) {
            return value
        }
        return defaultOption
    }

    public static func setValue(_ value: Self) {
        userDefaults.set(value.rawValue, forKey: getKey())
        NotificationCenter.default.post(name: .SettingsUpdate, object: nil)
    }

    public static var current: Self {
        getValue()
    }

    public static func setCurrent(_ value: Self) throws {
        setValue(value)
    }

    public static func getOptions<T: CaseIterable>() -> [T] {
        Array(T.allCases)
    }
}

// MARK: - UserDefaults Helpers

extension UserDefaults {
    public func getInt(forKey key: String) -> Int? {
        object(forKey: key) as? Int
    }

    public func getBool(forKey key: String) -> Bool? {
        object(forKey: key) as? Bool
    }

    public func getString(forKey key: String) -> String? {
        object(forKey: key) as? String
    }
}
