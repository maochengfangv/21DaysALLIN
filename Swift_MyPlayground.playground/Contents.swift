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

// 将使用 Property Wrapper 的代码封装在一个 struct 中
struct MyContainer {
    @DemoWrapper var name: String = "张三" // 声明时提供默认值
    
    mutating func demonstrate() {
        print("\n--- 演示 Property Wrapper 内部状态与控制接口 ---")
        
        print("初始值: \(name)") // 访问 wrappedValue
        print("初始修改次数 (projectedValue): \($name)") // 访问 projectedValue (内部状态)
        
        name = "李四" // 触发 wrappedValue 的 set，修改次数 +1
        print("修改后: \(name)")
        print("修改后修改次数 (projectedValue): \($name)") // 再次访问 projectedValue
        
        name = "王五" // 再次修改，修改次数 +1
        print("再次修改后: \(name)")
        print("再次修改后修改次数 (projectedValue): \($name)")
        
        // 通过访问 Property Wrapper 实例本身来调用其控制接口
        // _name 是 Property Wrapper 实例的名称
        print("\n--- 调用控制接口 ---")
        _name.resetModificationCount() // 调用 DemoWrapper 上的方法来重置内部状态
        
        print("重置后修改次数 (projectedValue): \($name)") // 验证重置结果
        
        print("\n--- 再次修改验证 ---")
        name = "赵六"
        print("再次修改后: \(name)")
        print("最终修改次数 (projectedValue): \($name)")
    }
}

var container = MyContainer() // MyContainer 需要是 var，因为 demonstrate 是 mutating
container.demonstrate()

// 顶层代码中直接访问 wrappedValue 是可以的
// print("顶层访问 name: \(container.name)")

// 但在顶层代码中直接访问 $name 仍然会报错 "Cannot find '$name' in scope"
// 因为 $name 只能在属性所属的类型内部访问
// print("顶层访问 $name: \(container.$name)") // 这行会报错
