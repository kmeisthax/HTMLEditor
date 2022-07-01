import SwiftUI

struct PageState: Codable {
    /**
     * Whether or not a page is owned by the filesystem or by us.
     */
    var ownership: FileOwnership;
    
    /**
     * Bookmark of the URL we need to unlock the file with.
     * 
     * For AppOwned files this may be nil.
     */
    var accessBookmark: Data?;
    
    /**
     * Bookmark of the URL that we should read and write from.
     */
    var locationBookmark: Data;
}
