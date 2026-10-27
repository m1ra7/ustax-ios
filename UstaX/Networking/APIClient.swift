import Foundation

@MainActor final class APIClient {
    var baseURL: URL? {
        didSet {
            if oldValue != baseURL {
                sessionToken = baseURL.flatMap { SessionVault.read($0.absoluteString) }
                mediaScope = UUID(); PhotoPipeline.shared.clear()
            }
        }
    }
    private var sessionToken: String?
    private(set) var mediaScope = UUID()
    var hasSession: Bool { sessionToken != nil }
    var language = "tr"
    var onUnauthorized: (() -> Void)?
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 90
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config, delegate: SameServerRedirectPolicy(), delegateQueue: nil)
    }
    static func validatedURL(_ input: String) throws -> URL {
        let edgeCharacters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’\u{200B}\u{FEFF}\u{200E}\u{200F}"))
        var value = input.trimmingCharacters(in: edgeCharacters)
        guard !value.isEmpty else { throw AppError("Geçerli sunucu adresi girin.") }
        if !value.contains("://") { value = "https://" + value }
        guard var components = URLComponents(string: value), let rawHost = components.host,
              !rawHost.isEmpty, components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw AppError("Geçerli sunucu adresi girin.")
        }
        let host = rawHost.lowercased()
        let scheme = (components.scheme ?? "").lowercased()
        let local = host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".local") || host.hasPrefix("192.168.") || host.hasPrefix("10.")
        guard scheme == "https" || scheme == "http" else { throw AppError("HTTPS bağlantısı gerekli.") }
        components.host = host
        components.scheme = scheme == "http" && !local ? "https" : scheme
        if components.scheme == "https" && (components.port == 443 || (scheme == "http" && !local && components.port == 80)) { components.port = nil }
        components.path = ""
        guard let url = components.url else { throw AppError("Geçerli sunucu adresi girin.") }
        return url
    }
    func url(_ path: String) throws -> URL {
        guard let base = baseURL, let url = URL(string: base.absoluteString + "/api/v1/" + path) else { throw AppError("Önce sunucu adresini kaydedin.") }
        return url
    }
    private func request(_ path: String, method: String, body: Data? = nil, contentType: String? = "application/json") throws -> URLRequest {
        var request = URLRequest(url: try url(path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(baseURL?.absoluteString, forHTTPHeaderField: "Origin")
        if let contentType = contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let token = sessionToken { request.setValue("ustax-session=" + token, forHTTPHeaderField: "Cookie") }
        return request
    }
    private func perform(_ request: URLRequest, path: String) async throws -> (Data, HTTPURLResponse) {
        let scope = mediaScope
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard scope == mediaScope else { throw CancellationError() }
        guard let http = response as? HTTPURLResponse else { throw AppError("Geçersiz sunucu yanıtı.") }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 && !path.hasPrefix("track/") && path != "auth/login" {
                clearSession(); onUnauthorized?()
            }
            if http.statusCode == 413 { throw AppError("Fotoğraf isteği çok büyük. Daha küçük bir fotoğraf seçin.", status: 413) }
            let message = (try? JSONDecoder().decode(APIMessage.self, from: data))?.error
            throw AppError(message ?? "Sunucu isteği tamamlanamadı.", status: http.statusCode)
        }
        return (data, http)
    }
    func send<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        let requestScope = mediaScope
        let data = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        let result = try await perform(request(path, method: method, body: data), path: path)
        do { let decoded = try await BackgroundWork.decode(T.self, data: result.0); try Task.checkCancellation(); guard requestScope == mediaScope else { throw CancellationError() }; return decoded }
        catch is CancellationError { throw CancellationError() }
        catch { throw AppError("API yanıtı bu sürümle uyumlu değil.") }
    }
    func login(email: String, password: String) async throws -> Staff {
        let body = try JSONSerialization.data(withJSONObject: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), "password": password])
        let result = try await perform(request("auth/login", method: "POST", body: body), path: "auth/login")
        guard let base = baseURL else { throw AppError("Önce sunucu adresini kaydedin.") }
        let fields = result.1.allHeaderFields.reduce(into: [String: String]()) { result, pair in result[String(describing: pair.key)] = String(describing: pair.value) }
        guard let cookie = HTTPCookie.cookies(withResponseHeaderFields: fields, for: base).first(where: { $0.name == "ustax-session" }), cookie.value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw AppError("Sunucu oturum açmadı. Bağımsız web sürümünü kullanın.") }
        try SessionVault.write(cookie.value, account: base.absoluteString)
        sessionToken = cookie.value; mediaScope = UUID(); PhotoPipeline.shared.clear()
        do { return try await send("me") } catch { clearSession(); throw error }
    }
    func clearSession() { if let base = baseURL { SessionVault.remove(base.absoluteString) }; sessionToken = nil; mediaScope = UUID(); PhotoPipeline.shared.clear() }
    func logout() async {
        let _: Ack? = try? await send("auth/logout", method: "POST", body: [:])
        clearSession()
    }
    func image(recordID: String, photoID: String, token: String? = nil) async throws -> Data {
        var path = "photos/\(recordID)/\(photoID)"
        if let token = token { path += "?token=" + token }
        let result = try await perform(request(path, method: "GET", contentType: nil), path: path)
        return result.0
    }
    func upload(recordID: String, jpeg: Data, phase: String, visible: Bool) async throws -> ServiceRecord {
        guard !jpeg.isEmpty, jpeg.count <= ImageWork.uploadLimit else { throw AppError("Fotoğraf isteği çok büyük. Daha küçük bir fotoğraf seçin.") }
        let boundary = "UstaX-" + UUID().uuidString
        var data = Data()
        func append(_ text: String) { data.append(Data(text.utf8)) }
        for (name, value) in [("phase", phase), ("visible", visible ? "true" : "false")] {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
        data.append(jpeg); append("\r\n--\(boundary)--\r\n")
        let path = "records/\(recordID)/photos"
        let requestScope = mediaScope
        let result = try await perform(request(path, method: "POST", body: data, contentType: "multipart/form-data; boundary=\(boundary)"), path: path)
        let decoded = try await BackgroundWork.decode(ServiceRecord.self, data: result.0)
        try Task.checkCancellation()
        guard requestScope == mediaScope else { throw CancellationError() }
        return decoded
    }
}

final class SameServerRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let original = task.originalRequest?.url, let destination = request.url,
              original.scheme == destination.scheme, original.host == destination.host,
              original.port == destination.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}
