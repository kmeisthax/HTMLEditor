import SwiftUI
import UniformTypeIdentifiers

struct ProjectEditor: View {
    @ObservedObject var project: Project;
    
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    @State var showSettings: Bool = false;
    @State var showPhotoPicker: Bool = false;
    
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
                                Label(doc.filename, systemImage: doc.icon)
                            }
                        }
                    }
                }
                if project.projectFiles.count > 0 {
                    Section(project.projectName) {
                        DirectoryListing(entries: $project.projectFiles, openPageID: $openPageID)
                    }
                }
            }.listStyle(.sidebar).toolbar {
                #if os(iOS)
                let primaryPlacement = ToolbarItemPlacement.navigationBarTrailing;
                #elseif os(macOS)
                let primaryPlacement = ToolbarItemPlacement.primaryAction;
                #endif
                
                #if os(macOS)
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                }
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
                        Divider()
                        Button {
                            #if os(iOS)
                            project.openPage(scene: sceneDelegate.scene!);
                            #endif
                        } label: {
                            Text("Open file...")
                            Image(systemName: "doc.text")
                        }
                        #if os(iOS)
                        Divider()
                        Button {
                            showPhotoPicker = true;
                        } label: {
                            Label("Import photo...", systemImage: "photo")
                        }
                        #endif
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
            ErrorView(error: "Please select a file.")
        }
        .navigationViewStyle(.columns)
        .sheet(isPresented: $showSettings) {
            ProjectSettings(project: project, directory: project.projectLocation)
        }
        .sheet(isPresented: $showPhotoPicker) {
            SystemImagePicker { photos in
                self.showPhotoPicker = false;
                
                self.project.importItems(items: photos.map({ photo in photo.itemProvider}))
            }
        }
    }
}

