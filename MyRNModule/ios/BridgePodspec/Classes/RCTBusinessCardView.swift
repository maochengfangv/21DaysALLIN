import Foundation
import UIKit

@objc public final class RCTBusinessCardView: UIView {

  @objc public var cardData: NSString? = nil {
    didSet { updateContentIfNeeded() }
  }

  @objc public var actions: NSString? = nil {
    didSet { updateContentIfNeeded() }
  }

  @objc public var cardType: Int32 = 0 {
    didSet { updateContentIfNeeded() }
  }

  @objc public var cornerRadius: CGFloat = 16 {
    didSet {
      layer.cornerRadius = cornerRadius
      layer.masksToBounds = true
    }
  }

  @objc public var enableShadow: Bool = true {
    didSet {
      layer.shadowOpacity = enableShadow ? 0.08 : 0
    }
  }

  @objc public var onCardPress: RCTDirectEventBlock?
  @objc public var onActionPress: RCTDirectEventBlock?
  @objc public var onExposure: RCTDirectEventBlock?

  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let descLabel = UILabel()
  private let tagLabel = UILabel()
  private let authorLabel = UILabel()
  private let timeLabel = UILabel()
  private let coverImageView = UIImageView()
  private let actionStack = UIStackView()
  private var contentStack = UIStackView()
  private var actionButtons: [UIButton] = []

  private var parsedData: [String: Any]?
  private var parsedActions: [[String: Any]]?

  private var hasReportedExposure = false

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setupUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    backgroundColor = .white
    layer.cornerRadius = cornerRadius
    layer.masksToBounds = true
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.08
    layer.shadowOffset = CGSize(width: 0, height: 4)
    layer.shadowRadius = 12

    coverImageView.contentMode = .scaleAspectFill
    coverImageView.clipsToBounds = true
    coverImageView.backgroundColor = UIColor(white: 0.9, alpha: 1)
    coverImageView.isUserInteractionEnabled = true
    coverImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

    titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
    titleLabel.textColor = UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
    titleLabel.numberOfLines = 2
    titleLabel.isUserInteractionEnabled = true
    titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

    subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    subtitleLabel.textColor = UIColor(red: 0.29, green: 0.33, blue: 0.39, alpha: 1)
    subtitleLabel.numberOfLines = 1

    descLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    descLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1)
    descLabel.numberOfLines = 2

    tagLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
    tagLabel.textColor = UIColor(red: 0.31, green: 0.27, blue: 0.9, alpha: 1)
    tagLabel.backgroundColor = UIColor(red: 0.93, green: 0.95, blue: 1, alpha: 1)
    tagLabel.textAlignment = .center
    tagLabel.layer.cornerRadius = 999
    tagLabel.layer.masksToBounds = true
    tagLabel.setContentHuggingPriority(.required, for: .horizontal)

    authorLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
    authorLabel.textColor = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)

    timeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    timeLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1)
    timeLabel.setContentHuggingPriority(.required, for: .horizontal)

    actionStack.axis = .horizontal
    actionStack.spacing = 10
    actionStack.distribution = .fillEqually
    actionStack.isLayoutMarginsRelativeArrangement = true
    actionStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

    let metaStack = UIStackView(arrangedSubviews: [authorLabel, timeLabel])
    metaStack.axis = .horizontal
    metaStack.spacing = 8
    metaStack.alignment = .center

    let infoStack = UIStackView(arrangedSubviews: [
      titleLabel,
      subtitleLabel,
      descLabel,
      metaStack,
    ])
    infoStack.axis = .vertical
    infoStack.spacing = 6
    infoStack.isLayoutMarginsRelativeArrangement = true
    infoStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)

    let coverContainer = UIView()
    coverContainer.addSubview(coverImageView)
    coverImageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      coverImageView.topAnchor.constraint(equalTo: coverContainer.topAnchor),
      coverImageView.leadingAnchor.constraint(equalTo: coverContainer.leadingAnchor),
      coverImageView.trailingAnchor.constraint(equalTo: coverContainer.trailingAnchor),
      coverImageView.bottomAnchor.constraint(equalTo: coverContainer.bottomAnchor),
      coverContainer.heightAnchor.constraint(equalTo: coverContainer.widthAnchor, multiplier: 9.0 / 16.0),
    ])
    coverContainer.addSubview(tagLabel)
    tagLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      tagLabel.topAnchor.constraint(equalTo: coverContainer.topAnchor, constant: 12),
      tagLabel.leadingAnchor.constraint(equalTo: coverContainer.leadingAnchor, constant: 12),
      tagLabel.heightAnchor.constraint(equalToConstant: 24),
      tagLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
    ])

    contentStack = UIStackView(arrangedSubviews: [
      coverContainer,
      infoStack,
      actionStack,
    ])
    contentStack.axis = .vertical
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(contentStack)

    NSLayoutConstraint.activate([
      contentStack.topAnchor.constraint(equalTo: topAnchor),
      contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
      contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
      contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func updateContentIfNeeded() {
    defer { setNeedsLayout() }
    do {
      if let raw = cardData as String?,
         let jsonData = raw.data(using: .utf8),
         let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
        parsedData = dict
        applyCardData(dict)
      }
      if let raw = actions as String?,
         let jsonData = raw.data(using: .utf8),
         let arr = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
        parsedActions = arr
        applyActions(arr)
      }
    } catch {
      NSLog("[RCTBusinessCardView] JSON parse error: \(error)")
    }
  }

  private func applyCardData(_ data: [String: Any]) {
    titleLabel.text = data["title"] as? String ?? ""
    subtitleLabel.text = data["subtitle"] as? String ?? ""
    descLabel.text = data["description"] as? String ?? ""
    authorLabel.text = (data["author"] as? String).map { "👤 \($0)" } ?? ""

    if let tag = data["tag"] as? String, !tag.isEmpty {
      tagLabel.text = "  \(tag)  "
      tagLabel.isHidden = false
    } else {
      tagLabel.isHidden = true
    }

    if let ts = data["timestamp"] as? TimeInterval {
      timeLabel.text = "⏱ " + formatTime(ts)
    } else {
      timeLabel.text = ""
    }

    if let cover = data["coverUrl"] as? String, !cover.isEmpty, let url = URL(string: cover) {
      loadRemoteImage(url: url)
    } else {
      coverImageView.image = nil
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self, !self.hasReportedExposure else { return }
      self.hasReportedExposure = true
      let cardId = data["cardId"] as? String ?? ""
      self.onExposure?([
        "cardId": cardId,
        "timestamp": Date().timeIntervalSince1970 * 1000,
      ])
    }
  }

  private func applyActions(_ actions: [[String: Any]]) {
    actionButtons.forEach { $0.removeFromSuperview() }
    actionButtons.removeAll()

    actionStack.isHidden = actions.isEmpty

    actions.enumerated().forEach { index, action in
      let button = UIButton(type: .system)
      button.setTitle(action["title"] as? String ?? "", for: .normal)
      button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
      button.tag = index
      let isPrimary = index == 0
      button.backgroundColor = isPrimary
        ? UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        : UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
      button.setTitleColor(isPrimary ? .white : UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1), for: .normal)
      button.layer.cornerRadius = min(cornerRadius * 0.5, 10)
      button.layer.masksToBounds = true
      button.addTarget(self, action: #selector(handleActionTap(_:)), for: .touchUpInside)
      button.heightAnchor.constraint(equalToConstant: 40).isActive = true
      actionStack.addArrangedSubview(button)
      actionButtons.append(button)
    }
  }

  @objc private func handleTap() {
    let cardId = parsedData?["cardId"] as? String ?? ""
    onCardPress?(["cardId": cardId])
  }

  @objc private func handleActionTap(_ sender: UIButton) {
    guard let actions = parsedActions, sender.tag < actions.count else { return }
    let action = actions[sender.tag]
    let cardId = parsedData?["cardId"] as? String ?? ""
    let actionId = action["id"] as? String ?? ""
    let actionType = (action["actionType"] as? Int32) ?? 0
    onActionPress?([
      "cardId": cardId,
      "actionId": actionId,
      "actionType": actionType,
    ])
  }

  private func formatTime(_ timestampMs: TimeInterval) -> String {
    let date = Date(timeIntervalSince1970: timestampMs / 1000.0)
    let now = Date()
    let diff = now.timeIntervalSince(date)
    if diff < 60 { return "刚刚" }
    if diff < 3600 { return "\(Int(diff/60))分钟前" }
    if diff < 86400 { return "\(Int(diff/3600))小时前" }
    if diff < 86400 * 7 { return "\(Int(diff/86400))天前" }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    return fmt.string(from: date)
  }

  private func loadRemoteImage(url: URL) {
    let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
      guard let data, error == nil, let image = UIImage(data: data) else { return }
      DispatchQueue.main.async {
        self?.coverImageView.image = image
      }
    }
    task.resume()
  }
}
