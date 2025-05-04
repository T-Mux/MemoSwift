import SwiftUI
import UIKit

// 定义图片来源
enum ImageSource {
    case photoLibrary
    case camera
}

// ImagePicker协调器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    let source: ImageSource
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = context.coordinator
        
        // 根据来源设置图片选择控制器
        switch source {
        case .photoLibrary:
            imagePickerController.sourceType = .photoLibrary
        case .camera:
            // 检查相机是否可用
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                imagePickerController.sourceType = .camera
            } else {
                print("相机不可用")
                imagePickerController.sourceType = .photoLibrary
            }
        }
        
        return imagePickerController
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 协调器类，处理UIImagePickerController的代理回调
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        // 图片选择完成
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 获取选择的图片
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            
            // 关闭图片选择器
            parent.isPresented = false
        }
        
        // 取消选择
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
} 