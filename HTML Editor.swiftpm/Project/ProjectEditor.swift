import SwiftUI
import UniformTypeIdentifiers

struct ProjectEditor: View {
    @StateObject var project: Project;
    
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
    
    #if os(macOS)
    @State var window: NSWindow?;
    #endif
    
    var goBack: (() -> Void)?;
    
    var body: some View {
        NavigationSplitView {
            List(selection: $openPageID) {
                if project.projectFiles.count > 0 {
                    Section(project.projectName) {
                        DirectoryListing(project: project, openPageID: $openPageID, showPhotoPicker: $showPhotoPicker, selectedSubpath: $selectedSubpath, wysiwygState: $wysiwygState)
                    }
                }
            }
            .listStyle(.sidebar)
            .toolbar {
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
        } detail: {
            ErrorView(error: "Please select a file.")
        }
        .sheet(isPresented: $showSettings) {
            ProjectSettings(project: project, directory: project.projectLocation)
        }
        #if os(iOS)
        .sheet(isPresented: $showPhotoPicker) {
            ImageImportSheet(isPresented: $showPhotoPicker, subpath: $selectedSubpath, project: project)
        }
        #endif
        
        #if os(macOS)
        WindowAccessor(window: $window, onLoad: {
            if let openPageID = self.openPageID, let page = self.project.page(withLinkIdentity: openPageID) {
                self.window?.representedURL = page.presentedItemURL;
            } else {
                self.window?.representedURL = nil;
            }
        })
            .frame(maxWidth: 0, maxHeight: 0)
            .onChange(of: openPageID) { newValue in
                if let newValue = newValue, let page = self.project.page(withLinkIdentity: newValue) {
                    self.window?.representedURL = page.presentedItemURL;
                } else {
                    self.window?.representedURL = nil;
                }
            }
        #endif
    }
}

