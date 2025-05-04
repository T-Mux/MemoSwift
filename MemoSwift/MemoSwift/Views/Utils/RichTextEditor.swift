import SwiftUI
import UIKit

// 富文本编辑器组件，使用UIKit的UITextView桥接到SwiftUI
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var onCommit: (NSAttributedString) -> Void
    @Binding var focus: Bool
    
    // 初始化函数，添加默认参数
    init(attributedText: Binding<NSAttributedString>, focus: Binding<Bool> = .constant(false), onCommit: @escaping (NSAttributedString) -> Void) {
        self._attributedText = attributedText
        self._focus = focus
        self.onCommit = onCommit
    }
    
    // 创建UITextView
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.autocapitalizationType = .sentences
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        
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
        // 避免更新时光标位置重置
        let selectedRange = textView.selectedRange
        
        textView.attributedText = attributedText
        
        // 恢复光标位置
        if selectedRange.location < attributedText.length {
            textView.selectedRange = selectedRange
        }
        
        // 强制保持键盘焦点，除非明确设置focus为false
        // 这确保了只有当调用doneEditing时才会失去焦点
        if focus && !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !focus && textView.isFirstResponder {
            // 只有当focus明确设置为false时才会关闭键盘
            // 这通常只会在doneEditing方法中发生
            textView.resignFirstResponder()
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
        var preventKeyboardDismiss = false  // 防止工具栏按钮导致键盘关闭
        
        // 字体大小相关视图引用
        var fontSizeContainer: UIView?
        var fontSizeSlider: UISlider?
        var fontSizeLabel: UILabel?
        var fontSizeTapGesture: UITapGestureRecognizer?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        // 文本改变时更新绑定值
        func textViewDidChange(_ textView: UITextView) {
            if let attributedText = textView.attributedText {
                parent.attributedText = attributedText
            }
            self.textView = textView
        }
        
        // 阻止编辑自动结束，除非是主动调用resignFirstResponder
        func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
            // 如果设置了阻止键盘消失，并且不是来自Done按钮的请求，则阻止键盘消失
            if preventKeyboardDismiss {
                // 保持输入焦点
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                }
                // 但仍然返回true允许其他操作发生
                return true
            }
            return true
        }
        
        // 当编辑结束时（如按下Done按钮后），确保保存内容
        func textViewDidEndEditing(_ textView: UITextView) {
            // 如果是通过Done按钮结束的编辑，那么在doneEditing方法中已经调用了onCommit
            // 这里不需要再次调用，避免重复保存
        }
        
        // 完成编辑 - 只有点击"Done"按钮才会执行这个方法
        @objc func doneEditing() {
            // 关闭阻止键盘消失的标志，允许键盘隐藏
            preventKeyboardDismiss = false
            
            // 隐藏键盘和工具栏
            textView?.resignFirstResponder()
            
            // 确保提交更新的内容
            parent.onCommit(parent.attributedText)
            
            // 关闭焦点状态
            parent.focus = false
        }
        
        // 切换粗体
        @objc func toggleBold() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
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
                
                // 更新绑定的文本
                parent.attributedText = mutableAttributedString
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 切换斜体
        @objc func toggleItalic() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
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
                
                // 更新绑定的文本
                parent.attributedText = mutableAttributedString
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
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
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
                
                // 更新绑定的文本
                parent.attributedText = mutableAttributedString
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 显示颜色选择器
        @objc func showColorPicker() {
            guard let textView = textView else { return }
            
            // 创建颜色选择器
            let colorPicker = UIColorPickerViewController()
            colorPicker.selectedColor = textView.textColor ?? .black
            colorPicker.delegate = self
            
            // 获取当前视图控制器并显示颜色选择器
            if let viewController = getViewController() {
                viewController.present(colorPicker, animated: true)
            }
        }
        
        // 添加链接
        @objc func addLink() {
            guard let textView = textView else { return }
            guard textView.selectedRange.length > 0 else {
                // 如果没有选中文本，保持焦点并返回
                textView.becomeFirstResponder()
                return
            }
            
            let alertController = UIAlertController(title: "添加链接", message: nil, preferredStyle: .alert)
            
            alertController.addTextField { textField in
                textField.placeholder = "https://example.com"
                textField.keyboardType = .URL
                textField.autocapitalizationType = .none
                textField.autocorrectionType = .no
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
                // 取消后确保文本视图保持焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.textView?.becomeFirstResponder()
                }
            }
            
            let addAction = UIAlertAction(title: "添加", style: .default) { [weak self] _ in
                guard let linkString = alertController.textFields?.first?.text, !linkString.isEmpty else {
                    // 如果链接为空，保持焦点并返回
                    self?.textView?.becomeFirstResponder()
                    return
                }
                
                guard let textView = self?.textView else { return }
                let selectedRange = textView.selectedRange
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
            
            if let viewController = getViewController() {
                viewController.present(alertController, animated: true)
            }
        }
        
        // 显示图片选项菜单
        @objc func showImageOptions() {
            guard let textView = textView else { return }
            
            // 创建并显示选项菜单
            let alertController = UIAlertController(title: "添加图片", message: "选择图片来源", preferredStyle: .actionSheet)
            
            // 添加选项
            let cameraAction = UIAlertAction(title: "拍照", style: .default) { [weak self] _ in
                self?.handleImageOption(source: .camera)
                // 在图片处理后，焦点会在NoteEditorView中通过通知系统处理，这里不需要特别处理
            }
            
            let photoLibraryAction = UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
                self?.handleImageOption(source: .photoLibrary)
                // 在图片处理后，焦点会在NoteEditorView中通过通知系统处理，这里不需要特别处理
            }
            
            let ocrAction = UIAlertAction(title: "OCR文字识别", style: .default) { [weak self] _ in
                self?.handleImageOption(source: .ocr)
                // 在OCR处理后，焦点会在NoteEditorView中通过通知系统处理，这里不需要特别处理
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
                // 取消后确保文本视图保持焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.textView?.becomeFirstResponder()
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
            if let viewController = getViewController() {
                viewController.present(alertController, animated: true)
            }
        }
        
        // 处理图片选项
        private func handleImageOption(source: ImageSource) {
            // 发送通知，让外部处理图片选择或OCR
            let userInfo: [String: Any] = ["source": source]
            NotificationCenter.default.post(
                name: NSNotification.Name("RichTextEditorImageRequest"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        // 切换文本属性
        private func toggleTextAttribute(_ attributeName: NSAttributedString.Key, value: Any) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            
            if selectedRange.length > 0 {
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                // 检查是否已有该属性
                var hasAttribute = false
                mutableAttributedString.enumerateAttribute(attributeName, in: selectedRange, options: []) { value, _, _ in
                    if value != nil {
                        hasAttribute = true
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
                
                // 更新绑定的文本
                parent.attributedText = mutableAttributedString
            }
            
            // 确保文本视图保持焦点
            textView.becomeFirstResponder()
        }
        
        // 添加对点击手势的处理
        @objc func handleTextViewTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            if !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }
        
        // 获取当前视图控制器
        private func getViewController() -> UIViewController? {
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
enum ImageSource {
    case camera
    case photoLibrary
    case ocr
} 