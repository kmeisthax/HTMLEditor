import SwiftUI

struct ProjectEditor: View {
    @ObservedObject var project: Project;
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    
    @State var showSettings: Bool = false;
    
    var body: some View {
        NavigationView {
            List {
                if project.openDocuments.count > 0 {
                    Section("Open Files") {
                        ForEach($project.openDocuments) { $doc in
                            NavigationLink(destination: PageEditor(page: doc)
                                .navigationTitle(doc.filename)
                                .navigationBarTitleDisplayMode(.inline)) {
                                Label(doc.filename, systemImage: "doc.richtext")
                            }
                        }
                    }
                }
                if project.projectFiles.count > 0 {
                    Section("Project Files") {
                        DirectoryListing(entries: $project.projectFiles)
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
                    Button {
                        self.showSettings = true;
                    } label: {
                        Image(systemName: "gearshape")
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
        }.sheet(isPresented: $showSettings) {
            ProjectSettings(project: project, directory: project.projectLocation)
        }
    }
}

