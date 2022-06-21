import SwiftUI

struct DirectoryListing: View {
    @Binding var entries: [ProjectFileEntry];
    
    var body: some View {
        OutlineGroup($entries, children: \ProjectFileEntry.children) { $entry in
            if let contents = entry.contents {
                NavigationLink(destination: PageEditor(page: contents)                   
                    .navigationTitle(contents.filename)
                    .navigationBarTitleDisplayMode(.inline)) {
                        Text(contents.filename)
                    }
            } else {
                Text(entry.location.lastPathComponent)
            }
        }
    }
}
