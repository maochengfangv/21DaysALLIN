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
//管共享状态
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1
    }
    
    func current() -> Int {
       value
    }
}

//管主线程UI
@MainActor
func updateUI(_ text: String) {
    print("是否主线程：\(Thread.isMainThread)")
    print("UI 更新：\(text)")
}

//sendable 约束跨并发域传递的数据是否安全
// 真正决定因素是它包裹的东西是否能够安全跨并发域传递
/*
 纯值类型大概率可以
 带class 大概率不行
 带泛型 看有没有sendable约束
 带闭包 看是不是@Sendable
 */
//struct User: Sendable {
//    let id: Int
//    let name: String
//}

//final class Profile: @unchecked Sendable {
//    var nickName: String
//    init(nickName: String) {
//        self.nickName = nickName
//    }
//}

actor Profile {
    var nickName: String
    init(nickName: String) {
        self.nickName = nickName
    }
    func updateName(_ newName: String) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        nickName = newName
        print("后台写入：\(nickName)")
    }
       
    func currentName() async -> String {
        try? await Task.sleep(nanoseconds: 50_000_000)
        return nickName
    }
}

struct User: Sendable {
    let id: Int
    let name: String
    let profile:Profile
}

struct Teacher:Sendable {
    let id: Int
    var name: String
}

final class TeacherRef {
    var name: String
    init(name: String) {
        self.name = name
    }
}

@propertyWrapper
struct Clamper0To100 {
    private var num: Int
    var wrappedValue: Int {
        get { num }
        set {
            num = min(max(newValue, 0), 100)
        }
    }
    init(wrappedValue: Int) {
        self.num = min(max(wrappedValue, 0), 100)
    }
}

@MainActor
struct DemoMainActorStruct  {
    var count: Int = 0
    mutating func inc(_ tag: String) {
        count += 1
        print("🧩 @MainActor struct inc[\(tag)] count=\(count) isMain=\(Thread.isMainThread)")
    }
}

@MainActor
enum DemoMainActorStructStore {
    static var value = DemoMainActorStruct()
    static  func inc(_ tag: String) {
        value.inc(tag)
    }
}

@MainActor
final class DemoMainActorClass {
    static let shared = DemoMainActorClass()
    var count: Int = 0

    func inc(_ tag: String) {
        count += 1
        print("🏷️ @MainActor class inc[\(tag)] count=\(count) isMain=\(Thread.isMainThread)")
    }
}

actor DemoActor {
    static let shared = DemoActor()
    private var count: Int = 0

    func inc(_ tag: String) {
        count += 1
        print("🎭 actor inc[\(tag)] count=\(count) isMain=\(Thread.isMainThread)")
    }
}


enum CancellationDemo {

