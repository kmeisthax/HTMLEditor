import SwiftUI

/**
 * What width breakpoint the HTML editor panes are in.
 *
 * normal is guaranteed to be at least wide enough to fit two 320px mobile views.
 */
enum PaneBreakpoint {
    case normal;
    case compact;
}

/**
 * A view that supports calculating the current breakpoint from view geometry.
 *
 * On iOS, views that adopt this protocol must expose the iOS horizontal size
 * class environment.
 */
protocol BreakpointCalculator {
    #if os(iOS)
    var horizontalSizeClass: UserInterfaceSizeClass? { get };
    #endif
}

extension BreakpointCalculator {
    /**
     * Calculate the current pane breakpoint.
     *
     * This only returns normal size iff the parent view is wide enough to fit
     * two panes and, on iOS, if we are not in a compact Scene.
     *
     * You must get the current view size from a GeometryReader.
     */
    func paneBreakpoint(_ withSize: CGSize) -> PaneBreakpoint {
        #if os(iOS)
        switch horizontalSizeClass {
        case .regular:
            if withSize.width / 2 < 320 {
                return PaneBreakpoint.compact;
            } else {
                return PaneBreakpoint.normal;
            }
        case .compact:
            return PaneBreakpoint.compact;
        case .none:
            return PaneBreakpoint.compact;
        case .some(_):
            return PaneBreakpoint.compact;
        }
        #else
        if withSize.width / 2 < 320 {
            return PaneBreakpoint.compact;
        } else {
            return PaneBreakpoint.normal;
        }
        #endif
    }
}
