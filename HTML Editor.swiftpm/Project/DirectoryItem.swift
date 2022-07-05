import SwiftUI

struct DirectoryItem: View {
    @Binding var entry: ProjectFileEntry;
    
    @Binding var openPageID: UUID?;
    
    @State var isRenaming = false;
    @State var renameTo = "";
    
    @FocusState var isRenameFocused;
    
    var body: some View {
        if let contents = entry.contents {
            NavigationLink(tag: contents.id, selection: $openPageID) {
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
                                print(renameTo);
                            }
                        })
                        .focused($isRenameFocused)
                        .onChange(of: isRenameFocused) { newValue in 
                            if !newValue {
                                isRenaming = false;
                            }
                        }
                    }
                } else {
                    Label(contents.filename, systemImage: "doc.richtext")
                }
            }
            .contextMenu(ContextMenu {
                Button {
                    isRenaming = true;
                    renameTo = contents.filename;
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            })
        } else {
            Label(entry.location.lastPathComponent, systemImage: "folder")
        }
    }
}
