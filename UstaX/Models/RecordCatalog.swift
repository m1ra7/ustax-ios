import Foundation

struct RecordCatalog {
    let revision = UUID()
    let records: [ServiceRecord]
    let byID: [String: ServiceRecord]
    let customerHistory: [String: [ServiceRecord]]
    let deviceHistory: [String: [ServiceRecord]]
    let customers: [ServiceRecord]
    let counts: [String: Int]
    let activeCount: Int
    let recent: [ServiceRecord]
    let searchEntries: [String: String]
    let customerSearchEntries: [String: String]

    init(_ input: [ServiceRecord] = []) {
        let sorted = input.sorted { $0.createdAt > $1.createdAt }
        var indexed: [String: ServiceRecord] = [:]
        var customerGroups: [String: [ServiceRecord]] = [:]
        var deviceGroups: [String: [ServiceRecord]] = [:]
        var representatives: [String: ServiceRecord] = [:]
        var statusCounts: [String: Int] = [:]
        var active = 0
        var search: [String: String] = [:]
        indexed.reserveCapacity(sorted.count)
        search.reserveCapacity(sorted.count)
        for record in sorted {
            indexed[record.id] = record
            customerGroups[record.customerId, default: []].append(record)
            deviceGroups[record.deviceId, default: []].append(record)
            if representatives[record.customerId] == nil { representatives[record.customerId] = record }
            statusCounts[record.displayStatus, default: 0] += 1
            if record.isActive { active += 1 }
            let text = [record.number, record.name, record.phone, record.device, record.technician, record.createdAt].joined(separator: " ")
            search[record.id] = Self.normalized(text)
        }
        records = sorted; byID = indexed; customerHistory = customerGroups; deviceHistory = deviceGroups
        customers = representatives.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        customerSearchEntries = representatives.mapValues { Self.normalized($0.name + " " + $0.phone) }
        counts = statusCounts; activeCount = active; recent = Array(sorted.prefix(8)); searchEntries = search
    }
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")).replacingOccurrences(of: "ı", with: "i")
    }
    func filtered(query: String, status: String, kind: String, oldest: Bool) -> [ServiceRecord] {
        let term = Self.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let matches = records.filter { record in
            (status.isEmpty || record.displayStatus == status) && (kind.isEmpty || record.kind == kind) && (term.isEmpty || (searchEntries[record.id] ?? "").contains(term))
        }
        return oldest ? Array(matches.reversed()) : matches
    }
}
struct RecordSearch: Hashable {
    let query: String
    let status: String
    let kind: String
    let oldest: Bool
    let revision: UUID
}

enum BackgroundWork {
    private static let decoding = DispatchQueue(label: "ustax.json", qos: .userInitiated)
    private static let searching = DispatchQueue(label: "ustax.search", qos: .userInitiated)
    private static let indexing = DispatchQueue(label: "ustax.catalog", qos: .userInitiated)
    static func catalog(_ records: [ServiceRecord]) async -> RecordCatalog {
        await withCheckedContinuation { continuation in
            indexing.async { continuation.resume(returning: RecordCatalog(records)) }
        }
    }
    static func decode<T: Decodable>(_ type: T.Type, data: Data) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            decoding.async {
                do { continuation.resume(returning: try JSONDecoder().decode(type, from: data)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    static func filter(_ catalog: RecordCatalog, search: RecordSearch) async -> [ServiceRecord] {
        await withCheckedContinuation { continuation in
            searching.async { continuation.resume(returning: catalog.filtered(query: search.query, status: search.status, kind: search.kind, oldest: search.oldest)) }
        }
    }
    static func customers(_ catalog: RecordCatalog, query: String) async -> [ServiceRecord] {
        await withCheckedContinuation { continuation in
            searching.async {
                let term = RecordCatalog.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
                let result = term.isEmpty ? catalog.customers : catalog.customers.filter { (catalog.customerSearchEntries[$0.customerId] ?? "").contains(term) }
                continuation.resume(returning: result)
            }
        }
    }
}
