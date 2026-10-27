import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

@MainActor struct StatusBadge: View {
    @EnvironmentObject var app: AppState
    let status: String
    @Environment(\.colorScheme) private var scheme
    private var color: Color {
        switch status { case "Müşteri onayladı", "Teslime hazır", "Teslim edildi", "approved": return scheme == .dark ? Color(red: 0.44, green: 0.83, blue: 0.63) : Color(red: 0.12, green: 0.42, blue: 0.29)
        case "Fiyat onayı bekliyor", "Parça bekleniyor", "pending": return scheme == .dark ? Color(red: 0.94, green: 0.73, blue: 0.37) : Color(red: 0.52, green: 0.32, blue: 0.07)
        case "İptal edildi", "Teklif reddedildi", "rejected": return .red
        default: return .accentColor }
    }
    var body: some View {
        Text(app.t(status == "approved" ? "Onaylandı" : status == "pending" ? "Onay bekliyor" : status == "rejected" ? "Reddedildi" : status))
            .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundColor(color).background(color.opacity(0.12), in: Capsule())
    }
}
@MainActor struct ErrorNotice: View {
    @EnvironmentObject var app: AppState
    let message: String
    var body: some View { Label(app.t(message), systemImage: "exclamationmark.circle.fill")
        .font(.subheadline).foregroundColor(.red).padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityAddTraits(.isStaticText) }
}
@MainActor struct EmptyState: View {
    @EnvironmentObject var app: AppState
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) { Image(systemName: "tray").font(.largeTitle).foregroundColor(.secondary).padding(.bottom, 8).accessibilityHidden(true); Text(app.t(title)).font(.title3.weight(.semibold)); Text(app.t(detail)).font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center) }
            .frame(maxWidth: .infinity).padding(32)
    }
}
enum ServiceStyle {
    static let canvas = Color("AppCanvas")
    static let surface = Color("AppSurface")
    static let line = Color.primary.opacity(0.07)
}

struct ServiceCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(18)
            .background(ServiceStyle.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ServiceStyle.line, lineWidth: 1))
    }
}

extension View {
    func serviceCard() -> some View { modifier(ServiceCard()) }
    func serviceList() -> some View {
        self.scrollContentBackground(.hidden).background(ServiceStyle.canvas)
            .listStyle(.insetGrouped)
    }
}

@MainActor struct RecordRow: View {
    @EnvironmentObject var app: AppState
    let record: ServiceRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.number).font(.caption.monospaced().weight(.medium))
                Spacer(minLength: 8)
                Text(app.date(record.createdAt)).font(.caption)
            }.foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: deviceSymbol(record.kind))
                    .font(.title3.weight(.medium)).foregroundColor(.accentColor)
                    .frame(width: 42, height: 46)
                    .background(Color("IconSurface"), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.device).font(.body.weight(.semibold)).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
                    Text(record.name).font(.subheadline).foregroundColor(.secondary)
                }
            }
            StatusBadge(status: record.displayStatus)
        }.padding(.vertical, 10)
    }
}

