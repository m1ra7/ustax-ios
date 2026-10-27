import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

@MainActor struct ProtectedPhoto: View {
    @EnvironmentObject var app: AppState
    let recordID: String
    let photo: ServicePhoto
    var token: String? = nil
    var fullSize = false
    @State private var image: UIImage?
    @State private var error: String?
    var body: some View {
        Group {
            if let image = image { Image(uiImage: image).resizable().scaledToFit() }
            else if let error = error { ErrorNotice(message: error).padding() }
            else { ProgressView().padding(30) }
        }.frame(maxWidth: .infinity).frame(minHeight: fullSize ? 150 : 100)
            .task(id: photo.id + (fullSize ? "/full" : "/thumb") + String(photo.visible)) {
                error = nil
                do {
                    try Task.checkCancellation()
                    let loaded = try await PhotoPipeline.shared.image(api: app.api, recordID: recordID, photo: photo, token: token, pixels: fullSize ? 2400 : 640)
                    try Task.checkCancellation()
                    image = loaded
                } catch is CancellationError { }
                catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            }
            .onDisappear { image = nil }
            .accessibilityLabel(app.t(photo.phase))
    }
}
@MainActor struct PhotoZoomView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let recordID: String
    let photo: ServicePhoto
    var token: String? = nil
    @State private var scale: CGFloat = 1
    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) { ProtectedPhoto(recordID: recordID, photo: photo, token: token, fullSize: true).frame(width: UIScreen.main.bounds.width - 24).scaleEffect(scale).padding(12) }
                .gesture(MagnificationGesture().onChanged { scale = min(max($0, 1), 4) })
                .navigationTitle(app.t(photo.phase)).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(app.t("Bitti")) { dismiss() } }; ToolbarItem(placement: .bottomBar) { Button(app.t("Boyutu sıfırla")) { scale = 1 } } }
        }
    }
}
@MainActor struct PhotosView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let record: ServiceRecord
    @State private var choosingPhoto = false
    @State private var choosingFile = false
    @State private var phase = "Kabul"
    @State private var visible = false
    @State private var busy = false
    @State private var uploading = false
    @State private var completed = 0
    @State private var total = 0
    @State private var error: String?
    @State private var selectedPhoto: ServicePhoto?
    @State private var camera = false
    @State private var pendingDelete: ServicePhoto?
    private var current: ServiceRecord { app.catalog.byID[record.id] ?? record }
    var body: some View {
        NavigationStack {
            List {
            Group {
                Section(app.t("Fotoğraf yükle")) {
                    SelectionRow(title: app.t("Aşama"), selection: $phase, options: ["Kabul", "Tamir öncesi", "Tamir sonrası"], label: { app.t($0) })
                    Toggle(app.t("Müşteri görebilsin"), isOn: $visible)
                    Button(app.t("Fotoğraf seç")) { choosingPhoto = true }.buttonStyle(.bordered).disabled(busy)
                    Button(app.t("Dosyalardan fotoğraf seç")) { choosingFile = true }.disabled(busy)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) { Button(app.t("Fotoğraf çek")) { camera = true }.disabled(busy) }
                    if uploading { Text(app.t("Yükleme sürüyor. Aşama değişikliği sonraki yüklemeye uygulanır.")).font(.caption).foregroundColor(.secondary) }
                    if uploading { ProgressView(value: Double(completed), total: Double(max(total, 1))); Text("\(completed) / \(total)").font(.caption).monospacedDigit() }
                    if busy && !uploading { ProgressView() }
                    Text(app.t("Fotoğraflar yüklemeden önce en fazla 3 MB boyutunda JPEG olarak hazırlanır.")).font(.caption).foregroundColor(.secondary)
                }
                if let error = error { Section { ErrorNotice(message: error) } }
                Section(app.t("Fotoğraflar")) {
                    if current.photos.isEmpty { Text(app.t("Henüz fotoğraf yok.")).foregroundColor(.secondary) }
                    ForEach(current.photos) { photo in photoCard(photo) }
                }
            
            }.listRowBackground(ServiceStyle.surface)
        }.serviceList().navigationTitle(app.t("Fotoğraflar")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(app.t("Bitti")) { dismiss() }.disabled(busy) } }
                .confirmationDialog(app.t("Bu fotoğraf silinsin mi? Müşteri takibinden de kaldırılacak."), isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                    if let photo = pendingDelete { Button(app.t("Fotoğrafı sil"), role: .destructive) { deletePhoto(photo) } }
                    Button(app.t("Vazgeç"), role: .cancel) { pendingDelete = nil }
                }
                .sheet(isPresented: $choosingPhoto) {
                    OriginalPhotoPicker { providers in choosingPhoto = false; load(providers) }
                }
                .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.image], allowsMultipleSelection: true, onCompletion: loadFile)
                .sheet(item: $selectedPhoto) { PhotoZoomView(recordID: current.id, photo: $0) }
                .sheet(isPresented: $camera) { CameraCapture { image in camera = false; if let image = image { uploadCamera(image) } } }
        }.interactiveDismissDisabled(busy)
    }
    private func photoCard(_ photo: ServicePhoto) -> some View {
                        VStack(alignment: .leading, spacing: 12) {
                            Button { selectedPhoto = photo } label: { ProtectedPhoto(recordID: current.id, photo: photo).frame(height: 180).clipped() }.buttonStyle(.plain)
                            HStack { Text(app.t(photo.phase)).font(.caption); Spacer(); Text(app.t(photo.visible ? "Müşteriye açık" : "İç kullanım")).font(.caption).foregroundColor(.secondary) }
                            HStack {
                                Button(app.t(photo.visible ? "Müşteriden gizle" : "Müşteriye göster")) { changeVisibility(photo) }.disabled(busy)
                                Spacer()
                                Button(role: .destructive) { pendingDelete = photo } label: { Label(app.t("Fotoğrafı sil"), systemImage: "trash") }.disabled(busy)
                            }.buttonStyle(.bordered)
                        }.padding(16)
                            .background(ServiceStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
    }
    private func deletePhoto(_ photo: ServicePhoto) {
        guard !busy else { return }
        pendingDelete = nil; busy = true; error = nil
        Task { @MainActor in
            do {
                let updated: ServiceRecord = try await app.api.send("records/\(record.id)/photos/\(photo.id)", method: "DELETE")
                PhotoPipeline.shared.invalidate(api: app.api, recordID: record.id, photoID: photo.id); app.update(updated)
                if selectedPhoto?.id == photo.id { selectedPhoto = nil }
                if let warning = updated.warning { self.error = app.t(warning) }
            } catch { self.error = photoError(error) }
            busy = false
        }
    }
    private func photoError(_ error: Error) -> String {
        let message = app.t(error.localizedDescription)
        if let status = (error as? AppError)?.status {
            #if DEBUG
            print("UstaX photo request failed: HTTP \(status)")
            #endif
            return message + " (HTTP \(status))"
        }
        #if DEBUG
        let details = error as NSError
        print("UstaX photo import/network failed: \(details.domain) \(details.code)")
        #endif
        return message
    }
    private func load(_ providers: [NSItemProvider]) {
        guard !busy, !providers.isEmpty else { return }
        busy = true; uploading = true; error = nil; completed = 0; total = providers.count
        let chosenPhase = phase, chosenVisibility = visible, recordID = record.id
        Task { @MainActor in
            for provider in providers {
                do {
                    let raw = try await OriginalPhotoData.load(provider)
                    let prepared = try await ImageWork.jpeg(raw)
                    try Task.checkCancellation()
                    let updated = try await app.api.upload(recordID: recordID, jpeg: prepared, phase: chosenPhase, visible: chosenVisibility)
                    app.update(updated)
                } catch { self.error = photoError(error) }
                completed += 1
            }
            busy = false; uploading = false
        }
    }
    private func loadFile(_ result: Result<[URL], Error>) {
        guard !busy else { return }
        switch result {
        case .failure: error = "Fotoğraf dosyası açılamadı. Dosyayı tekrar seçin."
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let urls = Array(urls.prefix(10))
            busy = true; uploading = true; error = nil; completed = 0; total = urls.count
            let chosenPhase = phase, chosenVisibility = visible, recordID = record.id
            Task { @MainActor in
                for url in urls {
                    do {
                        let raw = try await OriginalPhotoData.file(url)
                        let prepared = try await ImageWork.jpeg(raw)
                        try Task.checkCancellation()
                        let updated = try await app.api.upload(recordID: recordID, jpeg: prepared, phase: chosenPhase, visible: chosenVisibility)
                        app.update(updated)
                    } catch { self.error = photoError(error) }
                    completed += 1
                }
                busy = false; uploading = false
            }
        }
    }
    private func uploadCamera(_ image: UIImage) {
        guard !busy else { return }
        let chosenPhase = phase, chosenVisibility = visible
        busy = true; uploading = true; completed = 0; total = 1; error = nil
        Task { @MainActor in
            do { let prepared = try await ImageWork.cameraJPEG(image); try Task.checkCancellation(); let updated = try await app.api.upload(recordID: current.id, jpeg: prepared, phase: chosenPhase, visible: chosenVisibility); app.update(updated); completed = 1 } catch { self.error = photoError(error) } 
            busy = false; uploading = false
        }
    }
    private func changeVisibility(_ photo: ServicePhoto) {
        busy = true; error = nil
        Task { @MainActor in
            do { let updated: ServiceRecord = try await app.api.send("records/\(current.id)/photos", method: "PATCH", body: ["id": photo.id, "visible": !photo.visible]); app.update(updated) } catch { self.error = photoError(error) } 
            busy = false
        }
    }
}
@MainActor struct CameraCapture: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController { let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { completion(info[.originalImage] as? UIImage) }
    }
}

