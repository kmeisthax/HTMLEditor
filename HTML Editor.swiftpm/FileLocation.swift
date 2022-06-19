import SwiftUI
import UniformTypeIdentifiers;

/**
 * A location that can be changed by the user.
 */
class FileLocation: NSObject, UIDocumentPickerDelegate, ObservableObject {
    @Published var pickedUrls: [URL];
    
    var allowedContentTypes: [UTType];
    
    var displayName: String {
        if let url = self.pickedUrls.first {
            return url.lastPathComponent;
        } else {
            return "";
        }
    }
    
    init(contentTypes: [UTType]) {
        self.pickedUrls = [];
        self.allowedContentTypes = contentTypes;
    }
    
    init(urls: [URL], contentTypes: [UTType]) {
        self.pickedUrls = urls;
        self.allowedContentTypes = contentTypes;
    }
    
    /**
     * Open a document picker to change the location.
     */
    func pick(scene: UIWindowScene) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes);
        
        documentPicker.delegate = self;
        
        var viewController = scene.keyWindow!.rootViewController!;
        
        while let newVC = viewController.presentedViewController {
            viewController = newVC;
        }
        
        viewController.present(documentPicker, animated: true);
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.pickedUrls = urls;
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
    }
}
