import SwiftUI

struct DirectoryListing: View {
    @Binding var entries: [ProjectFileEntry];
    
    var body: some View {
        OutlineGroup($entries, children: \ProjectFileEntry.children) { $entry in
            if let contents = entry.contents {
                NavigationLink(destination: PageEditor(page: contents)                   
                    .navigationTitle(contents.filename)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    ) {
                        Label(contents.filename, systemImage: "doc.richtext")
                    }
            } else {
                Label(entry.location.lastPathComponent, systemImage: "folder")
            }
        }
    }
}
