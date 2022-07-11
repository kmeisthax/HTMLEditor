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
    
    /**
     * The path to the parent directory of this item.
     *
     * Should be used to calculate a traversable path through the Page tree to this item, for removals.
     */
    var containingPath: [String] {
        if let page = forProjectItem, let pathFragment = page.pathFragment {
            return pathFragment.dropLast();
        } else {
            return [];
        }
    }
    
    /**
     * The path to the currently selected directory.
     *
     * We treat directory items as selecting themselves, while files select their containing directory.
     */
    var selectedDirectoryPath: [String] {
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
                project.deleteItemFromProject(item: contents, inSubpath: containingPath);
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Divider()
        }
        Button {
            project.addNewPage(inSubpath: selectedDirectoryPath)
        } label: {
            Label("New page", systemImage: "doc.badge.plus")
        }
        Button {
            project.addNewDirectory(inSubpath: selectedDirectoryPath)
        } label: {
            Label("New folder", systemImage: "folder.badge.plus")
        }
        #if os(iOS)
        Divider()
        Button {
            showPhotoPicker = true;
            selectedSubpath = selectedDirectoryPath;
        } label: {
            Label("Import photo...", systemImage: "photo")
        }
        #endif
    }
}
