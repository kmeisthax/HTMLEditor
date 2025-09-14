import SwiftUI
import Introspect

struct DirectoryItem: View {
    @ObservedObject var project: Project;
    
    @Binding var entry: Page;
    
    @Binding var openPageID: String?;
    
    @Binding var showPhotoPicker: Bool;
    @Binding var selectedSubpath: [String];
    
    @Binding var wysiwygState: WYSIWYGState;
    
    @State var isRenaming = false;
    @State var renameTo = "";
    
    //Hack to try and force the text field to get re-introspected
    //every time we rename.
    @State var numberOfRenames = 0;
    
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
            .introspectTextField(customize: { field in
                //NOTE: This is a platform-specific type even though both types
                //have the same method.
                field.becomeFirstResponder()
            })
            .onChange(of: openPageID) { _ in
                isRenaming = false;
            }
        }
        .id(numberOfRenames)
    }
    
    var label: some View {
        Label(entry.filename, systemImage: entry.icon)
    }
    
    var body: some View {
        if entry.presentedItemURL == nil {
            Text("ERROR")
        } else if !(entry.presentedItemURL?.hasDirectoryPath ?? true) {
            NavigationLink(destination: {
                PageEditor(page: entry, wysiwygState: $wysiwygState)
                    .navigationTitle(entry.filename)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }, label: {
                if isRenaming {
                    self.renamingLabel
                } else {
                    self.label
                }
            })
            .contextMenu{
                FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo, numberOfRenames: $numberOfRenames)
            }
        } else {
            if isRenaming {
                self.renamingLabel
                    .contextMenu {
                        FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo, numberOfRenames: $numberOfRenames)
                    }
            } else {
                self.label
                    .contextMenu {
                        FileManagementMenuItems(project: self.project, forProjectItem: entry, showPhotoPicker: self.$showPhotoPicker, selectedSubpath: self.$selectedSubpath, isRenaming: $isRenaming, renameTo: $renameTo, numberOfRenames: $numberOfRenames)
                    }
            }
        }
    }
}
