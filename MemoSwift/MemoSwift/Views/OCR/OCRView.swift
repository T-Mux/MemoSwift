import SwiftUI
import UIKit

struct OCRView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var noteViewModel: NoteViewModel
    
    let folder: Folder
    
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var imageSource: PhotoSource = .photoLibrary
    @State private var recognizedText: String = ""
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var noteTitle = "OCR扫描结果"
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    
                    Spacer()
                    
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    
                    Spacer()
                    
                    Button("完成") {
                        createNoteFromOCR()
                    }
                    .padding()
                    .disabled(recognizedText.isEmpty || isProcessing)
                }
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 图片选择部分
                        VStack {
                            if let image = selectedImage {
                                SwiftUI.Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                                    .padding()
                            } else {
                                Text("选择或拍摄图片进行OCR文字识别")
                                    .font(.headline)
                                    .padding()
                            }
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    imageSource = .photoLibrary
                                    isImagePickerPresented = true
                                }) {
                                    Label("照片库", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    imageSource = .camera
                                    isImagePickerPresented = true
                                }) {
                                    Label("拍照", systemImage: "camera")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.vertical)
                        
                        // 笔记标题输入框
                        TextField("笔记标题", text: $noteTitle)
                            .font(.headline)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        
                        // 识别结果
                        if !recognizedText.isEmpty {
                            VStack(alignment: .leading) {
                                Text("识别结果:")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextEditor(text: $recognizedText)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .frame(minHeight: 200)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isImagePickerPresented) {
                PhotoPicker(
                    selectedImage: $selectedImage,
                    sourceType: imageSource == .camera ? .camera : .photoLibrary)
                    .onDisappear {
                        if let image = selectedImage {
                            performOCR(on: image)
                        }
                    }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("OCR识别"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("确定")))
            }
        }
    }
    
    // 执行OCR识别
    private func performOCR(on image: UIImage) {
        isProcessing = true
        
        OCRService.recognizeText(from: image) { (text, error) in
            DispatchQueue.main.async {
                isProcessing = false
                
                if let error = error {
                    alertMessage = "OCR识别失败：\(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                guard let recognizedText = text, !recognizedText.isEmpty else {
                    alertMessage = "未能识别到任何文字"
                    showAlert = true
                    return
                }
                
                self.recognizedText = recognizedText
            }
        }
    }
    
    // 创建包含OCR结果的笔记
    private func createNoteFromOCR() {
        guard !recognizedText.isEmpty else { return }
        
        // 创建新笔记
        _ = noteViewModel.createNote(
            title: noteTitle,
            content: recognizedText,
            folder: folder
        )
        
        // 关闭OCR视图
        presentationMode.wrappedValue.dismiss()
    }
} 