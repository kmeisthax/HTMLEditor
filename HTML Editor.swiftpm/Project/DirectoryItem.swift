import SwiftUI

struct DirectoryItem: View {
    @Binding var entry: ProjectFileEntry;
    
    @Binding var openPageID: String?;
    
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
                    Label(contents.filename, systemImage: "doc.richtext")
                }
            }
            .contextMenu{
                Button {
                    isRenaming = true;
                    renameTo = contents.filename;
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
        } else {
            Label(entry.location.lastPathComponent, systemImage: "folder")
        }
    }
}
