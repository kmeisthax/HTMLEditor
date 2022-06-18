import SwiftUI

/**
 * An entire HTML Editor project containing multiple open editors.
 * 
 * There is a one-to-one correspondance between Projects and scenes in the app.
 */
class Project : NSObject, UIDocumentPickerDelegate, ObservableObject {
    @Published var openDocuments: [Page];
    
    var lastSuccessCallback: (([URL]) -> Void)?;
    var lastCancelCallback: (() -> Void)?;
    
    override init() {
        self.openDocuments = []
    }
    
    func addNewPage() {
        openDocuments.append(Page())
    }
    
    func openPage(scene: UIWindowScene) {
        openPage(scene: scene) { [self] urls in
            for url in urls {
                openDocuments.append(Page.fromSecurityScopedUrl(url: url))
            }
        }
    }
    
    func openPage(scene: UIWindowScene, success: @escaping ([URL]) -> Void) {
        openPage(scene: scene, success: success, cancel: nil);
    }
    
    func openPage(scene: UIWindowScene, success: @escaping ([URL]) -> Void, cancel: (() -> Void)?) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.html]);
        
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
