import SwiftUI

struct DirectoryListing: View {
    @ObservedObject var project: Project;
    
    @Binding var entries: [Page];
    
    @Binding var openPageID: String?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    var body: some View {
        OutlineGroup($entries, children: \Page.children) { $entry in
            DirectoryItem(project: project, entry: $entry, openPageID: $openPageID, showPhotoPicker: $showPhotoPicker, selectedSubpath: $selectedSubpath)
        }
    }
}
