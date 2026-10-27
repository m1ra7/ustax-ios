import XCTest
import UIKit
@testable import UstaX

final class UstaXTests: XCTestCase {
    func testApprovedStaffStatusCountsAndFiltersAreConsistent() throws {
        let pending = try fixture(id: "pending")
        let approved = try fixture(decision: "approved", id: "approved")
        let repairing = try fixture(status: "Tamir ediliyor", decision: "approved", id: "repairing")
        let catalog = RecordCatalog([pending, approved, repairing])
        XCTAssertEqual(approved.displayStatus, "Müşteri onayladı")
        XCTAssertEqual(approved.status, "Fiyat onayı bekliyor")
        XCTAssertEqual(catalog.counts["Fiyat onayı bekliyor"], 1)
        XCTAssertEqual(catalog.counts["Müşteri onayladı"], 1)
        XCTAssertEqual(catalog.filtered(query: "", status: "Müşteri onayladı", kind: "", oldest: false).map(\.id), ["approved"])
        XCTAssertEqual(repairing.displayStatus, "Tamir ediliyor")
    }
    @MainActor func testAboutAttributionTranslations() {
        let app = AppState()
        for language in ["tr", "en", "de"] {
            app.language = language
            XCTAssertTrue(app.t("Mirac Suicmez tarafından geliştirilmiştir.").contains("Mirac Suicmez"))
            XCTAssertFalse(app.t("UstaX hakkında").isEmpty)
        }
    }

