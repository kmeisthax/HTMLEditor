import SwiftUI

#if (os(iOS))
extension UITextView {
    open override var frame: CGRect {
        didSet {
            self.smartQuotesType = UITextSmartQuotesType.no
        }
    }
}
#elseif (os(macOS))
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false;
        }
    }
}
#endif
