import SwiftUI
import UniformTypeIdentifiers

/**
 * An entire HTML Editor project containing multiple open editors.
 * 
 * There is a one-to-one correspondance between Projects and scenes in the app.
 */
class Project : NSObject, UIDocumentPickerDelegate, ObservableObject {
    /**
     * All the open documents in the project, including ones that are not
     * part of the project directory.
     */
    @Published var openDocuments: [Page];
    
    /**
     * The open project directory.
     */
    @Published var projectDirectory: URL?;
    
    /**
     * The open project directory in FileLocation format.
     */
    var projectLocation: FileLocation {
        get {
            if let pd = projectDirectory {
                return FileLocation(urls: [pd], contentTypes: [.folder]);
            } else {
                return FileLocation(contentTypes: [.folder]);
            }
        }
        set {
            projectDirectory = newValue.pickedUrls.first;
            republishDirectoryContents();
        }
    }
    
    @Published var projectFiles: [ProjectFileEntry] = [];
    
    func republishDirectoryContents() {
        if let url = projectDirectory {
            projectFiles = ProjectFileEntry.fromDirectoryContents(at: url);
        } else {
            projectFiles = [];
        }
    }
    
    var lastSuccessCallback: (([URL]) -> Void)?;
    var lastCancelCallback: (() -> Void)?;
    
    override init() {
        self.openDocuments = []
    }
    
    func addNewPage() {
        openDocuments.append(Page.fromTemporaryStorage())
    }
    
    func openPage(scene: UIWindowScene) {
        pickDocument(scene: scene, types: [.html]) { [self] urls in
            for url in urls {
                openDocuments.append(Page.fromSecurityScopedUrl(url: url, accessURL: url))
            }
        }
    }
    
    private func pickDocument(scene: UIWindowScene, types: [UTType], success: @escaping ([URL]) -> Void) {
        pickDocument(scene: scene, types: types, success: success, cancel: nil);
    }
    
    private func pickDocument(scene: UIWindowScene, types: [UTType], success: @escaping ([URL]) -> Void, cancel: (() -> Void)?) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types);
        
        documentPicker.delegate = self;
        
        self.lastSuccessCallback = success;
        self.lastCancelCallback = cancel;
        
        scene.keyWindow?.rootViewController?.present(documentPicker, animated: true);
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let success = lastSuccessCallback {
            success(urls)
        }
        
        lastSuccessCallback = nil;
        lastCancelCallback = nil;
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        if let cancel = lastCancelCallback {
            cancel()
        }
        
        lastSuccessCallback = nil;
        lastCancelCallback = nil;
    }
}
