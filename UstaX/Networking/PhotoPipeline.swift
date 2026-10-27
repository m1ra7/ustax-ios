import Foundation
import UIKit
import ImageIO

// ImageIO decodes only the requested pixel size; the serial queue bounds peak image work.
enum ImageWork {
    private static let queue = DispatchQueue(label: "ustax.images", qos: .userInitiated)
    private static func decoded(_ data: Data, pixels: Int) throws -> CGImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { throw AppError("Fotoğraf açılamadı.") }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true, kCGImageSourceThumbnailMaxPixelSize: pixels] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw AppError("Fotoğraf açılamadı.") }
        return image
    }
    static func thumbnail(_ data: Data, pixels: Int) async throws -> UIImage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            queue.async {
                autoreleasepool {
                    do { let image = try decoded(data, pixels: pixels); continuation.resume(returning: UIImage(cgImage: image)) }
                    catch { continuation.resume(throwing: error) }
                }
            }
        }
    }
    static let uploadLimit = 3 * 1024 * 1024
    private static func compressed(_ image: UIImage) throws -> Data {
        var current = image
        for _ in 0..<5 {
            for quality in [0.84, 0.72, 0.60, 0.48] {
                if let result = current.jpegData(compressionQuality: quality), result.count <= uploadLimit { return result }
            }
            let size = CGSize(width: max(1, current.size.width * 0.75), height: max(1, current.size.height * 0.75))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let source = current
            current = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
                source.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        throw AppError("Fotoğraf hazırlanamadı. Daha küçük bir fotoğraf seçin.")
    }
    static func jpeg(_ data: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            queue.async {
                autoreleasepool {
                    do {
                        guard data.count <= 30 * 1024 * 1024 else { throw AppError("Kaynak fotoğraf en fazla 30 MB olabilir.") }
                        let image = try decoded(data, pixels: 2200)
                        let normalized = UIImage(cgImage: image)
                        let jpeg = try compressed(normalized)
                        continuation.resume(returning: jpeg)
                    } catch { continuation.resume(throwing: error) }
                }
            }
        }
    }
    static func cameraJPEG(_ image: UIImage) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            queue.async {
                autoreleasepool {
                    let longest = max(image.size.width, image.size.height)
                    let ratio = min(1, 2200 / max(longest, 1))
                    let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                    let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size)) }
                    do { continuation.resume(returning: try compressed(normalized)) }
                    catch { continuation.resume(throwing: error) }
                }
            }
        }
    }
}

private actor PhotoDownloadGate {
    static let shared = PhotoDownloadGate()
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func acquire() async throws {
        try Task.checkCancellation()
        if active < 3 { active += 1; return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in waiters.append(continuation) }
        do { try Task.checkCancellation() }
        catch { release(); throw error }
    }
    func release() {
        if waiters.isEmpty { active -= 1 }
        else { waiters.removeFirst().resume() }
    }
}

@MainActor final class PhotoPipeline {
    static let shared = PhotoPipeline()
    private final class Entry {
        let image: UIImage
        let created = Date()
        init(_ image: UIImage) { self.image = image }
    }
    private let cache = NSCache<NSString, Entry>()
    private var flights: [String: Task<UIImage, Error>] = [:]
    private var epoch = 0
    private var observers: [NSObjectProtocol] = []
    private init() {
        cache.totalCostLimit = 24 * 1024 * 1024; cache.countLimit = 40
        for name in [UIApplication.didReceiveMemoryWarningNotification, UIApplication.didEnterBackgroundNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let pipeline = self else { return }
                Task { @MainActor [pipeline] in
                    pipeline.clear()
                }
            })
        }
    }
    func clear() {
        epoch += 1; cache.removeAllObjects()
        for flight in flights.values { flight.cancel() }
        flights.removeAll()
    }
    func invalidate(api: APIClient, recordID: String, photoID: String) {
        for pixels in [640, 2400] {
            for visible in [false, true] {
                let key = [api.baseURL?.absoluteString ?? "", api.mediaScope.uuidString, "staff", recordID, photoID, String(pixels), String(visible)].joined(separator: "|")
                cache.removeObject(forKey: key as NSString)
                flights.removeValue(forKey: key)?.cancel()
            }
        }
    }
    func image(api: APIClient, recordID: String, photo: ServicePhoto, token: String?, pixels: Int) async throws -> UIImage {
        let key = [api.baseURL?.absoluteString ?? "", api.mediaScope.uuidString, token ?? "staff", recordID, photo.id, String(pixels), String(photo.visible)].joined(separator: "|")
        if let existing = cache.object(forKey: key as NSString), Date().timeIntervalSince(existing.created) < 60 { return existing.image }
        if let existing = flights[key] { return try await existing.value }
        let generation = epoch
        let task: Task<UIImage, Error> = Task { @MainActor in
            try await PhotoDownloadGate.shared.acquire()
            do {
                let data = try await api.image(recordID: recordID, photoID: photo.id, token: token)
                try Task.checkCancellation()
                let image = try await ImageWork.thumbnail(data, pixels: pixels)
                try Task.checkCancellation()
                await PhotoDownloadGate.shared.release()
                return image
            } catch {
                await PhotoDownloadGate.shared.release()
                throw error
            }
        }
        flights[key] = task
        do {
            let image = try await task.value
            if generation == epoch {
                flights.removeValue(forKey: key)
                let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                cache.setObject(Entry(image), forKey: key as NSString, cost: cost)
            }
            return image
        } catch {
            if generation == epoch { flights.removeValue(forKey: key) }
            throw error
        }
    }
}
