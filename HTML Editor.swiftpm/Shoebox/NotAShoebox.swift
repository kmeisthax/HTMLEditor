import SwiftUI

/**
 * Fake shoebox browser that exists purely because shoeboxes are a bad design idea on macOS.
 */
struct NotAShoebox: View {
    @ObservedObject var shoebox: Shoebox;
    
    @State var openProject: String?;
    
    var body: some View {
        if let project = shoebox.project(fromStateName: openProject) {
            ProjectEditor(project: project)
        } else {
            Text("Error: Project missing")
        }
    }
}
