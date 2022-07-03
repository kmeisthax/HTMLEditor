import SwiftUI

struct ShoeboxBrowser: View {
    var items: [GridItem] = Array(repeating: .init(.adaptive(minimum: 225, maximum: 375), spacing: 20, alignment: .top), count: 1);
    
    @ObservedObject var shoebox: Shoebox;
    
    @State var newProject: Project? = nil;
    
    @State var editMode = false;
    @State var projectSelection: Set<Project> = [];
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                LazyVGrid(columns: items) {
                    ForEach($shoebox.projects) { $project in
                        ShoeboxProject(project: project, editMode: $editMode, projectSelection: $projectSelection)
                    }
                }.padding(.horizontal, 20)
            }
            .toolbar {
                #if os(iOS)
                let createPlacement = ToolbarItemPlacement.navigationBarLeading;
                #elseif os(macOS)
                let createPlacement = ToolbarItemPlacement.cancellationAction;
                #endif
                ToolbarItemGroup(placement: createPlacement) {
                    if editMode {
                        Button {
                            editMode.toggle();
                            projectSelection = [];
                        } label: {
                            Text("Cancel")
                        }
                    } else {
                        Button {
                            newProject = Project()
                        } label: {
                            Label("Create", systemImage: "square.and.pencil")
                        }
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if editMode {
                        Button {
                            for project in projectSelection {
                                shoebox.projects.removeAll(where: { other in
                                    other == project
                                })
                            }
                            
                            editMode.toggle();
                            projectSelection = [];
                        } label: {
                            Text("Close").fontWeight(.bold).foregroundColor(.red)
                        }
                    } else {
                        Button {
                            editMode.toggle();
                        } label: {
                            Text("Select")
                        }
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .sheet(item: $newProject) { project in
            ProjectSettings(project: project, directory: project.projectLocation, onSave: {
                shoebox.projects.append(newProject!);
                
                newProject = nil;
            })
        }
    }
}
