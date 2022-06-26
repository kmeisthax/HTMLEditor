import SwiftUI

struct ShoeboxSelector: View {
    var items: [GridItem] = Array(repeating: .init(.flexible(minimum: 50, maximum: 100), spacing: 15, alignment: .center), count: 5);
    
    @ObservedObject var shoebox: Shoebox;
    
    @State var newProject: Project? = nil;
    
    var body: some View {
        NavigationView {
            LazyVGrid(columns: items) {
                ForEach($shoebox.projects) { $project in
                    FullscreenLink { goBack in
                        return ProjectEditor(project: project, goBack: goBack);
                    } label: { () -> Text in 
                        var text = "Project Name Here";
                        
                        if project.projectDirectory != nil {
                            text = project.projectLocation.displayName
                        }
                        
                        return Text(text);
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        newProject = Project()
                    } label: {
                        Label("Create", systemImage: "square.and.pencil")
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
