import SwiftUI

struct PageEditor: View {
    @ObservedObject var page: Page
    
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    var body: some View {
        HStack {
            TextEditor(text: $page.html)
            WebPreview(html: $page.html)
        }.toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if page.ownership == .AppOwned {
                    Button {
                        #if os(iOS)
                        page.pickLocationForAppOwnedFile(scene: sceneDelegate.scene!);
                        #endif
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
                    } else if let path = page.path {
                        Text(path)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
            })
        }
    }
}
