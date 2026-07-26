//
//  ViewController.swift
//  Interview_Swift
//
//  Created by maochengfang on 2026/7/23.
//

import UIKit
import Combine

// 1. 定义一个符合 ObservableObject 的 ViewModel
class UserProfileViewModel: ObservableObject {
    @Observed var nickName: String = "初始昵称"
}

class ViewController: UIViewController {

    private var VM = UserProfileViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("\n--- 开始测试 ---")
        testObservedWrapper()
    }

    private func testObservedWrapper() {
        
        print("\n--- 开始测试 @Observed (模拟 @Published 原理) ---")
        
        // 2. 订阅宿主的 objectWillChange (这通常是 SwiftUI 内部做的事情)
        VM.objectWillChange.sink { _ in
            print("【Combine 通知】监听到 viewModel 即将发生改变！")
        }.store(in: &cancellables)
        
        // 3. 触发修改
        print("执行修改前...")
        VM.nickName = "高级 iOS 架构师"
        print("执行修改后，当前值: \(VM.nickName)")
    }
}

