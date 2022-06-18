import SwiftUI
import Foundation

class Page : ObservableObject, Identifiable {
    var id: UUID;
    
    @Published var html: String = "<!DOCTYPE html>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
    
    init() {
        id = UUID.init()
    }
}
