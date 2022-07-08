import SwiftUI

/**
 * Hierarchial data type for project files and directories.
 */
struct ProjectFileEntry: Hashable, Identifiable {
    var id: Self { self };
    var location: URL;
    
    /**
     * The relative path fragment from the base URL of the project,
     * if this is a project file.
     */
    var pathFragment: [String];
    
    /**
     * List of all child project files.
     */
    var children: [ProjectFileEntry]? = nil;
    
    /**
     * The object that represents the contents of the file.
     */
    var contents: Page? = nil;
    
    private static func fromDirectoryContentsInternal(at: URL, accessURL: URL, pathFragment: [String]) -> [Self] {
        var files: [ProjectFileEntry] = [];
        
        do {
            for child in try FileManager.default.contentsOfDirectory(at: at, includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey]) {
                let vals = try child.resourceValues(forKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey]);
                let childPathFragment = pathFragment + [child.lastPathComponent];
                
                if vals.isDirectory! {
                    let grandchildren = ProjectFileEntry.fromDirectoryContentsInternal(at: child, accessURL: accessURL, pathFragment: childPathFragment);
                    let elem = ProjectFileEntry(location: child, pathFragment: childPathFragment, children: grandchildren);
                    files.append(elem);
                } else if vals.isRegularFile! {
                    files.append(ProjectFileEntry(location: child, pathFragment: childPathFragment, contents: Page.fromSecurityScopedUrl(url: child, accessURL: accessURL)));
                }
                
                //TODO: Do we even care about symlinks?
                //Can you even HAVE symlinks on iPadOS?
            }
        } catch {
            //TODO: something
            print("Error")
        }
        
        return files;
    }
    
    /**
     * Read the contents of a directory into a files tree.
     * 
     * This should be called inside of a coordinated read.
     * 
     * This function assumes the URL can be used to unlock a security-scoped
     * resource.
     */
    static func fromDirectoryContents(at: URL) -> [Self] {
        CFURLStartAccessingSecurityScopedResource(at as CFURL);
        
        let files = Self.fromDirectoryContentsInternal(at: at, accessURL: at, pathFragment: []);
        
        CFURLStopAccessingSecurityScopedResource(at as CFURL);
        
        return files;
    }
    
    /**
     * Update the URLs in the project and its pages to be relative to a new project directory.
     *
     * The URL is assumed to be an access URL to the whole project. Path fragments will be
     * calculated relative to the original a
     */
    mutating func projectMovedToDirectory(to: URL) {
        var newUrl = to;
        
        for component in self.pathFragment {
            newUrl = newUrl.appendingPathComponent(component);
        }
        
        self.location = newUrl;
        
        if let contents = self.contents {
            contents.presentedItemURL = newUrl;
            contents.accessURL = to;
        }
        
        if let children = self.children {
            for var child in children {
                child.projectMovedToDirectory(to: to);
            }
        }
    }
}
