import SwiftUI
import UniformTypeIdentifiers
import Combine

/**
 * An entire HTML Editor project containing multiple open editors.
 * 
 * There is a one-to-one correspondance between Projects and scenes in the app.
 */
class Project : NSObject, UIDocumentPickerDelegate, ObservableObject, Identifiable {
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
    
    weak var shoebox: Shoebox?;
    
    private var c: [AnyCancellable] = [];
    
    override init() {
        id = UUID.init()
        self.openDocuments = []
        
        super.init();
        
        $openDocuments.sink(receiveValue: { [weak self] _ in
            if let self = self {
                for openDocument in self.openDocuments {
                    openDocument.shoebox = self.shoebox;
                }
            }
            
            self?.shoebox?.nestedStateDidChange()
        }).store(in: &c);
        
        $projectDirectory.sink(receiveValue: { [weak self] _ in
            self?.shoebox?.nestedStateDidChange()
        }).store(in: &c);
        
        //NOTE: We intentionally do not hook projectDocuments as that state
        //is derived from the filesystem and not persisted in shoebox.json
    }
    
    func intoState() -> ProjectState {
        var projectBookmark: Data? = nil;
        
        if let url = projectDirectory {
            do {
                projectBookmark = try url.bookmarkData();
            } catch {
                print("Bookmark lost!");
            }
        }
        
        var openFiles: [PageState] = [];
        
        for page in openDocuments {
            do {
                openFiles.append(try page.intoState());
            } catch {
                print("Page could not be saved")
            }
        }
        
        return ProjectState(projectBookmark: projectBookmark, openFiles: openFiles);
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
        
        var openDocuments: [Page] = [];
        for pageState in state.openFiles {
            openDocuments.append(Page.fromState(state: pageState));
        }
        
        let project = Project();
        
        project.projectDirectory = projectDirectory;
        project.openDocuments = openDocuments;
        
        return project;
    }
    
    func addNewPage() {
        if let url = projectDirectory {
            let untitledPage = Page.newFileInScopedStorage(withName: "Untitled Page", accessURL: url);
            projectFiles.append(ProjectFileEntry(location: untitledPage.presentedItemURL!, contents: untitledPage));
        } else {
            openDocuments.append(Page.fromTemporaryStorage())
        }
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
