import SwiftUI
import Introspect

/**
 * View modifier that adds a page title and subtitle to a page editor.
 *
 * The behavior of this modifier is platform-specific: on iOS, it adds a navigation toolbar
 * designed to look like a window titlebar; on macOS it actually sets the navigation title
 * and subtitle as appropriate.
 */
struct PageTitlebar: ViewModifier {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
    @Environment(\.dismiss) var dismiss;
    #endif
    
    var page: Page?;
    @Binding var pageTitle: String?;
    
    var windowTitle: String {
        if let pageTitle = pageTitle, pageTitle != "" {
            return pageTitle;
        } else {
            return page?.filename ?? "";
        }
    }
    
    var windowSubtitle: String? {
        if page?.ownership == .AppOwned {
            return "Temporary file";
        } else if let path = page?.path, path != windowTitle {
            return path;
        } else {
            return nil;
        }
    }
    
    var inlineFileMenu: some View {
        Menu {
            Text(page?.presentedItemURL?.lastPathComponent ?? "")
                .fontWeight(.bold)
            Divider()
            Button {
                self.isRenamingTitle = true;
                self.renamedTitle = pageTitle ?? "";
            } label: {
                Label("Rename Page...", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
        } label: {
            #if os(iOS)
                Image(systemName: "chevron.down.circle.fill").imageScale(.medium)
            #elseif os(macOS)
                Image(systemName: "info.circle")
            #endif
        }.foregroundColor(.secondary)
    }
    
    var renamingForm: some View {
        Form {
            Section("Page Title") {
                TextField("Title", text: $renamedTitle)
            }
        }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationTitle("Rename Page")
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        isRenamingTitle = false;
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Rename") {
                        pageTitle = renamedTitle;
                        isRenamingTitle = false;
                    }
                }
            }
    }
    
    @State var isRenamingTitle = false;
    @State var renamedTitle = "";
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading, content: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(windowTitle).fontWeight(.bold)
                        if let subtitle = windowSubtitle {
                            Text(subtitle)
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        }
                    }
                    
                    if page?.type == .html {
                        self.inlineFileMenu
                    }
                }
            })
            
            ToolbarItemGroup(placement: .cancellationAction, content: {
                if horizontalSizeClass == .compact { //custom back buttons are borked on large for some reason
                    Button {
                        dismiss();
                    } label: {
                        Image(systemName: "folder")
                    }
                }
            })
        }
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController { navigationController in
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
        }
        .navigationTitle("")
        .sheet(isPresented: $isRenamingTitle) {
            NavigationView { renamingForm }
        }
        .onChange(of: renamedTitle) { newValue in
            //We don't actually want to do anything with the value.
            //SwiftUI doesn't properly populate the text field if
            //we don't observe its backing state somehow.
        }
        #elseif os(macOS)
        content
            .navigationTitle(windowTitle)
            .navigationSubtitle(windowSubtitle ?? "")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    if page?.type == .html {
                        self.inlineFileMenu
                    }
                }
            }
            .sheet(isPresented: $isRenamingTitle) {
                renamingForm.frame(minWidth: 300, minHeight: 100).padding()
            }
            .onChange(of: renamedTitle) { newValue in
                //We don't actually want to do anything with the value.
                //SwiftUI doesn't properly populate the text field if
                //we don't observe its backing state somehow.
            }
        #endif
    }
}

extension View {
    func pageTitlebar(for page: Page? = nil, customTitle: Binding<String?> = Binding.constant(nil)) -> some View {
        modifier(PageTitlebar(page: page, pageTitle: customTitle))
    }
}
