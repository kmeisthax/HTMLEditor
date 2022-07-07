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
     *
     * This mode is unavailable on compact views and instead becomes the WYSIWYG state.
     */
    case Split;
}

#if os(macOS)
/**
 * Fake size class variable to make AppKit happy.
 */
enum HorizontalSizeClass {
    case normal;
    case compact;
}
#endif

struct PageEditor: View {
    @ObservedObject var page: Page;
    
    @State var wysiwygState = WYSIWYGState.Split;
    
    @Environment(\.dismiss) var dismiss;
    
    #if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
    #elseif os(macOS)
    @State var horizontalSizeClass = HorizontalSizeClass.normal;
    #endif
    
    var isSplit: Bool {
        wysiwygState == .Split && horizontalSizeClass != .compact;
    }
    
    var isSource: Bool {
        wysiwygState == .Source;
    }
    
    var isWysiwyg: Bool {
        wysiwygState == .WYSIWYG || (wysiwygState == .Split && horizontalSizeClass == .compact);
    }
    
    var body: some View {
        let navToolbar = ToolbarItemGroup(placement: .primaryAction) {
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
                    if self.wysiwygState != .Source {
                        self.wysiwygState = .Source;
                    } else {
                        self.wysiwygState = .Split;
                    }
                }
            } label: {
                if self.wysiwygState == .Source {
                    Image(systemName: "curlybraces.square.fill")
                } else {
                    Image(systemName: "curlybraces.square")
                }
            }
            
            if horizontalSizeClass != .compact {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if self.wysiwygState != .WYSIWYG {
                            self.wysiwygState = .WYSIWYG;
                        } else {
                            self.wysiwygState = .Split;
                        }
                        
                    }
                } label: {
                    if self.wysiwygState == .WYSIWYG {
                        Image(systemName: "doc.richtext.fill")
                    } else {
                        Image(systemName: "doc.richtext")
                    }
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
        let backToolbar = ToolbarItemGroup(placement: .cancellationAction, content: {
            if horizontalSizeClass == .compact { //custom back buttons are borked on large for some reason
                Button {
                    dismiss();
                } label: {
                    Image(systemName: "folder")
                }
            }
        });
        
        GeometryReader { geo_outer in
            TextEditor(text: $page.html)
                .font(.system(.body).monospaced())
                .disableAutocorrection(true)
                .padding(1)
                .offset(x: isWysiwyg ? geo_outer.size.width * -1.0 : 0.0)
                .frame(maxWidth: 
                        isSplit ? geo_outer.size.width / 2 : .infinity)
                .overlay(Rectangle().frame(width: 1, height: nil, alignment: .trailing).foregroundColor(.secondary), alignment: .trailing)
            WebPreview(html: $page.html)
                .offset(x: isSource ? geo_outer.size.width * 1.0 :
                            isSplit ? geo_outer.size.width * 0.5 : 0.0)
                .frame(maxWidth:
                        isSplit ? geo_outer.size.width / 2 :
                        isSource ? geo_outer.size.width : .infinity)
        }.toolbar {
            navToolbar
            principalToolbar
            backToolbar
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        #endif
    }
}
