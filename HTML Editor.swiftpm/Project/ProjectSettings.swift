import SwiftUI

struct ProjectSettings: View {
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    @Environment(\.presentationMode) var presentation;
    
    @ObservedObject var project: Project;
    
    var onSave: (() -> Void)?;
    
    var body: some View {
        let sheetContents = VStack {
            Form {
                Section("Project Directory") {
                    Text(project.projectName)
                }
            }
        }.toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Done") {
                    if let onSave = onSave {
                        onSave();
                    }
                    
                    self.presentation.wrappedValue.dismiss()
                }
            }
        };
        
        #if os(iOS)
        NavigationView {
            sheetContents
                .navigationTitle(project.projectName)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbarRole(.automatic)
        }
        #elseif os(macOS)
        sheetContents
            .frame(minWidth: 300, minHeight: 300)
        #endif
    }
}
