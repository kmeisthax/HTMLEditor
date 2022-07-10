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
    
    /**
     * Add a new page to the project.
     * 
     * If this project is not linked to a directory yet, we create a page in
     * temporary storage that is owned by the app. The inSubpath parameter is
     * ignored in this case.
     */
    func addNewPage(inSubpath: [String]) {
        if let url = projectDirectory {
            let untitledPage = Page.newFileInScopedStorage(inSubpath: inSubpath, withName: "Untitled Page", accessURL: url, project: self);
            
            if inSubpath.count == 0 {
                self.projectFiles.append(untitledPage);
            } else {
                let target = inSubpath.first!;
                
                for page in self.projectFiles {
                    if page.filename == target {
                        page.addSubitem(child: untitledPage, inSubpath: Array(inSubpath.dropFirst()));
                        
                        return;
                    }
                }
                
                print("WARNING: Could not find suitable child named \(target) to place subitem into");
            }
        } else {
            openDocuments.append(Page.fromTemporaryStorage(project: self))
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
