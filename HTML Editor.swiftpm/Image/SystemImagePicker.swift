import SwiftUI
import PhotosUI

/**
 * An image picker delegate for picking images to import into an
 * HTML Editor project.
 */
#if os(iOS)
struct SystemImagePicker: UIViewControllerRepresentable {
    var didPickPhoto: ([PHPickerResult]) -> Void;
    
    func makeCoordinator() -> ImagePickerCoordinator {
        return ImagePickerCoordinator(owner: self)
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared());
        
        config.filter = .images;
        
        let picker = PHPickerViewController(configuration: config);
        
        picker.delegate = context.coordinator;
        
        return picker;
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        //
    }
}

class ImagePickerCoordinator : NSObject, PHPickerViewControllerDelegate {
    var owner: SystemImagePicker;
    
    init(owner: SystemImagePicker) {
        self.owner = owner;
    }
    
    // == PHPickerViewControllerDelegate
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        owner.didPickPhoto(results)
    }
}
#endif
