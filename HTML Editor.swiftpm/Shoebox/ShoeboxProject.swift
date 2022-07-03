import SwiftUI

struct ShoeboxProject: View {
    @ObservedObject var project: Project;
    
    @Binding var editMode: Bool;
    @Binding var projectSelection: Set<Project>;
    
    var body: some View {
        let isSelected = projectSelection.contains(project);
        
        FullscreenLink(isEditMode: $editMode) { goBack in
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
        } onLongPress: {
            editMode = true;
            projectSelection.insert(project)
        }
    }
}