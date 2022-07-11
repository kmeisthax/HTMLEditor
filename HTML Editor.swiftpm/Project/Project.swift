import SwiftUI
import UniformTypeIdentifiers
import Combine

/**
 * An entire HTML Editor project containing multiple open editors.
 * 
 * There is a one-to-one correspondance between Projects and scenes in the app.
 */
class Project : NSObject, ObservableObject, Identifiable, NSFilePresenter {
    var presentedItemURL: URL? {
        self.projectDirectory
    }
    
    var presentedItemOperationQueue: OperationQueue = .main;
    
    var id: UUID;
    
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
    
    var projectName: String {
        var text = "Untitled Project";
        
        if self.projectDirectory != nil {
            text = self.projectLocation.displayName
        }
        
        return text;
    }
    
    @Published var projectFiles: [Page] = [];
    
    func republishDirectoryContents() {
        if let url = projectDirectory {
            projectFiles = Page.fromSecurityScopedProjectDirectory(url: url, project: self);
        } else {
            projectFiles = [];
        }
    }
    
    weak var shoebox: Shoebox?;
    
    private var c: [AnyCancellable] = [];
    
    private var isRegisteredAsFilePresenter = false;
    
    /**
     * Check if the project needs to be registered as a file presenter, and if so, do so.
     *
     * Since not all projects have an associated directory yet we only register ourselves
     * as a presenter if we need to.
     */
    func checkFilePresentationStatus() {
        if self.projectDirectory != nil && !isRegisteredAsFilePresenter {
            NSFileCoordinator.addFilePresenter(self);
            isRegisteredAsFilePresenter = true;
        } else if self.projectDirectory == nil && isRegisteredAsFilePresenter {
            NSFileCoordinator.removeFilePresenter(self);
            isRegisteredAsFilePresenter = false;
        }
    }
    
    override init() {
        id = UUID.init()
        self.openDocuments = []
        
        super.init();
        
        checkFilePresentationStatus();
        
        $openDocuments.throttle(for: 0.5, scheduler: OperationQueue.main, latest: true).sink(receiveValue: { [weak self] _ in
            if let self = self {
                for openDocument in self.openDocuments {
                    openDocument.shoebox = self.shoebox;
                    openDocument.project = self;
                }
            }
            
            self?.shoebox?.nestedStateDidChange()
        }).store(in: &c);
        
        $projectDirectory.throttle(for: 0.5, scheduler: OperationQueue.main, latest: true).sink(receiveValue: { [weak self] _ in
            self?.shoebox?.nestedStateDidChange();
            self?.checkFilePresentationStatus();
        }).store(in: &c);
        
        //NOTE: We intentionally do not hook projectDocuments as that state
        //is derived from the filesystem and not persisted in shoebox.json
    }
    
    deinit {
        if isRegisteredAsFilePresenter {
            NSFileCoordinator.removeFilePresenter(self);
        }
    }
    
    func intoState() -> ProjectState {
        var projectBookmark: Data? = nil;
        
        if let url = projectDirectory {
            do {
                CFURLStartAccessingSecurityScopedResource(url as CFURL);
                projectBookmark = try url.bookmarkData();
                CFURLStopAccessingSecurityScopedResource(url as CFURL);
            } catch {
                print("Bookmark lost due to \(error)");
            }
        }
        
        var openFiles: [PageState] = [];
        
        for page in openDocuments {
            do {
                openFiles.append(try page.intoState());
            } catch {
                print("Page could not be saved due to \(error)")
            }
        }
        
        return ProjectState(id: id, projectBookmark: projectBookmark, openFiles: openFiles);
    }
    
    class func fromState(state: ProjectState) -> Project {
        var isStale = false; //todo: error handling for stale projects
        var projectDirectory: URL? = nil;
        if let bookmark = state.projectBookmark {
            do {
                projectDirectory = try URL(resolvingBookmarkData: bookmark, options: .init(), relativeTo: nil, bookmarkDataIsStale: &isStale);
            } catch {
                print("cant hydrate bookmark into access url");
            }
        }
        
        let project = Project();
        
        var openDocuments: [Page] = [];
        for pageState in state.openFiles {
            openDocuments.append(Page.fromState(state: pageState, project: project));
        }
        
        project.id = state.id ?? UUID();
        project.projectDirectory = projectDirectory;
        project.openDocuments = openDocuments;
        
        project.republishDirectoryContents();
        
        return project;
    }
    
