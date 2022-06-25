import SwiftUI

struct ShoeboxSelector: View {
    var items: [GridItem] = Array(repeating: .init(.flexible(minimum: 50, maximum: 100), spacing: 15, alignment: .center), count: 5);
    
    @ObservedObject var shoebox: Shoebox;
    
    @State var showNewProjectSheet = false;
    
    var body: some View {
        NavigationView {
            LazyVGrid(columns: items) {
                ForEach($shoebox.projects) { $project in
                    FullscreenLink { goBack in
                        return ProjectEditor(project: project, goBack: goBack);
                    } label: {
                        Text("Project Name Here")
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        shoebox.projects.append(Project())
                    } label: {
                        Label("Create", systemImage: "square.and.pencil")
                    }
                }
            }
        }.navigationViewStyle(.stack)
    }
}
