import SwiftUI
import UniformTypeIdentifiers

public struct DocumentPicker: UIViewControllerRepresentable {
    public let forFolder: Bool
    public var onPickURLs: ([URL]) -> Void

    public init(forFolder: Bool = false, onPickURLs: @escaping ([URL]) -> Void) {
        self.forFolder = forFolder
        self.onPickURLs = onPickURLs
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        if forFolder {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        } else {
            let audioTypes: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio]
            picker = UIDocumentPickerViewController(forOpeningContentTypes: audioTypes, asCopy: false)
            picker.allowsMultipleSelection = true
        }
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPickURLs(urls)
        }
    }
}
