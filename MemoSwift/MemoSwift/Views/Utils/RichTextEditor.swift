import SwiftUI
import UIKit

// 富文本编辑器组件，使用UIKit的UITextView桥接到SwiftUI
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var focus: Bool
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
    var onCommit: (NSAttributedString) -> Void
    var textView: UITextView?
    
    // 初始化函数，添加默认参数
    init(attributedText: Binding<NSAttributedString>, 
         focus: Binding<Bool> = .constant(false),
         canUndo: Binding<Bool> = .constant(false),
         canRedo: Binding<Bool> = .constant(false),
         onCommit: @escaping (NSAttributedString) -> Void) {
        self._attributedText = attributedText
        self._focus = focus
        self._canUndo = canUndo
        self._canRedo = canRedo
        self.onCommit = onCommit
    }
    
    // 创建UITextView
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.font = UIFont.preferredFont(forTextStyle: .body).withSize(18)
        textView.autocapitalizationType = .sentences
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        
        // 确保撤销管理器正确配置
        textView.allowsEditingTextAttributes = true
        // UITextView已经有内置的undoManager，直接配置它
        textView.undoManager?.levelsOfUndo = 20  // 设置撤销步数限制
        
        // 确保保存对 textView 的引用
        context.coordinator.textView = textView
        
        // 获取自定义工具栏容器并设置为inputAccessoryView
        let toolbarContainer = createToolbar(context: context)
        textView.inputAccessoryView = toolbarContainer
        
        // 防止自动关闭键盘
        context.coordinator.preventKeyboardDismiss = true
        
        // 添加点击手势，确保能够唤起键盘
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTextViewTap(_:)))
        textView.addGestureRecognizer(tapGesture)
        
        return textView
    }
    
    // 更新UITextView
    func updateUIView(_ textView: UITextView, context: Context) {
        // 检查是否是格式化操作引起的更新（如粗体、斜体等）
        let timeSinceLastEdit = Date().timeIntervalSince(context.coordinator.lastEditTimestamp)
        let isFormattingUpdate = context.coordinator.isActivelyEditing && timeSinceLastEdit < 0.2
        
        // 只有在非活跃编辑状态或格式化更新时才进行内容更新
        if !context.coordinator.isActivelyEditing || isFormattingUpdate {
            // 避免更新时光标位置重置
            let selectedRange = textView.selectedRange
            
            // 只有当内容真正变化时才进行更新，减少不必要的重绘
            if !NSAttributedString.areEqual(textView.attributedText, attributedText) {
                print("RichTextEditor: updateUIView - 内容发生变化，进行更新")
                textView.attributedText = attributedText
                
                // 恢复光标位置
                if selectedRange.location < attributedText.length {
                    textView.selectedRange = selectedRange
                }
            }
        } else {
            print("RichTextEditor: updateUIView - 跳过内容更新（活跃编辑中）")
        }
        
        // 不在view update期间直接更新状态，使用Task以避免"在视图更新期间修改状态"警告
        Task { @MainActor in
            // 更新撤销重做状态
            context.coordinator.updateUndoRedoState()
        }
        
        // 处理焦点变化
        let shouldBecomeFirstResponder = focus && !textView.isFirstResponder && !context.coordinator.isResigningFocus
        let shouldResignFirstResponder = !focus && textView.isFirstResponder && context.coordinator.isResigningFocus
        
        // 使用Task避免在view update期间直接改变UI状态
        if shouldBecomeFirstResponder {
            Task { @MainActor in
                // 添加短暂延迟，避免与标题框焦点切换冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    textView.becomeFirstResponder()
                    context.coordinator.preventKeyboardDismiss = true
                }
            }
        } else if shouldResignFirstResponder {
            Task { @MainActor in
                textView.resignFirstResponder()
                
                // 延迟重置标志
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    context.coordinator.isResigningFocus = false
                }
            }
        }
    }
    
    // 协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 创建工具栏
    private func createToolbar(context: Context) -> UIView {
        // 创建自定义容器，包含工具栏和额外的上边距，并在底部添加空白区域使工具栏整体上移
        let toolbarHeight: CGFloat = 44  // 工具栏标准高度
        let topPadding: CGFloat = 10     // 顶部边距
        let bottomPadding: CGFloat = 30  // 底部添加空白区域，使工具栏实际位置上移
        let containerHeight: CGFloat = topPadding + toolbarHeight + bottomPadding
        
        let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: containerHeight))
        container.backgroundColor = .systemBackground
        
        // 只保留底部细线
        let bottomBorder = UIView(frame: CGRect(x: 0, y: containerHeight - 0.5, width: UIScreen.main.bounds.width, height: 0.5))
        bottomBorder.backgroundColor = UIColor.systemGray5
        container.addSubview(bottomBorder)
        
        // 创建标准工具栏并放置在容器的上部
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: topPadding, width: UIScreen.main.bounds.width, height: toolbarHeight))
        toolbar.tintColor = .systemBlue
        toolbar.isTranslucent = false
        toolbar.barTintColor = .systemBackground
        container.addSubview(toolbar)
        
        // 设置工具栏内容
        
        // 文本样式按钮
        let boldButton = UIBarButtonItem(image: UIImage(systemName: "bold"), style: .plain, target: context.coordinator, action: #selector(Coordinator.toggleBold))
        
        let italicButton = UIBarButtonItem(image: UIImage(systemName: "italic"), style: .plain, target: context.coordinator, action: #selector(Coordinator.toggleItalic))
        
        let underlineButton = UIBarButtonItem(image: UIImage(systemName: "underline"), style: .plain, target: context.coordinator, action: #selector(Coordinator.toggleUnderline))
        
        // 字体大小选择器
        let fontSizeButton = UIBarButtonItem(image: UIImage(systemName: "textformat.size"), style: .plain, target: context.coordinator, action: #selector(Coordinator.showFontSizeOptions))
        
        // 文本颜色选择器
        let colorButton = UIBarButtonItem(image: UIImage(systemName: "paintpalette"), style: .plain, target: context.coordinator, action: #selector(Coordinator.showColorPicker))
        
        // 添加图片按钮 - 使用actionSheet提供多个选项
        let imageButton = UIBarButtonItem(image: UIImage(systemName: "photo"), style: .plain, target: context.coordinator, action: #selector(Coordinator.showImageOptions))
        
        // 链接按钮
        let linkButton = UIBarButtonItem(image: UIImage(systemName: "link"), style: .plain, target: context.coordinator, action: #selector(Coordinator.addLink))
        
        // 灵活空间和固定空间
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = 12  // 设置固定宽度的间距
        
        // 完成按钮 - 使用自定义样式使其更突出
        let doneButton = UIBarButtonItem(title: "完成", style: .done, target: context.coordinator, action: #selector(Coordinator.doneEditing))
        doneButton.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ], for: .normal)
        
        // 组合按钮，添加适当的分组和间距
        toolbar.items = [
            // 文本格式化组
            boldButton, 
            fixedSpace,
            italicButton, 
            fixedSpace,
            underlineButton,
            fixedSpace, 
            fontSizeButton,
            fixedSpace,
            colorButton,
            
            flexSpace,
            
            // 插入内容组
            linkButton,
            fixedSpace,
            imageButton,
            
            flexSpace,
            
            // 完成按钮
            doneButton
        ]
        
        toolbar.sizeToFit()
        
        return container
    }
    
    // 协调器类
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var textView: UITextView?
        var isFirstUpdate = true  // 跟踪首次更新状态
        var preventKeyboardDismiss = true  // 默认阻止工具栏消失
        var isResigningFocus = false  // 跟踪是否主动放弃焦点
        var isActivelyEditing = false  // 跟踪是否正在活跃编辑
        var lastEditTimestamp = Date()  // 上次编辑时间戳
        
        // 字体大小相关视图引用
        var fontSizeContainer: UIView?
        var fontSizeSlider: UISlider?
        var fontSizeLabel: UILabel?
        var fontSizeTapGesture: UITapGestureRecognizer?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
            
            // 添加撤销和重做通知监听
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleUndo),
                name: NSNotification.Name("RichTextEditorUndo"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRedo),
                name: NSNotification.Name("RichTextEditorRedo"),
                object: nil
            )
            
            // 添加文本变化通知监听
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textDidChange),
                name: UITextView.textDidChangeNotification,
                object: nil
            )
            
            // 添加图片插入通知监听
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleImageInsertion),
                name: NSNotification.Name("RichTextEditorInsertImage"),
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? UITextView,
               textView === self.textView {
                updateUndoRedoState()
            }
        }
        
        @objc func handleUndo() {
            if let textView = textView {
                if textView.undoManager?.canUndo == true {
                    textView.undoManager?.undo()
                    updateUndoRedoState()
                }
            }
        }
        
        @objc func handleRedo() {
            if let textView = textView {
                if textView.undoManager?.canRedo == true {
                    textView.undoManager?.redo()
                    updateUndoRedoState()
                }
            }
        }
        
        @objc func handleImageInsertion(_ notification: Notification) {
            if let userInfo = notification.userInfo,
               let imageData = userInfo["imageData"] as? Data,
               let cursorPosition = userInfo["cursorPosition"] as? Int {
                DispatchQueue.main.async {
                    self.insertImageAtCursor(imageData: imageData, cursorPosition: cursorPosition)
                }
            }
        }
        
        func updateUndoRedoState() {
            if let textView = textView {
                // 使用 Task 和 MainActor 确保在正确的上下文中更新 UI 状态
                Task { @MainActor in
                    // 获取状态但不立即更新绑定值
                    let canUndo = textView.undoManager?.canUndo ?? false
                    let canRedo = textView.undoManager?.canRedo ?? false
                    
                    // 使用 withAnimation 避免在视图更新过程中修改状态
                    DispatchQueue.main.async {
                        self.parent.canUndo = canUndo
                        self.parent.canRedo = canRedo
                    }
                }
            }
        }
        
        // 文本改变时更新绑定值
        func textViewDidChange(_ textView: UITextView) {
            isActivelyEditing = true
            lastEditTimestamp = Date()
            
            print("RichTextEditor: 文本已改变，长度: \(textView.attributedText.length)")
            
            // 不要手动注册撤销操作 - UITextView已经内置了撤销支持
            // 手动注册会干扰内置的撤销机制
            
            // 更新文本内容
            parent.attributedText = textView.attributedText
            print("RichTextEditor: 调用 onCommit 回调")
            parent.onCommit(textView.attributedText)
            
            // 更新撤销重做状态
            updateUndoRedoState()
            
            // 延迟重置编辑状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isActivelyEditing = false
            }
        }
        
        // 开始编辑时的处理
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 确保更新焦点状态
            DispatchQueue.main.async {
                self.parent.focus = true
            }
            preventKeyboardDismiss = true
            updateUndoRedoState()
        }
        
        // 当编辑结束时（如按下Done按钮后），确保保存内容
        func textViewDidEndEditing(_ textView: UITextView) {
            // 只有当真正需要结束编辑时才更新状态
            if isResigningFocus {
                isActivelyEditing = false
                // 确保提交最终的内容
                parent.onCommit(parent.attributedText)
            }
            
            // 确保更新焦点状态
            DispatchQueue.main.async {
                self.parent.focus = false
            }
            
            updateUndoRedoState()
        }
        
        // 完成编辑 - 只有点击"Done"按钮才会执行这个方法
        @objc func doneEditing() {
            // 标记为主动放弃焦点
            isResigningFocus = true
            isActivelyEditing = false
            
            // 关闭阻止键盘消失的标志，允许键盘隐藏
            preventKeyboardDismiss = false
            
            // 确保提交更新的内容
            parent.onCommit(parent.attributedText)
            
            // 关闭焦点状态
            parent.focus = false
            
            // 隐藏键盘和工具栏
            textView?.resignFirstResponder()
            
            // 延迟重置变量，以避免即时恢复焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isResigningFocus = false
                self.preventKeyboardDismiss = true
            }
        }
        
        // 切换粗体
        @objc func toggleBold() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                // 保存当前状态用于撤销
                let previousAttributedText = textView.attributedText.copy() as! NSAttributedString
                
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                // 查看选中文本是否已经应用了粗体
                var allBold = true
                var existingFontSize: CGFloat = UIFont.systemFontSize
                
                mutableAttributedString.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, stop in
                    if let font = value as? UIFont {
                        // 保存已有的字体大小
                        existingFontSize = font.pointSize
                        
                        // 检查字体是否为粗体
                        if !font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                            allBold = false
                            stop.pointee = true
                        }
                    } else {
                        allBold = false
                        stop.pointee = true
                    }
                }
                
                // 注册撤销操作 - 避免 Swift 6 @Sendable 警告
                if let undoManager = textView.undoManager {
                    let undoData = try? previousAttributedText.data(from: NSRange(location: 0, length: previousAttributedText.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                    let undoRange = selectedRange
                    
                    undoManager.registerUndo(withTarget: self) { coordinator in
                        if let data = undoData,
                           let restoredText = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                            coordinator.textView?.attributedText = restoredText
                            coordinator.textView?.selectedRange = undoRange
                            coordinator.parent.attributedText = restoredText
                            coordinator.parent.onCommit(restoredText)
                        }
                    }
                }
                
                // 根据当前状态切换粗体
                mutableAttributedString.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                    var newFont: UIFont
                    
                    if let oldFont = value as? UIFont {
                        if allBold {
                            // 移除粗体，但保持字体大小和其他属性
                            let traits = oldFont.fontDescriptor.symbolicTraits.subtracting(.traitBold)
                            if let descriptor = oldFont.fontDescriptor.withSymbolicTraits(traits) {
                                newFont = UIFont(descriptor: descriptor, size: oldFont.pointSize)
                            } else {
                                newFont = UIFont.systemFont(ofSize: oldFont.pointSize)
                            }
                        } else {
                            // 添加粗体，但保持字体大小和其他属性
                            let traits = oldFont.fontDescriptor.symbolicTraits.union(.traitBold)
                            if let descriptor = oldFont.fontDescriptor.withSymbolicTraits(traits) {
                                newFont = UIFont(descriptor: descriptor, size: oldFont.pointSize)
                            } else {
                                newFont = UIFont.boldSystemFont(ofSize: oldFont.pointSize)
                            }
                        }
                    } else {
                        // 如果没有现有字体，使用系统字体并应用粗体
                        newFont = allBold ? UIFont.systemFont(ofSize: existingFontSize) : UIFont.boldSystemFont(ofSize: existingFontSize)
                    }
                    
                    mutableAttributedString.removeAttribute(.font, range: range)
                    mutableAttributedString.addAttribute(.font, value: newFont, range: range)
                }
                
                textView.attributedText = mutableAttributedString
                textView.selectedRange = selectedRange
                
                // 更新绑定的文本并触发保存
                parent.attributedText = mutableAttributedString
                parent.onCommit(mutableAttributedString)
                
                // 更新撤销重做状态
                updateUndoRedoState()
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 切换斜体
        @objc func toggleItalic() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                // 保存当前状态用于撤销
                let previousAttributedText = textView.attributedText.copy() as! NSAttributedString
                
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                // 查看选中文本是否已经应用了斜体
                var allItalic = true
                var existingFontSize: CGFloat = UIFont.systemFontSize
                
                mutableAttributedString.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, stop in
                    if let font = value as? UIFont {
                        // 保存已有的字体大小
                        existingFontSize = font.pointSize
                        
                        // 检查字体是否为斜体
                        if !font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                            allItalic = false
                            stop.pointee = true
                        }
                    } else {
                        allItalic = false
                        stop.pointee = true
                    }
                }
                
                // 注册撤销操作 - 避免 Swift 6 @Sendable 警告
                if let undoManager = textView.undoManager {
                    let undoData = try? previousAttributedText.data(from: NSRange(location: 0, length: previousAttributedText.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                    let undoRange = selectedRange
                    
                    undoManager.registerUndo(withTarget: self) { coordinator in
                        if let data = undoData,
                           let restoredText = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                            coordinator.textView?.attributedText = restoredText
                            coordinator.textView?.selectedRange = undoRange
                            coordinator.parent.attributedText = restoredText
                            coordinator.parent.onCommit(restoredText)
                        }
                    }
                }
                
                // 根据当前状态切换斜体
                mutableAttributedString.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                    var newFont: UIFont
                    
                    if let oldFont = value as? UIFont {
                        if allItalic {
                            // 移除斜体，但保持字体大小和其他属性
                            let traits = oldFont.fontDescriptor.symbolicTraits.subtracting(.traitItalic)
                            if let descriptor = oldFont.fontDescriptor.withSymbolicTraits(traits) {
                                newFont = UIFont(descriptor: descriptor, size: oldFont.pointSize)
                            } else {
                                newFont = UIFont.systemFont(ofSize: oldFont.pointSize)
                            }
                        } else {
                            // 添加斜体，但保持字体大小和其他属性
                            let traits = oldFont.fontDescriptor.symbolicTraits.union(.traitItalic)
                            if let descriptor = oldFont.fontDescriptor.withSymbolicTraits(traits) {
                                newFont = UIFont(descriptor: descriptor, size: oldFont.pointSize)
                            } else {
                                newFont = UIFont.italicSystemFont(ofSize: oldFont.pointSize)
                            }
                        }
                    } else {
                        // 如果没有现有字体，使用系统字体并应用斜体
                        newFont = allItalic ? UIFont.systemFont(ofSize: existingFontSize) : UIFont.italicSystemFont(ofSize: existingFontSize)
                    }
                    
                    mutableAttributedString.removeAttribute(.font, range: range)
                    mutableAttributedString.addAttribute(.font, value: newFont, range: range)
                }
                
                textView.attributedText = mutableAttributedString
                textView.selectedRange = selectedRange
                
                // 更新绑定的文本并触发保存
                parent.attributedText = mutableAttributedString
                parent.onCommit(mutableAttributedString)
                
                // 更新撤销重做状态
                updateUndoRedoState()
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 切换下划线
        @objc func toggleUnderline() {
            toggleTextAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
        }
        
        // 显示字体大小选项 - 使用浮动滑块代替弹出对话框
        @objc func showFontSizeOptions() {
            guard let textView = textView else { return }
            
            // 如果已经显示了字体大小调整器，先移除它
            if let existingContainer = fontSizeContainer {
                existingContainer.removeFromSuperview()
                fontSizeContainer = nil
                fontSizeSlider = nil
                fontSizeLabel = nil
                
                // 确保移除后立即恢复焦点和工具栏
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    self.preventKeyboardDismiss = true
                }
                return
            }
            
            // 获取当前字体大小
            var currentFontSize: CGFloat = UIFont.systemFontSize
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                textView.attributedText.enumerateAttribute(.font, in: selectedRange, options: []) { value, _, _ in
                    if let font = value as? UIFont {
                        currentFontSize = font.pointSize
                    }
                }
            }
            
            // 获取屏幕宽度 - 使用iOS 15兼容方式
            let screenWidth: CGFloat
            if #available(iOS 15.0, *) {
                // 使用更新的API
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    screenWidth = window.bounds.width
                } else {
                    screenWidth = UIScreen.main.bounds.width
                }
            } else {
                // 旧版API
                screenWidth = UIApplication.shared.windows.first?.bounds.width ?? UIScreen.main.bounds.width
            }
            
            // 创建一个包含滑块的视图 - 设计成工具栏风格
            let containerHeight: CGFloat = 60
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: containerHeight))
            
            // 设置样式
            containerView.backgroundColor = UIColor.systemBackground
            
            // 添加顶部细线条
            let topLine = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 0.5))
            topLine.backgroundColor = UIColor.systemGray4
            containerView.addSubview(topLine)
            
            // 添加底部阴影
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOpacity = 0.1
            containerView.layer.shadowOffset = CGSize(width: 0, height: -1)
            containerView.layer.shadowRadius = 1
            
            // 创建标题标签
            let titleLabel = UILabel(frame: CGRect(x: 15, y: 8, width: 100, height: 20))
            titleLabel.text = "字体大小"
            titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            titleLabel.textColor = .secondaryLabel
            containerView.addSubview(titleLabel)
            
            // 创建显示当前字体大小的标签
            let sizeLabel = UILabel(frame: CGRect(x: 115, y: 8, width: 40, height: 20))
            sizeLabel.text = "\(Int(currentFontSize))pt"
            sizeLabel.textAlignment = .left
            sizeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            sizeLabel.textColor = .secondaryLabel
            containerView.addSubview(sizeLabel)
            
            // 创建字体大小滑块
            let sliderMargin: CGFloat = 15
            let sliderWidth = screenWidth - (sliderMargin * 2) - 60 // 为右侧按钮留出空间
            let slider = UISlider(frame: CGRect(x: sliderMargin, y: 32, width: sliderWidth, height: 20))
            
            // 设置滑块范围和当前值
            slider.minimumValue = 8
            slider.maximumValue = 36
            slider.value = Float(currentFontSize)
            slider.minimumTrackTintColor = .systemBlue
            
            // 创建确认按钮
            let closeButton = UIButton(frame: CGRect(x: screenWidth - 60, y: 26, width: 44, height: 32))
            closeButton.backgroundColor = .systemBlue
            closeButton.layer.cornerRadius = 16
            closeButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
            closeButton.tintColor = .white
            containerView.addSubview(closeButton)
            
            // 添加滑块监听
            slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
            
            // 添加关闭按钮事件
            closeButton.addTarget(self, action: #selector(closeButtonTapped(_:)), for: .touchUpInside)
            
            // 组装视图
            containerView.addSubview(slider)
            
            // 存储引用以便在回调中使用
            self.fontSizeSlider = slider
            self.fontSizeLabel = sizeLabel
            self.fontSizeContainer = containerView
            
            // 计算位置 - 放在键盘工具栏上方
            if let inputAccessoryView = textView.inputAccessoryView {
                // 获取输入附件视图在屏幕中的位置 - 使用iOS 15兼容方式
                let keyWindow: UIWindow?
                if #available(iOS 15.0, *) {
                    keyWindow = UIApplication.shared.connectedScenes
                        .filter { $0.activationState == .foregroundActive }
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows
                        .filter { $0.isKeyWindow }
                        .first
                } else {
                    keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                }
                
                guard let window = keyWindow else { return }
                let accessoryFrame = inputAccessoryView.convert(inputAccessoryView.bounds, to: window)
                
                // 将容器放置在工具栏上方
                let yPos = accessoryFrame.origin.y - containerHeight - 15 - 30 // 考虑工具栏底部填充空间(30)
                containerView.frame.origin = CGPoint(x: 0, y: yPos)
                
                // 添加到window
                window.addSubview(containerView)
                
                // 添加点击手势识别器到textView，用于点击其他地方时关闭滑块
                // 注意：我们不添加到整个窗口，只添加到textView，这样工具栏仍然可以使用
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleOutsideTap(_:)))
                tapGesture.cancelsTouchesInView = false
                tapGesture.delegate = self
                textView.addGestureRecognizer(tapGesture)
                self.fontSizeTapGesture = tapGesture
            }
        }
        
        // 处理窗口其他区域的点击
        @objc func handleOutsideTap(_ gesture: UITapGestureRecognizer) {
            guard fontSizeContainer != nil else { 
                // 如果没有容器，移除手势识别器
                if let tapGesture = fontSizeTapGesture,
                   let textView = textView {
                    textView.removeGestureRecognizer(tapGesture)
                    fontSizeTapGesture = nil
                }
                return 
            }
            
            // 判断点击区域
            if let textView = textView {
                // 获取点击位置
                let location = gesture.location(in: textView)
                
                // 由于手势已经添加到textView，所以这里使用textView的坐标系
                // 如果点击在textView的有效区域内，则关闭字体大小调整器
                if location.y > 0 && location.y < textView.bounds.height - 50 {  // 留出底部工具栏区域的余量
                    closeButtonTapped(nil)
                }
            }
        }
        
        // 关闭按钮点击处理
        @objc func closeButtonTapped(_ button: UIButton?) {
            // 移除字体大小调整视图
            fontSizeContainer?.removeFromSuperview()
            
            // 移除手势识别器
            if let tapGesture = fontSizeTapGesture,
               let textView = textView {
                textView.removeGestureRecognizer(tapGesture)
            }
            
            // 清除引用
            fontSizeContainer = nil
            fontSizeSlider = nil
            fontSizeLabel = nil
            fontSizeTapGesture = nil
        }
        
        // 滑块值改变处理
        @objc func sliderValueChanged(_ slider: UISlider) {
            // 获取当前值，暂时不做吸附，提高滑动流畅度
            let value = slider.value
            
            // 立即更新当前字体大小标签
            fontSizeLabel?.text = "\(Int(value))pt"
            
            // 使用节流技术来改善性能
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(applyFontSize(_:)), object: slider)
            perform(#selector(applyFontSize(_:)), with: slider, afterDelay: 0.05)
        }
        
        // 应用字体大小的实际方法
        @objc func applyFontSize(_ slider: UISlider) {
            // 在这里应用吸附逻辑
            let value = slider.value
            let snapTolerance: Float = 1.0
            let snapPoints: [Float] = [12, 14, 16, 18, 20, 24, 28, 32]
            
            // 检查是否应该吸附到某个点
            var finalValue = value
            for point in snapPoints {
                if abs(value - point) < snapTolerance {
                    finalValue = point
                    
                    // 只有在值真正改变时才更新滑块位置
                    if slider.value != finalValue {
                        slider.setValue(finalValue, animated: true)
                        fontSizeLabel?.text = "\(Int(finalValue))pt"
                    }
                    break
                }
            }
            
            // 更新字体大小
            self.changeTextSize(CGFloat(finalValue))
        }
        
        // 修改文本大小
        private func changeTextSize(_ size: CGFloat) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                // 保存当前状态用于撤销
                let previousAttributedText = textView.attributedText.copy() as! NSAttributedString
                
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                // 注册撤销操作 - 避免 Swift 6 @Sendable 警告
                if let undoManager = textView.undoManager {
                    let undoData = try? previousAttributedText.data(from: NSRange(location: 0, length: previousAttributedText.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                    let undoRange = selectedRange
                    
                    undoManager.registerUndo(withTarget: self) { coordinator in
                        if let data = undoData,
                           let restoredText = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                            coordinator.textView?.attributedText = restoredText
                            coordinator.textView?.selectedRange = undoRange
                            coordinator.parent.attributedText = restoredText
                            coordinator.parent.onCommit(restoredText)
                        }
                    }
                }
                
                mutableAttributedString.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                    if let oldFont = value as? UIFont {
                        let newFont = oldFont.withSize(size)
                        mutableAttributedString.removeAttribute(.font, range: range)
                        mutableAttributedString.addAttribute(.font, value: newFont, range: range)
                    } else {
                        let newFont = UIFont.systemFont(ofSize: size)
                        mutableAttributedString.addAttribute(.font, value: newFont, range: range)
                    }
                }
                
                textView.attributedText = mutableAttributedString
                textView.selectedRange = selectedRange
                
                // 更新绑定的文本并触发保存
                parent.attributedText = mutableAttributedString
                parent.onCommit(mutableAttributedString)
                
                // 更新撤销重做状态
                updateUndoRedoState()
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 显示颜色选择器
        @objc func showColorPicker() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                let colorPicker = UIColorPickerViewController()
                colorPicker.delegate = self
                
                // 设置初始颜色为当前选择的文本颜色（如果有）
                textView.attributedText.enumerateAttribute(.foregroundColor, in: selectedRange, options: []) { value, _, _ in
                    if let color = value as? UIColor {
                        colorPicker.selectedColor = color
                    }
                }
                
                // 临时允许键盘关闭，以便显示颜色选择器
                preventKeyboardDismiss = false
                
                if let viewController = getViewController() {
                    viewController.present(colorPicker, animated: true)
                }
            } else {
                // 如果没有选择文本，确保textView保持焦点
                textView.becomeFirstResponder()
                preventKeyboardDismiss = true
            }
        }
        
        // 添加链接
        @objc func addLink() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                // 临时允许键盘关闭
                preventKeyboardDismiss = false
                
                let alertController = UIAlertController(title: "添加链接", message: nil, preferredStyle: .alert)
                alertController.addTextField { textField in
                    textField.placeholder = "输入URL (https://...)"
                    textField.keyboardType = .URL
                    textField.autocapitalizationType = .none
                    textField.clearButtonMode = .whileEditing
                }
                
                let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
                    // 取消后确保文本视图保持焦点
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.textView?.becomeFirstResponder()
                        self?.preventKeyboardDismiss = true
                    }
                }
                
                let addAction = UIAlertAction(title: "添加", style: .default) { [weak self] _ in
                    guard let linkString = alertController.textFields?.first?.text, !linkString.isEmpty else {
                        // 如果链接为空，保持焦点并返回
                        self?.textView?.becomeFirstResponder()
                        return
                    }
                    
                    guard let textView = self?.textView else { return }
                    let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                    
                    if let url = URL(string: linkString) {
                        mutableAttributedString.addAttribute(.link, value: url, range: selectedRange)
                        textView.attributedText = mutableAttributedString
                        textView.selectedRange = selectedRange
                        
                        // 更新绑定的文本
                        self?.parent.attributedText = mutableAttributedString
                    }
                    
                    // 添加链接后确保文本视图保持焦点
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        textView.becomeFirstResponder()
                    }
                }
                
                alertController.addAction(cancelAction)
                alertController.addAction(addAction)
                
                if let viewController = self.getViewController() {
                    viewController.present(alertController, animated: true)
                }
            } else {
                // 如果没有选中文本，保持焦点并返回
                textView.becomeFirstResponder()
            }
        }
        
        // 显示图片选项菜单
        @objc func showImageOptions() {
            guard let textView = textView else { return }
            
            // 创建并显示选项菜单
            let alertController = UIAlertController(title: "添加图片", message: "选择图片来源", preferredStyle: .actionSheet)
            
            // 临时允许键盘关闭
            preventKeyboardDismiss = false
            
            // 添加选项
            let cameraAction = UIAlertAction(title: "拍照", style: .default) { [weak self] _ in
                self?.handleImageOption(source: .camera)
            }
            
            let photoLibraryAction = UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
                self?.handleImageOption(source: .photoLibrary)
            }
            
            let ocrAction = UIAlertAction(title: "OCR文字识别", style: .default) { [weak self] _ in
                self?.handleImageOption(source: .ocr)
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
                // 取消后确保文本视图保持焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.textView?.becomeFirstResponder()
                    self?.preventKeyboardDismiss = true
                }
            }
            
            alertController.addAction(cameraAction)
            alertController.addAction(photoLibraryAction)
            alertController.addAction(ocrAction)
            alertController.addAction(cancelAction)
            
            // 在iPad上特殊处理
            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = textView
                popoverController.sourceRect = CGRect(x: textView.bounds.midX, y: textView.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            // 显示选项菜单
            if let viewController = self.getViewController() {
                viewController.present(alertController, animated: true)
            }
        }
        
        // 处理图片选项
        private func handleImageOption(source: ImageSource) {
            // 保存当前光标位置
            if let textView = textView {
                // 将光标位置保存到通知的userInfo中
                let userInfo: [String: Any] = [
                    "source": source.rawValue,
                    "cursorPosition": textView.selectedRange.location
                ]
                
                // 使用后台队列发送通知，避免在主线程执行I/O操作
                DispatchQueue.global(qos: .userInitiated).async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RichTextEditorImageRequest"),
                        object: nil,
                        userInfo: userInfo
                    )
                    
                    // 切回主线程设置UI状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.preventKeyboardDismiss = true
                        self.textView?.becomeFirstResponder()
                    }
                }
            }
        }
        
        // 在光标位置插入图片
        func insertImageAtCursor(imageData: Data, cursorPosition: Int) {
            guard let textView = textView else { return }
            
            // 验证图片数据
            guard let originalImage = UIImage(data: imageData) else {
                print("错误: 无法从数据创建图片")
                return
            }
            
            // 使用更保守的屏幕适配计算逻辑
            let screenWidth = UIScreen.main.bounds.width
            let maxWidth = min(screenWidth * 0.4, 160.0) // 更小：40%屏幕宽度，最大160px
            let minWidth: CGFloat = 100 // 最小宽度
            
            // 确保图片宽度在合理范围内
            let targetWidth = min(max(maxWidth, minWidth), originalImage.size.width)
            let scale = targetWidth / originalImage.size.width
            let targetSize = CGSize(
                width: targetWidth,
                height: originalImage.size.height * scale
            )
            
            print("=== 图片尺寸调试信息 ===")
            print("屏幕宽度: \(screenWidth)")
            print("计算最大宽度: \(maxWidth)")
            print("原始图片尺寸: \(originalImage.size)")
            print("目标尺寸: \(targetSize)")
            print("缩放比例: \(scale)")
            
            // 创建高质量的适配尺寸图片
            let adaptedImage = createScreenAdaptedImage(originalImage, targetSize: targetSize)
            
            // 创建图片附件
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = adaptedImage
            imageAttachment.bounds = CGRect(origin: .zero, size: targetSize)
            
            // 创建包含图片的属性字符串
            let imageString = NSAttributedString(attachment: imageAttachment)
            
            // 在图片前后添加换行符
            let mutableImageString = NSMutableAttributedString()
            mutableImageString.append(NSAttributedString(string: "\n"))
            mutableImageString.append(imageString)
            mutableImageString.append(NSAttributedString(string: "\n"))
            
            // 设置默认字体
            let defaultFont = UIFont.preferredFont(forTextStyle: .body).withSize(18)
            mutableImageString.addAttribute(.font, value: defaultFont, range: NSRange(location: 0, length: mutableImageString.length))
            
            // 获取当前富文本内容
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 确保插入位置有效
            let insertPosition = min(cursorPosition, mutableAttributedString.length)
            
            // 在指定位置插入图片
            mutableAttributedString.insert(mutableImageString, at: insertPosition)
            
            // 更新文本视图
            textView.attributedText = mutableAttributedString
            
            // 设置光标位置到图片后面
            let newCursorPosition = insertPosition + mutableImageString.length
            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
            
            // 更新绑定的文本并触发保存
            parent.attributedText = mutableAttributedString
            parent.onCommit(mutableAttributedString)
            
            print("图片已插入，最终尺寸: \(targetSize)")
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 创建屏幕适配的高质量图片
        private func createScreenAdaptedImage(_ originalImage: UIImage, targetSize: CGSize) -> UIImage {
            // 使用UIGraphicsImageRenderer创建高质量图片
            let format = UIGraphicsImageRendererFormat()
            format.scale = min(UIScreen.main.scale, 2.0) // 限制scale以平衡质量和性能
            format.opaque = false // 支持透明背景
            format.preferredRange = .standard
            
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            let adaptedImage = renderer.image { context in
                // 设置高质量插值
                context.cgContext.interpolationQuality = .high
                context.cgContext.setShouldAntialias(true)
                context.cgContext.setAllowsAntialiasing(true)
                
                // 绘制图片到目标尺寸
                originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
            return adaptedImage
        }
        
        // 切换文本属性
        private func toggleTextAttribute(_ attributeName: NSAttributedString.Key, value: Any) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                // 保存当前状态用于撤销
                let previousAttributedText = textView.attributedText.copy() as! NSAttributedString
                
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                // 检查是否已有该属性
                var hasAttribute = false
                mutableAttributedString.enumerateAttribute(attributeName, in: selectedRange, options: []) { value, _, _ in
                    if value != nil {
                        hasAttribute = true
                    }
                }
                
                // 注册撤销操作 - 避免 Swift 6 @Sendable 警告
                if let undoManager = textView.undoManager {
                    let undoData = try? previousAttributedText.data(from: NSRange(location: 0, length: previousAttributedText.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                    let undoRange = selectedRange
                    
                    undoManager.registerUndo(withTarget: self) { coordinator in
                        if let data = undoData,
                           let restoredText = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                            coordinator.textView?.attributedText = restoredText
                            coordinator.textView?.selectedRange = undoRange
                            coordinator.parent.attributedText = restoredText
                            coordinator.parent.onCommit(restoredText)
                        }
                    }
                }
                
                if hasAttribute {
                    // 如果已有属性，则移除
                    mutableAttributedString.removeAttribute(attributeName, range: selectedRange)
                } else {
                    // 如果没有属性，则添加
                    mutableAttributedString.addAttribute(attributeName, value: value, range: selectedRange)
                }
                
                textView.attributedText = mutableAttributedString
                textView.selectedRange = selectedRange
                
                // 更新绑定的文本并触发保存
                parent.attributedText = mutableAttributedString
                parent.onCommit(mutableAttributedString)
                
                // 更新撤销重做状态
                updateUndoRedoState()
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 添加对点击手势的处理
        @objc func handleTextViewTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            
            // 更新焦点状态
            DispatchQueue.main.async {
                self.parent.focus = true
            }
            
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
            
            // 确保富文本编辑器能够响应点击
            preventKeyboardDismiss = true
        }
        
        // 获取当前视图控制器
        private func getViewController() -> UIViewController? {
            // 由于UIKit操作必须在主线程进行，这里的UI访问是安全的
            // 我们只是获取视图控制器引用，没有进行实际的I/O操作
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = scene.windows.first?.rootViewController else {
                return nil
            }
            
            var currentController = rootViewController
            while let presentedController = currentController.presentedViewController {
                currentController = presentedController
            }
            
            return currentController
        }
    }
}

