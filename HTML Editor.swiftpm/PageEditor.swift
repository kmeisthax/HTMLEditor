import SwiftUI

struct PageEditor: View {
    @ObservedObject var page: Page
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
            ToolbarItemGroup(placement: .principal, content: {
                VStack {
                    Text(page.filename).fontWeight(.bold)
                    if page.ownership == .AppOwned {
                        Text("Temporary file")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
            })
        }
    }
}
