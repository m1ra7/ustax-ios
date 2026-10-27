import SwiftUI

@MainActor struct TeamView: View {
    @EnvironmentObject var app: AppState
    @State private var users: [Staff] = []
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var resetUser: Staff?
    @State private var role = "technician"
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Form {
            Group {
            Section(app.t("Çalışan ekle")) {
                TextField(app.t("Ad soyad"), text: $name)
                TextField(app.t("E-posta"), text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(app.t("İlk parola (en az 12 karakter)"), text: $password).textContentType(.newPassword)
                Picker(app.t("Rol"), selection: $role) { Text(app.t("Teknisyen")).tag("technician"); Text(app.t("Yönetici")).tag("admin") }.pickerStyle(.menu).buttonStyle(.automatic)
                Button(app.t("Çalışan ekle")) { add() }.disabled(busy || name.count < 2 || email.isEmpty || password.count < 12 || password.count > 200)
                Text(app.t("Parolayı çalışana güvenli bir kanaldan iletin.")).font(.caption).foregroundColor(.secondary)
            }
            if let error = error { Section { ErrorNotice(message: error) } }
            if busy { ProgressView() }
            Section(app.t("Ekip")) {
                ForEach(users) { user in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(user.name).font(.headline); Text(user.email).font(.caption).foregroundColor(.secondary)
                        if user.id == app.staff?.id { Text(app.t("Kendi hesabınız")).font(.caption) }
                        else {
                            Button(app.t("Parolayı yenile")) { resetUser = user }.disabled(busy)
                            Menu(app.t("Rol") + ": " + app.t(user.isAdmin ? "Yönetici" : "Teknisyen")) {
                                Button(app.t("Yönetici")) { update(user, body: ["role": "admin"]) }
                                Button(app.t("Teknisyen")) { update(user, body: ["role": "technician"]) }
                            }.disabled(busy)
                            Button(app.t(user.active ? "Erişimi kapat" : "Erişimi aç"), role: user.active ? .destructive : nil) { update(user, body: ["active": !user.active]) }.disabled(busy)
                        }
                    }.padding(.vertical, 5)
                }
            }
        
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Ekip ve yetkiler")).task { await load() }.refreshable { await load() }
            .sheet(item: $resetUser) { StaffPasswordView(user: $0) }
    }
    private func load() async { do { users = try await app.api.send("users"); error = nil } catch { self.error = error.localizedDescription } }
    private func add() { busy = true; Task { @MainActor in
            do { let _: Staff = try await app.api.send("users", method: "POST", body: ["name": name, "email": email, "role": role, "password": password]); name = ""; email = ""; password = ""; await load() } catch { self.error = error.localizedDescription } 
            busy = false
        } }
    private func update(_ user: Staff, body: [String: Any]) { busy = true; var payload = body; payload["id"] = user.id; Task { @MainActor in
            do { let _: Ack = try await app.api.send("users", method: "PATCH", body: payload); await load() } catch { self.error = error.localizedDescription } 
            busy = false
        } }
}

@MainActor struct StaffPasswordView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let user: Staff
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section(user.name) {
                    SecureField(app.t("Yeni parola (en az 12 karakter)"), text: $password).textContentType(.newPassword)
                    Text(app.t("Çalışanın açık oturumları kapatılır.")).font(.caption).foregroundColor(.secondary)
                }
                if let error = error { ErrorNotice(message: error) }
                Button(app.t("Kaydet")) { save() }.disabled(busy || password.count < 12 || password.count > 200)
                if busy { ProgressView() }
            }.serviceList().navigationTitle(app.t("Parolayı yenile"))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(app.t("Vazgeç")) { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
    }
    private func save() {
        busy = true; error = nil
        Task { @MainActor in
            do { let _: Ack = try await app.api.send("users/password", method: "PATCH", body: ["id": user.id, "password": password]); password = ""; dismiss() }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