// 使UIColorPickerViewControllerDelegate与Coordinator协同工作
extension RichTextEditor.Coordinator: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let color = viewController.selectedColor
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.addAttribute(.foregroundColor, value: color, range: selectedRange)
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
            
            // 更新绑定的文本
            parent.attributedText = mutableAttributedString
            
            // 确保关闭颜色选择器后文本视图保持焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                textView.becomeFirstResponder()
            }
        }
    }
    
    // 颜色选择器将要消失时
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        // 颜色已经被选择但控制器还未消失
        // 我们不需要在这里处理任何事情，因为dismissal会触发didFinish
    }
}

// 手势识别器代理实现
extension RichTextEditor.Coordinator: UIGestureRecognizerDelegate {
    // 允许多个手势识别器同时工作
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // 确保字体滑块的点击不会干扰文本编辑
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果点击发生在字体大小容器上，忽略此点击
        if let containerView = fontSizeContainer,
           touch.view?.isDescendant(of: containerView) == true {
            return false
        }
        return true
    }
}

// 图片操作的来源枚举
enum ImageSource: Int {
    case camera = 0
    case photoLibrary = 1
    case ocr = 2
}

// 添加NSAttributedString扩展，用于比较两个NSAttributedString
extension NSAttributedString {
    static func areEqual(_ lhs: NSAttributedString?, _ rhs: NSAttributedString?) -> Bool {
        // 如果两者都是nil或者是同一个对象，它们是相等的
        if lhs === rhs { return true }
        // 如果其中一个是nil，而另一个不是，它们不相等
        if lhs == nil || rhs == nil { return false }
        
        // 如果长度不同，它们不相等
        if lhs!.length != rhs!.length { return false }
        
        // 如果字符串内容不同，它们不相等
        if lhs!.string != rhs!.string { return false }
        
        // 简单地比较文本内容，对于编辑器的大多数情况来说已经足够
        // 为了性能，我们不比较详细的属性
        return true
    }
} 