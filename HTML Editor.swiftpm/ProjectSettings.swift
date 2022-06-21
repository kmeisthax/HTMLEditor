import SwiftUI

struct ProjectSettings: View {
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    @Environment(\.presentationMode) var presentation;
    
    @ObservedObject var project: Project;
    @StateObject var directory: FileLocation;
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section("Project Directory") {
                        if directory.pickedUrls.count > 0 {
                            Text(directory.displayName)
                        }
                        Button(role: .destructive) {
                            directory.pick(scene: self.sceneDelegate.scene!)
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
                        
                        self.presentation.wrappedValue.dismiss()
                    }
                }
            }.navigationTitle("Project Settings")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
