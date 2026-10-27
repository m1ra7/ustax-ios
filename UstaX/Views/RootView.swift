import SwiftUI
import UIKit

@MainActor struct RootView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    private var refreshIdentity: String { scenePhase == .active ? (app.staff?.id ?? "") : "" }
    var body: some View {
        Group {
            if app.loading {
                ZStack {
                    ServiceStyle.canvas.ignoresSafeArea()
                    Text("UstaX").font(.system(size: 36, weight: .semibold)).foregroundColor(Color("LaunchInk"))
                    ProgressView().tint(Color("LaunchInk")).offset(y: 64).accessibilityLabel(app.t("Yükleniyor…"))
                }
            }
            else if app.staff != nil {
                TabView {
                    NavigationStack { DashboardView() }.tabItem { Label(app.t("Genel bakış"), systemImage: "square.grid.2x2") }
                    NavigationStack { RecordsView() }.tabItem { Label(app.t("Servis kayıtları"), systemImage: "list.bullet.rectangle") }
                    NavigationStack { CustomersView() }.tabItem { Label(app.t("Müşteriler"), systemImage: "person.2") }
                    NavigationStack { SettingsView() }.tabItem { Label(app.t("Ayarlar"), systemImage: "slider.horizontal.3") }
                }
            } else { NavigationStack { LoginView() } }
        }.tint(Color.accentColor).task { await app.restore() }
            .task(id: refreshIdentity) {
                guard !refreshIdentity.isEmpty else { return }
                while !Task.isCancelled {
                    do { try await app.reload() } catch is CancellationError { return } catch { }
                    do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
                }
            }
    }
}
@MainActor struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var endpoint = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var serverExpanded = false
    @State private var passwordVisible = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case server, email, password }
    private var canLogin: Bool {
        !busy && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                VStack(alignment: .leading, spacing: 20) {
                    serverSettings
                    accountFields
                    if let message = error ?? app.error { ErrorNotice(message: message) }
                    signInButton
                }.serviceCard()
                trackingLink
                preferences
            }
            .padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 28)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background(ServiceStyle.canvas)
        .statusBarHidden(false)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            endpoint = app.endpoint
            serverExpanded = endpoint.isEmpty
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("UstaX").font(.system(.largeTitle, design: .rounded).weight(.bold)).tracking(-0.8)
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("Çalışan girişi")).font(.title2.weight(.semibold))
                Text(app.t("Servislerinizi tek yerden yönetin.")).font(.body).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.bottom, 2)
    }
    private var serverSettings: some View {
        DisclosureGroup(isExpanded: $serverExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://servis.example.com", text: $endpoint)
                    .font(.subheadline).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focusedField, equals: .server).submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .padding(12).frame(minHeight: 48)
                    .background(ServiceStyle.canvas, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(app.t("Sunucu adresi"))
                Text(app.t("Bağımsız web uygulamanızın HTTPS adresini girin.")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 12)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(app.t("Sunucu")).font(.subheadline.weight(.medium)).foregroundColor(.primary)
                Text(serverDescription).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }.frame(minHeight: 44, alignment: .leading)
        }.disabled(busy)
    }
    private var serverDescription: String {
        let value = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return app.t("İlk kullanımda sunucu adresini ekleyin.") }
        let address = value.contains("://") ? value : "https://" + value
        return URL(string: address)?.host ?? app.t("Sunucu adresini kontrol edin.")
    }
    private var accountFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("E-posta")).font(.subheadline.weight(.medium))
                TextField("ornek@servis.com", text: $email)
                    .keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focusedField, equals: .email).submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .padding(14).frame(minHeight: 50)
                    .background(ServiceStyle.canvas, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(app.t("E-posta"))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("Parola")).font(.subheadline.weight(.medium))
                HStack(spacing: 0) {
                    passwordField.padding(.leading, 14)
                    Button {
                        passwordVisible.toggle()
                        focusedField = .password
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .font(.body).foregroundColor(.accentColor).frame(width: 48, height: 50)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(app.t(passwordVisible ? "Parolayı gizle" : "Parolayı göster"))
                }.background(ServiceStyle.canvas, in: RoundedRectangle(cornerRadius: 12))
            }
        }.disabled(busy)
    }
    private var passwordField: some View {
        Group {
            if passwordVisible { TextField(app.t("Parola"), text: $password) }
            else { SecureField(app.t("Parola"), text: $password) }
        }
        .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
        .focused($focusedField, equals: .password).submitLabel(.go)
        .onSubmit { login() }.accessibilityLabel(app.t("Parola"))
    }
    private var signInButton: some View {
        Button { login() } label: {
            HStack(spacing: 10) {
                if busy { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                Text(app.t(busy ? "Giriş yapılıyor…" : "Giriş yap")).font(.body.weight(.semibold)).foregroundColor(.white)
            }.frame(maxWidth: .infinity, minHeight: 40)
        }.buttonStyle(ServicePrimaryButtonStyle(loading: busy)).disabled(!canLogin && !busy).allowsHitTesting(!busy)
    }
    private var trackingLink: some View {
        NavigationLink { TrackingView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox").font(.title3.weight(.medium)).foregroundColor(.accentColor)
                    .frame(width: 46, height: 48)
                    .background(Color("IconSurface"), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.t("Cihazımı takip et")).font(.subheadline.weight(.semibold)).foregroundColor(.accentColor)
                    Text(app.t("Takip bağlantınızla servis durumunu görün.")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).serviceCard()
        }.buttonStyle(.plain).disabled(busy)
    }
    private var preferences: some View {
        VStack(spacing: 12) {
            LanguageControl().frame(minHeight: 44)
            NavigationLink { AppIconPickerView() } label: {
                HStack { Text(app.t("Uygulama simgesi")); Spacer(); Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true) }
                    .font(.subheadline).foregroundColor(.accentColor).frame(minHeight: 44)
            }
            NavigationLink(app.t("UstaX hakkında")) { AboutView() }.frame(minHeight: 44)
            Divider()
            Toggle(app.t("Koyu mod"), isOn: $app.dark).font(.subheadline).frame(minHeight: 44)
        }.disabled(busy)
    }
    private func login() {
        guard canLogin else { return }
        focusedField = nil
        busy = true; error = nil
        Task { @MainActor in
            do {
                try await app.saveEndpoint(endpoint)
                endpoint = app.endpoint
                try await app.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                password = ""
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
@MainActor struct LanguageControl: View {
    @EnvironmentObject var app: AppState
    var body: some View { SelectionRow(title: app.t("Uygulama dili"), selection: $app.language, options: ["tr", "en", "de"], label: { ["tr": "Türkçe", "en": "English", "de": "Deutsch"][$0] ?? $0 }) }
}
@MainActor struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var endpoint = ""
    @State private var health: Health?
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        Form {
            Group {
            if let user = app.staff { Section(app.t("Hesap")) { DetailLine(title: app.t("Ad soyad"), value: user.name); DetailLine(title: app.t("E-posta"), value: user.email); Text(app.t(user.isAdmin ? "Yönetici" : "Teknisyen")) } }
            Section(app.t("Sunucu")) {
                TextField("https://servis.example.com", text: $endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text(app.t("Sunucu değiştiğinde yeniden giriş yapmanız gerekir.")).font(.caption).foregroundColor(.secondary)
                Button(app.t("Bağlantıyı kontrol et")) { busy = true; Task { @MainActor in
            do { try await app.saveEndpoint(endpoint); health = try await app.api.send("health"); error = nil } catch { self.error = error.localizedDescription } 
            busy = false
        } }.disabled(busy)
                if let health = health { connection("Veritabanı", health.database); connection("Fotoğraflar", health.photos); connection("E-posta doğrulaması", health.email) }
            }
            if let error = error { Section { ErrorNotice(message: error) } }
            if app.isAdmin { Section { NavigationLink(app.t("Ekip ve yetkiler")) { TeamView() } } }
            Section { NavigationLink(app.t("Uygulama simgesi")) { AppIconPickerView() }; NavigationLink(app.t("Cihazımı takip et")) { TrackingView() }; LanguageControl() }
            Section(app.t("Para birimi")) {
                SelectionRow(title: app.t("Yeni kayıtlar için"), selection: $app.preferredCurrency, options: Currency.codes, label: { app.t(Currency.title($0)) })
                Text(app.t("Yalnızca yeni servis kayıtlarına uygulanır. Mevcut tutarlar dönüştürülmez.")).font(.caption).foregroundColor(.secondary)
            }
            Section { NavigationLink(app.t("UstaX hakkında")) { AboutView() } }
            Section { Button(app.t("Oturumu kapat"), role: .destructive) { Task { await app.logout() } } }
            Section { Toggle(app.t("Koyu mod"), isOn: $app.dark) }
        
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Ayarlar")).onAppear { endpoint = app.endpoint }
    }
    private func connection(_ title: String, _ ready: Bool) -> some View { HStack { Text(app.t(title)); Spacer(); Text(app.t(ready ? "Yapılandırıldı" : "Bağlantı gerekli")).font(.caption).foregroundColor(ready ? .green : .orange) } }
}


private struct AppIconChoice: Identifiable {
    let id: String
    let title: String
    let preview: String
    var alternateName: String? { id == "primary" ? nil : id }
}

@MainActor private struct AppIconPickerView: View {
    @EnvironmentObject var app: AppState
    @State private var selected = "primary"
    @State private var busy = false
    @State private var error: String?
    private let choices = [
        AppIconChoice(id: "primary", title: "Lacivert U", preview: "LogoNavy"),
        AppIconChoice(id: "UstaXTeal", title: "Petrol yeşili X", preview: "LogoTeal"),
        AppIconChoice(id: "UstaXIvory", title: "Açık zeminli U", preview: "LogoIvory")
    ]
    var body: some View {
        List {
            Group {
            Section {
                Text(app.t("Ana ekrandaki UstaX simgesini seçin.")).font(.callout).foregroundColor(.secondary)
            }
            Section {
                ForEach(choices) { choice in
                    Button { choose(choice) } label: {
                        HStack(spacing: 16) {
                            Image(choice.preview).resizable().scaledToFit()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                            Text(app.t(choice.title)).foregroundColor(.accentColor)
                            Spacer()
                            if selected == choice.id { Text(app.t("Seçili")).font(.caption.weight(.semibold)) }
                        }.padding(.vertical, 6)
                    }.disabled(busy || selected == choice.id)
                    .accessibilityLabel(app.t(choice.title))
                    .accessibilityValue(selected == choice.id ? app.t("Seçili") : "")
                }
            }
            if busy { ProgressView() }
            if let error = error { Section { ErrorNotice(message: error) } }
        
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Uygulama simgesi"))
            .onAppear { selected = UIApplication.shared.alternateIconName ?? "primary" }
    }
    private func choose(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons else { error = "Bu cihazda simge değiştirme desteklenmiyor."; return }
        busy = true; error = nil
        UIApplication.shared.setAlternateIconName(choice.alternateName) { failure in
            Task { @MainActor in
                busy = false
                if failure != nil { error = "Uygulama simgesi değiştirilemedi." }
                else { selected = UIApplication.shared.alternateIconName ?? "primary" }
            }
        }
    }
}
