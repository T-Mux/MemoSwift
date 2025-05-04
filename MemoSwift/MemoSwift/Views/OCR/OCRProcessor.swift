import SwiftUI
import Vision
import VisionKit
import UIKit

// OCR处理器结果
struct OCRResult {
    let text: String
    let image: UIImage
}

// OCR处理器视图模型
class OCRProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var result: OCRResult?
    @Published var error: String?
    
    // 从图片中提取文本
    func extractText(from image: UIImage, completion: @escaping (OCRResult?) -> Void) {
        guard let cgImage = image.cgImage else {
            self.error = "无法处理图片"
            completion(nil)
            return
        }
        
        self.isProcessing = true
        
        // 创建文本识别请求
        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                }
            }
            
            // 处理错误
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = "文本识别失败: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // 获取识别结果
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self?.error = "无法获取识别结果"
                    completion(nil)
                }
                return
            }
            
            // 提取识别到的文本
            let extractedText = observations.compactMap { observation in
                return observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            // 如果未识别到文本
            if extractedText.isEmpty {
                DispatchQueue.main.async {
                    self?.error = "未能识别到任何文本"
                    completion(nil)
                }
                return
            }
            
            // 创建识别结果
            let ocrResult = OCRResult(text: extractedText, image: image)
            
            // 更新结果
            DispatchQueue.main.async {
                self?.result = ocrResult
                self?.error = nil
                completion(ocrResult)
            }
        }
        
        // 配置请求参数
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
        
        // 创建请求处理器
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // 执行请求
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.error = "文本识别请求失败: \(error.localizedDescription)"
                    self?.isProcessing = false
                    completion(nil)
                }
            }
        }
    }
}

// OCR处理视图
struct OCRProcessView: View {
    @ObservedObject var processor = OCRProcessor()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageSource: PhotoSource = .photoLibrary
    @State private var showActionSheet = false
    
    var onProcessed: (OCRResult) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                // 图片显示区域
                if let image = selectedImage {
                    SwiftUI.Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    VStack {
                        SwiftUI.Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .padding()
                        
                        Text("选择或拍摄一张图片以提取文本")
                            .font(.headline)
                    }
                    .padding()
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 错误显示
                if let error = processor.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // 按钮区域
                VStack(spacing: 16) {
                    if selectedImage == nil {
                        Button {
                            showActionSheet = true
                        } label: {
                            HStack {
                                SwiftUI.Image(systemName: "photo")
                                Text("选择图片")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        // 提取文本按钮
                        Button {
                            if let image = selectedImage {
                                processor.extractText(from: image) { result in
                                    if let result = result {
                                        onProcessed(result)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if processor.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    SwiftUI.Image(systemName: "text.viewfinder")
                                }
                                Text(processor.isProcessing ? "处理中..." : "提取文本")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(processor.isProcessing)
                        
                        // 重新选择图片
                        Button {
                            showActionSheet = true
                        } label: {
                            HStack {
                                SwiftUI.Image(systemName: "arrow.triangle.2.circlepath")
                                Text("重新选择")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                        .disabled(processor.isProcessing)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("OCR文本提取")
            .navigationBarItems(
                trailing: Button("关闭") {
                    onDismiss()
                }
            )
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(
                    title: Text("选择图片来源"),
                    buttons: [
                        .default(Text("拍照")) {
                            imageSource = .camera
                            showImagePicker = true
                        },
                        .default(Text("从相册选择")) {
                            imageSource = .photoLibrary
                            showImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showImagePicker) {
                PhotoPicker(
                    selectedImage: $selectedImage,
                    sourceType: imageSource == .camera ? .camera : .photoLibrary,
                    onImagePicked: { _ in }
                )
            }
        }
    }
} 