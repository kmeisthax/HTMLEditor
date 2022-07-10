import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct IdentifiableType: Identifiable, Hashable {
    var type: UTType;
    
    var id: String {
        type.identifier
    }
    
    var label: String {
        type.localizedDescription ?? type.preferredFilenameExtension ?? id
    }
}

#if os(iOS)
/**
 * An image importer flow intended to be placed inside of a sheet.
 * 
 * Leverages SystemImagePicker to get an image picker and asks the user
 * what image formats they want to import.
 */
struct ImageImportSheet: View {
    @Binding var isPresented: Bool;
    
    @Binding var subpath: [String];
    
    @State var photos: [PHPickerResult]? = nil;
    @State var availableTypes: [IdentifiableType] = .init();
    @State var allowedTypes: Set<IdentifiableType> = .init();
    
    @ObservedObject var project: Project;
    
    var body: some View {
        if let photos = photos {
            NavigationView {
                Form {
                    Section("Image Types") {
                        ForEach($availableTypes) { $type in
                            Button {
                                if allowedTypes.contains(type) {
                                    allowedTypes.remove(type)
                                } else {
                                    allowedTypes.insert(type)
                                }
                            } label: {
                                HStack {
                                    Text(type.label)
                                    if allowedTypes.contains(type) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Text("Select the image formats to import into the project.")
                }.toolbar {
                    ToolbarItemGroup(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                    
                    ToolbarItemGroup(placement: .confirmationAction) {
                        Button("Import") {
                            isPresented = false;
                            project.importItems(items: photos.map({ photo in photo.itemProvider }), allowedTypes: allowedTypes, toSubpath: subpath)
                        }
                    }
                }.navigationBarTitleDisplayMode(.inline)
            }
        } else {
            SystemImagePicker { photos in
                self.photos = photos;
                
                var typesSet = Set<IdentifiableType>.init();
                
                for photo in photos {
                    for type in photo.itemProvider.registeredTypeIdentifiers {
                        if let type = UTType(type) {
                            typesSet.insert(IdentifiableType(type: type));
                            
                            //Known web-safe formats are preselected so that users that
                            //click through everything without reading get something reasonable.
                            if type.identifier == UTType.png.identifier || type.identifier == UTType.jpeg.identifier || type.identifier == UTType.gif.identifier {
                                allowedTypes.insert(IdentifiableType(type: type));
                            }
                        }
                    }
                }
                
                availableTypes = Array(typesSet);
            }
        }
    }
}
#endif
