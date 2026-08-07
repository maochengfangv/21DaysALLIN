import UIKit
import Foundation

var greeting = "Hello, playground"

//class Person {
//    func sayHello() {
//        print("hello")
//    }
//}
///* *
// * 实例方法调用
// * 调用者是对象实例 语法上通过实例.方法名()触发
// * */
//let p = Person()
//p.sayHello()
//
//class MathTool {
//    // static 不能被子类重写
//    static func add(_ a: Int, _ b: Int) -> Int {
//        a + b
//    }
//    //class 可以被子类重写
//    class func desc() {
//        print("hello")
//    }
//}
///*
// 通过类型本身调用 而不是实例
// */
//let result = MathTool.add(1, 2)
//MathTool.desc()
//print("\(result)")
//
////构造器本质山也是一种特殊的方法调用入口
//class Car {
//    let name:String
//    
//    init(name: String) {
//        self.name = name
//    }
//}
//
//let car = Car(name: "Geely")
//
//print(car.name)
//
//// 方法当作函数来调用 方法可以作为函数值传递
//// swift 支持把方法引用出来 当作闭包和函数值调用。常见于函数式编程场景
//class Greeter {
//    func greet(name:String) {
//        print("Hello, \(name)")
//    }
//}
//
//let greeter = Greeter()
//let fn = greeter.greet
//fn("World")

//可选调用链 只有对象不为nil 时才会真正发起方法调用
class Dog {
    func bark() {
       print("wang")
    }
}

//var dog: Dog? = Dog()
//dog?.bark()
//
//dog = nil
//dog?.bark()

//协议类型调用 它能引出 witness table

protocol Runner {
    func run()
}

struct Man: Runner {
    func run() {
        print("man run")
    }
}

let runner: Runner = Man()
// 底层时通过协议见证表找到真正实现
runner.run()

class Downloader {
    func start(completion: @escaping () -> Void) {
        completion
    }
}

//  闭包回调间接调用方法
class Page {
    func reload() {
        print("reload page")
    }
    func test() {
        let d = Downloader()
        d.start { [weak self] in
            self?.reload()
        }
    }
}

let page = Page()

page.test()

//直接派发

//虚表派发

//协议见证表派发

//OC消息派发
