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
                        NavigationLink(destination: PageEditor(html: $doc.html)) {
                            Text(doc.id.uuidString)
                        }
                    }
                }
            }.toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            project.addNewPage()
                        } label: {
                            Text("Add New Page")
                            Image(systemName: "doc.badge.plus")
                        }
                        Button {
                            project.openPage(scene: sceneDelegate.scene!)
                        } label: {
                            Text("Open file...")
                            Image(systemName: "doc.text")
                        }
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
            Image(systemName: "questionmark.folder")
        }
    }
}
