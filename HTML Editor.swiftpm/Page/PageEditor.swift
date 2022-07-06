import SwiftUI

/**
 * Which set of editors are currently visible.
 */
enum WYSIWYGState {
    /**
     * Only the editable preview is shown.
     */
    case WYSIWYG;
    
    /**
     * Only the document source is shown.
     */
    case Source;
    
    /**
     * Both preview and source are shown, side-by-side.
     */
    case Split;
}

struct PageEditor: View {
    @ObservedObject var page: Page;
    
    @State var wysiwygState = WYSIWYGState.Split;
    
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    #endif
    
    var body: some View {
        let navToolbar = ToolbarItemGroup(placement: .navigation) {
            if page.ownership == .AppOwned {
                Button {
                    #if os(iOS)
                    page.pickLocationForAppOwnedFile(scene: sceneDelegate.scene!);
                    #endif
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.wysiwygState = .Source;
                }
            } label: {
                if self.wysiwygState == .Source {
                    Image(systemName: "curlybraces.square.fill")
                } else {
                    Image(systemName: "curlybraces.square")
                }
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.wysiwygState = .Split;
                }
            } label: {
                if self.wysiwygState == .Split {
                    Image(systemName: "rectangle.split.2x1.fill")
                } else {
                    Image(systemName: "rectangle.split.2x1")
                }
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.wysiwygState = .WYSIWYG;
                }
            } label: {
                if self.wysiwygState == .WYSIWYG {
                    Image(systemName: "doc.richtext.fill")
                } else {
                    Image(systemName: "doc.richtext")
                }
            }
        }
        let principalToolbar = ToolbarItemGroup(placement: .principal, content: {
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
        });
        
        //TODO: I replaced the Hstack with explicit geometry calculations, but they
        //are very much incomplete.
        GeometryReader { geo_outer in
            TextEditor(text: $page.html)
                .font(.system(.body).monospaced())
                .disableAutocorrection(true)
                .padding(1)
                .offset(x: wysiwygState == .WYSIWYG ? geo_outer.size.width * -1.0 : 0.0)
                .frame(maxWidth: 
                        wysiwygState == .Split ? geo_outer.size.width / 2 : .infinity)
            WebPreview(html: $page.html)
                .offset(x: wysiwygState == .Source ? geo_outer.size.width * 1.0 :
                            wysiwygState == .Split ? geo_outer.size.width * 0.5 : 0.0)
                .frame(maxWidth:
                        wysiwygState == .Split ? geo_outer.size.width / 2 :
                        wysiwygState == .Source ? geo_outer.size.width : .infinity)
        }.toolbar {
            navToolbar
            principalToolbar
        }
    }
}
