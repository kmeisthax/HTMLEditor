import SwiftUI

struct DirectoryItem: View {
    @ObservedObject var project: Project;
    
    @Binding var entry: ProjectFileEntry;
    
    @Binding var openPageID: String?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    @State var isRenaming = false;
    @State var renameTo = "";
    
    var body: some View {
        if let contents = entry.contents {
            NavigationLink(tag: contents.linkIdentity, selection: $openPageID) {
                PageEditor(page: contents)
                    .navigationTitle(contents.filename)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            } label: {
                if isRenaming {
                    HStack {
                        Image(systemName: "doc.richtext")
                        TextField("", text: $renameTo, onEditingChanged: { (isChanged) in
                            if !isChanged {
                                isRenaming = false;
                            }
                        }, onCommit: {
                            contents.renameFile(to: renameTo);
                        })
                        .onChange(of: openPageID) { _ in
                            isRenaming = false;
                        }
                    }
                } else {
                    Label(contents.filename, systemImage: contents.icon)
                }
            }
            .contextMenu{
                FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo)
            }
        } else {
            Label(entry.location.lastPathComponent, systemImage: "folder")
                .contextMenu {
                    FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath)
                }
        }
    }
}
