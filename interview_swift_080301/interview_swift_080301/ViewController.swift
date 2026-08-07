//
//  ViewController.swift
//  interview_swift_080301
//
//  Created by maochengfang on 2026/8/3.
//

import UIKit
import Foundation

/* 直接派发
    编译期就明确调用目标 性能最好 场景: struct final class private static
    这类方法通常会被编译期直接确定目标地址
    不需要运行时再查表 调用成本更低
 */

struct Counter {
    func plus() {
        print("plus")
    }
}

final class Animal {
    
    func eat() {
        print("eat")
    }
}

/* 虚表派发
  类的集成 多态场景最典型
 */

class Father {
    func work() {
        print("father work")
    }
}

class Son: Father {
    override func work() {
        print("son work")
    }
}

//协议见证表派发
protocol Flyable {
    func fly()
}

struct Bird:Flyable {
    func fly() {
        print("bird fly")
    }
}

//OC消息派发 需要动态能力会出现
class Student: NSObject {
    //@objc dynamic 会强制走OC消息派发 常见于KVO 动态低缓 运行时特征
    @objc dynamic func study() {
        print("Study")
    }
}

// 协议扩展为什么没有重写成功

protocol TestProtocol {
    func say()
}

extension TestProtocol {
    func say() {
        print("protocol extension say")
    }
    
    func run() {
        print("protocol extension run")
    }
}

struct User: TestProtocol {
    func say() {
        print("user say")
    }
    
    func run() {
        print("user run")
    }
}


final class Storage {
    var value: String
    
    init(value: String) {
        self.value = value
    }
}

struct MyString {
    private var storage: Storage
    init(_ value: String) {
        self.storage = Storage(value: value)
    }
    
    var value: String {
        storage.value
    }
    //COW 用共享底层存储 去实现值类型独立语义
    mutating func append(_ text: String){
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(value: storage.value)
        }
        storage.value += text
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        directDispatch()
//        VTDispatch()
//        witnessDispath()
//        dynamicDispath()
//        testProctocl()
        testCustomStr()
    }

    private func testCustomStr() {
        
        var a = MyString("Hello")
        var b = a
        b.append("World")
        print(a.value)
        print(b.value)
    }
    
    private func directDispatch() {
        let c = Counter()
        c.plus()
        let a = Animal()
        a.eat()
    }
    
    private func VTDispatch() {
        /*
            变量静态类型时Father 实际调用对象 Son,运行时需要根据真实对象找到最终实现，一般会走类的虚表派发
           */
        let obj: Father = Son()
        obj.work()
    }
    
    private func witnessDispath() {
        let bird = Bird()
        
        startFly(bird)
        /*
           startFly 只知道传图的是协议Flyable
           具体是bird还是别的类型 需要通过协议见证表定位实现
           */
    }
    
    private func startFly(_ value: Flyable){
        value.fly()
    }

    
    private func dynamicDispath() {
        let s =  Student()
        s.study()
    }
    
    private func testProctocl() {
        let u = User()
        u.say() //user say
        u.run() //user run
        
        let p: TestProtocol = User()
        p.say() //user say say()是协议要求的方法 调用时会参与协议见证表分发
        p.run() //protocol extension run run() 不是协议要求的方法，只是扩展里额外提供默认实现 当变量类型是 TestProtocol 时， run() 不会走到 User 的那个同名方法，而是静态绑定到扩展实现
        /*
            swift协议扩展并不等价于真正的动态分发重写，
            协议要求的方法和扩展附加的方法 派发语义不一样
           */
    }
}

