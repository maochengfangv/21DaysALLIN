#import "InterviewFabricCardComponentView.h"

#import <React/RCTConversions.h>

#if __has_include(<react/renderer/components/InterviewNativeKit/ComponentDescriptors.h>)
#import <react/renderer/components/InterviewNativeKit/ComponentDescriptors.h>
#import <react/renderer/components/InterviewNativeKit/Props.h>
#import <react/renderer/components/InterviewNativeKit/RCTComponentViewHelpers.h>
#endif

using namespace facebook::react;

@interface InterviewFabricCardComponentView () <RCTInterviewFabricCardViewProtocol>
@end

@implementation InterviewFabricCardComponentView {
  UILabel *_labelView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<InterviewFabricCardComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const InterviewFabricCardProps>();
    _props = defaultProps;

    self.clipsToBounds = YES;
    self.backgroundColor = [UIColor colorWithRed:0.114 green:0.306 blue:0.847 alpha:1.0];

    _labelView = [[UILabel alloc] initWithFrame:CGRectZero];
    _labelView.textAlignment = NSTextAlignmentCenter;
    _labelView.textColor = UIColor.whiteColor;
    _labelView.font = [UIFont boldSystemFontOfSize:18];
    _labelView.text = @"Fabric Native Card";
    [self addSubview:_labelView];
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _labelView.frame = self.bounds;
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &newProps = *std::static_pointer_cast<const InterviewFabricCardProps>(props);

  [super updateProps:props oldProps:oldProps];

  NSString *labelText =
      newProps.label.empty() ? @"Fabric Native Card" : [NSString stringWithUTF8String:newProps.label.c_str()];
  _labelView.text = labelText;

  self.backgroundColor = newProps.cardBackgroundColor
      ? RCTUIColorFromSharedColor(newProps.cardBackgroundColor)
      : [UIColor colorWithRed:0.114 green:0.306 blue:0.847 alpha:1.0];
  self.layer.cornerRadius = newProps.cornerRadius;
}

Class<RCTComponentViewProtocol> InterviewFabricCardCls(void)
{
  return InterviewFabricCardComponentView.class;
}

@end
