import SwiftUI

struct FileManagementMenuItems: View {
    @ObservedObject var project: Project;
    
    /**
     * The entry that this menu performs operations relative to.
     * 
     * If nil, then this menu performs operations in the root of the project.
     */
    var forProjectItem: Page?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    var isRenaming: Binding<Bool>?;
    var renameTo: Binding<String>?;
    
    var directoryPath: [String] {
        if let page = forProjectItem, let url = page.presentedItemURL, let pathFragment = page.pathFragment {
            if url.hasDirectoryPath {
                return pathFragment;
            } else {
                return pathFragment.dropLast();
            }
        } else {
            return [];
        }
    }
    
    var body: some View {
        if let isRenaming = isRenaming, let contents = forProjectItem, let renameTo = renameTo {
            Button {
                isRenaming.wrappedValue = true;
                renameTo.wrappedValue = contents.filename;
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                project.deleteItemFromProject(item: contents, inSubpath: directoryPath);
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Divider()
        }
        Button {
            project.addNewPage(inSubpath: directoryPath)
        } label: {
            Label("New page", systemImage: "doc.badge.plus")
        }
        Button {
            project.addNewDirectory(inSubpath: directoryPath)
        } label: {
            Label("New folder", systemImage: "folder.badge.plus")
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
