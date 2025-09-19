import SwiftUI

/**
 * Snapshot of the current state of a single project.
 */
struct ProjectState : Codable {
    /**
     * The ID of the project.
     *
     * Used by scene storage for state restoration, must not change.
     */
    var id: UUID?;
    
    /**
     * The location of the project's files on disk.
     * 
     * Intended to be a security-scoped URL.
     */
    var projectBookmark: Data?;
}
