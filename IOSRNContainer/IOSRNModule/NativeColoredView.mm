#import "NativeColoredView.h"
#import <react/renderer/components/MyRNAppSpecs/ComponentDescriptors.h>
#import <react/renderer/components/MyRNAppSpecs/Props.h>
#import <react/renderer/components/MyRNAppSpecs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface NativeColoredView () <RCTNativeColoredViewViewProtocol>
- (void)invalidateLayer;
@end

@implementation NativeColoredView

+ (void)load
{
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<NativeColoredViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const NativeColoredViewProps>();
    _props = defaultProps;
  }
  return self;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newViewProps = *std::static_pointer_cast<const NativeColoredViewProps>(props);

  [super updateProps:props oldProps:oldProps];

  if (!newViewProps.color.empty()) {
    NSString *hexString = [NSString stringWithUTF8String:newViewProps.color.c_str()];
    if (hexString.length > 0) {
      self.backgroundColor = [self rgbaFromHexString:hexString];
      [self invalidateLayer];
    }
  }

  self.layer.cornerRadius = newViewProps.cornerRadius;
}

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
