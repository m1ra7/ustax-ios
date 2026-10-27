import SwiftUI

enum DetailSheet: String, Identifiable { case quote, note, email, complete, deliver, photos; var id: String { rawValue } }
@MainActor struct RecordDetailView: View {
    @EnvironmentObject var app: AppState
    let initial: ServiceRecord
    @State private var sheet: DetailSheet?
    @State private var link: LinkToken?
    @State private var error: String?
    @State private var busy = false
    @State private var pendingStatus: String?
    @State private var selectedStatus = ""
    @State private var rotating = false
    @State private var reopening = false
    @State private var pendingEvent: ServiceEvent?
    @State private var pendingQuote: Quote?
    private var record: ServiceRecord { app.catalog.byID[initial.id] ?? initial }
    var body: some View {
        List {
            Group {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: deviceSymbol(record.kind)).font(.title).foregroundColor(.accentColor).accessibilityHidden(true)
                    Text(record.device).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    StatusBadge(status: record.displayStatus)
                }.padding(.vertical, 12)
                DetailLine(title: app.t("Servis numarası"), value: record.number)
                DetailLine(title: app.t("Para birimi"), value: record.currencyCode)
                DetailLine(title: app.t("Sorumlu teknisyen"), value: record.technician)
                DetailLine(title: app.t("Teslim alma tarihi"), value: app.date(record.createdAt))
                if !record.eta.isEmpty { DetailLine(title: app.t("Tahmini teslim"), value: record.eta) }
            }
            if let error = error { Section { ErrorNotice(message: error) } }
            actions
            Section(app.t("Müşteri bilgileri")) {
                DetailLine(title: app.t("Ad soyad"), value: record.name)
                DetailLine(title: app.t("Telefon"), value: record.phone)
                if let url = URL(string: "tel:" + record.phone.filter { $0.isNumber || $0 == "+" }) { Link(app.t("Müşteriyi ara"), destination: url) }
                DetailLine(title: app.t("E-posta"), value: record.email)
                Button(app.t("E-posta güncelle")) { sheet = .email }
            }
            Section(app.t("Cihaz bilgileri")) {
                DetailLine(title: app.t("Cihaz türü"), value: app.t(record.kind))
                DetailLine(title: app.t("Seri numarası / IMEI"), value: record.serial)
                DetailLine(title: app.t("Bildirilen arıza"), value: record.fault)
                DetailLine(title: app.t("Fiziksel durum"), value: record.condition)
                DetailLine(title: app.t("Teslim alınan aksesuarlar"), value: record.accessories)
            }
            quoteHistory
            if let completion = record.completion { Section(app.t("Tamamlanan işlemler")) {
                DetailLine(title: app.t("Yapılan işlemler"), value: completion.work)
                DetailLine(title: app.t("Değiştirilen parçalar"), value: completion.parts)
                DetailLine(title: app.t("Nihai ücret"), value: app.money(completion.fee, currency: record.currencyCode))
                DetailLine(title: app.t("Garanti süresi ve koşulları"), value: completion.warranty)
                DetailLine(title: app.t("Tamamlanma tarihi"), value: app.date(completion.completedAt))
                if let at = completion.deliveredAt { DetailLine(title: app.t("Teslim tarihi"), value: app.date(at)) }
                if let note = completion.deliveryNote { DetailLine(title: app.t("Teslim açıklaması"), value: note) }
            } }
            Section(app.t("İşlem geçmişi")) { Timeline(events: record.events, onDelete: app.isAdmin ? { pendingEvent = $0 } : nil, deleting: busy) }
            Section(app.t("Cihazın servis geçmişi")) {
                let history = (app.catalog.deviceHistory[record.deviceId] ?? []).filter { $0.id != record.id }
                if history.isEmpty { Text(app.t("Önceki servis kaydı yok.")).foregroundColor(.secondary) }
                ForEach(history) { previous in NavigationLink { RecordDetailView(initial: previous) } label: { RecordRow(record: previous) } }
            }
        
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(record.number).navigationBarTitleDisplayMode(.inline)
            .refreshable { await refresh() }
            .sheet(item: $sheet) { item in
                switch item {
                case .quote: QuoteForm(record: record)
                case .note: ActionForm(record: record, action: .note)
                case .email: ActionForm(record: record, action: .email)
                case .complete: CompletionForm(record: record)
                case .deliver: ActionForm(record: record, action: .deliver)
                case .photos: PhotosView(record: record)
                }
            }
            .sheet(item: $link) { TrackingLinkSheet(token: $0.token) }
            .confirmationDialog(app.t("Durum değiştirilsin mi?"), isPresented: Binding(get: { pendingStatus != nil }, set: { if !$0 { pendingStatus = nil } }), titleVisibility: .visible) {
                if let status = pendingStatus { Button(app.t(status), role: status == "İptal edildi" ? .destructive : nil) { changeStatus(status) } }
                Button(app.t("Vazgeç"), role: .cancel) { pendingStatus = nil }
            }
            .confirmationDialog(app.t("Bu adım geçmişten kaldırılsın mı? İşlem denetim kaydında saklanır."), isPresented: Binding(get: { pendingEvent != nil }, set: { if !$0 { pendingEvent = nil } }), titleVisibility: .visible) {
                if let event = pendingEvent { Button(app.t("Adımı kaldır"), role: .destructive) { removeEvent(event) } }
                Button(app.t("Vazgeç"), role: .cancel) { pendingEvent = nil }
            }
            .confirmationDialog(app.t("Bu teklif silinsin mi? Müşteri bu teklif için karar veremeyecek."), isPresented: Binding(get: { pendingQuote != nil }, set: { if !$0 { pendingQuote = nil } }), titleVisibility: .visible) {
                if let quote = pendingQuote { Button(app.t("Teklifi sil"), role: .destructive) { deleteQuote(quote) } }
                Button(app.t("Vazgeç"), role: .cancel) { pendingQuote = nil }
            }
            .confirmationDialog(app.t("İptal edilen kayıt yeniden aktif edilsin mi?"), isPresented: $reopening, titleVisibility: .visible) {
                Button(app.t("Yeniden aktif et")) { reopenRecord() }
                Button(app.t("Vazgeç"), role: .cancel) {}
            }
            .confirmationDialog(app.t("Eski takip bağlantısı iptal edilecek."), isPresented: $rotating, titleVisibility: .visible) { Button(app.t("Bağlantıyı yenile"), role: .destructive) { rotate() }; Button(app.t("Vazgeç"), role: .cancel) {} }
    }
    @ViewBuilder private var quoteHistory: some View {
        if !record.visibleQuotes.isEmpty {
            Section(app.t("Teklif geçmişi")) {
                ForEach(record.visibleQuotes.reversed()) { quote in quoteCard(quote) }
            }
        }
    }
    private func quoteCard(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            QuoteSummary(quote: quote, currency: record.currencyCode)
            if Workflow.canDeleteQuote(quote, record: record) {
                Button(role: .destructive) { pendingQuote = quote } label: { Label(app.t("Teklifi sil"), systemImage: "trash") }.buttonStyle(.bordered).disabled(busy)
            } else {
                Text(app.t("Devam eden veya tamamlanan tamire ait güncel teklif silinemez.")).font(.caption).foregroundColor(.secondary)
            }
        }.padding(16)
            .background(ServiceStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
    }
    private func deleteQuote(_ quote: Quote) {
        guard !busy else { return }
        pendingQuote = nil; busy = true; error = nil
        Task { @MainActor in
            do {
                let updated: ServiceRecord = try await app.api.send("records/\(record.id)/quotes/\(quote.version)", method: "DELETE")
                app.update(updated)
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private var actions: some View {
        Section(app.t("İşlemler")) {
            statusActions
            repairActions
            noteAndPhotoActions
            trackingActions
        }
    }

    @ViewBuilder private var statusActions: some View {
        if busy { ProgressView() }
        if record.displayStatus == "Müşteri onayladı" {
            Text(app.t("Müşteri teklifi onayladı. Tamire başlayabilirsiniz."))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        if record.status == "İptal edildi" && record.completion?.deliveredAt == nil {
            Button { reopening = true } label: {
                Label(app.t("Yeniden aktif et"), systemImage: "arrow.counterclockwise")
            }.disabled(busy)
        }
        statusEditor

    }

    private var statusEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(app.t("Süreci güncelle")).font(.headline)
            StatusBadge(status: record.displayStatus)
            SelectionRow(title: app.t("Yeni servis durumu"), selection: $selectedStatus,
                         options: Workflow.statuses, label: { app.t($0) })
            Button(app.t("Güncelle"), action: submitSelectedStatus)
                .buttonStyle(ServicePrimaryButtonStyle())
                .disabled(busy || selectedStatus.isEmpty || selectedStatus == record.status)
            Text(app.t("Müşteri onayı, tamamlama ve teslim kuralları sunucuda denetlenir."))
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 10)
            .onAppear { selectedStatus = record.status }
            .onChange(of: record.status) { selectedStatus = $0 }
    }

    private func submitSelectedStatus() {
        guard !busy, Workflow.statuses.contains(selectedStatus), selectedStatus != record.status else { return }
        error = nil
        // Required repair and handover details are collected before changing these statuses.
        if selectedStatus == "Teslime hazır" && record.status == "Tamir ediliyor" && record.latestQuote?.decision == "approved" {
            sheet = .complete
        } else if selectedStatus == "Teslim edildi" && record.status == "Teslime hazır" {
            sheet = .deliver
        } else if selectedStatus == "Fiyat onayı bekliyor" && record.latestQuote == nil && Workflow.canQuote(record) {
            sheet = .quote
        } else {
            pendingStatus = selectedStatus
        }
    }

    @ViewBuilder private var repairActions: some View {
        if Workflow.canQuote(record) {
            Button(app.t("Fiyat teklifi hazırla")) { sheet = .quote }.disabled(busy)
        }
        if record.status == "Tamir ediliyor" && record.latestQuote?.decision == "approved" {
            Button(app.t("Tamiri tamamla")) { sheet = .complete }.disabled(busy)
        }
        if record.status == "Teslime hazır" {
            Button(app.t("Teslim edildi olarak kaydet")) { sheet = .deliver }.disabled(busy)
        }
    }

    private var noteAndPhotoActions: some View {
        Group {
            Button(app.t("Not ekle")) { sheet = .note }
            Button(photoActionTitle) { sheet = .photos }
        }
    }

    private var photoActionTitle: String {
        app.t("Fotoğraflar") + " (" + String(record.photos.count) + ")"
    }

    @ViewBuilder private var trackingActions: some View {
        if app.trackingTokens[record.id] != nil || app.isAdmin {
            Button(app.t("Takip bağlantısı ve QR kod"), action: showTrackingLink)
                .disabled(busy)
        }
        if app.isAdmin && app.trackingTokens[record.id] != nil {
            Button(app.t("Takip bağlantısını yenile")) { rotating = true }.disabled(busy)
        }
    }

    private func showTrackingLink() {
        if let token = app.trackingTokens[record.id] {
            link = LinkToken(token: token)
        } else {
            rotating = true
        }
    }
    private func reopenRecord() {
        guard !busy else { return }
        reopening = false; busy = true; error = nil
        Task { @MainActor in
            do {
                let updated: ServiceRecord = try await app.api.send("records/\(record.id)/reopen", method: "POST", body: [:])
                app.update(updated)
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func removeEvent(_ event: ServiceEvent) {
        pendingEvent = nil; busy = true; error = nil
        Task { @MainActor in
            do { let updated: ServiceRecord = try await app.api.send("records/\(record.id)/events/\(event.id)", method: "DELETE"); app.update(updated) } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func refresh() async { do { let updated: ServiceRecord = try await app.api.send("records/\(record.id)"); app.update(updated); error = nil } catch { self.error = error.localizedDescription } }
    private func changeStatus(_ status: String) {
        guard !busy else { pendingStatus = nil; return }
        selectedStatus = ""; busy = true; pendingStatus = nil; Task { @MainActor in
            do { let updated: ServiceRecord = try await app.api.send("records/\(record.id)/status", method: "PATCH", body: ["status": status]); app.update(updated); error = nil } catch { self.error = error.localizedDescription } 
            busy = false
        } }
    private func rotate() { busy = true; Task { @MainActor in
            do { let result: TokenResult = try await app.api.send("records/\(record.id)/rotate", method: "POST", body: [:]); app.trackingTokens[record.id] = result.token; link = LinkToken(token: result.token); await refresh() } catch { self.error = error.localizedDescription } 
            busy = false
        } }
}
