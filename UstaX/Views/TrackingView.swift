import SwiftUI

@MainActor struct TrackingView: View {
    @EnvironmentObject var app: AppState
    @State private var endpoint = ""
    @State private var input = ""
    @State private var token = ""
    @State private var record: TrackingRecord?
    @State private var busy = false
    @State private var error: String?
    @State private var challenge = ""
    @State private var code = ""
    @State private var decision: String?
    @State private var selectedPhoto: ServicePhoto?
    var body: some View {
        List {
            Group {
            Section(app.t("Güvenli servis takibi")) {
                if app.staff == nil { TextField("https://servis.example.com", text: $endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled() }
                TextField(app.t("Takip bağlantısı veya güvenli anahtar"), text: $input, axis: .vertical).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                Button(app.t("Sorgula")) { load() }.disabled(busy || input.isEmpty)
                if busy { ProgressView() }
            }
            if let error = error { Section { ErrorNotice(message: error) } }
            if let record = record { content(record) }
        
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Cihazımı takip et")).navigationBarTitleDisplayMode(.inline)
            .onAppear { endpoint = app.endpoint }
            .refreshable { if !token.isEmpty { await refresh() } }
            .confirmationDialog(app.t("Teklif kararınızı kaydetmek istiyor musunuz?"), isPresented: Binding(get: { decision != nil }, set: { if !$0 { decision = nil } }), titleVisibility: .visible) {
                if let decision = decision { Button(app.t(decision == "approved" ? "Teklifi onayla" : "Teklifi reddet"), role: decision == "rejected" ? .destructive : nil) { decide(decision) } }
                Button(app.t("Vazgeç"), role: .cancel) { decision = nil }
            }
            .sheet(item: $selectedPhoto) { PhotoZoomView(recordID: "tracking", photo: $0, token: token) }
    }
    @ViewBuilder private func content(_ record: TrackingRecord) -> some View {
        Section {
            Text(record.brand + " " + record.model).font(.title2.weight(.semibold))
            Text(record.number).font(.caption.monospaced()).foregroundColor(.secondary)
            StatusBadge(status: record.displayStatus)
            if !record.eta.isEmpty { DetailLine(title: app.t("Tahmini teslim"), value: record.eta) }
        }
        if let quote = record.quotes.last {
            Section(app.t("Fiyat teklifi")) {
                QuoteSummary(quote: quote, currency: record.currencyCode)
                if quote.decision == "pending" {
                    Text(app.t("İşlem yapabilmemiz için teklif kararınız bekleniyor.")).font(.headline)
                    Text(app.t("Doğrulama kodu serviste kayıtlı e-posta adresinize gönderilir.")).font(.callout).foregroundColor(.secondary)
                    Button(app.t(challenge.isEmpty ? "Doğrulama kodu gönder" : "Yeni kod gönder")) { requestCode() }.disabled(busy)
                    if !challenge.isEmpty {
                        TextField(app.t("6 haneli doğrulama kodu"), text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                            .onChange(of: code) { code = String($0.filter(\.isNumber).prefix(6)) }
                        Button(app.t("Teklifi onayla")) { decision = "approved" }.disabled(busy || code.count != 6)
                        Button(app.t("Teklifi reddet"), role: .destructive) { decision = "rejected" }.disabled(busy || code.count != 6)
                    }
                }
            }
        }
        if let completed = record.completion {
            Section(app.t("Tamamlanan işlemler")) {
                DetailLine(title: app.t("Yapılan işlemler"), value: completed.work)
                DetailLine(title: app.t("Değiştirilen parçalar"), value: completed.parts)
                DetailLine(title: app.t("Nihai ücret"), value: app.money(completed.fee, currency: record.currencyCode))
                DetailLine(title: app.t("Garanti süresi ve koşulları"), value: completed.warranty)
                if let at = completed.deliveredAt { DetailLine(title: app.t("Teslim tarihi"), value: app.date(at)) }
            }
        }
        if !record.photos.isEmpty {
            Section(app.t("Fotoğraflar")) { ForEach(record.photos) { photo in Button { selectedPhoto = photo } label: { ProtectedPhoto(recordID: "tracking", photo: photo, token: token).frame(height: 180) }.buttonStyle(.plain) } }
        }
        Section(app.t("İşlem geçmişi")) { Timeline(events: record.events) }
        if let phone = Bundle.main.object(forInfoDictionaryKey: "ServicePhone") as? String, !phone.isEmpty, let url = URL(string: "tel:" + phone) { Section { Link(app.t("Servisi ara"), destination: url) } }
        Section { NavigationLink(app.t("UstaX hakkında")) { AboutView() } }
    }
    private func load() {
        guard let candidate = Workflow.trackingToken(input) else { error = "Geçerli takip bağlantısı veya güvenli anahtar girin."; return }
        // Pasted links never change the server or receive a staff session.
        if let pasted = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)), let host = pasted.host,
           let configured = try? APIClient.validatedURL(endpoint), host != configured.host { error = "Takip bağlantısı seçili sunucuya ait değil."; return }
        busy = true; error = nil; record = nil; challenge = ""; code = ""
        Task { @MainActor in
            do {
            if app.staff == nil { try await app.saveEndpoint(endpoint) }
            token = candidate; try await fetchRecord()
        } catch { self.error = error.localizedDescription } 
            busy = false
        }
    }
    private func fetchRecord() async throws {
        let updated: TrackingRecord = try await app.api.send("track/" + token)
        if updated.quotes.last?.version != record?.quotes.last?.version { challenge = ""; code = "" }
        record = updated
    }
    private func refresh() async { do { try await fetchRecord(); error = nil } catch { self.error = error.localizedDescription } }
    private func requestCode() {
        busy = true; error = nil
        Task { @MainActor in
            do { let result: ChallengeResult = try await app.api.send("track/\(token)/code", method: "POST", body: [:]); challenge = result.challengeId; code = "" } catch { self.error = error.localizedDescription } 
            busy = false
        }
    }
    private func decide(_ value: String) {
        guard let version = record?.quotes.last?.version, !challenge.isEmpty else { return }
        decision = nil; busy = true; error = nil
        Task { @MainActor in
            do { let _: Ack = try await app.api.send("track/\(token)/decision", method: "POST", body: ["challengeId": challenge, "code": code, "decision": value, "version": version]); challenge = ""; code = ""; try await fetchRecord() } catch { self.error = error.localizedDescription; if (error as? AppError)?.status == 409 { await refresh() } } 
            busy = false
        }
    }
}
