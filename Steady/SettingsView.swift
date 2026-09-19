import SwiftUI
import SteadyCore
import StoreKit
import UniformTypeIdentifiers

/// 设置页（W7 视图+设置批②）：
/// General：周起始日/角标；归档列表（恢复/硬删）；数据：JSON 导出/导入；评分/反馈/重看 onboarding
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("steady.weekStartsMonday") private var weekStartsMonday = true
    @AppStorage("steady.showBadge") private var showBadge = true
    @AppStorage("steady.showStreaks") private var showStreaks = true
    @AppStorage("steady.showWeekDots") private var showWeekDots = true

    @State private var archived: [HabitEntity] = []
    @State private var confirmDelete: HabitEntity? = nil
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDoc = JSONDocument()
    @State private var toast: String? = nil

    private var repo: HabitRepository { HabitRepository(context: context) }

    var body: some View {
        NavigationView {
            Form {
                Section("General") {
                    // 周起始日：存偏好，引擎以周一为锚（weekly bucket 计算基准）
                    Picker("Week starts on", selection: $weekStartsMonday) {
                        Text("Monday").tag(true)
                        Text("Sunday").tag(false)
                    }
                    Toggle("App icon badge", isOn: $showBadge)
                        .onChange(of: showBadge) { v in
                            if !v { UIApplication.shared.applicationIconBadgeNumber = 0 }
                        }
                }

                // W7④ 面板自定义：Today 行显示元素开关（对齐 HabitKit Dashboard Customization）
                Section("Dashboard") {
                    Toggle("Show streak counts", isOn: $showStreaks)
                    Toggle("Show week dots", isOn: $showWeekDots)
                }

                Section("Archived habits") {
                    if archived.isEmpty {
                        Text("No archived habits").foregroundColor(.secondary)
                    }
                    ForEach(archived, id: \.id) { h in
                        HStack {
                            Image(systemName: h.icon).foregroundColor(Color(hex: h.colorHex))
                            Text(h.name)
                            Spacer()
                            Button("Restore") { repo.unarchive(h); reloadArchived() }
                                .font(.subheadline)
                            Button("Delete", role: .destructive) { confirmDelete = h }
                                .font(.subheadline)
                        }
                    }
                }

                Section("Data") {
                    Button {
                        if let data = try? BackupService.export(context: context) {
                            exportDoc = JSONDocument(data: data)
                            exporting = true
                        }
                    } label: { Label("Export JSON", systemImage: "square.and.arrow.up") }
                    Button { importing = true } label: {
                        Label("Import JSON", systemImage: "square.and.arrow.down")
                    }
                }

                Section("About") {
                    Button {
                        // SKStoreReviewController：系统限频，连续点不会重复弹
                        if let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    } label: { Label("Rate Steady", systemImage: "star") }
                    Link(destination: URL(string: "mailto:wtt_mac@163.com?subject=Steady%20feedback")!) {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    Button { UserDefaults.standard.removeObject(forKey: "steady.onboarded") } label: {
                        Label("Replay onboarding", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .onAppear(perform: reloadArchived)
            .alert("Delete permanently?", isPresented: Binding(
                get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let h = confirmDelete {
                        NotificationManager.cancelReminder(habitId: h.id)
                        repo.deletePermanently(h)
                        reloadArchived()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes \"\(confirmDelete?.name ?? "")\" and all its history. This can't be undone.")
            }
            .fileExporter(isPresented: $exporting, document: exportDoc,
                          contentType: .json, defaultFilename: "steady-backup") { _ in }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url),
                   let (h, c) = try? BackupService.restore(context: context, from: data) {
                    toast = "Imported \(h) habits, \(c) check-ins"
                } else {
                    toast = "Import failed — not a valid Steady backup"
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                        .task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            self.toast = nil
                        }
                }
            }
        }
    }

    private func reloadArchived() { archived = repo.archivedHabits() }
}

/// fileExporter 需要 Document 协议包装
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json]
    var data: Data = Data()

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
