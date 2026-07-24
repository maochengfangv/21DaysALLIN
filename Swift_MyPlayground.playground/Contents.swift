import UIKit
import Foundation
var greeting = "Hello, playground"

@propertyWrapper
struct DemoWrapper<T> {
    private var value: T
    private var _modificationCount: Int = 0 // 内部状态：记录 wrappedValue 被修改的次数

    // 对外读写的值
    var wrappedValue: T {
        get { value }
        set {
            // 统一拦截逻辑
            print("WrappedValue set: \(newValue)")
            value = newValue
            _modificationCount += 1 // 每次修改 wrappedValue，内部状态更新
        }
    }
    
    init(wrappedValue: T) { // Property Wrapper 的标准初始化方法
        self.value = wrappedValue
    }
    
    // projectedValue 用于暴露内部状态
    var projectedValue: Int {
        return _modificationCount // 暴露修改次数
    }
    
    // 提供一个控制接口：重置修改次数
    mutating func resetModificationCount() {
        _modificationCount = 0
        print("DemoWrapper: Modification count has been reset!")
    }
}

@propertyWrapper
struct LimitNum {
    
    private var num: Int
    let max: Int
    
    var wrappedValue: Int {
        get { num }
        set { num = min(newValue,  max) }
    }
    init(wrappedValue: Int, max: Int) {
        self.num = min(wrappedValue,max)
        self.max = max
    }
    
    var projectedValue: String {
        "Range: [\(max)]"
    }
}


@propertyWrapper
struct UserDefault<T: Sendable> : Sendable{
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            // 从 UserDefaults 读取，如果不存在则返回默认值
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            print("[UserDefault] Saved '\(newValue)' to key '\(key)'")
        }
    }
    
    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
        print("[UserDefault] Initialized for key '\(key)' with defaultValue '\(defaultValue)'")
    }
    
    var projectedValue: UserDefaults {
        return UserDefaults.standard
    }
}

// MARK: - 4. MainThread (主线程 UI 自动切换)
@propertyWrapper
final class MainThread<T: Sendable>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()
    
    var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            if Thread.isMainThread {
                lock.lock()
                _value = newValue
                lock.unlock()
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    lock.lock()
                    self._value = newValue
                    lock.unlock()
                }
            }
        }
    }
    init(wrappedValue: T) {
        _value = wrappedValue
    }
    
    var projectedValue: () -> T {
           return {
               if Thread.isMainThread {
                   return self.wrappedValue
               } else {
                   // 警告：在非主线程同步获取可能会导致死锁，这里仅作演示
                   print("[MainThread] Warning: Synchronously getting value from non-main thread.")
                   return DispatchQueue.main.sync { self.wrappedValue }
               }
           }
       }
}



// 将使用 Property Wrapper 的代码封装在一个 struct 中
@MainActor
class MyContainer{
    
//    @LimitNum(max:100) var count = 200
    @UserDefault(key: "app_theme", defaultValue: "light") var appTheme: String
    @UserDefault(key: "user_agreed_terms", defaultValue: false) var agreedTerms: Bool
    // UI控件绑定，赋值自动切主线程
    @MainThread var uiLabelText: String = ""
    
     func demodd() {
//        print(count)
//        print($count)
        // --- UserDefault 演示 ---
//        print("\n--- UserDefault (App Theme & Agreed Terms) ---")
//        print("Current app theme: \(appTheme)")
//        print("User agreed terms: \(agreedTerms)")
//        
//        appTheme = "dark" // 写入 UserDefaults
//        agreedTerms = true // 写入 UserDefaults
//        
//        print("New app theme: \(appTheme)") // 从 UserDefaults 读取
//        print("New user agreed terms: \(agreedTerms)")
//        
//        // 通过 projectedValue 访问 UserDefaults 实例，并清除数据
//        print("Clearing UserDefault for app_theme...")
//        $appTheme.removeObject(forKey: "app_theme")
//        print("App theme after clearing: \(appTheme)") // 应该恢复为默认值 "light"
        
        // --- MainThread 演示 ---
        print("\n--- MainThread (UI 线程安全) ---")
        uiLabelText = "主线程设置的文本"
        print("初始 UI 文本: \(uiLabelText)")
       
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            // 使用 Task 异步切回主线程执行环境，确保符合 Swift 6 隔离要求
            Task { @MainActor in
                // 1. 通过投影值获取 (此时已在主线程)
                let currentUIText = self.$uiLabelText()
                print("Current UI text (via projectedValue): \(currentUIText)")
                
                // 2. 直接赋值 (此时已在主线程)
                self.uiLabelText = "后台线程通过 Task 设置的文本"
                print("UI Text updated via Task on MainActor")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("最终 UI文本： \(self.uiLabelText)")
        }
    }
    
//    @DemoWrapper var name: String = "张三" // 声明时提供默认值
    
//    mutating func demonstrate() {
//        print("\n--- 演示 Property Wrapper 内部状态与控制接口 ---")
//        
//        print("初始值: \(name)") // 访问 wrappedValue
//        print("初始修改次数 (projectedValue): \($name)") // 访问 projectedValue (内部状态)
//        
//        name = "李四" // 触发 wrappedValue 的 set，修改次数 +1
//        print("修改后: \(name)")
//        print("修改后修改次数 (projectedValue): \($name)") // 再次访问 projectedValue
//        
//        name = "王五" // 再次修改，修改次数 +1
//        print("再次修改后: \(name)")
//        print("再次修改后修改次数 (projectedValue): \($name)")
//        
//        // 通过访问 Property Wrapper 实例本身来调用其控制接口
//        // _name 是 Property Wrapper 实例的名称
//        print("\n--- 调用控制接口 ---")
//        _name.resetModificationCount() // 调用 DemoWrapper 上的方法来重置内部状态
//        
//        print("重置后修改次数 (projectedValue): \($name)") // 验证重置结果
//        
//        print("\n--- 再次修改验证 ---")
//        name = "赵六"
//        print("再次修改后: \(name)")
//        print("最终修改次数 (projectedValue): \($name)")
//    }
}

var container = MyContainer() // MyContainer 需要是 var，因为 demonstrate 是 mutating
container.demodd()
//container.demonstrate()

// 顶层代码中直接访问 wrappedValue 是可以的
// print("顶层访问 name: \(container.name)")

// 但在顶层代码中直接访问 $name 仍然会报错 "Cannot find '$name' in scope"
// 因为 $name 只能在属性所属的类型内部访问
// print("顶层访问 $name: \(container.$name)") // 这行会报错
