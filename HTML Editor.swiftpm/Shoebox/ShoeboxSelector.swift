import SwiftUI

struct ShoeboxSelector: View {
    var items: [GridItem] = Array(repeating: .init(.flexible(minimum: 50, maximum: 100), spacing: 15, alignment: .center), count: 5);
    
    @ObservedObject var shoebox: Shoebox;
    
    @State var newProject: Project? = nil;
    
    @State var editMode = false;
    @State var projectSelection: Set<Project> = [];
    
    var body: some View {
        NavigationView {
            LazyVGrid(columns: items) {
                ForEach($shoebox.projects) { $project in
                    let isSelected = projectSelection.contains(project);
                    
                    FullscreenLink { goBack in
                        return ProjectEditor(project: project, goBack: goBack);
                    } label: { () -> Text in
                        return Text(project.projectName);
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
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
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
        }
        .navigationViewStyle(.stack)
        .sheet(item: $newProject) { project in
            ProjectSettings(project: project, directory: project.projectLocation, onSave: {
                shoebox.projects.append(newProject!);
                
                newProject = nil;
            })
        }
    }
}
