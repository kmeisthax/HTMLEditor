import SwiftUI
import UniformTypeIdentifiers

struct ProjectEditor: View {
    @ObservedObject var project: Project;
    
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    @State var wysiwygState = WYSIWYGState.Split;
    
    @State var showSettings: Bool = false;
    @State var showPhotoPicker: Bool = false;
    
    /**
     * The currently selected subpath for operation sheets (e.g. photo import) 
     */
    @State var selectedSubpath: [String] = [];
    
    @SceneStorage("ProjectEditor.openPageID") var openPageID: String?;
    
    var goBack: (() -> Void)?;
    
    var body: some View {
        NavigationView {
            List {
                if project.openDocuments.count > 0 {
                    Section("Open Files") {
                        ForEach($project.openDocuments) { $doc in
                            NavigationLink(tag: doc.linkIdentity, selection: $openPageID) {
                                PageEditor(page: doc, wysiwygState: $wysiwygState)
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
                        DirectoryListing(project: project, openPageID: $openPageID, showPhotoPicker: $showPhotoPicker, selectedSubpath: $selectedSubpath, wysiwygState: $wysiwygState)
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
                        FileManagementMenuItems(project: project, showPhotoPicker: $showPhotoPicker, selectedSubpath: $selectedSubpath)
                        Divider()
                        Button {
                            #if os(iOS)
                            project.openPage(scene: sceneDelegate.scene!);
                            #endif
                        } label: {
                            Label("Open file...", systemImage: "doc.text")
                        }
                    } label: {
                        Label("Add file...", systemImage: "doc.badge.plus")
                    }
                    Button {
                        self.showSettings = true;
                    } label: {
                        Label("Project settings...", systemImage: "gearshape")
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
        #if os(iOS)
        .sheet(isPresented: $showPhotoPicker) {
            ImageImportSheet(isPresented: $showPhotoPicker, subpath: $selectedSubpath, project: project)
        }
        #endif
    }
}

