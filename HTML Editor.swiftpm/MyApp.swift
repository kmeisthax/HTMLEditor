import SwiftUI

@main
struct MyApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(OldschoolAppDelegate.self) var appDelegate;
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(OldschoolAppDelegate.self) var appDelegate;
    #endif
    
    var body: some Scene {
        DocumentGroup(newDocument: ProjectDocument()) { configuration in
            ProjectEditor(project: Project(projectDirectory: configuration.fileURL))
        }
    }
}

#if os(iOS)
class OldschoolAppDelegate: NSObject, UIApplicationDelegate {
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
#endif
