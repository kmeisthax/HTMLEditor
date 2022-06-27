import SwiftUI

/**
 * Viewmodel class for holding all currently open projects.
 */
class Shoebox: ObservableObject {
    @Published var projects: [Project] = [];
}
