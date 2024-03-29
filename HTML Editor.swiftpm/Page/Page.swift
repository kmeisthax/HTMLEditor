import SwiftUI
import Foundation
import Combine
import UniformTypeIdentifiers

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
    
    /**
     * The relative path fragment from the base URL of the project to this item.
     *
     * This is inclusive of the file or directory itself. If you want just the directory,
     * check if the presented item is a file; if so strip off the last path component.
     */
    @Published var pathFragment: [String]?;
    
    /**
     * List of all children of this object (if it is a directory).
     */
    @Published var children: [Page]? = nil;
    
    /**
     * Calculate the project-relative subpath for this page.
     */
    var path: String? {
        pathFragment?.joined(separator: "/")
    }
    
    var type: UTType? {
        do {
            if self.ownership == .SecurityScoped, let accessURL = self.accessURL {
                CFURLStartAccessingSecurityScopedResource(accessURL as CFURL);
            }
            
            defer {
                if self.ownership == .SecurityScoped, let accessURL = self.accessURL {
                    CFURLStopAccessingSecurityScopedResource(accessURL as CFURL);
                }
            }
            
            return try self.presentedItemURL?.resourceValues(forKeys: [.contentTypeKey]).contentType
        } catch {
            print("Cannot read type of \(String(describing: self.presentedItemURL)), got error \(error)");
            
            return nil;
        }
    }
    
    var icon: String {
        if self.type == .html || self.type?.identifier == "public.xhtml" {
            return "doc.richtext"
        } else if self.type == .xml || self.type?.isSubtype(of: .xml) ?? false || self.type?.preferredFilenameExtension == "opf" {
            return "curlybraces.square"
        } else if self.type == .folder {
            return "folder"
        } else if self.type == .json || self.type?.isSubtype(of: .json) ?? false {
            return "curlybraces.square"
        } else if self.type == .text || self.type?.isSubtype(of: .text) ?? false {
            return "doc.plaintext"
        } else if self.type == .image || self.type?.isSubtype(of: .image) ?? false {
            return "photo"
        } else {
            return "questionmark.square"
        }
    }
    
    /**
     * Determine if this Page is representable as text (e.g. it's a text or HTML file).
     */
    var isTextRepresentable: Bool {
        self.type == .html || self.type == .text || self.type?.isSubtype(of: .text) ?? false || self.type?.preferredFilenameExtension == "opf"
    }
    
    /**
     * Get a string that uniquely identifies this file.
     */
    var linkIdentity: String {
        if ownership == .SecurityScoped, let pathFragment = pathFragment {
            return pathFragment.joined(separator: "/");
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
     *
     * This property is only used for HTML and text and should not be used
     * for non-text file types or directories.
     */
    @Published var html: String = "";
    
    /**
     * The contents of the file on disk.
     * 
     * Updates to HTML should only trip autosave iff they do not match what is
     * already on disk in this parameter.
     * 
     * The default value of this parameter must match html; otherwise the
     * default value of that parameter will overwrite every file we open and
     * lose user data.
     *
     * This property is only used for HTML and text and should not be used
     * for non-text file types or directories.
     */
    var htmlOnDisk: String? = nil;
    
    /**
     * Autosave event storage
     */
    var c: [AnyCancellable] = [];
    
    weak var shoebox: Shoebox?;
    
    weak var project: Project?;
    
    override init() {
        id = UUID.init()
        
        super.init()
        
        $html.throttle(for: 1.0, scheduler: presentedItemOperationQueue, latest: true).sink(receiveValue: { [weak self] _ in
            if self?.isTextRepresentable ?? false {
                if let url = self?.presentedItemURL, let scheduled_html = self?.html, let htmlOnDisk = self!.htmlOnDisk {
                    let coordinator = NSFileCoordinator.init(filePresenter: self);
                    
                    if scheduled_html != htmlOnDisk {
                        coordinator.coordinate(with: [.writingIntent(with: url)], queue: self!.presentedItemOperationQueue) { [self] error in
                            if let error = error {
                                print (error);
                            }
                            
                            self!.doActualSave(url: url, html: scheduled_html);
                        }
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
        
        $children.throttle(for: 0.5, scheduler: OperationQueue.main, latest: true).sink(receiveValue: { [weak self] _ in
            // Force a project UI update any time any page in the project sees children change
            if let self = self, let project = self.project {
                let realFiles = project.projectFiles;
                
                project.projectFiles = realFiles;
            }
        }).store(in: &c);
    }
    
    deinit {
        NSFileCoordinator.removeFilePresenter(self);
    }
    
    static func readChildrenAtDirectory(itemURL: URL, accessURL: URL, pathFragment: [String], project: Project) -> [Page] {
        var children: [Page] = [];
        
        do {
            for child in try FileManager.default.contentsOfDirectory(at: itemURL, includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey]) {
                let childPathFragment = pathFragment + [child.lastPathComponent];
                
                children.append(Page.fromSecurityScopedUrl(url: child, accessURL: accessURL, pathFragment: childPathFragment, project: project));
            }
        } catch {
            print("Error attempting to enumerate contents of \(itemURL): \(error)");
        }
        
        return children;
    }
    
    /**
     * Populate the initial contents of an open directory.
     *
     * This should only be called once to populate contents; it will refuse to
     * overwrite existing pages. Instead, you should update the children list
     * using file presenter methods.
     *
     * Caller must have ensured the parent's access URL was unlocked and
     * reads coordinated before calling this function.
     */
    private func populateChildren() {
        if let itemURL = self.presentedItemURL, let accessURL = self.accessURL, let pathFragment = self.pathFragment, let project = self.project {
            if self.children == nil {
                self.children = Page.readChildrenAtDirectory(itemURL: itemURL, accessURL: accessURL, pathFragment: pathFragment, project: project);
            } else {
                print("WARNING: Attempt to overwrite existing Page objects blocked");
            }
        } else {
            print("WARNING: Premature attempt to read directory contents of nil path blocked");
        }
    }
    
    /**
     * List out all files within a project directory and create pages for them.
     *
     * No page entry is created for the project itself. You must instead provide the project
     * so that child pages may access it.
     */
    class func fromSecurityScopedProjectDirectory(url: URL, project: Project) -> [Page] {
        CFURLStartAccessingSecurityScopedResource(url as CFURL);
        
        let children = Self.readChildrenAtDirectory(itemURL: url, accessURL: url, pathFragment: [], project: project);
        
        CFURLStopAccessingSecurityScopedResource(url as CFURL);
        
        return children;
    }
    
    /**
     * Create a new Page from an already-existing file or folder on disk.
     *
     * The file pointed to by url *must exist* on disk, otherwise SwiftUI will break
     * immediately after this Page hits the Project.
     *
     * You may provide the HTML from the file in this function (say, if you just
     * created the file and want to skip the load). Otherwise we will read the file
     * or directory contents ourselves and populate everything normally.
     */
    class func fromSecurityScopedUrl(url: URL, accessURL: URL, pathFragment: [String]?, project: Project, htmlOnDisk: String? = nil) -> Page {
        let page = Page();
        page.accessURL = accessURL;
        page.presentedItemURL = url;
        page.ownership = .SecurityScoped;
        page.pathFragment = pathFragment;
        page.project = project;
        
        if let htmlOnDisk = htmlOnDisk {
            page.html = htmlOnDisk;
            page.htmlOnDisk = htmlOnDisk;
        }
        
        let coordinator = NSFileCoordinator.init(filePresenter: page);
        
        coordinator.coordinate(with: [.readingIntent(with: url)], queue: page.presentedItemOperationQueue) { error in
            //TODO: Error handling.
            if let error = error {
                print (error);
            }
            
            CFURLStartAccessingSecurityScopedResource(accessURL as CFURL);
            
            NSFileCoordinator.addFilePresenter(page);
            
            if htmlOnDisk == nil {
                if !url.hasDirectoryPath {
                    //We have to kick off the load ourselves, so let's just
                    //pretend to be a file coordinator and notify ourselves.
                    page.presentedItemDidChange();
                } else {
                    page.populateChildren();
                }
            }
            
            CFURLStopAccessingSecurityScopedResource(accessURL as CFURL);
            
            //TODO: Do we even care about symlinks?
            //Can you even HAVE symlinks on iPadOS?
        };
        
        return page;
    }
    
    static let DEFAULT_FILE = "<!DOCTYPE html>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"><meta charset=\"utf8\">";
    
    class func fromTemporaryStorage(project: Project) -> Page {
        let name = UUID().uuidString + ".html";
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0];
        
        let page = Page();
        page.presentedItemURL = url.appendingPathComponent(name);
        page.ownership = .AppOwned;
        page.html = Self.DEFAULT_FILE;
        page.htmlOnDisk = "";
        page.project = project;
        
        //This is an app-owned file, so we don't need to coordinate
        //as we created the file and it can't exist elsewhere
        NSFileCoordinator.addFilePresenter(page);
        
        return page;
    }
    
    func intoState() throws -> PageState {
        if self.presentedItemURL == nil {
            throw NSError.init(domain: "NoURLError", code: 0);
        }
        
        if self.ownership == .SecurityScoped, let accessURL = self.accessURL {
            CFURLStartAccessingSecurityScopedResource(accessURL as CFURL);
        }
        
        let state = PageState(id: self.id,
                        ownership: self.ownership,
                        accessBookmark: try self.accessURL?.bookmarkData(),
                        locationBookmark: try self.presentedItemURL!.bookmarkData());
        
        if self.ownership == .SecurityScoped, let accessURL = self.accessURL {
            CFURLStopAccessingSecurityScopedResource(accessURL as CFURL);
        }
        
        return state;
    }
    
    class func fromState(state: PageState, project: Project) -> Page {
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
        page.project = project;
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
                    self.presentedItemDidMove(to: newItemUrl);
                } catch let error as NSError {
                    print("Rename failed because \(error)")
                }
                
                if self.ownership == .SecurityScoped {
                    CFURLStopAccessingSecurityScopedResource(self.accessURL as CFURL?);
                }
            }
        }
    }
    
    private func regeneratePathFragment() {
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
                    
                    print(common_components);
                    
                    self.pathFragment = Array(common_components);
                }
            }
        }
    }
    
    func presentedItemDidChange() {
        if self.isTextRepresentable {
            if let url = self.presentedItemURL {
                if self.ownership == .SecurityScoped && !CFURLStartAccessingSecurityScopedResource(self.accessURL! as CFURL) {
                    //panic! at the disco
                    print("Cannot access URL")
                }
                
                do {
                    let new_html = try String(contentsOf: url);
                    
                    // The update rules are complicated because we're trying to avoid
                    // two different problems at the same time:
                    //
                    // 1. We don't want to trigger an update loop between two SwiftUI
                    // views bound to the same page.
                    //
                    // 2. We didn't implement conflict resolution yet. If someone grabs
                    // a write lock (say, ubiquityd/iCloud) we want the user to be able
                    // to keep typing, but once the lock clears we still need to update
                    // ourselves. We thus only update anything if the file on disk
                    // ACTUALLY CHANGED from our last write.
                    //
                    // Hence we not only double-check for changes, but we do so in a
                    // specific order.
                    if new_html != htmlOnDisk {
                        htmlOnDisk = new_html;
                        
                        if new_html != html {
                            html = new_html;
                        } else {
                            print("Refused update because it matches what is in memory");
                        }
                    } else {
                        print("Refused update because HTML on disk did not change");
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
    }
    
    func presentedItemDidMove(to newURL: URL) {
        self.presentedItemURL = newURL;
        self.regeneratePathFragment();
        
        if let children = self.children {
            for child in children {
                let newChildURL = newURL.appendingPathComponent(child.filename);
                child.presentedItemDidMove(to: newChildURL);
            }
        }
    }
    
    func projectDidMove(toDirectory accessURL: URL) {
        self.accessURL = accessURL;
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
        print("Write lock claimed");
        writer({
            print("Write lock released, forcing a reload.");
            self.presentedItemDidChange();
        })
    }
    
    /**
     * Save the file back to disk.
     *
     * The URL parameter allows saving the file to an alternate location. The
     * given URL must be accessible within the sandbox provided by the
     * access URL on this page.
     *
     * If this page is not text-representable this does nothing. This causes
     * problems for files that we are trying to *create*, as we can't get the type
     * of a file that does not exist. Setting fileExistsOnDisk to false skips the
     * check.
     */
    private func doActualSave(url: URL, html: String, fileExistsOnDisk: Bool = true) {
        if self.isTextRepresentable || !fileExistsOnDisk { //Type checks on unsaved files don't work
            if self.ownership == .SecurityScoped && !CFURLStartAccessingSecurityScopedResource(self.accessURL! as CFURL) {
                //panic! at the disco
                print("Cannot access URL")
            }
            
            do {
                print("About to save");
                try html.write(to: url, atomically: true, encoding: .utf8);
                self.htmlOnDisk = html;
                print("Saved");
            } catch {
                //panic?!
                print("Error writing URL")
            }
            
            if self.ownership == .SecurityScoped {
                CFURLStopAccessingSecurityScopedResource(self.accessURL! as CFURL);
            }
        } else {
            print("Blocked attempt to save non-text file \(url) of type \(String(describing: self.type))");
        }
    }
    
    /**
     * Add a new page as a child of this one.
     *
     * This does nothing if the parent is not a directory.
     *
     * The subpath should be provided relative to this page.
     */
    func addSubItem(child: Page, inSubpath: [String]) {
        guard let children = self.children else {
            print("WARNING: Blocked attempt to add child item to file");
            return;
        }
        
        if inSubpath.count == 0 {
            self.children = children + [child];
        } else {
            let target = inSubpath.first!;
            
            for myChild in children {
                if myChild.filename == target {
                    myChild.addSubItem(child: child, inSubpath: Array(inSubpath.dropFirst()))
                    
                    return;
                }
            }
            
            print("WARNING: Could not find suitable child named \(target) to place subitem into");
        }
    }
    
    /**
     * Remove a page that is a child of this one.
     *
     * This does nothing if the parent is not a directory.
     *
     * The subpath should be provided relative to this page.
     */
    func removeSubItem(child: Page, inSubpath: [String]) {
        guard let children = self.children else {
            print("WARNING: Blocked attempt to remove child item from file");
            return;
        }
        
        if inSubpath.count == 0 {
            self.children!.removeAll(where: { otherItem in
                child == otherItem
            });
        } else {
            let target = inSubpath.first!;
            
            for page in children {
                if page.filename == target {
                    page.removeSubItem(child: child, inSubpath: Array(inSubpath.dropFirst()));
                    
                    return;
                }
            }
            
            print("WARNING: Could not find suitable child named \(target) to remove subitem from");
        }
    }
    
    func findSubItem(withSubpath: [Substring]) -> Page? {
        guard withSubpath.count > 0 else {
            return self;
        }
        
        guard let children = self.children else {
            return nil;
        }
        
        guard let subpage = children.first(where: { candidatePage in
            candidatePage.pathFragment?.first?[...] == withSubpath.first
        }) else {
            return nil;
        }
        
        return subpage.findSubItem(withSubpath: Array(withSubpath.dropFirst()));
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
