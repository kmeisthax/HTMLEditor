import SwiftUI

struct ShoeboxProject: View {
    @ObservedObject var project: Project;
    
    @Binding var editMode: Bool;
    @Binding var projectSelection: Set<Project>;
    
    @Binding var openProject: String?;
    
    var body: some View {
        let isSelected = projectSelection.contains(project);
        
        FullscreenLink(selection: $openProject, tag: project.id.uuidString, isPresented: openProject == project.id.uuidString, isEditMode: $editMode) { goBack in
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
                    .stroke(isSelected ? Color.accentColor : .primary, lineWidth: isSelected ? 2 : 1)
            )
            .padding(.vertical, 10)
            .shadow(color: .secondary, radius: 10.0, x: 0.0, y: 5.0);
        } onAction: {
            if editMode {
                if projectSelection.contains(project) {
                    projectSelection.remove(project)
                } else {
                    projectSelection.insert(project)
                }
            } else {
                project.projectIsVisible()
            }
            
            return !editMode;
        } onLongPress: {
            editMode = true;
            projectSelection.insert(project)
        }
    }
}
