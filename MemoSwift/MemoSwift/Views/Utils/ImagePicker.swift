import SwiftUI
import UIKit
import PhotosUI

// 图片来源选择
enum PhotoSource {
    case camera
    case photoLibrary
}

// 图片选择器组件
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: ((UIImage) -> Void)?
    
    @Environment(\.presentationMode) private var presentationMode
    
    // 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 创建控制器
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        imagePickerController.sourceType = sourceType
        return imagePickerController
    }
    
    // 更新控制器
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    // 协调器类
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        // 处理图片选择
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImagePicked?(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        // 处理取消
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// 图片选择器封装视图
struct PhotoPickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?
    var source: PhotoSource
    var onImagePicked: ((UIImage) -> Void)?
    
    var body: some View {
        if isPresented {
            ZStack {
                // 背景用于接收点击事件
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPresented = false
                    }
                
                switch source {
                case .camera:
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        PhotoPicker(
                            selectedImage: $selectedImage,
                            sourceType: .camera,
                            onImagePicked: onImagePicked
                        )
                    } else {
                        Text("相机不可用")
                            .padding()
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(8)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    isPresented = false
                                }
                            }
                    }
                    
                case .photoLibrary:
                    PhotoPicker(
                        selectedImage: $selectedImage, 
                        sourceType: .photoLibrary,
                        onImagePicked: onImagePicked
                    )
                }
            }
        }
    }
}

// 图片显示组件
struct NoteImageView: View {
    let imageData: Data
    var onTap: (() -> Void)?
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                SwiftUI.Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .padding(.vertical, 4)
                    .onTapGesture {
                        onTap?()
                    }
            } else {
                ProgressView()
                    .padding()
                    .onAppear {
                        // 在后台线程加载图片数据
                        DispatchQueue.global().async {
                            if let img = UIImage(data: imageData) {
                                DispatchQueue.main.async {
                                    self.image = img
                                }
                            }
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
} 