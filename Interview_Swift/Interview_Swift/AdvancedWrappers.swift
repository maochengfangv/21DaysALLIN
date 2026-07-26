//
//  AdvancedWrappers.swift
//  Interview_Swift
//
//  Created by maochengfang on 2026/7/26.
//

import Foundation
import Combine

/// 一个模拟 @Published 底层原理的高级属性包装器
/// 核心点：利用 _enclosingInstance 静态下标获取宿主引用，并手动触发 ObservableObject 的通知

@propertyWrapper
public struct Observed<Value> {
    private var value: Value
    
    public init(wrappedValue : Value) {
        self.value = wrappedValue
    }
    
    /// 编译器黑魔法：感知宿主实例的静态下标
    /// - Parameters:
    /// - instance: 宿主对象实例（即持有该属性的 class 实例）
    /// - wrappedKeyPath: 属性本身的 KeyPath
    /// - storageKeyPath: 包装器自身的 KeyPath
    
    public static subscript<OutSelf: ObservableObject>(
        _enclosingInstance instance: OutSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OutSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<OutSelf, Observed<Value>>
    ) -> Value where OutSelf.ObjectWillChangePublisher == ObservableObjectPublisher {
        get {
            return instance[keyPath: storageKeyPath].value
        }
        
        set {
            print("【Observed 拦截】宿主 [\(type(of: instance))] 的属性即将变更为: \(newValue)")
            //  关键逻辑 在赋值前 手动触发宿主的objectWillChange
            // 这正是Swift UI 你够在数值变化前准备好UI刷新的秘密
            instance.objectWillChange.send()
            
            // 执行真正的赋值
            instance[keyPath: storageKeyPath].value = newValue
        }
        
    }
    
    /// 注意：当定义了上面的 static subscript 后，这个 wrappedValue 的 get/set 就不会被调用了。
    /// 但为了符合 @propertyWrapper 协议，仍需声明。
    public var wrappedValue: Value {
        get { fatalError("Should use static subscript") }
        set { fatalError("Should use static subscript") }
    }
}
