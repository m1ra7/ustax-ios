import SwiftUI
import UIKit

@MainActor final class AppState: ObservableObject {
    @Published var staff: Staff?
    @Published var trackingTokens: [String: String] = [:]
    @Published private(set) var catalog = RecordCatalog()
    var records: [ServiceRecord] { catalog.records }
    private var mutationVersion = 0
    private var restoreInProgress = false
    private var reloadID = UUID()
    private var reloadTask: Task<RecordCatalog, Error>?
    private let amountFormatter = NumberFormatter()
    private let dateFormatter = DateFormatter()
    private let iso = ISO8601DateFormatter()
    private let isoFallback = ISO8601DateFormatter()
    private let dateCache = NSCache<NSString, NSString>()
    private var formatterSignature = ""
    @Published var loading = false
    @Published var error: String?
    @Published var language: String { didSet { UserDefaults.standard.set(language, forKey: "language"); api.language = language } }
    @Published var dark: Bool { didSet { UserDefaults.standard.set(dark, forKey: "dark") } }
    @Published var preferredCurrency: String { didSet { UserDefaults.standard.set(preferredCurrency, forKey: "currency") } }
    @Published var endpoint: String
    let api = APIClient()
    private let translations: [String: [String: String]]
    init() {
        preferredCurrency = Currency.code(UserDefaults.standard.string(forKey: "currency"))
        language = UserDefaults.standard.string(forKey: "language") ?? "tr"
        dark = UserDefaults.standard.object(forKey: "dark") as? Bool ?? (UITraitCollection.current.userInterfaceStyle == .dark)
        endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? ""
        if let url = Bundle.main.url(forResource: "Translations", withExtension: "json"), let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) { translations = decoded } else { translations = [:] }
        api.language = language
        api.baseURL = try? APIClient.validatedURL(endpoint)
        api.onUnauthorized = { [weak self] in self?.staff = nil; self?.clearRecords() }
    }
    var isAdmin: Bool { staff?.isAdmin == true }
    func t(_ key: String) -> String { language == "tr" ? key : translations[key]?[language] ?? key }
    var locale: Locale { Locale(identifier: language == "de" ? "de_DE" : language == "en" ? "en_GB" : "tr_TR") }
    private func prepareFormatters() {
        let signature = language + TimeZone.current.identifier
        guard signature != formatterSignature else { return }
        formatterSignature = signature
        amountFormatter.numberStyle = .currency; amountFormatter.currencyCode = "TRY"; amountFormatter.locale = locale
        dateFormatter.locale = locale; dateFormatter.timeZone = .current
        dateFormatter.dateStyle = .medium; dateFormatter.timeStyle = .short
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateCache.removeAllObjects(); dateCache.countLimit = 512
    }
    func money(_ cents: Int, currency: String = "TRY") -> String {
        prepareFormatters()
        amountFormatter.currencyCode = Currency.code(currency)
        return amountFormatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "₺0"
    }
    func eventText(_ value: String) -> String {
        if language == "tr" { return value }
        if value.hasPrefix("Fiyat teklifi v"), let version = value.split(separator: " ").first(where: { $0.first == "v" }) {
            return language == "de" ? "Kostenvoranschlag \(version) zur Kundenfreigabe eingereicht." : "Quote \(version) submitted for customer approval."
        }
        if value.hasPrefix("Teklif v"), let version = value.split(separator: " ").dropFirst().first {
            if value.hasSuffix("onaylandı.") { return language == "de" ? "Kostenvoranschlag \(version) freigegeben." : "Quote \(version) approved." }
            if value.hasSuffix("reddedildi.") { return language == "de" ? "Kostenvoranschlag \(version) abgelehnt." : "Quote \(version) rejected." }
        }
        return t(value)
    }
    func date(_ value: String) -> String {
        prepareFormatters()
        if let cached = dateCache.object(forKey: value as NSString) { return cached as String }
        guard let parsed = iso.date(from: value) ?? isoFallback.date(from: value) else { return value }
        let text = dateFormatter.string(from: parsed)
        dateCache.setObject(text as NSString, forKey: value as NSString)
        return text
    }
    private func clearRecords() {
        trackingTokens.removeAll(); mutationVersion += 1; reloadID = UUID(); reloadTask?.cancel(); reloadTask = nil; catalog = RecordCatalog()
    }
    func saveEndpoint(_ value: String) async throws {
        let url = try APIClient.validatedURL(value)
        if api.baseURL != url { await api.logout(); staff = nil; clearRecords() }
        api.baseURL = url; endpoint = url.absoluteString
        UserDefaults.standard.set(endpoint, forKey: "endpoint")
        let health: Health = try await api.send("health")
        guard health.database else { throw AppError("Veritabanı bağlantısı gerekli.") }
        guard health.auth == "email-password" else { throw AppError("Bağımsız web sürümünü kullanın.") }
    }
    private func loadedCatalog() async throws -> RecordCatalog {
        let scope = api.mediaScope
        let loaded: [ServiceRecord] = try await api.send("records")
        let indexed = await BackgroundWork.catalog(loaded)
        try Task.checkCancellation()
        guard scope == api.mediaScope else { throw CancellationError() }
        return indexed
    }
    func restore() async {
        guard api.baseURL != nil, api.hasSession, staff == nil, !restoreInProgress else { return }
        restoreInProgress = true; loading = true
        do {
            let user: Staff = try await api.send("me")
            let indexed = try await loadedCatalog()
            staff = user; catalog = indexed; error = nil
        } catch is CancellationError { }
        catch { if (error as? AppError)?.status != 401 { self.error = error.localizedDescription } }
        loading = false; restoreInProgress = false
    }
    func login(email: String, password: String) async throws {
        let user = try await api.login(email: email, password: password)
        let indexed = try await loadedCatalog()
        catalog = indexed; staff = user; error = nil
    }
    func reload() async throws {
        if let existing = reloadTask { _ = try await existing.value; return }
        let version = mutationVersion
        let identifier = UUID(); reloadID = identifier
        let task: Task<RecordCatalog, Error> = Task { @MainActor in try await self.loadedCatalog() }
        reloadTask = task
        do {
            let indexed = try await task.value
            if version == mutationVersion {
                let changed = catalog.records.count != indexed.records.count || indexed.records.contains { catalog.byID[$0.id]?.updatedAt != $0.updatedAt }
                if changed { catalog = indexed }
            }
            if reloadID == identifier { reloadTask = nil }
        } catch { if reloadID == identifier { reloadTask = nil }; throw error }
    }
    func update(_ record: ServiceRecord) {
        mutationVersion += 1
        var updated = records
        if let index = updated.firstIndex(where: { $0.id == record.id }) { updated[index] = record }
        else { updated.insert(record, at: 0) }
        catalog = RecordCatalog(updated)
    }
    func logout() async { await api.logout(); staff = nil; clearRecords() }
}
