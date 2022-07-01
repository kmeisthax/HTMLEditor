import SwiftUI

/**
 * Snapshot of the current state of a single project.
 */
struct ProjectState : Codable {
    /**
     * The location of the project's files on disk.
     * 
     * Intended to be a security-scoped URL.
     */
    var projectBookmark: Data?;
    
    /**
     * The location of all open non-project files.
     */
    var openFiles: [PageState];
}
