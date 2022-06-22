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
    
    /**
     * A scoped-storage URL that can be used to unlock the presented item
     * for reading or writing.
     */
    var accessURL: URL?;
    
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
    
    /**
     * The contents of the file in memory.
     * 
     * This is a published property intended to be used by UI code to both
     * display and modify file contents. When this string is modified, an
     * autosave is triggered.
     */
    @Published var html: String = "<!DOCTYPE html>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
    
    /**
     * The contents of the file on disk.
     * 
     * Updates to HTML should only trip autosave iff they do not match what is
     * already on disk in this parameter.
     * 
     * The default value of this parameter must match html; otherwise the
     * default value of that parameter will overwrite every file we open and
     * lose user data.
     */
    var htmlOnDisk: String? = "<!DOCTYPE html>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
    
    /**
     * Autosave event storage
     */
    var c: [AnyCancellable] = [];
    
    override init() {
        id = UUID.init()
        
        super.init()
        
        $html.throttle(for: 1.0, scheduler: presentedItemOperationQueue, latest: true).sink(receiveValue: { [weak self] _ in
            if let url = self?.presentedItemURL {
                let coordinator = NSFileCoordinator.init(filePresenter: self);
                let scheduled_html = self!.html;
                
                if scheduled_html != self!.htmlOnDisk {
                    coordinator.coordinate(with: [.writingIntent(with: url)], queue: self!.presentedItemOperationQueue) { [self] error in
                        if let error = error {
                            print (error);
                        }
                        
                        self!.doActualSave(url: url, html: scheduled_html);
                    }
                }
            }
        }).store(in: &c);
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self);
    }
    
    class func fromSecurityScopedUrl(url: URL, accessURL: URL) -> Page {
        let page = Page();
        page.accessURL = accessURL;
        page.presentedItemURL = url;
        page.ownership = .SecurityScoped;
        
        let coordinator = NSFileCoordinator.init(filePresenter: page);
        
        coordinator.coordinate(with: [.readingIntent(with: url)], queue: page.presentedItemOperationQueue) { error in
            //TODO: Error handling.
            if let error = error {
                print (error);
            }
            
            NSFileCoordinator.addFilePresenter(page);
            
            //We have to kick off the load ourselves, so let's just
            //pretend to be a file coordinator and notify ourselves.
            page.presentedItemDidChange();
        };
        
        return page;
    }
    
    class func fromTemporaryStorage() -> Page {
        let name = UUID().uuidString + ".html";
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0];
        
        let page = Page();
        page.presentedItemURL = url.appendingPathComponent(name);
        page.ownership = .AppOwned;
        
        //This is an app-owned file, so we don't need to coordinate
        //as we created the file and it can't exist elsewhere
        NSFileCoordinator.addFilePresenter(page);
        
        return page;
    }
    
    class func newFileInScopedStorage(withName: String, accessURL: URL) -> Page {
        let untitledName = accessURL.appendingPathComponent(withName, conformingTo: .html)
        
        let page = Page();
        page.accessURL = accessURL;
        page.presentedItemURL = untitledName;
        page.ownership = .SecurityScoped;
        
        let coordinator = NSFileCoordinator.init(filePresenter: page);
        
        coordinator.coordinate(with: [.writingIntent(with: untitledName)], queue: page.presentedItemOperationQueue) { error in
            //TODO: Error handling.
            if let error = error {
                print (error);
            }
            
            NSFileCoordinator.addFilePresenter(page);
            
            //We have to kick off the load ourselves, so let's just
            //pretend to be a file coordinator and notify ourselves.
            page.presentedItemDidChange();
        };
        
        return page;
    }
    
    func presentedItemDidChange() {
        if let url = self.presentedItemURL {
            if self.ownership == .SecurityScoped && !CFURLStartAccessingSecurityScopedResource(self.accessURL! as CFURL) {
                //panic! at the disco
                print("Cannot access URL")
            }
            
            do {
                let new_html = try String(contentsOf: url);
                
                // We only update HTML if the file contents have actually
                // changed. Otherwise, we can wind up in a loop of constantly
                // updating SwiftUI and pinging ourselves about the file change
                if new_html != html {
                    htmlOnDisk = new_html;
                    html = new_html;
                }
            } catch {
                //panic?!
                print("Error reading URL")
            }
            
            if self.ownership == .SecurityScoped {
                CFURLStopAccessingSecurityScopedResource(self.accessURL! as CFURL);
            }
        } else {
            print("No URL")
        }
    }
    
    private func doActualSave(url: URL, html: String) {
        if self.ownership == .SecurityScoped && !CFURLStartAccessingSecurityScopedResource(self.accessURL! as CFURL) {
            //panic! at the disco
            print("Cannot access URL")
        }
        
        do {
            print("About to save");
            try html.write(to: url, atomically: true, encoding: .utf8);
            htmlOnDisk = html;
            print("Saved");
        } catch {
            //panic?!
            print("Error writing URL")
        }
        
        if self.ownership == .SecurityScoped {
            CFURLStopAccessingSecurityScopedResource(self.accessURL! as CFURL);
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
        self.accessURL = urls[0];
        self.presentedItemURL = urls[0];
        self.ownership = .SecurityScoped;
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
    }
}
