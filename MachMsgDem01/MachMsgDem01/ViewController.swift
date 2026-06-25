//
//  ViewController.swift
//  MachMsgDem01
//
//  Created by maochengfang on 2026/6/25.
//

import UIKit
import Darwin.Mach

final class ViewController: UIViewController {
    private let memoryWorkerQueue = DispatchQueue(label: "demo.memory.worker", qos: .userInitiated)
    private let machWorkerQueue = DispatchQueue(label: "demo.mach.worker", qos: .userInitiated)
    private let stateQueue = DispatchQueue(label: "demo.state")

    private var isMemoryChurnRunning: Bool = false
    private var memoryUpdateTimer: Timer?

    private var isMachReceiverRunning: Bool = false
    private var machReceivePort: mach_port_t = mach_port_t(MACH_PORT_NULL)
    private var machMessageCounter: UInt32 = 0

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let residentTitleLabel = UILabel()
    private let residentBytesLabel = UILabel()
    private let residentMBLabel = UILabel()
    private let memoryChurnButton = UIButton(type: .system)

    private let machTitleLabel = UILabel()
    private let machStatusLabel = UILabel()
    private let machLastMessageLabel = UILabel()
    private let machStartButton = UIButton(type: .system)
    private let machSendButton = UIButton(type: .system)
    private let machStopButton = UIButton(type: .system)

