import SwiftUI

struct DirectoryListing: View {
    @Binding var entries: [ProjectFileEntry];
    
    @Binding var openPageID: UUID?;
    
    var body: some View {
        OutlineGroup($entries, children: \ProjectFileEntry.children) { $entry in
            DirectoryItem(entry: $entry, openPageID: $openPageID)
        }
    }
}