    func testDeletedLatestQuoteDoesNotReactivateEarlierApproval() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture())) as! [String: Any]
        let first = (object["quotes"] as! [[String: Any]])[0]
        var approved = first; approved["version"] = 1; approved["decision"] = "approved"
        var removed = first; removed["version"] = 2; removed["deletedAt"] = "2026-10-24T12:00:00Z"
        object["quotes"] = [approved, removed]; object["status"] = "İnceleniyor"
        let record = try JSONDecoder().decode(ServiceRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(record.visibleQuotes.count, 1)
        XCTAssertNil(record.latestQuote)
        XCTAssertFalse(Workflow.available(record).contains("Tamir ediliyor"))
    }

    @MainActor func testPhotoFileImportAndJPEGPreparation() async throws {
        let png = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }.pngData()!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try png.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try await OriginalPhotoData.file(url)
        XCTAssertEqual(original, png)
        let jpeg = try await ImageWork.jpeg(original)
        XCTAssertEqual(Array(jpeg.prefix(3)), [0xff, 0xd8, 0xff])
        XCTAssertLessThanOrEqual(jpeg.count, ImageWork.uploadLimit)
    }
    func testPhotoImportRejectsOversizedFileBeforeJPEGPreparation() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(OriginalPhotoData.limit + 1))
        try handle.close()
        do { _ = try await OriginalPhotoData.file(url); XCTFail("Oversized originals must be rejected") }
        catch { XCTAssertEqual(error.localizedDescription, "Kaynak fotoğraf en fazla 30 MB olabilir.") }
    }

    func testCurrencyFallbackAndRoundTrip() throws {
        var record = try fixture()
        XCTAssertEqual(record.currencyCode, "TRY")
        for code in Currency.codes {
            record.currency = code
            let data = try JSONEncoder().encode(record)
            let decoded = try JSONDecoder().decode(ServiceRecord.self, from: data)
            XCTAssertEqual(decoded.currencyCode, code)
            XCTAssertEqual(decoded.latestQuote?.total, record.latestQuote?.total)
        }
        XCTAssertEqual(Currency.code("GBP"), "TRY")
    }
    @MainActor func testCurrencyFormattingAndLegacyTimeline() throws {
        let app = AppState()
        app.language = "en"
        XCTAssertTrue(app.money(12345, currency: "EUR").contains("€"))
        XCTAssertTrue(app.money(12345, currency: "USD").contains("$"))
        let event = try JSONDecoder().decode(ServiceEvent.self, from: Data("{\"id\":\"e\",\"at\":\"2026-10-23\",\"text\":\"Entry\",\"internal\":false}".utf8))
        XCTAssertNil(event.deletedAt)
        XCTAssertEqual(ImageWork.uploadLimit, 3 * 1024 * 1024)
    }
    func testAmountsUseIntegerCents() {
        XCTAssertEqual(Workflow.cents("1250,50"), 125050)
        XCTAssertEqual(Workflow.cents("0.01"), 1)
        XCTAssertNil(Workflow.cents("-1"))
        XCTAssertNil(Workflow.cents("1.001"))
        XCTAssertNil(Workflow.cents("NaN"))
        XCTAssertNil(Workflow.cents("1000001"))
    }
    func testTrackingDoesNotAcceptOrderNumbers() {
        let token = String(repeating: "a", count: 64)
        XCTAssertEqual(Workflow.trackingToken(token), token)
        XCTAssertEqual(Workflow.trackingToken("https://service.example/takip/" + token), token)
        XCTAssertNil(Workflow.trackingToken("SRV-2026-12345678"))
        XCTAssertNil(Workflow.trackingToken("https://service.example/records/" + token))
        XCTAssertNil(Workflow.trackingToken("../" + token))
    }
    @MainActor func testEndpointValidation() throws {
        XCTAssertEqual(try APIClient.validatedURL("https://service.example/").absoluteString, "https://service.example")
        XCTAssertNoThrow(try APIClient.validatedURL("http://localhost:3000"))
        XCTAssertEqual(try APIClient.validatedURL("http://public.example").absoluteString, "https://public.example")
        XCTAssertEqual(try APIClient.validatedURL("service.example").absoluteString, "https://service.example")
        XCTAssertEqual(try APIClient.validatedURL("  HTTPS://SERVICE.EXAMPLE/  ").absoluteString, "https://service.example")
        XCTAssertEqual(try APIClient.validatedURL("https://service.example:443/").absoluteString, "https://service.example")
        XCTAssertThrowsError(try APIClient.validatedURL("ftp://service.example"))
        XCTAssertThrowsError(try APIClient.validatedURL("https://user:secret@service.example"))
        XCTAssertThrowsError(try APIClient.validatedURL("https://service.example/path"))
        XCTAssertThrowsError(try APIClient.validatedURL("https://service.example?token=secret"))
    }
    func testPublicTrackingProjectionDecodesWithoutStaffFields() throws {
        let json = """
        {"number":"SRV-1","kind":"Telefon","brand":"Apple","model":"iPhone","status":"İnceleniyor","createdAt":"2026-10-20T10:00:00Z","eta":"","events":[{"id":"e1","at":"2026-10-20T10:00:00Z","text":"Cihaz teslim alındı.","internal":false}],"quotes":[],"photos":[{"id":"p1","format":"jpg","phase":"Kabul","visible":true}]}
        """
        let record = try JSONDecoder().decode(TrackingRecord.self, from: Data(json.utf8))
        XCTAssertNil(record.events[0].actor)
        XCTAssertNil(record.photos[0].publicId)
        XCTAssertNil(record.completion)
    }
    func testWorkflowDoesNotOfferRepairBeforeApproval() throws {
        let record = try fixture(decision: "pending")
        XCTAssertFalse(Workflow.available(record).contains("Tamir ediliyor"))
        XCTAssertTrue(Workflow.available(try fixture(decision: "approved")).contains("Tamir ediliyor"))
        XCTAssertEqual(Workflow.available(try fixture(status: "Teslim edildi")), [])
    }
    func testCatalogMaintainsHistoryCountsAndSortOrder() throws {
        let old = try fixture(status: "İnceleniyor", id: "older", created: "2026-10-19T10:00:00Z")
        let recent = try fixture(status: "Teslim edildi", id: "newer")
        let catalog = RecordCatalog([old, recent])
        XCTAssertEqual(catalog.records.map(\.id), ["newer", "older"])
        XCTAssertEqual(catalog.activeCount, 1)
        XCTAssertEqual(catalog.counts["İnceleniyor"], 1)
        XCTAssertEqual(catalog.customers.count, 1)
        XCTAssertEqual(catalog.customerHistory["c1"]?.count, 2)
        XCTAssertEqual(catalog.deviceHistory["d1"]?.count, 2)
        XCTAssertEqual(catalog.byID["older"]?.status, "İnceleniyor")
        XCTAssertEqual(catalog.filtered(query: "Test", status: "", kind: "Telefon", oldest: true).map(\.id), ["older", "newer"])
        XCTAssertTrue(catalog.filtered(query: "missing", status: "", kind: "", oldest: false).isEmpty)
        XCTAssertEqual(RecordCatalog.normalized("MİRAÇ"), RecordCatalog.normalized("mirac"))
    }
    func testJSONDecodingRunsOffMainThread() async throws {
        let result = try await BackgroundWork.decode(BackgroundDecodeProbe.self, data: Data("{}".utf8))
        XCTAssertTrue(result.decodedOffMain)
    }
    @MainActor func testPhotoThumbnailBounds() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1000), format: format).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
        }
        let raw = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let thumbnail = try await ImageWork.thumbnail(raw, pixels: 640)
        let cg = try XCTUnwrap(thumbnail.cgImage)
        XCTAssertEqual(max(cg.width, cg.height), 640)
        XCTAssertEqual(CGFloat(cg.width) / CGFloat(cg.height), 1.6, accuracy: 0.01)
    }
    func testIndexedCustomerSearchNormalizesAndTrims() async throws {
        let record = try fixture(name: "MİRAÇ Suiçmez", phone: "+49 12345")
        let catalog = await BackgroundWork.catalog([record])
        let named = await BackgroundWork.customers(catalog, query: "  mirac  ")
        let phone = await BackgroundWork.customers(catalog, query: "12345")
        let all = await BackgroundWork.customers(catalog, query: "   ")
        let missing = await BackgroundWork.customers(catalog, query: "nonexistent")
        XCTAssertEqual(named.map(\.id), [record.id])
        XCTAssertEqual(phone.map(\.id), [record.id])
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(missing.isEmpty)
    }
    private func fixture(status: String = "Fiyat onayı bekliyor", decision: String = "pending", id: String = "r1", created: String = "2026-10-20T10:00:00Z", name: String = "Test", phone: String = "0000000000") throws -> ServiceRecord {
        let payload: [String: Any] = ["id":id, "number":"SRV-1", "customerId":"c1", "deviceId":"d1", "name":name, "phone":phone, "email":"", "kind":"Telefon", "brand":"Test", "model":"Test", "serial":"", "fault":"Test fault", "condition":"", "accessories":"", "technician":"Test", "status":status, "createdAt":created, "updatedAt":"2026-10-20T10:00:00Z", "eta":"", "events":[], "photos":[], "quotes":[["version":1, "diagnosis":"Test", "work":"Test", "parts":[], "labor":100, "total":100, "eta":"", "decision":decision]]]
        return try JSONDecoder().decode(ServiceRecord.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}

private struct BackgroundDecodeProbe: Decodable {
    let decodedOffMain: Bool
    init(from decoder: Decoder) throws {
        guard !Thread.isMainThread else { throw AppError("Main-thread decoding") }
        decodedOffMain = true
    }
}
