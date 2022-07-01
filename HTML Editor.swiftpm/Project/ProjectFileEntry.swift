import SwiftUI

/**
 * Hierarchial data type for project files and directories.
 */
struct ProjectFileEntry: Hashable, Identifiable {
    var id: Self { self };
    var location: URL;
    
    /**
     * List of all child project files.
     */
    var children: [ProjectFileEntry]? = nil;
    
    /**
     * The object that represents the contents of the file.
     */
    var contents: Page? = nil;
    
    private static func fromDirectoryContentsInternal(at: URL, accessURL: URL) -> [Self] {
        var files: [ProjectFileEntry] = [];
        
        do {
            for child in try FileManager.default.contentsOfDirectory(at: at, includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey]) {
                let vals = try child.resourceValues(forKeys: [.nameKey, .isDirectoryKey, .isRegularFileKey]);
                
                if vals.isDirectory! {
                    let grandchildren = ProjectFileEntry.fromDirectoryContentsInternal(at: child, accessURL: accessURL);
                    let elem = ProjectFileEntry(location: child, children: grandchildren);
                    files.append(elem);
                } else if vals.isRegularFile! {
                    files.append(ProjectFileEntry(location: child, contents: Page.fromSecurityScopedUrl(url: child, accessURL: accessURL)));
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
        
        let files = Self.fromDirectoryContentsInternal(at: at, accessURL: at);
        
        CFURLStopAccessingSecurityScopedResource(at as CFURL);
        
        return files;
    }
}