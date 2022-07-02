import SwiftUI

struct ShoeboxSelector: View {
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
                        let isSelected = projectSelection.contains(project);
                        
                        FullscreenLink { goBack in
                            return ProjectEditor(project: project, goBack: goBack);
                        } label: {
                            return VStack {
                                    Spacer()
                                    Text(project.projectName)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(5)
                                        #if os(iOS)
                                        .background(Color(UIColor.systemBackground))
                                        .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                                        #endif
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(.tertiary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.primary, lineWidth: 1)
                                )
                                .padding(.vertical, 10);
                        } onAction: {
                            if editMode {
                                if projectSelection.contains(project) {
                                    projectSelection.remove(project)
                                } else {
                                    projectSelection.insert(project)
                                }
                            }
                            
                            return !editMode;
                        }.background(isSelected ? Color.accentColor : Color.clear)
                    }
                }.padding(.horizontal, 20)
            }
            .toolbar {
                #if os(iOS)
                var createPlacement = ToolbarItemPlacement.navigationBarLeading;
                #elseif os(macOS)
                var createPlacement = ToolbarItemPlacement.cancellationAction;
                #endif
                ToolbarItemGroup(placement: createPlacement) {
                    if editMode {
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
                            editMode.toggle();
                            projectSelection = [];
                        } label: {
                            Text("Done").fontWeight(.bold)
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
