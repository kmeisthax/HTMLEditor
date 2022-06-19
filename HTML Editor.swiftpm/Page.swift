import SwiftUI
import Foundation
import Combine

/**
 * Who owns a given file.
 */
enum FileOwnership {
    /**
     * File is owned by the app.
     */
    case AppOwned;
    
    /**
     * File is owned by the system and we are borrowing it.
     */
    case SecurityScoped;
}

/**
 * Viewmodel class for individual HTML files in a project.
 * 
 * Intended to be owned by a Project viewmodel. Also adopts NSFilePresenter
 * to allow file updates (which apparently even Swift Playgrounds itself
 * doesn't do?)
 * 
 * View code should not create pages directly; views should ask their
 * associated Project to create a Page and then access it from there.
 */
class Page : NSObject, ObservableObject, Identifiable, NSFilePresenter, UIDocumentPickerDelegate {
    var id: UUID;
    
    @Published var presentedItemURL: URL?;
    
    @Published var ownership: FileOwnership = .AppOwned;
    
    var filename: String {
        if let url = presentedItemURL {
            return url.lastPathComponent
        } else {
            return "Untitled"
        }
    };
    
    lazy var presentedItemOperationQueue: OperationQueue = OperationQueue.main;
    
    @Published var html: String = "<!DOCTYPE html>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
    
    var c: [AnyCancellable] = [];
    
    override init() {
        id = UUID.init()
        
        super.init()
        
        $html.sink(receiveValue: { [weak self] html in
            if let url = self?.presentedItemURL {
                let coordinator = NSFileCoordinator.init(filePresenter: self);
                
                print(url);
                
                coordinator.coordinate(with: [.writingIntent(with: url)], queue: self!.presentedItemOperationQueue) { error in
                    if let error = error {
                        print (error);
                    }
                    
                    self!.doActualSave(url: url, html: html);
                }
            }
        }).store(in: &c);
    }
    
    class func fromSecurityScopedUrl(url: URL) -> Page {
        let page = Page();
        page.presentedItemURL = url;
        page.ownership = .SecurityScoped;
        
        let coordinator = NSFileCoordinator.init(filePresenter: page);
        
        coordinator.coordinate(with: [.readingIntent(with: url)], queue: page.presentedItemOperationQueue) { error in
            //TODO: Error handling.
            if let error = error {
                print (error);
            }
            
            page.presentedItemDidChange();
        };
        
        print("Opened");
        
        return page;
    }
    
    class func fromTemporaryStorage() -> Page {
        let name = UUID().uuidString + ".html";
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0];
        
        let page = Page();
        page.presentedItemURL = url.appendingPathComponent(name);
        page.ownership = .AppOwned;
        
        return page;
    }
    
    func presentedItemDidChange() {
        if let url = self.presentedItemURL {
            if self.ownership == .SecurityScoped && !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
                //panic! at the disco
                print("Cannot access URL")
            }
            
            do {
                self.html = try String(contentsOf: url);
            } catch {
                //panic?!
                print("Error reading URL")
            }
            
            if self.ownership == .SecurityScoped {
                CFURLStopAccessingSecurityScopedResource(url as CFURL);
            }
        } else {
            print("No URL")
        }
    }
    
    private func doActualSave(url: URL, html: String) {
        if self.ownership == .SecurityScoped && !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
            //panic! at the disco
            print("Cannot access URL")
        }
        
        do {
            print("About to save");
            try html.write(to: url, atomically: true, encoding: .utf8);
            print("Saved");
        } catch {
            //panic?!
            print("Error writing URL")
        }
        
        if self.ownership == .SecurityScoped {
            CFURLStopAccessingSecurityScopedResource(url as CFURL);
        }
    }
    
    func pickLocationForAppOwnedFile(scene: UIWindowScene) {
        if let url = self.presentedItemURL {
            self.doActualSave(url: url, html: self.html);
            
            let documentPicker = UIDocumentPickerViewController(forExporting: [url], asCopy: false);
            
            documentPicker.delegate = self;
            
            scene.keyWindow?.rootViewController?.present(documentPicker, animated: true);
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.presentedItemURL = urls[0];
        self.ownership = .SecurityScoped;
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
    }
}