func deviceSymbol(_ kind: String) -> String {
    switch kind { case "Telefon": return "iphone"; case "Tablet": return "ipad"; default: return "laptopcomputer" }
}
@MainActor struct DetailLine: View {
    let title: String
    let value: String
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption).foregroundColor(.secondary); Text(value.isEmpty ? "—" : value).font(.body).textSelection(.enabled) }.padding(.vertical, 3) }
}
@MainActor struct QuoteSummary: View {
    @EnvironmentObject var app: AppState
    let quote: Quote
    let currency: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("\(app.t("Teklif")) v\(quote.version)").font(.headline); Spacer(); StatusBadge(status: quote.decision) }
            DetailLine(title: app.t("Tespit edilen arıza"), value: quote.diagnosis)
            DetailLine(title: app.t("Yapılacak işlemler"), value: quote.work)
            ForEach(quote.parts.indices, id: \.self) { index in HStack { Text(quote.parts[index].name); Spacer(); Text(app.money(quote.parts[index].amount, currency: currency)).monospacedDigit() } }
            HStack { Text(app.t("İşçilik")); Spacer(); Text(app.money(quote.labor, currency: currency)) }
            Divider()
            HStack { Text(app.t("Toplam")); Spacer(); Text(app.money(quote.total, currency: currency)).monospacedDigit() }.font(.headline)
            if !quote.eta.isEmpty { DetailLine(title: app.t("Tahmini teslim"), value: quote.eta) }
            if let at = quote.decidedAt { Text(app.date(at)).font(.caption).foregroundColor(.secondary) }
        }.padding(.vertical, 6)
    }
}
@MainActor struct Timeline: View {
    @EnvironmentObject var app: AppState
    let events: [ServiceEvent]
    var onDelete: ((ServiceEvent) -> Void)? = nil
    var deleting = false
    var body: some View {
        ForEach(events.filter { $0.deletedAt == nil }.reversed()) { event in
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 8) {
                    Circle().fill(event.internal ? Color.secondary : Color.accentColor).frame(width: 8, height: 8)
                    Rectangle().fill(ServiceStyle.line).frame(width: 1).frame(minHeight: 35)
                }.padding(.top, 5).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(app.date(event.at)); if event.internal { Label(app.t("İç not"), systemImage: "lock") } }
                        .font(.caption).foregroundColor(.secondary)
                    Text(app.eventText(event.text)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    if let remove = onDelete { Button(app.t("Adımı kaldır"), role: .destructive) { remove(event) }.disabled(deleting).font(.caption) }
                    if let actor = event.actor { Text(actor).font(.caption).foregroundColor(.secondary) }
                }.padding(.bottom, 12)
            }.padding(.vertical, 6)
        }
    }
}
@MainActor struct TrackingLinkSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let token: String
    private var link: String { app.endpoint + "/takip/" + token }
    @State private var qr: UIImage?
    private func makeQR() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(link.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 9, y: 9)), let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(app.t("Müşteri takip bağlantısı")).font(.title2.weight(.semibold))
                if let qr = qr { Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 220, height: 220).padding(20).background(Color.white, in: RoundedRectangle(cornerRadius: 16)).accessibilityLabel(app.t("Takip QR kodu")) }
                Text(app.t("Bu bağlantıyı güvenli şekilde saklayın. Yalnızca bir kez gösterilir.")).font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
                Text(link).font(.caption.monospaced()).textSelection(.enabled)
                ShareLink(item: link) { Text(app.t("Paylaş")) }.buttonStyle(ServicePrimaryButtonStyle())
                Button(app.t("Kopyala")) { UIPasteboard.general.string = link }.buttonStyle(.bordered)
            }.padding(24).frame(maxWidth: 550).navigationTitle("UstaX")
                .onAppear { if qr == nil { qr = makeQR() } }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(app.t("Bitti")) { dismiss() } } }
        }
    }
}

struct ServiceTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundColor(.accentColor)
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

struct ServicePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var loading = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Color("ButtonBlue"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(enabled || loading ? (configuration.isPressed ? 0.85 : 1) : 0.55)
    }
}

// Menu choices stay on the current screen and use the native control style.
@MainActor struct SelectionRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let label: (String) -> String
    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in Text(label(option)).tag(option) }
        }.pickerStyle(.menu).buttonStyle(.automatic).frame(minHeight: 44)
    }
}

@MainActor struct AboutView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("UstaX").font(.largeTitle.weight(.semibold))
                Text(app.t("UstaX, telefon, tablet ve bilgisayar teknik servisleri için geliştirilmiş bir servis ve tamir takip sistemidir.")).font(.body).fixedSize(horizontal: false, vertical: true)
                Text(app.t("Müşteri ve cihaz kabulünden fiyat teklifine, müşteri onayından tamir ve teslim aşamalarına kadar süreci tek yerde yönetir. Müşteriler, güvenli takip bağlantılarıyla cihazlarının güncel durumunu görüntüleyebilir.")).font(.body).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                Text(app.t("Mirac Suicmez tarafından geliştirilmiştir.")).font(.headline).fixedSize(horizontal: false, vertical: true)
            }.padding(24).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
        }.background(ServiceStyle.canvas).navigationTitle(app.t("UstaX hakkında")).navigationBarTitleDisplayMode(.inline)
    }
}