    func addSubItem(item: Page, inSubpath: [String]) {
        if inSubpath.count == 0 {
            self.projectFiles.append(item);
        } else {
            let target = inSubpath.first!;
            
            for page in self.projectFiles {
                if page.filename == target {
                    page.addSubItem(child: item, inSubpath: Array(inSubpath.dropFirst()));
                    
                    return;
                }
            }
            
            print("WARNING: Could not find suitable child named \(target) to place subitem into");
        }
    }
    
    func removeSubItem(item: Page, inSubpath: [String]) {
        if inSubpath.count == 0 {
            self.projectFiles.removeAll(where: { otherItem in
                item == otherItem
            });
        } else {
            let target = inSubpath.first!;
            
            for page in self.projectFiles {
                if page.filename == target {
                    page.removeSubItem(child: item, inSubpath: Array(inSubpath.dropFirst()));
                    
                    return;
                }
            }
            
            print("WARNING: Could not find suitable child named \(target) to remove subitem from");
        }
    }
    
    private func collapse(subpath: [String], intoURL: URL) -> URL {
        var suburl = intoURL;
        for component in subpath {
            suburl = suburl.appendingPathComponent(component);
        }
        
        return suburl;
    }
    
    /**
     * Add a new page to the project.
     * 
     * If this project is not linked to a directory yet, we create a page in
     * temporary storage that is owned by the app. The inSubpath parameter is
     * ignored in this case.
     */
    func addNewPage(inSubpath: [String]) {
        if let url = projectDirectory {
            let directory_url = self.collapse(subpath: inSubpath, intoURL: url);
            let file_url = directory_url.appendingPathComponent("Untitled Page", conformingTo: .html);
            
            let coordinator = NSFileCoordinator.init(filePresenter: nil);
            
            coordinator.coordinate(with: [.writingIntent(with: directory_url)], queue: OperationQueue.main) { error in
                //TODO: Error handling.
                if let error = error {
                    print (error);
                }
                
                if !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
                    //panic! at the disco
                    print("Cannot access URL: \(String(describing: error))")
                }
                
                print("Creating new file")
                //Pre-create a file before creating the Page around it.
                FileManager.default.createFile(atPath: file_url.path, contents: Page.DEFAULT_FILE.data(using: .utf8)!);
                
                let untitledPage = Page.fromSecurityScopedUrl(url: file_url, accessURL: url, pathFragment: inSubpath + ["Untitled Page.html"], project: self, htmlOnDisk: Page.DEFAULT_FILE);
                
                self.addSubItem(item: untitledPage, inSubpath: inSubpath);
                
                CFURLStopAccessingSecurityScopedResource(url as CFURL);
            };
        } else {
            openDocuments.append(Page.fromTemporaryStorage(project: self))
        }
    }
    
    /**
     * Add a new directory to the project.
     *
     * No attempt is made to create a directory without a project directory to store files in.
     */
    func addNewDirectory(inSubpath: [String]) {
        if let url = projectDirectory {
            let directory_url = self.collapse(subpath: inSubpath, intoURL: url);
            let untitledName = directory_url.appendingPathComponent("Untitled", conformingTo: .folder);
            
            let coordinator = NSFileCoordinator.init(filePresenter: nil);
            
            // This is slightly backwards from how new page creation works.
            // Usually we create the Page first and rely on its constructor
            // to do a coordinated write to disk. However, if SwiftUI EVER
            // sees a folder that hasn't been saved yet it starts tripping
            // bounds checks and the whole process dies. So instead we
            // create the directory first and then create a Page for it,
            // as if someone else had made it for us.
            coordinator.coordinate(with: [.writingIntent(with: directory_url)], queue: OperationQueue.main) { error in
                //TODO: Error handling.
                if let error = error {
                    print (error);
                }
                
                if !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
                    //panic! at the disco
                    print("Cannot access URL: \(String(describing: error))")
                }
                
                do {
                    print("Creating new directory")
                    //Create a new directory corresponding to this new Page.
                    try FileManager.default.createDirectory(at: untitledName, withIntermediateDirectories: false);
                    
                    let untitledDirectory = Page.fromSecurityScopedUrl(url: untitledName, accessURL: url, pathFragment: inSubpath + ["Untitled"], project: self);
                    
                    self.addSubItem(item: untitledDirectory, inSubpath: inSubpath);
                } catch {
                    //panic?!
                    print("Error creating new directory: \(error)")
                }
                
                CFURLStopAccessingSecurityScopedResource(url as CFURL);
            }
        }
    }
    
    /**
     * Delete a file from the project.
     *
     * The given item's path fragment, minus it's own file name (for files),
     * must be provided so that the project can find and remove the item
     * from the correct spot in the page tree.
     */
    func deleteItemFromProject(item: Page, inSubpath: [String]) {
        if let url = projectDirectory, let itemUrl = item.presentedItemURL {
            let coordinator = NSFileCoordinator.init(filePresenter: nil);
            
            let parentUrl = itemUrl.deletingLastPathComponent();
            
            coordinator.coordinate(with: [.writingIntent(with: parentUrl)], queue: OperationQueue.main) { error in
                //TODO: Error handling.
                if let error = error {
                    print (error);
                }
                
                if !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
                    //panic! at the disco
                    print("Cannot access URL: \(String(describing: error))")
                }
                
                do {
                    print("Deleting item")
                    try FileManager.default.removeItem(at: itemUrl);
                    self.removeSubItem(item: item, inSubpath: inSubpath);
                } catch {
                    //panic?!
                    print("Error deleting item: \(error)")
                }
                
                CFURLStopAccessingSecurityScopedResource(url as CFURL);
            }
        }
    }
    
    /**
     * Import picked or dragged items into the project root.
     */
    func importItems(items: [NSItemProvider], allowedTypes: Set<IdentifiableType>, toSubpath: [String]) {
        for (i, item) in items.enumerated() {
            for type in item.registeredTypeIdentifiers {
                let uttype = UTType(type);
                if uttype == nil {
                    continue;
                }
                
                if !allowedTypes.contains(IdentifiableType(type: uttype!)) {
                    continue;
                }
                
                let suggestedName = item.suggestedName ?? "item_\(i)";
                
                if let url = projectDirectory {
                    var subpathUrl = url;
                    for component in toSubpath {
                        subpathUrl = subpathUrl.appendingPathComponent(component);
                    }
                    
                    let suggestedUrl = subpathUrl.appendingPathComponent(suggestedName).appendingPathExtension(for: uttype!);
                    
                    item.loadFileRepresentation(forTypeIdentifier: type, completionHandler: { fileUrl, error in
                        print ("importing format \(type)");
                        if let fileUrl = fileUrl {
                            do {
                                CFURLStartAccessingSecurityScopedResource(url as CFURL);
                                
                                try FileManager.default.copyItem(at: fileUrl, to: suggestedUrl);
                                
                                CFURLStopAccessingSecurityScopedResource(url as CFURL);
                            } catch {
                                print("Could not import \(suggestedUrl): \(error)");
                            }
                        }
                        
                        if let error = error {
                            print("Could not import \(suggestedUrl): \(error)");
                        }
                    });
                }
            }
        }
    }
    
    private var picker_c: [AnyCancellable] = [];
    private var pagePickerLocation: FileLocation?;
    
    // ==NSFilePresenter impl
    
    func presentedItemDidMove(to: URL) {
        self.projectDirectory = to;
        
        for child in self.projectFiles {
            child.projectDidMove(toDirectory: to)
        }
    }
}

