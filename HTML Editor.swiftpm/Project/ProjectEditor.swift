import SwiftUI

struct ProjectEditor: View {
    @ObservedObject var project: Project;
    
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    @State var showSettings: Bool = false;
    @SceneStorage("ProjectEditor.openPageID") var openPageID: String?;
    
    var goBack: (() -> Void)?;
    
    var body: some View {
        NavigationView {
            List {
                if project.openDocuments.count > 0 {
                    Section("Open Files") {
                        ForEach($project.openDocuments) { $doc in
                            NavigationLink(tag: doc.linkIdentity, selection: $openPageID) {
                                PageEditor(page: doc)
                                    .navigationTitle(doc.filename)
                                    #if os(iOS)
                                    .navigationBarTitleDisplayMode(.inline)
                                    #endif
                            } label: {
                                Label(doc.filename, systemImage: "doc.richtext")
                            }
                        }
                    }
                }
                if project.projectFiles.count > 0 {
                    Section(project.projectName) {
                        DirectoryListing(entries: $project.projectFiles, openPageID: $openPageID)
                    }
                }
            }.listStyle(SidebarListStyle()).toolbar {
                #if os(iOS)
                let primaryPlacement = ToolbarItemPlacement.navigationBarTrailing;
                #else
                let primaryPlacement = ToolbarItemPlacement.primaryAction;
                #endif
                ToolbarItemGroup(placement: .cancellationAction) {
                    if let gb = goBack {
                        Button {
                            gb()
                        } label: {
                            Label("Back", systemImage: "xmark")
                        }
                    }
                }
                ToolbarItemGroup(placement: primaryPlacement) {
                    Menu {
                        Button {
                            project.addNewPage()
                        } label: {
                            Text("New page")
                            Image(systemName: "doc.badge.plus")
                        }
                        Button {
                            #if os(iOS)
                            project.openPage(scene: sceneDelegate.scene!);
                            #endif
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
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            ZStack {
                #if os(iOS)
                Color(UIColor.secondarySystemBackground)
                #endif
                VStack {
                    Image(systemName: "questionmark.folder").font(.system(size: 180, weight: .medium))
                    Text("Please select a file.")
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }.navigationViewStyle(.columns).sheet(isPresented: $showSettings) {
            ProjectSettings(project: project, directory: project.projectLocation)
        }
    }
}