    static func cooperative(tag: String, steps: Int = 10, delayNanoseconds: UInt64 = 100_000_000) async {
        
        var index = 0
        do {
            for i in 1...steps {
//                try Task.checkCancellation()
                index = i
                try await Task.sleep(nanoseconds: delayNanoseconds)
                print("✅ coop[\(tag)] step=\(i) isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
            }
            print("✅ coop[\(tag)] finished")
        } catch is CancellationError {
            print("🛑 coop[\(tag)] step=\(index) cancelled isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
        } catch {
            print("❌ coop[\(tag)] error=\(error)")
        }
    }

    private static func blockingSleep(seconds: TimeInterval) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                Thread.sleep(forTimeInterval: seconds)
                continuation.resume()
            }
        }
    }

    static func nonCooperativeBlocking(tag: String, steps: Int = 6, sleepSeconds: TimeInterval = 0.2) async {
        print("🚧 nonCoop[\(tag)] begin isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
        for i in 1...steps {
            await blockingSleep(seconds: sleepSeconds)
            print("🚧 nonCoop[\(tag)] step=\(i) isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
        }
        print("🚧 nonCoop[\(tag)] finished isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
    }
}

class ViewController: UIViewController {

    private var VM = UserProfileViewModel()
    private var cancellables = Set<AnyCancellable>()
    private lazy var demoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        return stackView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "WKWebView 面试 Demo"
        label.font = .boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "覆盖活动页、JSBridge、_blank 新开页、异常页演示"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .systemBackground
        setupDemoEntryView()
        print("\n--- 开始测试 ---")
//        @Clamper0To100 var score = 120
//        print(score)
//        score = -10
//        print(score)
//        testObservedWrapper()
//        testAnySomeFunc()
//        testAsssociateType()
//        testAnyContainers()
        // 测试并发特性
//        Task {
//            await testConcurrency()
//        }
//        testAwait()
//        testTaskGroup()
//        testCounter()
//        testSendable()
//        testSendableStruct()
//        testCOWAddress()
//        Task {
//            await demoWhyMainActorPlusClass()
//        }
//        Task {
//            await testTaskCancellation()
//        }
    }

    private func setupDemoEntryView() {
        view.addSubview(demoStackView)
        demoStackView.addArrangedSubview(titleLabel)
        demoStackView.addArrangedSubview(subtitleLabel)
        demoStackView.addArrangedSubview(makeDemoButton(title: "打开活动页", action: #selector(didTapOpenCampaignButton)))
        demoStackView.addArrangedSubview(makeDemoButton(title: "测试 JSBridge", action: #selector(didTapOpenJSBridgeButton)))
        demoStackView.addArrangedSubview(makeDemoButton(title: "测试 _blank 新开页", action: #selector(didTapOpenBlankPageButton)))
        demoStackView.addArrangedSubview(makeDemoButton(title: "打开异常页", action: #selector(didTapOpenErrorPageButton)))

        NSLayoutConstraint.activate([
            demoStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            demoStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            demoStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc
    private func didTapOpenCampaignButton() {
        openTestWebView()
    }

    @objc
    private func didTapOpenJSBridgeButton() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system; padding: 24px; background: #f5f7fb; }
                .card { background: white; border-radius: 16px; padding: 20px; box-shadow: 0 6px 20px rgba(0, 0, 0, 0.08); }
                button { width: 100%; margin-top: 12px; padding: 14px; border: 0; border-radius: 12px; background: #007aff; color: white; font-size: 16px; }
                pre { margin-top: 16px; padding: 16px; border-radius: 12px; background: #111827; color: #e5e7eb; font-size: 13px; white-space: pre-wrap; word-break: break-all; }
                .tip { margin-top: 12px; color: #6b7280; font-size: 13px; }
            </style>
            <script>
                // window 是当前网页 JS 运行时的全局对象。
                // 在 WKWebView 里，WebKit 会把 Native 注册的桥接对象挂到 window.webkit.messageHandlers 上。
                // 所以这句代码的含义是：H5 通过名为 nativeBridge 的消息通道，把 action 发给 iOS 端。
                function requestNativeJSON() {
                    window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'getNativeJSON', from: 'h5' });
                }

                // 这个函数同样挂在 window 上。
                // Native 会通过 evaluateJavaScript("window.renderNativeJSONFromNative(...)") 主动回调它。
                // 这里把 Native 回传的对象格式化成 JSON 字符串，再展示到页面上。
                function renderNativeJSONFromNative(payload) {
                    var resultNode = document.getElementById('nativeJSONResult');
                    resultNode.textContent = JSON.stringify(payload, null, 2);
                }
            </script>
        </head>
        <body>
            <div class="card">
                <h2>JSBridge Demo</h2>
                <p>扫盲版理解：window 是网页全局对象，window.webkit.messageHandlers.nativeBridge.postMessage(...) 是 H5 调 Native。</p>
                <p>点击下面按钮，从 Native 获取 JSON 并展示到 H5 页面。</p>
                <button onclick="requestNativeJSON()">获取 Native JSON</button>
                <button onclick="window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'reload', from: 'h5' })">通知 Native Reload</button>
                <button onclick="window.webkit.messageHandlers.nativeBridge.postMessage({ action: 'close', from: 'h5' })">通知 Native Close</button>
                <div class="tip">下面区域展示 Native 回传给 H5 的 JSON 字符串。这个回传动作来自 Native 执行 window.renderNativeJSONFromNative(...)</div>
                <pre id="nativeJSONResult">等待 Native 回传 JSON...</pre>
            </div>
        </body>
        </html>
        """

        openWebView(
            .init(
                title: "JSBridge Demo",
                source: .htmlString(html, baseURL: nil),
                businessId: "js-bridge-demo"
            )
        )
    }

    @objc
    private func didTapOpenBlankPageButton() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system; padding: 24px; background: #fff; }
                a { display: inline-block; margin-top: 16px; padding: 12px 16px; background: #34c759; color: white; border-radius: 12px; text-decoration: none; }
            </style>
        </head>
        <body>
            <h2>target=_blank Demo</h2>
            <p>点击下面链接，会命中 WebView 的 targetFrame == nil 分支。</p>
            <a href="https://www.apple.com" target="_blank">新开页打开 Apple</a>
        </body>
        </html>
        """

        openWebView(
            .init(
                title: "_blank Demo",
                source: .htmlString(html, baseURL: nil),
                businessId: "blank-target-demo"
            )
        )
    }

    @objc
    private func didTapOpenErrorPageButton() {
        openWebView(
            .init(
                title: "异常页 Demo",
                source: .remoteURL(URL(string: "ftp://invalid-webview-demo")!),
                businessId: "error-page-demo"
            )
        )
    }

    private func makeDemoButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = title
        button.configuration?.cornerStyle = .large
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func openTestWebView() {
        openWebView(
            .init(
                title: "活动页",
                source: .remoteURL(URL(string: "https://www.apple.com")!),
                businessId: "campaign-detail"
            )
        )
    }

    private func openWebView(_ configuration: WebViewPageConfiguration) {
        let controller = WKWebViewController(configuration: configuration)
        if let navigationController {
            navigationController.pushViewController(controller, animated: true)
        } else {
            let wrappedNavigationController = UINavigationController(rootViewController: controller)
            wrappedNavigationController.modalPresentationStyle = .fullScreen
            present(wrappedNavigationController, animated: true)
        }
    }
    
    // 测试Task Cancellation
    private func testTaskCancellation() async {
        
        print("\n--- Demo: Task 取消是协作式（cooperative）---")
        
        let coop = Task.detached(priority: .background) {
            await CancellationDemo.cooperative(tag: "detached-coop",steps: 500)
        }
        
        let nonCoop = Task.detached(priority: .background) {
            await CancellationDemo.nonCooperativeBlocking(tag: "detached-nonCoop")
        }
        
        try? await Task.sleep(nanoseconds: 350_000_000)
        
        print(">>> cancel coop & nonCoop")
        
        coop.cancel()
        nonCoop.cancel()
        
//        print("\n--- Demo: 结构化并发会随父任务取消；detached 不会 ---")
//        
//        let structered = Task.detached(priority: .background) {
//            print("group parent begin isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
//            
//            await withTaskGroup(of: Void.self) { group in
//                group.addTask { await CancellationDemo.cooperative(tag: "group-1") }
//                group.addTask { await CancellationDemo.cooperative(tag: "group-2") }
//                group.addTask { await CancellationDemo.cooperative(tag: "group-3") }
//                await group.waitForAll()
//            }
//            print("group parent end isCancelled=\(Task.isCancelled) isMain=\(Thread.isMainThread)")
//        }
        
//        let siblingDetached = Task.detached(priority: .background) {
//            await CancellationDemo.cooperative(tag: "sibling-detached", steps: 12)
////            await CancellationDemo.nonCooperativeBlocking(tag: "non-sibling-detached",steps: 12)
//
//        }
//        
//        try? await Task.sleep(nanoseconds: 350_000_000)
////        print(">>> cancel group parent (should stop group tasks), sibling-detached keeps running")
////        structered.cancel()
//        
//        siblingDetached.cancel()
        
//        _ = await structered.value
//        _ = await siblingDetached.value
        
        print("--- Demo: Task cancellation done ---")
    }
    private func demoWhyMainActorPlusClass() async {
         print("\n--- Demo: @MainActor 可修饰 struct/class，但不能修饰 actor ---")
         print("入口线程 isMain=\(Thread.isMainThread)")
        
         await MainActor.run {
             var a = DemoMainActorStruct()
             var b = a
             a.inc("a1")
             b.inc("b1")
             a.inc("a2")
             print("🧩 struct copy 独立状态 aCount=\(a.count) bCount=\(b.count) isMain=\(Thread.isMainThread)")

             let c1 = DemoMainActorClass.shared
             let c2 = DemoMainActorClass.shared
             c1.inc("c1")
             c2.inc("c2")
             print("🏷️ class identity same=\(ObjectIdentifier(c1) == ObjectIdentifier(c2)) count=\(c1.count) isMain=\(Thread.isMainThread)")
         }

         print("\n--- Demo: 后台调用 @MainActor 会 hop 到主线程；actor 只是串行隔离，不等于主线程 ---")
         let detached = Task.detached(priority: .background) {
             print("Detached(before await) isMain=\(Thread.isMainThread)")
             await DemoMainActorStructStore.inc("detached-struct")
             await DemoMainActorClass.shared.inc("detached-class")
             await DemoActor.shared.inc("detached-actor")
             print("Detached(after await) isMain=\(Thread.isMainThread)")
         }
         _ = await detached.value
     }
    //底层证明先共享后拷贝
    private func  testCOWAddress() {
        
        let arr1 = [1,2,3]
        var arr2 = arr1
        
        arr1.withUnsafeBufferPointer { p1 in
            arr2.withUnsafeBufferPointer { p2 in
                print("写入前是否共享存储：\(p1.baseAddress == p2.baseAddress)")
            }
        }
        arr2.append(4)
        arr1.withUnsafeBufferPointer { p1 in
            arr2.withUnsafeBufferPointer { p2 in
                print("写入后是否共享存储：\(p1.baseAddress == p2.baseAddress)")
            }
        }
    }
    
    func testSendableStruct() {
        var user = Teacher(id: 1, name: "Oliver")
        
//        //跨并发安全传值
//        Task.detached { [user] in
//            try? await Task.sleep(nanoseconds: 200_000_000)
//            print("后台任务收到用户：\(user.name)")
//        }
//        //值快照 传递不可变快照
//        let snapshot = user
//           Task.detached {
//               try? await Task.sleep(nanoseconds: 200_000_000)
//               print("后台任务收到用户：\(snapshot.name)")
//           }
//        
//        user.name = "Jack"
//        print("主线程修改后的本地用户：\(user.name)")
        
        let tt = TeacherRef(name: "Zhang")
        
        Task.detached { [tt] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            print("后台任务收到TeacherRef用户：\(tt.name)")
        }
        
        tt.name = "Wang"
        print("主线程修改后的本地TeacherRef用户：\(tt.name)")
        
    }
    
    private func testSendable () {
        let user = User(id: 1, name: "王松", profile: Profile(nickName: ""))

           Task.detached {
               for i in 1...5 {
                   await user.profile.updateName("后台改名\(i)")
                   let name = await user.profile.currentName()
                   print("后台读取：\(name)")
               }
           }

//           Task.detached {
//               for _ in 1...5 {
//                   let name = await user.profile.currentName()
//                   print("后台读取：\(name)")
//               }
//           }
    }
    
    private func testCounter() {
        let counter = Counter()
        Task.detached {
            await counter.increment()
            await counter.increment()
            let value = await counter.current()
            await updateUI("当前计数：\(value)")
        }
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
