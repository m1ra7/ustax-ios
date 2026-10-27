import SwiftUI

@main @MainActor struct UstaXApp: App {
    @StateObject private var app = AppState()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).preferredColorScheme(app.dark ? .dark : .light)
                .environment(\.locale, app.locale)
                .tint(Color.accentColor)
                .toggleStyle(SwitchToggleStyle(tint: Color("ButtonBlue")))
                .statusBarHidden(false)
        }
    }
}
