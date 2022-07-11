import SwiftUI

struct DirectoryItem: View {
    @ObservedObject var project: Project;
    
    @Binding var entry: Page;
    
    @Binding var openPageID: String?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    @State var isRenaming = false;
    @State var renameTo = "";
    
    var renamingLabel: some View {
        HStack {
            Image(systemName: entry.icon)
            TextField("", text: $renameTo, onEditingChanged: { (isChanged) in
                if !isChanged {
                    isRenaming = false;
                }
            }, onCommit: {
                entry.renameFile(to: renameTo);
            })
            .onChange(of: openPageID) { _ in
                isRenaming = false;
            }
        }
    }
    
    var label: some View {
        Label(entry.filename, systemImage: entry.icon)
    }
    
    var body: some View {
        if entry.presentedItemURL == nil {
            Text("ERROR")
        } else if !(entry.presentedItemURL?.hasDirectoryPath ?? true) {
            NavigationLink(tag: entry.linkIdentity, selection: $openPageID) {
                PageEditor(page: entry)
                    .navigationTitle(entry.filename)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            } label: {
                if isRenaming {
                    self.renamingLabel
                } else {
                    self.label
                }
            }
            .contextMenu{
                FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo)
            }
        } else {
            if isRenaming {
                self.renamingLabel
                    .contextMenu {
                        FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo)
                    }
            } else {
                self.label
                    .contextMenu {
                        FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo)
                    }
            }
        }
    }
}
