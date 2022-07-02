import SwiftUI

struct ProjectSettings: View {
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    @Environment(\.presentationMode) var presentation;
    
    @ObservedObject var project: Project;
    @StateObject var directory: FileLocation;
    
    var onSave: (() -> Void)?;
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section("Project Directory") {
                        if directory.pickedUrls.count > 0 {
                            Text(directory.displayName)
                        }
                        Button(role: .destructive) {
                            #if os(iOS)
                            directory.pick(scene: self.sceneDelegate.scene!)
                            #endif
                        } label: {
                            Text("Link new directory")
                        }
                    }
                }
            }.toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        self.presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save") {
                        project.projectLocation = directory;
                        
                        if let onSave = onSave {
                            onSave();
                        }
                        
                        self.presentation.wrappedValue.dismiss()
                    }
                }
            }.navigationTitle("Project Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
