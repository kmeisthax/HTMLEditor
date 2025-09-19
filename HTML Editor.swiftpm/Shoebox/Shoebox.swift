import SwiftUI
import Combine

/**
 * Viewmodel class for holding all currently open projects.
 */
class Shoebox: ObservableObject {
    @Published var projects: [Project] = [];
    
    private var c: [AnyCancellable] = [];
    
    init() {
        $projects.throttle(for: 0.5, scheduler: OperationQueue.main, latest: true).sink(receiveValue: { [weak self] _ in
            if let self = self {
                self.nestedStateDidChange()
            }
        }).store(in: &c);
    }
    
    /**
     * Function to be called when a project or page is updated.
     * 
     * We can't actually hook all the projects and pages reachable from the
     * shoebox using ObservableObject; Combine and SwiftUI don't really
     * support that. So instead we have all the viewmodel classes manually
     * trigger this function when *they* change.
     * 
     * Personally I dislike the cross-cutting concern polluting other
     * classes, but this is how SwiftUI wants to work.
     * 
     * Alternative options I rejected, and why:
     * 
     *  - Holding a list of all the event sources in the shoebox and
     *    sinking each one. Difficult to throttle correctly and requires
     *    cancelling and rehooking potentially thousands of files.
     * 
     *  - Maintaining a single ShoeboxState somewhere and having the
     *    viewmodels update it when it needs to be saved. This is more
     *    in the spirit of SwiftUI, but since that's gotta be a value
     *    type we need the viewmodels to manually navigate and change
     *    the value each time.
     */
    func nestedStateDidChange() {
        self.intoState().saveToDisk() //todo: throttling
    }
    
    /**
     * Extract viewmodel state into a codable object.
     */
    func intoState() -> ShoeboxState {
        var projectStates: [ProjectState] = [];
        
        for project in self.projects {
            projectStates.append(project.intoState());
        }
        
        return ShoeboxState(projects: projectStates);
    }
    
    /**
     * Inject viewmodel state from a codable object.
     */
    class func fromState(state: ShoeboxState) -> Shoebox {
        var projects: [Project] = [];
        
        for project in state.projects {
            projects.append(Project.fromState(state: project));
        }
        
        let shoebox = Shoebox();
        
        shoebox.projects = projects;
        
        return shoebox;
    }
    
    func project(fromStateName: String?) -> Project? {
        self.projects.first(where: { elem in
            elem.id.uuidString == fromStateName
        })
    }
}
