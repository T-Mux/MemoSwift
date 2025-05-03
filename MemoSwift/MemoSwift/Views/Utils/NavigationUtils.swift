//
//  NavigationUtils.swift
//  MemoSwift
//
//  Created by T-Mux on 6/11/25.
//

import SwiftUI
import UIKit

// 添加环境值键，用于在组件间共享文件夹操作状态
struct FolderActionKey: EnvironmentKey {
    static let defaultValue: FolderAction = FolderAction()
}

// 标准动画设置
extension Animation {
    static let standardNavigation = Animation.easeInOut(duration: 0.35)
    
    // 更接近UIKit导航控制器的动画
    static let navigationPush = Animation.interpolatingSpring(mass: 1.0, stiffness: 100, damping: 20, initialVelocity: 0)
    static let navigationPop = Animation.interpolatingSpring(mass: 1.0, stiffness: 100, damping: 20, initialVelocity: 0)
}

// 自定义导航过渡动画修饰符 - 更准确地模拟UIKit导航控制器的效果
struct NavigationTransition: ViewModifier {
    let isPresenting: Bool
    
    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .offset(x: isPresenting ? UIScreen.main.bounds.width : -UIScreen.main.bounds.width),
                    removal: .offset(x: isPresenting ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width)
                )
            )
    }
}

extension View {
    func navigationTransition(isPresenting: Bool) -> some View {
        self.modifier(NavigationTransition(isPresenting: isPresenting))
    }
}

extension EnvironmentValues {
    var folderAction: FolderAction {
        get { self[FolderActionKey.self] }
        set { self[FolderActionKey.self] = newValue }
    }
}

// 文件夹操作状态类
class FolderAction: ObservableObject {
    @Published var folderToRename: Folder? = nil
    @Published var renamedFolderName: String = ""
    @Published var showRenameDialog: Bool = false
    
    @Published var folderToMove: Folder? = nil
    @Published var targetFolders: [Folder] = []
    @Published var selectedTargetFolder: Folder? = nil
    @Published var showMoveDialog: Bool = false
    
    @Published var folderToDelete: Folder? = nil
    @Published var showDeleteConfirmation: Bool = false
    
    func setupRename(folder: Folder) {
        self.folderToRename = folder
        self.renamedFolderName = folder.name
        self.showRenameDialog = true
    }
    
    func setupMove(folder: Folder, availableTargets: [Folder]) {
        self.folderToMove = folder
        self.targetFolders = availableTargets
        self.selectedTargetFolder = nil
        self.showMoveDialog = true
    }
    
    func setupDelete(folder: Folder) {
        self.folderToDelete = folder
        self.showDeleteConfirmation = true
    }
} 