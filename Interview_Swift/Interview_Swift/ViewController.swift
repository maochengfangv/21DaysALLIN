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

// MARK: - Actor & MainActor 演示
actor BankAccount {
    private var balance: Double = 0
    
    // 模拟一个耗时的异步汇率检查
    func fetchExchangeRate() async -> Double {
        try? await Task.sleep(nanoseconds: 100 * 1_000_000) // 挂起 100ms
        return 1.0
    }
    
    func deposit(amount: Double) async {
        // 1. await 之前检查
        guard balance < 100 else {
            print("🚫 存款前检查：余额已达上限，拒绝操作")
            return
        }
        
        print("➡️ Actor: 开始存款 \(amount)，挂起前余额: \(balance)")
        
        // 🚨 风险点：此处 await 会释放 Actor 执行权
        let rate = await fetchExchangeRate()
        
//        // 💡 2. await 回来后重新检查业务规则
//        // Actor 保证了内存安全，但不保证逻辑原子性。
//        guard balance < 100 else {
//            print("🚨 重入检查：挂起期间余额已达上限 \(balance)，取消本次存款")
//            return
//        }
//        
//        let oldBalance = balance
//        balance += amount * rate
//        print("✅ Actor: 存款完成！挂起前是 \(oldBalance)，现在余额: \(balance)")
        
        // 💡 改进后的检查：不仅看当前，还要看加完之后超不超
        let projectedBalance = balance + (amount * rate)
        guard projectedBalance <= 100 else {
            print("🚨 严格检查：加存后将达到 \(projectedBalance)，超过 100 限制，取消操作")
            return
        }
                
        balance = projectedBalance
        print("✅ Actor: 存款成功，现在余额: \(balance)")
    }
    
    func getBalance() -> Double { balance }
}

@MainActor
class UIHanler {
    func updateLabel(text: String) {
        print("🖥️ MainActor: 正在更新 UI -> [\(text)]，当前线程: \(Thread.current)")
    }
}

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
//        testAnyContainers()
        // 测试并发特性
//        Task {
//            await testConcurrency()
//        }
//        testAwait()
        testTaskGroup()
        
    }
    
    private func testAwait() {
        Task {
            let name = await fetchName()
            print("拿到结果：\(name)")
        }
    }
    
    private func fetchName() async -> String {
        try? await Task.sleep(nanoseconds:  300_000_000)
        return "Hello World"
    }
    
    private func testTaskGroup() {
        Task {
            await withTaskGroup(of: Int.self) { group in
                for i in 1...3 {
                    group.addTask {
                        await self.work(i)
                    }
                }
                
                var sum = 0
                for await value in group {
                    print("当前value：\(value)")
                    sum += value
                }
                print("总和：\(sum)")
            }
            
        }
    }
    
    private  func work(_ id: Int) async -> Int {
        
        try? await Task.sleep(nanoseconds: UInt64() * 100_000_000)
        print("任务\(id) 完成")
        return id * 10
    }
    
    
    
    private func testConcurrency() async {
        
        print("\n--- 开始测试 Actor & MainActor ---")
        
        let account = BankAccount()
        let uiHandler = UIHanler()
        
        //模拟多个并发任务
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    await account.deposit(amount: Double(i * 10))
                }
            }
        }
        let finalBalance = await account.getBalance()
        
        // 跨 Actor 调用 MainActor
        await uiHandler.updateLabel(text: "最终账户余额：\(finalBalance)")
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

