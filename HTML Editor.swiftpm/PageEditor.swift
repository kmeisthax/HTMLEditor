import SwiftUI

struct PageEditor: View {
    @Binding var page: Page
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    
    var body: some View {
        HStack {
            TextEditor(text: $page.html)
            WebPreview(html: $page.html)
        }.toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if page.ownership == .AppOwned {
                    Button {
                        page.pickLocationForAppOwnedFile(scene: sceneDelegate.scene!);
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }
}
