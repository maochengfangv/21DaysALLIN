//
//  ViewController.swift
//  PerfTuningSimDemo2
//
//  Created by maochengfang on 2026/6/29.
//

import UIKit
import Darwin.Mach

final class ViewController: UIViewController {
    private enum Mode: Int {
        case bad = 0
        case optimized = 1

        var title: String {
            switch self {
            case .bad: return "Bad"
            case .optimized: return "Optimized"
            }
        }
    }

    private let stateQueue = DispatchQueue(label: "perf.state")

    private let memoryQueue = DispatchQueue(label: "perf.memory", qos: .userInitiated)
    private var isMemoryChurnRunning: Bool = false

    private var viewChurnLink: CADisplayLink?
    private var isViewChurnRunning: Bool = false

    private var timerStormTimers: [Timer] = []
    private var timerStormSpawner: Timer?
    private var isTimerStormRunning: Bool = false

    private let cpuQueue = DispatchQueue(label: "perf.cpu", qos: .userInitiated)
    private var isCPUBurnRunning: Bool = false

    private var statsTimer: Timer?

    private var mode: Mode = .bad

    private var canvasViews: [UIView] = []
    private var canvasPool: [UIView] = []
    private var canvasPoolIndex: Int = 0

    private var leakBudgetBytes: Int = 24 * 1024 * 1024
    private var leakedBytes: Int = 0

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let titleLabel = UILabel()
    private let modeControl = UISegmentedControl(items: [Mode.bad.title, Mode.optimized.title])

    private let residentLabel = UILabel()
    private let cpuLabel = UILabel()

    private let memoryButton = UIButton(type: .system)
    private let viewChurnButton = UIButton(type: .system)
    private let timerStormButton = UIButton(type: .system)
    private let cpuBurnButton = UIButton(type: .system)

    private let startAllButton = UIButton(type: .system)
    private let stopAllButton = UIButton(type: .system)

    private let canvasTitleLabel = UILabel()
    private let canvasView = UIView()

    private let statusLabel = UILabel()

