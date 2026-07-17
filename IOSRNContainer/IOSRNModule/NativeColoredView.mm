#import "NativeColoredView.h"
#import <react/renderer/components/MyRNAppSpecs/ComponentDescriptors.h>
#import <react/renderer/components/MyRNAppSpecs/Props.h>
#import <react/renderer/components/MyRNAppSpecs/RCTComponentViewHelpers.h>
#import <react/renderer/components/MyRNAppSpecs/EventEmitters.h>

using namespace facebook::react;

@interface NativeColoredView () <RCTNativeColoredViewViewProtocol>
@property (nonatomic, strong) NSTimer *valueTimer;
@property (nonatomic, assign) double currentValue;
@end

@implementation NativeColoredView

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<NativeColoredViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const NativeColoredViewProps>();
    _props = defaultProps;
    _currentValue = 0.0;
  }
  return self;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newViewProps = *std::static_pointer_cast<const NativeColoredViewProps>(props);
  const auto oldViewProps = std::static_pointer_cast<const NativeColoredViewProps>(oldProps);

  [super updateProps:props oldProps:oldProps];

  // --- color / cornerRadius ---
  if (!newViewProps.color.empty()) {
    NSString *hexString = [NSString stringWithUTF8String:newViewProps.color.c_str()];
    if (hexString.length > 0) {
      self.backgroundColor = [self rgbaFromHexString:hexString];
    }
  }

  self.layer.cornerRadius = newViewProps.cornerRadius;

  // --- isActive 状态变更 → 启动 / 停止 Timer ---
  // 首次挂载时 oldProps 可能为 null，用 shared_ptr 的 bool 转换做安全判断
  BOOL wasActive = oldViewProps ? oldViewProps->isActive : false;
  if (newViewProps.isActive != wasActive) {
    if (newViewProps.isActive) {
      [self startValueTimer];
    } else {
      [self stopValueTimer];
    }
  }
}

#pragma mark - 持续推送动态值

- (void)startValueTimer {
  [self stopValueTimer];  // 防重复创建

  __weak NativeColoredView *weakSelf = self;
  self.valueTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
    NativeColoredView *strongSelf = weakSelf;
    if (!strongSelf) {
      [timer invalidate];
      return;
    }
    [strongSelf emitValueChange];
  }];

  // 加入 common modes，保证滚动时也能持续推送
  [[NSRunLoop mainRunLoop] addTimer:self.valueTimer forMode:NSRunLoopCommonModes];
}

- (void)stopValueTimer {
  if (self.valueTimer) {
    [self.valueTimer invalidate];
    self.valueTimer = nil;
  }
}

- (void)emitValueChange {
  self.currentValue += 1.0;  // 每秒递增（可按需替换为 sensor / 动画 / 音频等实时数据源）

  // 通过 Codegen 生成的 EventEmitter 向 JS 侧派发事件
  auto eventEmitter = std::static_pointer_cast<const NativeColoredViewEventEmitter>(_eventEmitter);
  if (eventEmitter) {
    eventEmitter->onValueChange({
      .value = self.currentValue,
      .timestamp = CACurrentMediaTime() * 1000.0  // 毫秒级时间戳
    });
  }
}

#pragma mark - 生命周期清理

- (void)prepareForRecycle {
  [self stopValueTimer];
  self.currentValue = 0.0;
  [super prepareForRecycle];
}

- (void)dealloc {
  [self stopValueTimer];
}

#pragma mark - 颜色工具（保持不变）

- (UIColor *)rgbaFromHexString:(NSString *)hexString {
  NSString *clean = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
  if (clean.length == 6) {
    clean = [clean stringByAppendingString:@"FF"];
  }
  unsigned int rgba = 0;
  [[NSScanner scannerWithString:clean] scanHexInt:&rgba];
  return [UIColor colorWithRed:((rgba >> 24) & 0xFF) / 255.0
                         green:((rgba >> 16) & 0xFF) / 255.0
                          blue:((rgba >> 8) & 0xFF) / 255.0
                         alpha:(rgba & 0xFF) / 255.0];
}

@end
