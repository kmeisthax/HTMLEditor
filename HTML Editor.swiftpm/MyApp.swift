import SwiftUI

@main
struct MyApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(OldschoolAppDelegate.self) var appDelegate;
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(OldschoolAppDelegate.self) var appDelegate;
    #endif
    
    var body: some Scene {
        #if os(iOS)
        DocumentGroup(newDocument: ProjectDocument()) { configuration in
            ProjectEditor(project: Project(projectDirectory: configuration.fileURL))
        }
        #elseif os(macOS)
        WindowGroup {
            ForEach(appDelegate.shoebox.projects, id: \.id) { project in
                NotAShoebox(shoebox: appDelegate.shoebox, openProject: project.id.uuidString)
            }
        }
        #endif
    }
}

#if os(iOS)
class OldschoolAppDelegate: NSObject, UIApplicationDelegate {
    var shoebox: Shoebox = Shoebox.fromState(state: ShoeboxState.restoreFromDisk());
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role);
        
        sceneConfig.delegateClass = OldschoolSceneDelegate.self
        
        return sceneConfig
    }
}

class OldschoolSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var scene: UIWindowScene?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        self.scene = windowScene
    }
}
#elseif os(macOS)
class OldschoolAppDelegate: NSObject, NSApplicationDelegate {
    var shoebox: Shoebox = Shoebox.fromState(state: ShoeboxState.restoreFromDisk());
}
#endif
