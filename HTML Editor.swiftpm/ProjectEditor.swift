import SwiftUI

struct ProjectEditor: View {
    @ObservedObject var project: Project;
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    
    @State var viewOpenFiles: Bool = true;
    
    var body: some View {
        NavigationView {
            List {
                DisclosureGroup("Open Files", isExpanded: $viewOpenFiles) {
                    ForEach($project.openDocuments) { $doc in
                        NavigationLink(destination: PageEditor(html: $doc.html)
                            .navigationTitle(doc.filename)
                            .navigationBarTitleDisplayMode(.inline)) {
                            Text(doc.filename)
                        }
                    }
                }
            }.listStyle(SidebarListStyle()).toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            project.addNewPage()
                        } label: {
                            Text("New page")
                            Image(systemName: "doc.badge.plus")
                        }
                        Button {
                            project.openPage(scene: sceneDelegate.scene!);
                        } label: {
                            Text("Open file...")
                            Image(systemName: "doc.text")
                        }
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }.navigationBarTitleDisplayMode(.inline)
            ZStack {
                Color(UIColor.secondarySystemBackground)
                VStack {
                    Image(systemName: "questionmark.folder").font(.system(size: 180, weight: .medium))
                    Text("Please select a file.")
                }
            }.navigationBarTitleDisplayMode(.inline)
        }
    }
}
