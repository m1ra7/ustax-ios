import SwiftUI

@MainActor struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @State private var creating = false
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 145), spacing: 12)] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overviewHeader
                LazyVGrid(columns: columns, spacing: 12) {
                    metric("Aktif servisler", app.catalog.activeCount, "tray.full", .accentColor)
                    metric("İnceleniyor", app.catalog.counts["İnceleniyor", default: 0], "magnifyingglass", .blue)
                    metric("Fiyat onayı bekliyor", app.catalog.counts["Fiyat onayı bekliyor", default: 0], "clock", .orange)
                    metric("Müşteri onayladı", app.catalog.counts["Müşteri onayladı", default: 0], "checkmark.seal", .green)
                    metric("Tamir ediliyor", app.catalog.counts["Tamir ediliyor", default: 0], "wrench.adjustable", .accentColor)
                    metric("Parça bekleniyor", app.catalog.counts["Parça bekleniyor", default: 0], "shippingbox", .orange)
                    metric("Teslime hazır", app.catalog.counts["Teslime hazır", default: 0], "checkmark.circle", .green)
                }
                if let error = error { ErrorNotice(message: error) }
                recentRecords
            }.padding(20).frame(maxWidth: 960).frame(maxWidth: .infinity)
        }.background(ServiceStyle.canvas)
            .navigationTitle("UstaX").navigationBarTitleDisplayMode(.inline)
            .refreshable { do { try await app.reload(); error = nil } catch { self.error = error.localizedDescription } }
            .sheet(isPresented: $creating) { IntakeView() }
    }
    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(app.staff?.name ?? "").font(.subheadline).foregroundColor(.secondary)
                Text(app.t("Genel bakış")).font(.largeTitle.weight(.bold)).tracking(-0.6)
            }
            Button { creating = true } label: {
                Label(app.t("Yeni servis kaydı"), systemImage: "plus")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 42)
            }.buttonStyle(ServicePrimaryButtonStyle()).controlSize(.large)
        }
    }
    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(app.t("Son servis kayıtları")).font(.title3.weight(.semibold))
            if app.records.isEmpty { EmptyState(title: "Henüz servis kaydı yok", detail: "İlk cihazınızı kaydederek başlayın.").serviceCard() }
            LazyVStack(spacing: 12) {
                ForEach(app.catalog.recent) { record in
                    NavigationLink { RecordDetailView(initial: record) } label: {
                        HStack(spacing: 12) {
                            RecordRow(record: record)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(.secondary).accessibilityHidden(true)
                        }.serviceCard()
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func metric(_ title: String, _ count: Int, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.body.weight(.medium)).foregroundColor(color).accessibilityHidden(true)
            Text(String(count)).font(.largeTitle.weight(.semibold)).monospacedDigit()
            Text(app.t(title)).font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading).serviceCard()
    }
}
@MainActor struct RecordsView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var status = ""
    @State private var kind = ""
    @State private var oldest = false
    @State private var creating = false
    @State private var error: String?
    @State private var filtered: [ServiceRecord] = []
    @State private var filtering = true
    private var search: RecordSearch { RecordSearch(query: query, status: status, kind: kind, oldest: oldest, revision: app.catalog.revision) }
    var body: some View {
        List {
            Group {
            Section {
                Picker(app.t("Durum"), selection: $status) { Text(app.t("Tümü")).tag(""); ForEach(Workflow.filterStatuses, id: \.self) { Text(app.t($0)).tag($0) } }.pickerStyle(.menu).buttonStyle(.automatic)
                Picker(app.t("Cihaz türü"), selection: $kind) { Text(app.t("Tümü")).tag(""); ForEach(["Telefon", "Tablet", "Bilgisayar"], id: \.self) { Text(app.t($0)).tag($0) } }.pickerStyle(.menu).buttonStyle(.automatic)
                Toggle(app.t("Önce en eski"), isOn: $oldest)
            }
            if let error = error { ErrorNotice(message: error) }
            if filtering { ProgressView() }
            if filtered.isEmpty && !filtering { EmptyState(title: "Kayıt bulunamadı", detail: "Arama veya filtrelerinizi değiştirin.") }
            ForEach(filtered) { record in NavigationLink { RecordDetailView(initial: record) } label: { RecordRow(record: record) } }
        
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Servis kayıtları"))
            .searchable(text: $query, prompt: app.t("Müşteri, cihaz, servis no veya teknisyen"))
            .toolbar { ToolbarItem(placement: .primaryAction) { Button(app.t("Yeni kayıt")) { creating = true } } }
            .refreshable { do { try await app.reload(); error = nil } catch { self.error = error.localizedDescription } }
            .sheet(isPresented: $creating) { IntakeView() }
            .task(id: search) {
                let request = search
                filtering = true
                do {
                    if !request.query.isEmpty { try await Task.sleep(nanoseconds: 180_000_000) }
                    try Task.checkCancellation()
                    let result = await BackgroundWork.filter(app.catalog, search: request)
                    try Task.checkCancellation()
                    filtered = result; filtering = false
                } catch is CancellationError { } catch { self.error = error.localizedDescription; filtering = false }
            }
    }
}
@MainActor struct CustomersView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""

    @State private var customers: [ServiceRecord] = []
    @State private var filtering = true
    private var search: RecordSearch { RecordSearch(query: query, status: "", kind: "", oldest: false, revision: app.catalog.revision) }

    var body: some View {
        customerList.serviceList()
            .navigationTitle(app.t("Müşteriler"))
            .searchable(text: $query, prompt: app.t("Ad veya telefon"))
            .task(id: search) {
                let request = search
                filtering = true
                do {
                    if !request.query.isEmpty { try await Task.sleep(nanoseconds: 180_000_000) }
                    try Task.checkCancellation()
                    let result = await BackgroundWork.customers(app.catalog, query: request.query)
                    try Task.checkCancellation()
                    customers = result; filtering = false
                } catch { }
            }
    }

    private var customerList: some View {
        List {
            Group {
            if filtering { ProgressView() }
            if customers.isEmpty && !filtering {
                EmptyState(title: "Müşteri bulunamadı", detail: "Servis kaydı oluşturduğunuzda müşteriler burada görünür.")
            }
            ForEach(customers) { customer in
                CustomerNavigationRow(customer: customer)
            }
        
            }.listRowBackground(ServiceStyle.surface)
        }
    }
}

