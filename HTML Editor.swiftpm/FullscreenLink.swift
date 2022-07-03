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
    
    @State var isTapped = false;
    @GestureState var isLongPressed = false;
    
    @Binding var isEditMode: Bool;
    
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
    
    var onLongPress: () -> Void = {};
    
    var body: some View {
        #if os(iOS)
        VStack {
            label()
        }
        .opacity(isTapped ? 0.5 : 1.0)
        .scaleEffect(isLongPressed && !isEditMode ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.3).delay(0.5), value: isLongPressed && !isEditMode ? 0.9 : 1.0)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .updating($isLongPressed, body: { value, state, transaction in
                    state = value;
                })
                .onEnded({ _ in
                    isTapped = false;
                    onLongPress()
                })
                .onChanged {_ in
                    withAnimation(.easeIn(duration: 0.1), {
                        isTapped = true;
                    })
                }
                .exclusively(before: LongPressGesture(minimumDuration: 0)
                        .onEnded({ _ in
                            isTapped = false;
                            isPresented = onAction();
                        })
                          ) //Misformatting enforced by Swift Playgrounds
                           
        )
        .fullScreenCover(isPresented: $isPresented, onDismiss: {
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
