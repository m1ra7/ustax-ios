import Foundation

struct Staff: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    let active: Bool
    var isAdmin: Bool { role == "admin" }
}
struct Customer: Codable, Identifiable {
    let id: String
    let name: String
    let phone: String
    let email: String
}
struct ServiceEvent: Codable, Identifiable {
    let id: String
    let at: String
    let actor: String?
    let text: String
    var deletedAt: String? = nil
    var deletedBy: String? = nil
    let `internal`: Bool
}
struct Part: Codable, Identifiable {
    var name: String
    var amount: Int
    var id: String { name + ":" + String(amount) }
}
struct Quote: Codable, Identifiable {
    var deletedAt: String? = nil
    var deletedBy: String? = nil
    let version: Int
    let diagnosis: String
    let work: String
    let parts: [Part]
    let labor: Int
    let total: Int
    let eta: String
    let decision: String
    let decidedAt: String?
    var id: Int { version }
}
struct ServicePhoto: Codable, Identifiable {
    let id: String
    let publicId: String?
    let format: String
    let phase: String
    let visible: Bool
}
struct Completion: Codable {
    let work: String
    let parts: String
    let fee: Int
    let warranty: String
    let completedAt: String
    let deliveredAt: String?
    let deliveryNote: String?
}
struct ServiceRecord: Codable, Identifiable {
    var warning: String? = nil
    var currency: String? = nil
    var currencyCode: String { Currency.code(currency) }
    let id: String
    let number: String
    let customerId: String
    let deviceId: String
    let name: String
    let phone: String
    let email: String
    let kind: String
    let brand: String
    let model: String
    let serial: String
    let fault: String
    let condition: String
    let accessories: String
    let technician: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let eta: String
    let events: [ServiceEvent]
    let quotes: [Quote]
    let photos: [ServicePhoto]
    let completion: Completion?
    var device: String { "\(brand) \(model)" }
    var isActive: Bool { !["Teslim edildi", "İptal edildi"].contains(status) }
    var displayStatus: String { status == "Fiyat onayı bekliyor" && latestQuote?.decision == "approved" ? "Müşteri onayladı" : status }
    var visibleQuotes: [Quote] { quotes.filter { $0.deletedAt == nil } }
    var latestQuote: Quote? { guard let latest = quotes.last, latest.deletedAt == nil else { return nil }; return latest }
}
struct TrackingRecord: Decodable {
    var currency: String? = nil
    var currencyCode: String { Currency.code(currency) }
    var displayStatus: String { status == "Fiyat onayı bekliyor" && quotes.last?.deletedAt == nil && quotes.last?.decision == "approved" ? "Müşteri onayladı" : status }
    let number: String
    let kind: String
    let brand: String
    let model: String
    let status: String
    let createdAt: String
    let eta: String
    let events: [ServiceEvent]
    let quotes: [Quote]
    let photos: [ServicePhoto]
    let completion: Completion?
}
struct CreatedRecord: Decodable { let data: ServiceRecord; let token: String }
struct TokenResult: Decodable { let token: String }
struct ChallengeResult: Decodable { let challengeId: String; let message: String }
struct Health: Decodable { let database: Bool; let photos: Bool; let email: Bool; let auth: String? }
struct Ack: Decodable {}
struct APIMessage: Decodable { let error: String? }
struct AppError: LocalizedError {
    let message: String
    let status: Int?
    init(_ message: String, status: Int? = nil) { self.message = message; self.status = status }
    var errorDescription: String? { message }
}

enum Workflow {
    static let statuses = ["Teslim alındı", "İnceleniyor", "Fiyat onayı bekliyor", "Tamir ediliyor", "Parça bekleniyor", "Teslime hazır", "Teslim edildi", "Teklif reddedildi", "İptal edildi"]
    static var filterStatuses: [String] { statuses + ["Müşteri onayladı"] }
    static let transitions: [String: [String]] = [
        "Teslim alındı": ["İnceleniyor", "İptal edildi"],
        "İnceleniyor": ["İptal edildi"],
        "Fiyat onayı bekliyor": ["Tamir ediliyor", "İptal edildi"],
        "Tamir ediliyor": ["Parça bekleniyor", "İptal edildi"],
        "Parça bekleniyor": ["Tamir ediliyor", "İptal edildi"],
        "Teklif reddedildi": ["İptal edildi"]
    ]
    static func available(_ record: ServiceRecord) -> [String] {
        (transitions[record.status] ?? []).filter { $0 != "Tamir ediliyor" || record.latestQuote?.decision == "approved" }
    }
    static func canDeleteQuote(_ quote: Quote, record: ServiceRecord) -> Bool {
        quote.deletedAt == nil && (quote.version != record.quotes.last?.version || !["Tamir ediliyor", "Parça bekleniyor", "Teslime hazır", "Teslim edildi"].contains(record.status))
    }
    static func canQuote(_ record: ServiceRecord) -> Bool { !["Teslim alındı", "Teslim edildi", "İptal edildi"].contains(record.status) }
    static func cents(_ text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard normalized.range(of: "^[0-9]+(?:\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value <= 1000000 else { return nil }
        return NSDecimalNumber(decimal: value * 100).intValue
    }
    static func trackingToken(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String
        if let url = URL(string: value), url.scheme != nil {
            let components = url.pathComponents
            guard components.count == 3, components[1] == "takip" else { return nil }
            candidate = components[2]
        } else { candidate = value }
        guard candidate.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { return nil }
        return candidate
    }
}

// Amounts remain integer minor units. Currency is fixed at intake; no exchange conversion.
enum Currency {
    static let codes = ["EUR", "TRY", "USD"]
    static func code(_ value: String?) -> String { codes.contains(value ?? "") ? value! : "TRY" }
    static func title(_ value: String) -> String {
        switch value { case "EUR": return "Euro (€)"; case "USD": return "ABD doları ($)"; default: return "Türk lirası (₺)" }
    }
}
