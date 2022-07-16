import SwiftUI

#if os(macOS)
struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?;
    
    var onLoad: () -> Void;
    
    func makeNSView(context: Context) -> some NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window;
            onLoad();
        }
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        
    }
}
#endif