    deinit {
        stopMemoryChurn()
        stopMachReceiver()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Mach + Memory Demos"

        buildUI()
        configureInitialUIState()
        startResidentMemoryUpdates()
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16

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

        residentTitleLabel.font = .preferredFont(forTextStyle: .headline)
        residentTitleLabel.text = "Demo 1: autoreleasepool + 临时对象内存波动"

        residentBytesLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        residentBytesLabel.textColor = .secondaryLabel
        residentBytesLabel.numberOfLines = 0

        residentMBLabel.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        residentMBLabel.numberOfLines = 0

        memoryChurnButton.setTitle("Start Memory Churn", for: .normal)
        memoryChurnButton.addTarget(self, action: #selector(onToggleMemoryChurn), for: .touchUpInside)

        let memSection = makeSection(arrangedSubviews: [
            residentTitleLabel,
            residentMBLabel,
            residentBytesLabel,
            memoryChurnButton
        ])

        machTitleLabel.font = .preferredFont(forTextStyle: .headline)
        machTitleLabel.text = "Demo 2: mach_msg 阻塞与唤醒"

        machStatusLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        machStatusLabel.textColor = .secondaryLabel
        machStatusLabel.numberOfLines = 0

        machLastMessageLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        machLastMessageLabel.numberOfLines = 0

        machStartButton.setTitle("Start Receiver", for: .normal)
        machStartButton.addTarget(self, action: #selector(onStartMachReceiver), for: .touchUpInside)

        machSendButton.setTitle("Send Wake Once", for: .normal)
        machSendButton.addTarget(self, action: #selector(onSendMachMessage), for: .touchUpInside)

        machStopButton.setTitle("Stop Receiver", for: .normal)
        machStopButton.addTarget(self, action: #selector(onStopMachReceiver), for: .touchUpInside)

        let machButtonsRow = UIStackView(arrangedSubviews: [machStartButton, machSendButton, machStopButton])
        machButtonsRow.axis = .horizontal
        machButtonsRow.spacing = 12
        machButtonsRow.distribution = .fillEqually

        let machSection = makeSection(arrangedSubviews: [
            machTitleLabel,
            machStatusLabel,
            machLastMessageLabel,
            machButtonsRow
        ])

        contentStack.addArrangedSubview(memSection)
        contentStack.addArrangedSubview(machSection)

        contentStack.addArrangedSubview(makeFooterLabel())
    }

    private func makeSection(arrangedSubviews: [UIView]) -> UIView {
        let container = UIStackView(arrangedSubviews: arrangedSubviews)
        container.axis = .vertical
        container.spacing = 10
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.separator.cgColor
        return container
    }

    private func makeFooterLabel() -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "Tip: 开启 Demo 2 后，在 Debug navigator 里找到 MachMsgReceiver 线程；它会阻塞在 mach_msg*。点击 Send Wake Once 可观察线程唤醒与调用栈变化。"
        return label
    }

    private func configureInitialUIState() {
        updateResidentLabels()
        updateMachUIState(isRunning: false)
    }

    private func startResidentMemoryUpdates() {
        memoryUpdateTimer?.invalidate()
        memoryUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateResidentLabels()
        }
        RunLoop.main.add(memoryUpdateTimer!, forMode: .common)
    }

    private func updateResidentLabels() {
        let bytes = residentMemoryBytes()
        let mb = Double(bytes) / (1024.0 * 1024.0)
        residentMBLabel.text = String(format: "resident: %.2f MB", mb)
        residentBytesLabel.text = "resident: \(bytes) bytes"
    }

    private func residentMemoryBytes() -> UInt64 {
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

    @objc private func onToggleMemoryChurn() {
        let running = stateQueue.sync { isMemoryChurnRunning }
        if running {
            stopMemoryChurn()
        } else {
            startMemoryChurn()
        }
    }

    private func startMemoryChurn() {
        stateQueue.sync {
            isMemoryChurnRunning = true
        }
        memoryChurnButton.setTitle("Stop Memory Churn", for: .normal)

        memoryWorkerQueue.async { [weak self] in
            guard let self else { return }
            while self.stateQueue.sync(execute: { self.isMemoryChurnRunning }) {
                autoreleasepool {
                    var holder: [AnyObject] = []
                    holder.reserveCapacity(20000)

                    for i in 0..<20000 {
                        let s = NSMutableString(string: "temp-\(i)-\(UUID().uuidString)")
                        holder.append(s)
                        holder.append(NSNumber(value: i))
                        holder.append(NSDate())

                        let d = NSMutableData(length: 512) ?? NSMutableData()
                        holder.append(d)
                    }

                    _ = holder.count
                }

                usleep(15_000)
            }
        }
    }

    private func stopMemoryChurn() {
        stateQueue.sync {
            isMemoryChurnRunning = false
        }
        DispatchQueue.main.async { [weak self] in
            self?.memoryChurnButton.setTitle("Start Memory Churn", for: .normal)
        }
    }

    @objc private func onStartMachReceiver() {
        startMachReceiver()
    }

    @objc private func onSendMachMessage() {
        sendMachMessageOnce()
    }

    @objc private func onStopMachReceiver() {
        stopMachReceiver()
    }

    private func updateMachUIState(isRunning: Bool) {
        machStartButton.isEnabled = !isRunning
        machSendButton.isEnabled = isRunning
        machStopButton.isEnabled = isRunning

        if isRunning {
            machStatusLabel.text = "MachMsgReceiver: running (blocked in mach_msg RCV)"
        } else {
            machStatusLabel.text = "MachMsgReceiver: stopped"
            machLastMessageLabel.text = "last: (none)"
        }
    }

    private func startMachReceiver() {
        let alreadyRunning = stateQueue.sync { isMachReceiverRunning }
        guard !alreadyRunning else { return }

        var port: mach_port_t = 0
        var kr = mach_port_allocate(mach_task_self_, mach_port_right_t(MACH_PORT_RIGHT_RECEIVE), &port)
        guard kr == KERN_SUCCESS else {
            machLastMessageLabel.text = "mach_port_allocate failed: \(kr)"
            return
        }

        kr = mach_port_insert_right(mach_task_self_, port, port, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
        guard kr == KERN_SUCCESS else {
            mach_port_destroy(mach_task_self_, port)
            machLastMessageLabel.text = "mach_port_insert_right failed: \(kr)"
            return
        }

        stateQueue.sync {
            isMachReceiverRunning = true
            machReceivePort = port
            machMessageCounter = 0
        }

        updateMachUIState(isRunning: true)

        machWorkerQueue.async { [weak self] in
            self?.machReceiverLoop()
        }
    }

    private func stopMachReceiver() {
        let running = stateQueue.sync { isMachReceiverRunning }
        guard running else { return }

        stateQueue.sync {
            isMachReceiverRunning = false
        }

        sendMachControlMessage(id: MachMessageID.stop.rawValue, value: 0)
    }

    private func sendMachMessageOnce() {
        let running = stateQueue.sync { isMachReceiverRunning }
        guard running else { return }

        let next: UInt32 = stateQueue.sync {
            machMessageCounter &+= 1
            return machMessageCounter
        }

        sendMachControlMessage(id: MachMessageID.wake.rawValue, value: next)
    }

    private enum MachMessageID: Int32 {
        case wake = 100
        case stop = 999
    }

    private struct SimpleMachMessage {
        var header: mach_msg_header_t = mach_msg_header_t()
        var value: UInt32 = 0
    }

    private func sendMachControlMessage(id: Int32, value: UInt32) {
        let port = stateQueue.sync { machReceivePort }
        guard port != mach_port_t(MACH_PORT_NULL) else { return }

        var msg = SimpleMachMessage()
        msg.value = value
        let size = mach_msg_size_t(MemoryLayout<SimpleMachMessage>.size)

        let remoteBits = UInt32(MACH_MSG_TYPE_COPY_SEND)
        let localBits: UInt32 = 0
        msg.header.msgh_bits = mach_msg_bits_t(remoteBits | (localBits << 8))
        msg.header.msgh_size = size
        msg.header.msgh_remote_port = port
        msg.header.msgh_local_port = mach_port_t(MACH_PORT_NULL)
        msg.header.msgh_id = id

        let kr: kern_return_t = withUnsafeMutableBytes(of: &msg) { raw -> kern_return_t in
            let headerPtr = raw.baseAddress!.assumingMemoryBound(to: mach_msg_header_t.self)
            return mach_msg(headerPtr, MACH_SEND_MSG, size, 0, mach_port_t(MACH_PORT_NULL), 0, mach_port_t(MACH_PORT_NULL))
        }

        if kr != KERN_SUCCESS {
            DispatchQueue.main.async { [weak self] in
                self?.machLastMessageLabel.text = "send failed: \(kr)"
            }
        }
    }

    private func machReceiverLoop() {
        Thread.current.name = "MachMsgReceiver"

        let port = stateQueue.sync { machReceivePort }
        guard port != mach_port_t(MACH_PORT_NULL) else {
            DispatchQueue.main.async { [weak self] in
                self?.updateMachUIState(isRunning: false)
            }
            return
        }

        let size = mach_msg_size_t(MemoryLayout<SimpleMachMessage>.size)

        while true {
            var msg = SimpleMachMessage()
            msg.header.msgh_size = size
            msg.header.msgh_local_port = port

            let kr: kern_return_t = withUnsafeMutableBytes(of: &msg) { raw -> kern_return_t in
                let headerPtr = raw.baseAddress!.assumingMemoryBound(to: mach_msg_header_t.self)
                return mach_msg(headerPtr, MACH_RCV_MSG, 0, size, port, 0, mach_port_t(MACH_PORT_NULL))
            }

            if kr != KERN_SUCCESS {
                let stillRunning = stateQueue.sync { isMachReceiverRunning }
                DispatchQueue.main.async { [weak self] in
                    self?.machLastMessageLabel.text = "rcv failed: \(kr)"
                    if !stillRunning {
                        self?.updateMachUIState(isRunning: false)
                    }
                }
                if !stateQueue.sync(execute: { isMachReceiverRunning }) {
                    break
                }
                continue
            }

            if msg.header.msgh_id == MachMessageID.stop.rawValue {
                break
            }

            let value = msg.value
            let msgId = msg.header.msgh_id
            print("Mach receive id=\(msgId) value=\(value)")

            DispatchQueue.main.async { [weak self] in
                self?.machLastMessageLabel.text = "last: id=\(msgId) value=\(value)"
            }
        }

        let portToDestroy = stateQueue.sync { machReceivePort }
        if portToDestroy != mach_port_t(MACH_PORT_NULL) {
            _ = mach_port_destroy(mach_task_self_, portToDestroy)
        }

        stateQueue.sync {
            machReceivePort = mach_port_t(MACH_PORT_NULL)
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateMachUIState(isRunning: false)
        }
    }
}

