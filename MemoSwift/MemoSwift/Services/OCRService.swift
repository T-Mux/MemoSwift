import Vision
import UIKit

class OCRService {
    static func recognizeText(from image: UIImage, completion: @escaping (String?, Error?) -> Void) {
        // 转换UIImage为CGImage
        guard let cgImage = image.cgImage else {
            completion(nil, NSError(domain: "OCRService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法从UIImage获取CGImage"]))
            return
        }
        
        // 创建文本识别请求
        let request = VNRecognizeTextRequest { (request, error) in
            // 处理错误
            if let error = error {
                completion(nil, error)
                return
            }
            
            // 处理识别结果
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil, NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取识别结果"]))
                return
            }
            
            // 合并所有识别到的文本
            let recognizedText = observations.compactMap { observation in
                // 获取最高置信度的文本
                return observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            // 返回识别结果
            completion(recognizedText, nil)
        }
        
        // 配置请求 - 使用准确的模式，支持中文和英文
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
        
        // 创建处理请求的handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // 执行请求
        do {
            try requestHandler.perform([request])
        } catch {
            completion(nil, error)
        }
    }
} 