@MainActor private struct CustomerNavigationRow: View {
    let customer: ServiceRecord

    var body: some View {
        NavigationLink(destination: CustomerDetailView(customer: customer)) {
            VStack(alignment: .leading, spacing: 5) {
                Text(customer.name).font(.headline)
                Text(customer.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }.padding(.vertical, 8)
        }
    }
}

@MainActor private struct CustomerDetailView: View {
    @EnvironmentObject var app: AppState
    let customer: ServiceRecord

    private var history: [ServiceRecord] {
        app.catalog.customerHistory[customer.customerId] ?? []
    }

    var body: some View {
        List {
            Group {
            contactSection
            historySection
            newOrderSection
        
            }.listRowBackground(ServiceStyle.surface)
        }
        .serviceList()
        .navigationTitle(customer.name)
    }

    private var contactSection: some View {
        Section {
            DetailLine(title: app.t("Telefon"), value: customer.phone)
            DetailLine(title: app.t("E-posta"), value: customer.email)
        }
    }

    private var historySection: some View {
        Section(app.t("Servis geçmişi")) {
            ForEach(history) { record in
                CustomerServiceNavigationRow(record: record)
            }
        }
    }

    private var newOrderSection: some View {
        Section {
            NavigationLink(destination: IntakeView(customer: customer)) {
                Text(app.t("Yeni servis kaydı"))
            }
        }
    }
}

@MainActor private struct CustomerServiceNavigationRow: View {
    let record: ServiceRecord

    var body: some View {
        NavigationLink(destination: RecordDetailView(initial: record)) {
            RecordRow(record: record)
        }
    }
}
