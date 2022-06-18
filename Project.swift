import SwiftUI

/**
 * An entire HTML Editor project containing multiple open editors.
 * 
 * There is a one-to-one correspondance between Projects and scenes in the app.
 */
class Project : NSObject, UIDocumentPickerDelegate, ObservableObject {
    @Published var openDocuments: [Page];
    
    override init() {
        self.openDocuments = []
    }
    
    func addNewPage() {
        openDocuments.append(Page())
    }
    
    func openPage(scene: UIWindowScene) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.html]);
        
        documentPicker.delegate = self;
        
        scene.keyWindow?.rootViewController?.present(documentPicker, animated: true);
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("Picked.")
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Cancelled.")
    }
}
