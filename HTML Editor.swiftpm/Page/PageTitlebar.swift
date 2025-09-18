import SwiftUI
import Introspect

/**
 * View modifier that adds a page title and subtitle to a page editor.
 *
 * The behavior of this modifier is platform-specific: on iOS, it adds a navigation toolbar
 * designed to look like a window titlebar; on macOS it actually sets the navigation title
 * and subtitle as appropriate.
 */
struct PageTitlebar<MenuContent>: ViewModifier where MenuContent: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
    @Environment(\.dismiss) var dismiss;
    #endif
    
    var page: Page?;
    @Binding var pageTitle: String?;
    
    private var menu: MenuContent?;
    
    init(page: Page?, pageTitle: Binding<String?>, menu: () -> MenuContent) {
        self.page = page;
        self._pageTitle = pageTitle;
        self.menu = menu();
    }
    
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
            
            if page?.type == .html {
                Divider()
                Button {
                    self.isRenamingTitle = true;
                    self.renamedTitle = pageTitle ?? "";
                } label: {
                    Label("Rename Page...", systemImage: "rectangle.and.pencil.and.ellipsis")
                }
            }
            
            if let menu = menu {
                Divider()
                menu
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
            ToolbarItem(placement: .title, content: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(windowTitle).fontWeight(.bold)
                        if let subtitle = windowSubtitle {
                            Text(subtitle)
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        }
                    }
                    
                    self.inlineFileMenu
                }
                .frame(maxWidth: horizontalSizeClass == .compact ? 250 : .infinity)
                .fixedSize()
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
        .toolbarRole(.editor)
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController { navigationController in
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
            navigationController.navigationBar.compactScrollEdgeAppearance = navigationController.navigationBar.compactAppearance
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
                    self.inlineFileMenu
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
    func pageTitlebarMenu<MenuContent>(for page: Page? = nil, customTitle: Binding<String?> = Binding.constant(nil), @ViewBuilder menu: () -> MenuContent) -> some View where MenuContent: View {
        modifier(PageTitlebar(page: page, pageTitle: customTitle, menu: menu))
    }
    
    func pageTitlebar(for page: Page? = nil, customTitle: Binding<String?> = Binding.constant(nil)) -> some View {
        modifier(PageTitlebar(page: page, pageTitle: customTitle, menu: {
            EmptyView()
        }))
    }
}