#if os(iOS)
extension Project {
    /**
     * Open an individual page separate from any project ownership.
     */
    func openPage(scene: UIWindowScene) {
        let location = FileLocation(contentTypes: [.html]);
        
        location.$pickedUrls.sink(receiveValue: { [weak self] urls in
            if let self = self {
                for url in urls {
                    self.openDocuments.append(Page.fromSecurityScopedUrl(url: url, accessURL: url, pathFragment: nil, project: self))
                }
                
                // Cancel ourselves now that location picking is done
                self.picker_c = [];
                self.pagePickerLocation = nil;
            }
        }).store(in: &picker_c);
        
        pagePickerLocation = location;
        location.pick(scene: scene);
    }
}
#elseif os(macOS)
extension Project {
    /**
     * Open an individual page separate from any project ownership.
     */
    func openPage() {
        let location = FileLocation(contentTypes: [.html]);
        
        location.$pickedUrls.sink(receiveValue: { [weak self] urls in
            if let self = self {
                for url in urls {
                    self.openDocuments.append(Page.fromSecurityScopedUrl(url: url, accessURL: url, pathFragment: nil, project: self))
                }
                
                // Cancel ourselves now that location picking is done
                self.picker_c = [];
                self.pagePickerLocation = nil;
            }
        }).store(in: &picker_c);
        
        pagePickerLocation = location;
        location.pick();
    }
}
#endif
