import SwiftUI

struct DirectoryListing: View {
    @ObservedObject var project: Project;
    
    @Binding var openPageID: String?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    @Binding var wysiwygState: WYSIWYGState;
    
    var body: some View {
        OutlineGroup($project.projectFiles, children: \Page.children) { $entry in
            DirectoryItem(project: project, entry: $entry, openPageID: $openPageID, showPhotoPicker: $showPhotoPicker, selectedSubpath: $selectedSubpath, wysiwygState: $wysiwygState)
        }
    }
}
