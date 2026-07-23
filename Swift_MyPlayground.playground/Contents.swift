import UIKit
import Foundation
var greeting = "Hello, playground"

@propertyWrapper
struct DemoWrapper<T> {
    private var value: T
    //对外读写的值
    var wrappedValue: T {
        get { value }
        set {
            //统一拦截逻辑
            print("复制拦截: \(newValue)")
            value = newValue
        }
    }
    init(wrappedValue: T) { // Property Wrapper 的标准初始化方法
        self.value = wrappedValue
    }
    var projectedValue: String {
        "投影数据"
    }
}

// 将使用 Property Wrapper 的代码封装在一个 struct 中
struct MyContainer {
    @DemoWrapper var name: String = "张三" // 声明时提供默认值
    
    mutating func demonstrate() {
        print("初始值: \(name)")
        name = "李四" // 触发 wrappedValue 的 set
        print("修改后: \(name)")
        print("投影值: \($name)") // 访问 projectedValue
    }
}

var container = MyContainer()
container.demonstrate()