// Request the original representation instead of asking the Photos helper to transcode.
@MainActor struct OriginalPhotoPicker: UIViewControllerRepresentable {
    let completion: ([NSItemProvider]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 10
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([NSItemProvider]) -> Void
        init(completion: @escaping ([NSItemProvider]) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            completion(results.map { $0.itemProvider })
        }
    }
}

enum OriginalPhotoData {
    static let limit = 30 * 1024 * 1024
    private static func checked(_ data: Data) throws -> Data {
        guard !data.isEmpty else { throw AppError("Fotoğraf açılamadı.") }
        guard data.count <= limit else { throw AppError("Kaynak fotoğraf en fazla 30 MB olabilir.") }
        return data
    }
    private static func read(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values.fileSize, size > limit { throw AppError("Kaynak fotoğraf en fazla 30 MB olabilir.") }
        return try checked(Data(contentsOf: url))
    }
    static func load(_ provider: NSItemProvider) async throws -> Data {
        guard let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else { throw AppError("Fotoğraf açılamadı.") }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                if let url = url {
                    // The temporary file is valid only during this completion callback.
                    do { continuation.resume(returning: try read(url)) }
                    catch { continuation.resume(throwing: error) }
                } else {
                    provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                        guard let data = data else {
                            continuation.resume(throwing: AppError("Fotoğraf arşivden alınamadı. Dosyalardan fotoğraf seç seçeneğini deneyin.")); return
                        }
                        do { continuation.resume(returning: try checked(data)) }
                        catch { continuation.resume(throwing: error) }
                    }
                }
            }
        }
    }
    static func file(_ url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let accessed = url.startAccessingSecurityScopedResource()
                do {
                    let data = try read(url)
                    if accessed { url.stopAccessingSecurityScopedResource() }
                    continuation.resume(returning: data)
                } catch {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
