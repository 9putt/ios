import SwiftUI

public struct AppUpdateSheet: View {
    @ObservedObject var updateManager = AppUpdateManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Header Card
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color.green.opacity(0.3), Color.cyan.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 72, height: 72)
                                Image(systemName: updateManager.hasUpdate ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.seal.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(updateManager.hasUpdate ? .green : .cyan)
                            }
                            .padding(.top, 12)

                            Text(updateManager.hasUpdate ? "มีเวอร์ชันใหม่พร้อมให้อัปเดต!" : "คุณกำลังใช้เวอร์ชันล่าสุด")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                Text("เวอร์ชันปัจจุบัน: v\(updateManager.currentVersion)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.gray)

                                if updateManager.hasUpdate {
                                    Text("→")
                                        .foregroundColor(.green)
                                    Text("ล่าสุด: \(updateManager.latestVersionTag)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        // Action Buttons Card
                        VStack(spacing: 12) {
                            if updateManager.hasUpdate {
                                // 1. TrollStore One-Click Update
                                Button(action: {
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    updateManager.installViaTrollStore()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("⚡ อัปเดตทันทีผ่าน TrollStore")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(LinearGradient(colors: [Color.green, Color(red: 0.0, green: 0.9, blue: 0.6)], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(8)
                                    .shadow(color: Color.green.opacity(0.4), radius: 6)
                                }

                                Text("• กดครั้งเดียว TrollStore จะดาวน์โหลดและติดตั้งทับแอพเดิมให้ทันที ไม่ต้องลบแอพ")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)

                                // 2. In-App Download
                                if updateManager.isDownloading {
                                    VStack(spacing: 6) {
                                        ProgressView(value: updateManager.downloadProgress, total: 1.0)
                                            .tint(.cyan)
                                        Text("กำลังดาวน์โหลด: \(Int(updateManager.downloadProgress * 100))%")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.cyan)
                                    }
                                    .padding(.vertical, 6)
                                } else {
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        updateManager.startInAppDownload()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 14))
                                            Text("📥 ดาวน์โหลดไฟล์ IPA ในแอพ")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(8)
                                    }
                                }
                            }

                            // Check Updates Button
                            Button(action: {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                updateManager.checkForUpdates(silent: false)
                            }) {
                                HStack(spacing: 6) {
                                    if updateManager.isChecking {
                                        ProgressView().scaleEffect(0.7).tint(.white)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(updateManager.isChecking ? "กำลังตรวจสอบ..." : "🔄 ตรวจสอบอัปเดตใหม่")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .disabled(updateManager.isChecking)

                            if !updateManager.statusMessage.isEmpty {
                                Text(updateManager.statusMessage)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        // Release Notes
                        if !updateManager.releaseNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("รายละเอียดการอัปเดต:")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)

                                Text(updateManager.releaseNotes)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(3)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Winamp App Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ปิด") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $updateManager.showShareSheet) {
                if let fileUrl = updateManager.downloadedFileURL {
                    ShareSheetView(activityItems: [fileUrl])
                }
            }
        }
    }
}

public struct ShareSheetView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
