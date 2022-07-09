import SwiftUI
import Foundation
import Combine

/**
 * Who owns a given file.
 */
enum FileOwnership: Codable {
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
class Page : NSObject, ObservableObject, Identifiable, NSFilePresenter {
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
    
    var path: String? {
        if let self_components = presentedItemURL?.pathComponents {
            if let access_components = accessURL?.pathComponents {
                var lastCommonComponent = 0;
                
                for (self_i, self_component) in self_components.enumerated() {
                    if self_i < access_components.count {
                        if self_component == access_components[self_i] {
                            lastCommonComponent = self_i;
                        }
                    }
                }
                
                if self_components.count > lastCommonComponent + 1 {
                    var common_components = self_components.suffix(from: lastCommonComponent);
                    
                    common_components.removeFirst();
                    
                    if common_components.count > 0 {
                        return common_components.joined(separator: "/");
                    }
                }
            }
        }
        
        return nil;
    }
    
    /**
     * Get a string that uniquely identifies this file.
     */
    var linkIdentity: String {
        if ownership == .SecurityScoped {
            if let self_components = presentedItemURL?.pathComponents {
                if let access_components = accessURL?.pathComponents {
                    var lastCommonComponent = 0;
                    
                    for (self_i, self_component) in self_components.enumerated() {
                        if self_i < access_components.count {
                            if self_component == access_components[self_i] {
                                lastCommonComponent = self_i;
                            }
                        }
                    }
                    
                    if self_components.count > lastCommonComponent + 1 {
                        let common_components = self_components.suffix(from: lastCommonComponent);
                        
                        if common_components.count > 0 {
                            return common_components.joined(separator: "/");
                        }
                    }
                }
            }
        }
        
        return self.id.uuidString;
    }
    
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
    
    weak var shoebox: Shoebox?;
    
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
        
        $ownership.throttle(for: 0.5, scheduler: OperationQueue.main, latest: true).sink(receiveValue: { [weak self] _ in
            self?.shoebox?.nestedStateDidChange()
        }).store(in: &c);
        
        $presentedItemURL.throttle(for: 0.5, scheduler: OperationQueue.main, latest: true).sink(receiveValue: { [weak self] _ in
            self?.shoebox?.nestedStateDidChange()
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
    
    func intoState() throws -> PageState {
        if self.ownership == .SecurityScoped, let accessURL = self.accessURL {
            CFURLStartAccessingSecurityScopedResource(accessURL as CFURL);
        }
        
        let state = PageState(id: self.id,
                        ownership: self.ownership,
                        accessBookmark: try self.accessURL?.bookmarkData(),
                        locationBookmark: try self.presentedItemURL!.bookmarkData())
        
        if self.ownership == .SecurityScoped, let accessURL = self.accessURL {
            CFURLStopAccessingSecurityScopedResource(accessURL as CFURL);
        }
        
        return state;
    }
    
    class func fromState(state: PageState) -> Page {
        let ownership = state.ownership;
        var accessUrl: URL? = nil;
        var fileUrl: URL? = nil;
        
        var isAccessUrlStale = false; //TODO: error handling for stale URLs
        var isFileUrlStale = false;
        
        if let accessBookmark = state.accessBookmark {
            do {
                accessUrl = try URL.init(resolvingBookmarkData: accessBookmark, options: .init(), relativeTo: nil, bookmarkDataIsStale: &isAccessUrlStale);
            } catch {
                print("Access bookmark invalid");
            }
        }
        
        do {
            fileUrl = try URL.init(resolvingBookmarkData: state.locationBookmark, bookmarkDataIsStale: &isFileUrlStale);
        } catch {
            print("Location bookmark invalid");
        }
        
        let page = Page();
        
        page.id = state.id ?? UUID();
        page.ownership = ownership;
        page.accessURL = accessUrl;
        page.presentedItemURL = fileUrl;
        page.triggerFileLoad();
        
        return page;
    }
    
    /**
     * Trigger a file load using coordinated access.
     */
    func triggerFileLoad() {
        let coordinator = NSFileCoordinator.init(filePresenter: self);
        
        if let url = self.presentedItemURL {
            coordinator.coordinate(with: [.readingIntent(with: url)], queue: self.presentedItemOperationQueue) { error in
                //TODO: Error handling.
                if let error = error {
                    print (error);
                }
                
                self.presentedItemDidChange();
            };
        }
    }
    
    /**
     * Rename the file to a new name in the same directory.
     */
    func renameFile(to: String) {
        let coordinator = NSFileCoordinator.init(filePresenter: self);
        
        if let url = self.presentedItemURL {
            coordinator.coordinate(with: [.writingIntent(with: url, options: .forMoving)], queue: self.presentedItemOperationQueue) { error in
                //TODO: Error handling.
                if let error = error {
                    print (error);
                }
                
                if self.ownership == .SecurityScoped {
                    CFURLStartAccessingSecurityScopedResource(self.accessURL as CFURL?);
                }
                
                let newItemUrl = url.deletingLastPathComponent().appendingPathComponent(to);
                
                do {
                    try FileManager.default.moveItem(at: url, to: newItemUrl);
                    self.presentedItemURL = newItemUrl;
                } catch let error as NSError {
                    print("Rename failed because \(error)")
                }
                
                if self.ownership == .SecurityScoped {
                    CFURLStopAccessingSecurityScopedResource(self.accessURL as CFURL?);
                }
            }
        }
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
                print("Error reading URL: \(error)")
            }
            
            if self.ownership == .SecurityScoped {
                CFURLStopAccessingSecurityScopedResource(self.accessURL! as CFURL);
            }
        } else {
            print("No URL")
        }
    }
    
    func presentedItemDidMove(to newURL: URL) {
        self.presentedItemURL = newURL;
    }
    
    func presentedItemDidChangeUbiquityAttributes(_ attributes: Set<URLResourceKey>) {
        print("iCloud did a thing!")
        print(attributes);
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        print("deleted");
        completionHandler(nil);
    }
    
    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
        print("begged to read");
        reader(nil)
    }
    
    func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void) {
        writer({
            print("Got back the file from a writer. Forcing a reload.")
            self.presentedItemDidChange();
        })
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
}

#if os(iOS)
extension Page: UIDocumentPickerDelegate {
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
#endif
