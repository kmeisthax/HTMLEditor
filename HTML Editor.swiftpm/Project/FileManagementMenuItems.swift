import SwiftUI

struct FileManagementMenuItems: View {
    @ObservedObject var project: Project;
    
    /**
     * The entry that this menu performs operations relative to.
     * 
     * If nil, then this menu performs operations in the root of the project.
     */
    var forProjectItem: ProjectFileEntry?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    var isRenaming: Binding<Bool>?;
    var renameTo: Binding<String>?;
    
    var directoryPath: [String] {
        if forProjectItem?.location.hasDirectoryPath ?? false {
            return forProjectItem!.pathFragment;
        } else {
            return forProjectItem?.pathFragment.dropLast() ?? [];
        }
    }
    
    var body: some View {
        Button {
            project.addNewPage(inSubpath: directoryPath)
        } label: {
            Text("New page")
            Image(systemName: "doc.badge.plus")
        }
        if let isRenaming = isRenaming, let contents = forProjectItem?.contents, let renameTo = renameTo {
            Button {
                isRenaming.wrappedValue = true;
                renameTo.wrappedValue = contents.filename;
            } label: {
                Label("Rename", systemImage: "pencil")
            }
        }
        #if os(iOS)
        Divider()
        Button {
            showPhotoPicker = true;
            selectedSubpath = directoryPath;
        } label: {
            Label("Import photo...", systemImage: "photo")
        }
        #endif
    }
}
