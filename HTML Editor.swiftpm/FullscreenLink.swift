import SwiftUI

/**
 * A wrapper around `.fullScreenCover` that stores the open/closed state.
 * 
 * Useful for ForEach et all.
 * 
 * Contains a view hierarchy inside of a floating layer that is opened
 * when the associated label view is pressed.
 */
struct FullscreenLink<Content, LabelContent>: View where Content: View, LabelContent: View {
    @State var isPresented = false;
    
    /**
     * Content builder function.
     * 
     * Accepts a closure which must be called when the inner view
     * wants to dismiss itself.
     */
    var content: (@escaping () -> Void) -> Content;
    
    /**
     * Label builder function.
     */
    var label: () -> LabelContent;
    
    /**
     * Action for when the link is clicked.
     * 
     * If specified, the button action will replace the default link functionality.
     * The callback will be able to determine if the link should open or not by
     * returning true or false.
     */
    var onAction: () -> Bool = { true };
    
    var body: some View {
        #if os(iOS)
        Button {
            isPresented = onAction();
        } label: {
            label()
        }.fullScreenCover(isPresented: $isPresented, onDismiss: {
            isPresented = false;
        }) {
            content({
                isPresented = false;
            })
        }
        #elseif (macOS)
        Button {
            isPresented = onAction();
        } label: {
            label()
        }.sheet(isPresented: $isPresented, onDismiss: {
            isPresented = false;
        }) {
            content({
                isPresented = false;
            })
        }
        #endif
    }
}
