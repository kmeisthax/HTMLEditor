import SwiftUI

struct DirectoryListing: View {
    @Binding var entries: [ProjectFileEntry];
    
    var body: some View {
        OutlineGroup($entries, children: \ProjectFileEntry.children) { $entry in 
            NavigationLink(destination: Text("TBI")) {
                Text(entry.location.lastPathComponent)
            }
        }
    }
}
