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

protocol Animal {
    func speak()
}


struct Dog: Animal { func speak() {
    print("🐶 汪！")
} }

struct Cat: Animal {
    func speak() {
        print("🐱 喵！")
    }
}


protocol Container<Item> {
    associatedtype Item
    var value: Item { get }
}

struct IntContainer: Container { var value: Int = 42 }
struct StringContainer: Container { var value: String = "Hello" }

class ViewController: UIViewController {

    private var VM = UserProfileViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("\n--- 开始测试 ---")
//        testObservedWrapper()
//        testAnySomeFunc()
//        testAsssociateType()
        testAnyContainers()
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
    
    private func testAnySomeFunc () {
        
        // MARK: - 1. some (不透明类型)
        // 承诺返回“某种”确定的动物，一旦确定就不能更改

        func getOneAnimal() -> some Animal {
            return Dog()
        }

        let animal1 = getOneAnimal()
        let animal2 = getOneAnimal()

        // MARK: - 2. any (类型擦除/存在类型)
        // 这是一个容器，可以装任何满足 Animal 协议的对象
        func getAnyAnimal(isDog: Bool) -> any Animal {
            return isDog ? Dog(): Cat()
        }


        var anyAnimal: any Animal = Dog()
        print("--- anyAnimal test1 ---")
        anyAnimal.speak()
        
        anyAnimal = Cat()
        print("--- anyAnimal test2 ---")
        anyAnimal.speak()
        // MARK: - 3. 核心区别演示：异构数组

        let animals: [any Animal] = [Dog(),Cat(),Dog()]

        print("--- some test ---")
        animal1.speak()

        print("\n --- any test ---")

        for a in animals {
            a.speak()
        }
    }
    
    func makeSomeContainer() -> some Container<Int> {
        return IntContainer()
    }
    
    func testAsssociateType() {
        let c1 = makeSomeContainer()
        let c2 = makeSomeContainer()
        
        // 现在可以相加了，因为编译器知道 c1.value 和 c2.value 都是同一种且满足 Numeric 的类型
        let sum = c1.value + c2.value
        print("some Container sum: \(sum)")
        
        let a1 = makeAnyContainer(isInt: true)
         let val = a1.value // 仍然报错，因为 any Container 抹除了具体类型
        let a2 = makeAnyContainer(isInt: false)
        
        print("any Container 1: \(a1.value)")
        print("any Container val: \(val)")
        print("any Container 2: \(a2.value)")
        
    }
    
    func makeAnyContainer(isInt: Bool) -> any Container {
        return isInt ? IntContainer() : StringContainer()
    }

    func processContainer<C: Container>(_ container: C) {
        print("处理容器，值类型是: \(type(of: container.value))，值是: \(container.value)")
    }
    
    func testAnyContainers() {
        let containers: [any Container] = [IntContainer(),StringContainer()]
        for c in containers {
            processContainer(c)
        }
    }
}