    deinit {
        stopAll()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "PerfTuningSimDemo2"

        buildUI()
        configureInitialState()
        startStatsUpdates()
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 0
        titleLabel.text = "性能劣化模拟：大数组/视图抖动/定时器风暴/CPU 高位"

        modeControl.selectedSegmentIndex = Mode.bad.rawValue
        modeControl.addTarget(self, action: #selector(onModeChanged), for: .valueChanged)

        residentLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        residentLabel.numberOfLines = 0

        cpuLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        cpuLabel.numberOfLines = 0

        memoryButton.setTitle("Start Memory Churn", for: .normal)
        memoryButton.addTarget(self, action: #selector(onToggleMemory), for: .touchUpInside)

        viewChurnButton.setTitle("Start View Churn", for: .normal)
        viewChurnButton.addTarget(self, action: #selector(onToggleViewChurn), for: .touchUpInside)

        timerStormButton.setTitle("Start Timer Storm", for: .normal)
        timerStormButton.addTarget(self, action: #selector(onToggleTimerStorm), for: .touchUpInside)

        cpuBurnButton.setTitle("Start CPU Burn", for: .normal)
        cpuBurnButton.addTarget(self, action: #selector(onToggleCPUBurn), for: .touchUpInside)

        startAllButton.setTitle("Start All", for: .normal)
        startAllButton.addTarget(self, action: #selector(onStartAll), for: .touchUpInside)

        stopAllButton.setTitle("Stop All", for: .normal)
        stopAllButton.addTarget(self, action: #selector(onStopAll), for: .touchUpInside)

        let row1 = UIStackView(arrangedSubviews: [memoryButton, viewChurnButton])
        row1.axis = .horizontal
        row1.spacing = 12
        row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [timerStormButton, cpuBurnButton])
        row2.axis = .horizontal
        row2.spacing = 12
        row2.distribution = .fillEqually

        let row3 = UIStackView(arrangedSubviews: [startAllButton, stopAllButton])
        row3.axis = .horizontal
        row3.spacing = 12
        row3.distribution = .fillEqually

        canvasTitleLabel.font = .preferredFont(forTextStyle: .headline)
        canvasTitleLabel.text = "Canvas (视图创建/复用区)"

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .secondarySystemBackground
        canvasView.layer.cornerRadius = 12
        NSLayoutConstraint.activate([
            canvasView.heightAnchor.constraint(equalToConstant: 260)
        ])

        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        contentStack.addArrangedSubview(makeSection([
            titleLabel,
            modeControl,
            residentLabel,
            cpuLabel,
            row1,
            row2,
            row3,
            statusLabel
        ]))

        contentStack.addArrangedSubview(makeSection([
            canvasTitleLabel,
            canvasView
        ]))
    }

    private func makeSection(_ views: [UIView]) -> UIView {
        let container = UIStackView(arrangedSubviews: views)
        container.axis = .vertical
        container.spacing = 10
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.separator.cgColor
        return container
    }

    private func configureInitialState() {
        updateStatsLabels()
        updateButtonTitles()
        statusLabel.text = "mode=\(mode.title)"
    }

    private func startStatsUpdates() {
        // 用 Timer 周期性刷新指标（resident/cpu）。
        // 选择 .common mode 是为了在滚动/Tracking 等 RunLoop mode 切换时也能持续刷新。
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updateStatsLabels()
        }
        RunLoop.main.add(statsTimer!, forMode: .common)
    }

    private func updateStatsLabels() {
        let bytes = residentMemoryBytes()
        let mb = Double(bytes) / (1024.0 * 1024.0)
        residentLabel.text = String(format: "resident: %.2f MB (%llu bytes)", mb, bytes)

        let cpu = processCPUUsagePercent()
        cpuLabel.text = String(format: "cpu: %.1f%%", cpu)
    }

    @objc private func onModeChanged() {
        let next = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .bad
        stateQueue.sync {
            mode = next
            leakedBytes = 0
            leakBudgetBytes = 24 * 1024 * 1024
        }
        statusLabel.text = "mode=\(next.title)"
    }

    @objc private func onToggleMemory() {
        let running = stateQueue.sync { isMemoryChurnRunning }
        running ? stopMemoryChurn() : startMemoryChurn()
    }

    @objc private func onToggleViewChurn() {
        let running = stateQueue.sync { isViewChurnRunning }
        running ? stopViewChurn() : startViewChurn()
    }

    @objc private func onToggleTimerStorm() {
        let running = stateQueue.sync { isTimerStormRunning }
        running ? stopTimerStorm() : startTimerStorm()
    }

    @objc private func onToggleCPUBurn() {
        let running = stateQueue.sync { isCPUBurnRunning }
        running ? stopCPUBurn() : startCPUBurn()
    }

    @objc private func onStartAll() {
        startMemoryChurn()
        startViewChurn()
        startTimerStorm()
        startCPUBurn()
    }

    @objc private func onStopAll() {
        stopAll()
    }

    private func stopAll() {
        stopMemoryChurn()
        stopViewChurn()
        stopTimerStorm()
        stopCPUBurn()
    }

    private func updateButtonTitles() {
        let mem = stateQueue.sync { isMemoryChurnRunning }
        let viewChurn = stateQueue.sync { isViewChurnRunning }
        let timers = stateQueue.sync { isTimerStormRunning }
        let cpu = stateQueue.sync { isCPUBurnRunning }

        memoryButton.setTitle(mem ? "Stop Memory Churn" : "Start Memory Churn", for: .normal)
        viewChurnButton.setTitle(viewChurn ? "Stop View Churn" : "Start View Churn", for: .normal)
        timerStormButton.setTitle(timers ? "Stop Timer Storm" : "Start Timer Storm", for: .normal)
        cpuBurnButton.setTitle(cpu ? "Stop CPU Burn" : "Start CPU Burn", for: .normal)
    }

    private func startMemoryChurn() {
        // 内存抖动模拟：循环创建大量临时对象/大块数据，制造分配压力与 resident 波动。
        // - Bad：更大 burst + 注入“受控泄漏”（供 Leaks 复现/定位）
        // - Optimized：降低分配规模 + 用 autoreleasepool 缩短 autorelease 对象生命周期 + 节流
        let shouldStart = stateQueue.sync {
            if isMemoryChurnRunning { return false }
            isMemoryChurnRunning = true
            return true
        }
        guard shouldStart else { return }
        updateButtonTitles()

        memoryQueue.async { [weak self] in
            guard let self else { return }
            var sink: UInt64 = 0
            while self.stateQueue.sync(execute: { self.isMemoryChurnRunning }) {
                let currentMode = self.stateQueue.sync { self.mode }

                if currentMode == .optimized {
                    autoreleasepool {
                        sink &+= self.allocateBurst(objects: 6_000, bytesPerData: 2048)
                    }
                    usleep(15_000)
                } else {
                    sink &+= self.allocateBurst(objects: 14_000, bytesPerData: 4096)
                    self.maybeLeakMemoryOnce()
                }
            }
            _ = sink
        }
    }

    private func stopMemoryChurn() {
        let shouldStop = stateQueue.sync {
            if !isMemoryChurnRunning { return false }
            isMemoryChurnRunning = false
            return true
        }
        guard shouldStop else { return }
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonTitles()
        }
    }

    @inline(never)
    private func allocateBurst(objects: Int, bytesPerData: Int) -> UInt64 {
        // 关键点：这里故意把热点做成独立函数并禁止内联，方便 Time Profiler 里稳定看到栈帧。
        // 每轮创建 NSMutableString/NSNumber/NSDate/NSMutableData，模拟业务里频繁创建临时对象。
        var holder: [AnyObject] = []
        holder.reserveCapacity(objects)

        for i in 0..<objects {
            let s = NSMutableString(string: "arr-\(i)-\(UUID().uuidString)")
            holder.append(s)
            holder.append(NSNumber(value: i))
            holder.append(NSDate())

            let d = NSMutableData(length: bytesPerData) ?? NSMutableData()
            holder.append(d)
        }

        return UInt64(holder.count)
    }

    @inline(never)
    private func maybeLeakMemoryOnce() {
        // 故意制造“可控泄漏”：分配一段原生内存但不释放。
        // 目的：让 Instruments 的 Leaks 能稳定抓到泄漏记录，并在 Backtrace 中定位到这里。
        // 通过 leakBudgetBytes 限制泄漏上限，避免无限增长导致进程被系统杀掉。
        let (budget, leaked) = stateQueue.sync { (leakBudgetBytes, leakedBytes) }
        guard leaked < budget else { return }

        let chunk = 256 * 1024
        let p = UnsafeMutableRawPointer.allocate(byteCount: chunk, alignment: 16)
        p.initializeMemory(as: UInt8.self, repeating: 0xA5, count: chunk)

        stateQueue.sync {
            leakedBytes += chunk
        }
    }

    private func startViewChurn() {
        // 视图抖动模拟（主线程）：用 CADisplayLink 按帧回调，持续创建/添加/布局 view。
        // - Bad：每帧 new UIView 并加入层级，触发大量分配、布局、渲染合成压力
        // - Optimized：预创建 view pool，循环复用，减少分配与层级抖动
        let shouldStart = stateQueue.sync {
            if isViewChurnRunning { return false }
            isViewChurnRunning = true
            return true
        }
        guard shouldStart else { return }
        updateButtonTitles()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.viewChurnLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(self.onViewChurnTick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.viewChurnLink = link

            self.prepareCanvasForCurrentMode()
        }
    }

    private func stopViewChurn() {
        let shouldStop = stateQueue.sync {
            if !isViewChurnRunning { return false }
            isViewChurnRunning = false
            return true
        }
        guard shouldStop else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.viewChurnLink?.invalidate()
            self.viewChurnLink = nil

            self.canvasViews.forEach { $0.removeFromSuperview() }
            self.canvasViews.removeAll(keepingCapacity: true)

            self.updateButtonTitles()
        }
    }

    private func prepareCanvasForCurrentMode() {
        let currentMode = stateQueue.sync { mode }
        if currentMode == .optimized {
            if canvasPool.isEmpty {
                canvasPool = (0..<400).map { _ in
                    let v = UIView()
                    v.layer.cornerRadius = 6
                    v.backgroundColor = .systemBlue
                    return v
                }
            }
        } else {
            canvasPool.removeAll(keepingCapacity: true)
            canvasPoolIndex = 0
        }
    }

    @objc private func onViewChurnTick() {
        guard stateQueue.sync(execute: { isViewChurnRunning }) else { return }

        let currentMode = stateQueue.sync { mode }
        let bounds = canvasView.bounds.insetBy(dx: 8, dy: 8)
        guard bounds.width > 0 && bounds.height > 0 else { return }

        if currentMode == .optimized {
            for _ in 0..<40 {
                let v = canvasPool[canvasPoolIndex % canvasPool.count]
                canvasPoolIndex += 1

                if v.superview == nil {
                    canvasView.addSubview(v)
                }

                let w = CGFloat(Int.random(in: 10...60))
                let h = CGFloat(Int.random(in: 10...60))
                let x = CGFloat.random(in: bounds.minX...(bounds.maxX - w))
                let y = CGFloat.random(in: bounds.minY...(bounds.maxY - h))
                v.frame = CGRect(x: x, y: y, width: w, height: h)
                v.backgroundColor = (canvasPoolIndex % 2 == 0) ? .systemBlue : .systemGreen
            }
        } else {
            for _ in 0..<60 {
                let v = UIView()
                v.layer.cornerRadius = 6
                v.backgroundColor = .systemRed

                let w = CGFloat(Int.random(in: 10...60))
                let h = CGFloat(Int.random(in: 10...60))
                let x = CGFloat.random(in: bounds.minX...(bounds.maxX - w))
                let y = CGFloat.random(in: bounds.minY...(bounds.maxY - h))
                v.frame = CGRect(x: x, y: y, width: w, height: h)

                canvasView.addSubview(v)
                canvasViews.append(v)
            }

            if canvasViews.count > 1200 {
                let removeCount = 300
                let toRemove = canvasViews.prefix(removeCount)
                toRemove.forEach { $0.removeFromSuperview() }
                canvasViews.removeFirst(removeCount)
            }
        }

        canvasView.setNeedsLayout()
        canvasView.layoutIfNeeded()
    }

    private func startTimerStorm() {
        // 定时器风暴模拟（主线程 RunLoop 压力）：
        // - Bad：多个高频 Timer + 逐步增殖 timer（spawner）=> 回调拥塞、主线程持续被唤醒
        // - Optimized：合并为单个较低频 Timer + 更小 work unit
        let shouldStart = stateQueue.sync {
            if isTimerStormRunning { return false }
            isTimerStormRunning = true
            return true
        }
        guard shouldStart else { return }
        updateButtonTitles()

        let currentMode = stateQueue.sync { mode }

        if currentMode == .optimized {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.invalidateTimerStormLocked()

                let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                    self?.timerStormWork(unit: 2_000)
                }
                RunLoop.main.add(t, forMode: .common)
                self.timerStormTimers = [t]
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.invalidateTimerStormLocked()

                for _ in 0..<16 {
                    let t = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                        self?.timerStormWork(unit: 5_000)
                    }
                    RunLoop.main.add(t, forMode: .common)
                    self.timerStormTimers.append(t)
                }

                let spawner = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    guard self.timerStormTimers.count < 40 else { return }
                    for _ in 0..<6 {
                        let t = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                            self?.timerStormWork(unit: 5_000)
                        }
                        RunLoop.main.add(t, forMode: .common)
                        self.timerStormTimers.append(t)
                    }
                }
                RunLoop.main.add(spawner, forMode: .common)
                self.timerStormSpawner = spawner
            }
        }
    }

    private func stopTimerStorm() {
        let shouldStop = stateQueue.sync {
            if !isTimerStormRunning { return false }
            isTimerStormRunning = false
            return true
        }
        guard shouldStop else { return }

        DispatchQueue.main.async { [weak self] in
            self?.invalidateTimerStormLocked()
            self?.updateButtonTitles()
        }
    }

    private func invalidateTimerStormLocked() {
        timerStormSpawner?.invalidate()
        timerStormSpawner = nil

        timerStormTimers.forEach { $0.invalidate() }
        timerStormTimers.removeAll(keepingCapacity: true)
    }

    @inline(never)
    private func timerStormWork(unit: Int) {
        var sum: Int = 0
        var arr: [Int] = []
        arr.reserveCapacity(unit)
        for i in 0..<unit {
            arr.append(i ^ (i & 7))
        }
        for v in arr {
            sum &+= v
        }
        if sum == Int.min {
            statusLabel.text = "impossible"
        }
    }

    private func startCPUBurn() {
        let shouldStart = stateQueue.sync {
            if isCPUBurnRunning { return false }
            isCPUBurnRunning = true
            return true
        }
        guard shouldStart else { return }
        updateButtonTitles()

        cpuQueue.async { [weak self] in
            guard let self else { return }
            var seed: UInt64 = 0x1234_5678_9ABC_DEF0
            var sink: UInt64 = 0

            while self.stateQueue.sync(execute: { self.isCPUBurnRunning }) {
                let currentMode = self.stateQueue.sync { self.mode }

                if currentMode == .optimized {
                    for _ in 0..<40_000 {
                        sink &+= self.cpuBurnStep(&seed)
                    }
                    usleep(10_000)
                } else {
                    for _ in 0..<200_000 {
                        sink &+= self.cpuBurnStep(&seed)
                    }
                }
            }

            _ = sink
        }
    }

    private func stopCPUBurn() {
        let shouldStop = stateQueue.sync {
            if !isCPUBurnRunning { return false }
            isCPUBurnRunning = false
            return true
        }
        guard shouldStop else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateButtonTitles()
        }
    }

    @inline(never)
    private func cpuBurnStep(_ seed: inout UInt64) -> UInt64 {
        seed &+= 0x9E37_79B9_7F4A_7C15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)

        var x: UInt64 = z
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        return x
    }

    private func residentMemoryBytes() -> UInt64 {
        // resident memory：进程当前常驻物理内存（非虚拟地址空间）。
        // 用 task_info(MACH_TASK_BASIC_INFO) 读取 mach_task_basic_info.resident_size。
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride)

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return 0
        }

        return UInt64(info.resident_size)
    }

    private func processCPUUsagePercent() -> Double {
        // 进程 CPU%：枚举 task 的所有线程，累加 thread_basic_info.cpu_usage。
        // - cpu_usage 是 TH_USAGE_SCALE 的定点数，需要换算成百分比
        // - 注意释放 task_threads 返回的数组：对每个 thread port deallocate，并 vm_deallocate 整块数组
        var threads: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let kr = task_threads(mach_task_self_, &threads, &threadCount)
        guard kr == KERN_SUCCESS, let threads else { return 0 }

        defer {
            for i in 0..<Int(threadCount) {
                mach_port_deallocate(mach_task_self_, threads[i])
            }
            let size = vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)
        }

        var total: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.stride / MemoryLayout<natural_t>.stride)

            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), intPtr, &count)
                }
            }

            guard kerr == KERN_SUCCESS else { continue }
            if (info.flags & TH_FLAGS_IDLE) != 0 { continue }

            total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
        }

        return total
    }
}

