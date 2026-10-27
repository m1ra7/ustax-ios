import SwiftUI

struct LinkToken: Identifiable { let token: String; var id: String { token } }
@MainActor struct IntakeView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    var customer: ServiceRecord? = nil
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var currency = "TRY"
    @State private var kind = "Telefon"
    @State private var brand = ""
    @State private var model = ""
    @State private var serial = ""
    @State private var fault = ""
    @State private var condition = ""
    @State private var accessories = ""
    @State private var technician = ""
    @State private var receivedAt = Date()
    @State private var busy = false
    @State private var error: String?
    @State private var link: LinkToken?
    @State private var created = false
    private var candidates: [ServiceRecord] {
        app.catalog.customers
    }
    var body: some View {
        NavigationStack {
            Form {
            Group {
                Section(app.t("Müşteri bilgileri")) {
                    if !candidates.isEmpty { Menu(app.t("Mevcut müşteri seç")) { ForEach(candidates) { record in Button(record.name + " · " + record.phone) { fill(record) } } } }
                    TextField(app.t("Ad soyad"), text: $name).textContentType(.name)
                    TextField(app.t("Telefon"), text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    TextField(app.t("E-posta"), text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section(app.t("Cihaz bilgileri")) {
                    Picker(app.t("Cihaz türü"), selection: $kind) { ForEach(["Telefon", "Tablet", "Bilgisayar"], id: \.self) { Text(app.t($0)).tag($0) } }.pickerStyle(.menu).buttonStyle(.automatic)
                    TextField(app.t("Marka"), text: $brand)
                    TextField(app.t("Model"), text: $model)
                    TextField(app.t("Seri numarası / IMEI"), text: $serial).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section(app.t("Kabul bilgileri")) {
                    TextField(app.t("Bildirilen arıza"), text: $fault, axis: .vertical).lineLimit(3...6)
                    TextField(app.t("Fiziksel durum"), text: $condition, axis: .vertical).lineLimit(2...4)
                    TextField(app.t("Teslim alınan aksesuarlar"), text: $accessories)
                    TextField(app.t("Sorumlu teknisyen"), text: $technician)
                    SelectionRow(title: app.t("Para birimi"), selection: $currency, options: Currency.codes, label: { app.t(Currency.title($0)) })
                    DatePicker(app.t("Teslim alma tarihi"), selection: $receivedAt, in: ...Date())
                }
                if let error = error { Section { ErrorNotice(message: error) } }
                Section { Button { save() } label: { HStack { Text(app.t("Servis kaydı oluştur")); Spacer(); if busy { ProgressView() } } }.disabled(busy || created || name.trimmingCharacters(in: .whitespaces).count < 2 || phone.count < 10 || brand.isEmpty || model.isEmpty || fault.count < 5 || technician.isEmpty) }
            
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Yeni servis kaydı")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(app.t("Vazgeç")) { dismiss() }.disabled(busy) } }
                .onAppear { if name.isEmpty { currency = app.preferredCurrency; if let customer = customer { fill(customer) }; technician = app.staff?.name ?? "" } }
                .sheet(item: $link, onDismiss: { if created { dismiss() } }) { TrackingLinkSheet(token: $0.token) }
        }.interactiveDismissDisabled(busy || created)
    }
    private func fill(_ record: ServiceRecord) { name = record.name; phone = record.phone; email = record.email }
    private func save() {
        busy = true; error = nil
        Task { @MainActor in
            do {
            let payload: [String: Any] = ["currency": currency, "name": name, "phone": phone, "email": email, "kind": kind, "brand": brand, "model": model, "serial": serial, "fault": fault, "condition": condition, "accessories": accessories, "technician": technician, "receivedAt": ISO8601DateFormatter().string(from: receivedAt)]
            let result: CreatedRecord = try await app.api.send("records", method: "POST", body: payload)
            app.update(result.data); app.trackingTokens[result.data.id] = result.token; created = true; link = LinkToken(token: result.token)
        } catch { self.error = error.localizedDescription } 
            busy = false
        }
    }
}
struct QuotePartDraft: Identifiable { let id = UUID(); var name = ""; var amount = "" }
@MainActor struct QuoteForm: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let record: ServiceRecord
    @State private var diagnosis = ""
    @State private var work = ""
    @State private var parts: [QuotePartDraft] = []
    @State private var labor = ""
    @State private var eta = ""
    @State private var busy = false
    @State private var error: String?
    private var total: Int { parts.reduce(0) { $0 + (Workflow.cents($1.amount) ?? 0) } + (Workflow.cents(labor) ?? 0) }
    var body: some View {
        NavigationStack {
            Form {
            Group {
                Section { Text(app.t("Kapsam veya fiyat değişirse müşteriden yeniden onay alınır.")).font(.callout).foregroundColor(.secondary) }
                Section(app.t("İşlem detayları")) {
                    TextField(app.t("Tespit edilen arıza"), text: $diagnosis, axis: .vertical).lineLimit(2...5)
                    TextField(app.t("Yapılacak işlemler"), text: $work, axis: .vertical).lineLimit(3...6)
                    TextField(app.t("Tahmini teslim"), text: $eta)
                }
                Section(app.t("Parçalar")) {
                    ForEach($parts) { $part in VStack(alignment: .leading) { TextField(app.t("Parça adı"), text: $part.name); TextField(app.t("Parça ücreti") + " (" + record.currencyCode + ")", text: $part.amount).keyboardType(.decimalPad) } }
                    .onDelete { parts.remove(atOffsets: $0) }
                    Button(app.t("Parça ekle")) { parts.append(QuotePartDraft()) }.disabled(parts.count >= 50)
                }
                Section { TextField(app.t("İşçilik") + " (" + record.currencyCode + ")", text: $labor).keyboardType(.decimalPad); HStack { Text(app.t("Toplam")); Spacer(); Text(app.money(total, currency: record.currencyCode)).fontWeight(.semibold) } }
                if let error = error { Section { ErrorNotice(message: error) } }
                Section { Button(app.t("Teklifi kaydet")) { save() }.disabled(busy || diagnosis.count < 3 || work.count < 3 || Workflow.cents(labor) == nil); if busy { ProgressView() } }
            
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Fiyat teklifi")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(app.t("Vazgeç")) { dismiss() }.disabled(busy) } }
                .onAppear { if diagnosis.isEmpty, let quote = record.latestQuote { diagnosis = quote.diagnosis; work = quote.work; eta = quote.eta; labor = String(format: "%.2f", Double(quote.labor)/100); parts = quote.parts.map { QuotePartDraft(name: $0.name, amount: String(format: "%.2f", Double($0.amount)/100)) } } }
        }.interactiveDismissDisabled(busy)
    }
    private func save() {
        guard let laborCents = Workflow.cents(labor), parts.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && Workflow.cents($0.amount) != nil }) else { error = "Bilgileri kontrol edin."; return }
        busy = true; error = nil
        Task { @MainActor in
            do { let updated: ServiceRecord = try await app.api.send("records/\(record.id)/quote", method: "PATCH", body: ["diagnosis": diagnosis, "work": work, "parts": parts.map { ["name": $0.name, "amount": Workflow.cents($0.amount)!] as [String: Any] }, "labor": laborCents, "eta": eta]); app.update(updated); dismiss() } catch { self.error = error.localizedDescription } 
            busy = false
        }
    }
}
enum SimpleAction: String, Identifiable { case note, email, deliver; var id: String { rawValue } }
@MainActor struct ActionForm: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let record: ServiceRecord
    let action: SimpleAction
    @State private var text = ""
    @State private var internalNote = true
    @State private var busy = false
    @State private var error: String?
    private var title: String { action == .note ? "Not ekle" : action == .email ? "E-posta güncelle" : "Teslim kaydı" }
    var body: some View {
        NavigationStack {
            Form {
            Group {
                Section(app.t(title)) {
                    if action == .email { TextField(app.t("E-posta"), text: $text).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled() }
                    else { TextField(app.t(action == .note ? "Açıklama" : "Teslim açıklaması"), text: $text, axis: .vertical).lineLimit(4...10) }
                    if action == .note { Toggle(app.t("Yalnızca çalışanlar görsün"), isOn: $internalNote) }
                }
                if let error = error { Section { ErrorNotice(message: error) } }
                Section { Button(app.t("Kaydet")) { save() }.disabled(busy || (action != .deliver && text.trimmingCharacters(in: .whitespaces).isEmpty)); if busy { ProgressView() } }
            
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t(title)).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(app.t("Vazgeç")) { dismiss() }.disabled(busy) } }
                .onAppear { if action == .email { text = record.email } }
        }.interactiveDismissDisabled(busy)
    }
    private func save() {
        busy = true; error = nil
        let path = action == .note ? "notes" : action.rawValue
        let body: [String: Any] = action == .note ? ["text": text, "internal": internalNote] : action == .email ? ["email": text] : ["note": text]
        Task { @MainActor in
            do { let updated: ServiceRecord = try await app.api.send("records/\(record.id)/\(path)", method: "PATCH", body: body); app.update(updated); dismiss() } catch { self.error = error.localizedDescription } 
            busy = false
        }
    }
}
@MainActor struct CompletionForm: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let record: ServiceRecord
    @State private var work = ""
    @State private var parts = ""
    @State private var warranty = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
            Group {
                Section(app.t("Tamir tamamlama")) {
                    TextField(app.t("Yapılan işlemler"), text: $work, axis: .vertical).lineLimit(3...8)
                    TextField(app.t("Değiştirilen parçalar"), text: $parts, axis: .vertical).lineLimit(2...5)
                    TextField(app.t("Garanti süresi ve koşulları"), text: $warranty, axis: .vertical).lineLimit(3...6)
                    DetailLine(title: app.t("Nihai ücret"), value: app.money(record.latestQuote?.total ?? 0, currency: record.currencyCode))
                    Text(app.t("Fiyat değişecekse önce yeni teklif hazırlayın.")).font(.caption).foregroundColor(.secondary)
                }
                if let error = error { Section { ErrorNotice(message: error) } }
                Section { Button(app.t("Teslime hazır olarak kaydet")) { save() }.disabled(busy || work.count < 3); if busy { ProgressView() } }
            
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Tamir tamamlama")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(app.t("Vazgeç")) { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
    }
    private func save() { busy = true; Task { @MainActor in
            do { let updated: ServiceRecord = try await app.api.send("records/\(record.id)/complete", method: "PATCH", body: ["work": work, "parts": parts, "fee": record.latestQuote?.total ?? 0, "warranty": warranty]); app.update(updated); dismiss() } catch { self.error = error.localizedDescription } 
            busy = false
        } }
}
