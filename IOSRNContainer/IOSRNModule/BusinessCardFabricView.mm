#import "BusinessCardFabricView.h"
#if __has_include(<react/renderer/components/MyRNAppSpecs/ComponentDescriptors.h>)
#import <react/renderer/components/MyRNAppSpecs/ComponentDescriptors.h>
#import <react/renderer/components/MyRNAppSpecs/Props.h>
#import <react/renderer/components/MyRNAppSpecs/RCTComponentViewHelpers.h>
#import <react/renderer/components/MyRNAppSpecs/EventEmitters.h>
#endif
#import <QuartzCore/QuartzCore.h>

using namespace facebook::react;

@interface BusinessCardFabricView ()
#if __has_include(<react/renderer/components/MyRNAppSpecs/RCTComponentViewHelpers.h>)
<RCTBusinessCardFabricViewViewProtocol>
#endif
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UILabel *tagLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIStackView *actionStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *actionButtons;
@property (nonatomic, strong) NSDictionary *parsedCardData;
@property (nonatomic, strong) NSArray *parsedActions;
@property (nonatomic, assign) BOOL hasReportedExposure;
@end

@implementation BusinessCardFabricView

#if __has_include(<react/renderer/components/MyRNAppSpecs/ComponentDescriptors.h>)
+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<BusinessCardFabricViewComponentDescriptor>();
}
#endif

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
#if __has_include(<react/renderer/components/MyRNAppSpecs/Props.h>)
    static const auto defaultProps = std::make_shared<const BusinessCardFabricViewProps>();
    _props = defaultProps;
#endif
    self.actionButtons = [NSMutableArray array];
    self.hasReportedExposure = NO;
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  self.clipsToBounds = NO;
  self.backgroundColor = [UIColor whiteColor];
  self.layer.cornerRadius = 16;
  self.layer.masksToBounds = YES;
  self.layer.shadowColor = [UIColor blackColor].CGColor;
  self.layer.shadowOpacity = 0.08;
  self.layer.shadowOffset = CGSizeMake(0, 4);
  self.layer.shadowRadius = 12;

  _contentContainer = [[UIView alloc] init];
  _contentContainer.backgroundColor = [UIColor whiteColor];
  _contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_contentContainer];
  [NSLayoutConstraint activateConstraints:@[
    [_contentContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
    [_contentContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
    [_contentContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    [_contentContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
  ]];

  _coverImageView = [[UIImageView alloc] init];
  _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
  _coverImageView.clipsToBounds = YES;
  _coverImageView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
  _coverImageView.translatesAutoresizingMaskIntoConstraints = NO;
  _coverImageView.userInteractionEnabled = YES;
  UITapGestureRecognizer *coverTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
  [_coverImageView addGestureRecognizer:coverTap];
  [_contentContainer addSubview:_coverImageView];

  _tagLabel = [[UILabel alloc] init];
  _tagLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
  _tagLabel.textColor = [UIColor colorWithRed:0.31 green:0.27 blue:0.9 alpha:1];
  _tagLabel.backgroundColor = [UIColor colorWithRed:0.93 green:0.95 blue:1 alpha:1];
  _tagLabel.textAlignment = NSTextAlignmentCenter;
  _tagLabel.layer.cornerRadius = 999;
  _tagLabel.layer.masksToBounds = YES;
  _tagLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_tagLabel];

  _titleLabel = [[UILabel alloc] init];
  _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
  _titleLabel.textColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.15 alpha:1];
  _titleLabel.numberOfLines = 2;
  _titleLabel.userInteractionEnabled = YES;
  UITapGestureRecognizer *titleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
  [_titleLabel addGestureRecognizer:titleTap];
  _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_titleLabel];

  _subtitleLabel = [[UILabel alloc] init];
  _subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  _subtitleLabel.textColor = [UIColor colorWithRed:0.29 green:0.33 blue:0.39 alpha:1];
  _subtitleLabel.numberOfLines = 1;
  _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_subtitleLabel];

  _descriptionLabel = [[UILabel alloc] init];
  _descriptionLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
  _descriptionLabel.textColor = [UIColor colorWithRed:0.42 green:0.45 blue:0.5 alpha:1];
  _descriptionLabel.numberOfLines = 2;
  _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_descriptionLabel];

  _authorLabel = [[UILabel alloc] init];
  _authorLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
  _authorLabel.textColor = [UIColor colorWithRed:0.15 green:0.39 blue:0.92 alpha:1];
  _authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_authorLabel];

  _timeLabel = [[UILabel alloc] init];
  _timeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  _timeLabel.textColor = [UIColor colorWithRed:0.42 green:0.45 blue:0.5 alpha:1];
  _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_timeLabel];

  _actionStack = [[UIStackView alloc] init];
  _actionStack.axis = UILayoutConstraintAxisHorizontal;
  _actionStack.spacing = 10;
  _actionStack.distribution = UIStackViewDistributionFillEqually;
  _actionStack.layoutMarginsRelativeArrangement = YES;
  _actionStack.layoutMargins = UIEdgeInsetsMake(12, 16, 12, 16);
  _actionStack.translatesAutoresizingMaskIntoConstraints = NO;
  [_contentContainer addSubview:_actionStack];

  [NSLayoutConstraint activateConstraints:@[
    [_coverImageView.topAnchor constraintEqualToAnchor:_contentContainer.topAnchor],
    [_coverImageView.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor],
    [_coverImageView.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor],
    [_coverImageView.heightAnchor constraintEqualToAnchor:_coverImageView.widthAnchor multiplier:9.0/16.0],

    [_tagLabel.topAnchor constraintEqualToAnchor:_coverImageView.topAnchor constant:12],
    [_tagLabel.leadingAnchor constraintEqualToAnchor:_coverImageView.leadingAnchor constant:12],
    [_tagLabel.heightAnchor constraintEqualToConstant:24],

    [_titleLabel.topAnchor constraintEqualToAnchor:_coverImageView.bottomAnchor constant:16],
    [_titleLabel.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor constant:16],
    [_titleLabel.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor constant:-16],

    [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6],
    [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor constant:16],
    [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor constant:-16],

    [_descriptionLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:6],
    [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor constant:16],
    [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor constant:-16],

    [_authorLabel.topAnchor constraintEqualToAnchor:_descriptionLabel.bottomAnchor constant:8],
    [_authorLabel.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor constant:16],

    [_timeLabel.centerYAnchor constraintEqualToAnchor:_authorLabel.centerYAnchor],
    [_timeLabel.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor constant:-16],

    [_actionStack.topAnchor constraintEqualToAnchor:_authorLabel.bottomAnchor constant:12],
    [_actionStack.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor],
    [_actionStack.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor],
    [_actionStack.bottomAnchor constraintEqualToAnchor:_contentContainer.bottomAnchor],
  ]];
}

#if __has_include(<react/renderer/components/MyRNAppSpecs/Props.h>)
- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps = *std::static_pointer_cast<const BusinessCardFabricViewProps>(props);
  [super updateProps:props oldProps:oldProps];

  self.layer.cornerRadius = newProps.cornerRadius;
  self.layer.shadowOpacity = newProps.enableShadow ? 0.08 : 0;

  NSString *cardData = [NSString stringWithUTF8String:newProps.cardData.c_str()];
  if (cardData.length > 0) {
    NSData *jsonData = [cardData dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData) {
      NSError *error = nil;
      NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
      if (dict && error == nil) {
        self.parsedCardData = dict;
        [self applyCardData:dict];
      }
    }
  }

  NSString *actions = [NSString stringWithUTF8String:newProps.actions.c_str()];
  if (actions.length > 0) {
    NSData *jsonData = [actions dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData) {
      NSError *error = nil;
      NSArray *arr = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
      if (arr && error == nil && [arr isKindOfClass:[NSArray class]]) {
        self.parsedActions = arr;
        [self applyActions:arr];
      }
    }
  }
}
#endif

- (void)applyCardData:(NSDictionary *)data {
  _titleLabel.text = data[@"title"] ?: @"";
  _subtitleLabel.text = data[@"subtitle"] ?: @"";
  _descriptionLabel.text = data[@"description"] ?: @"";
  _authorLabel.text = data[@"author"] ? [NSString stringWithFormat:@"👤 %@", data[@"author"]] : @"";

  NSString *tag = data[@"tag"];
  if (tag && ![tag isEqualToString:@""]) {
    _tagLabel.text = [NSString stringWithFormat:@"  %@  ", tag];
    _tagLabel.hidden = NO;
  } else {
    _tagLabel.hidden = YES;
  }

  NSNumber *tsNum = data[@"timestamp"];
  if (tsNum) {
    _timeLabel.text = [NSString stringWithFormat:@"⏱ %@", [self formatTime:[tsNum doubleValue]]];
  } else {
    _timeLabel.text = @"";
  }

  NSString *cover = data[@"coverUrl"];
  if (cover && ![cover isEqualToString:@""]) {
    NSURL *url = [NSURL URLWithString:cover];
    if (url) {
      [self loadRemoteImage:url];
    }
  } else {
    _coverImageView.image = nil;
  }

  if (!self.hasReportedExposure) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      if (self.hasReportedExposure) return;
      self.hasReportedExposure = YES;
      NSString *cardId = data[@"cardId"] ?: @"";
#if __has_include(<react/renderer/components/MyRNAppSpecs/EventEmitters.h>)
      auto eventEmitter = std::static_pointer_cast<const BusinessCardFabricViewEventEmitter>(_eventEmitter);
      if (eventEmitter) {
        eventEmitter->onExposure({
          .cardId = [cardId UTF8String],
          .timestamp = [[NSDate date] timeIntervalSince1970] * 1000.0
        });
      }
#endif
    });
  }
}

- (void)applyActions:(NSArray *)actions {
  for (UIButton *btn in self.actionButtons) {
    [btn removeFromSuperview];
  }
  [self.actionButtons removeAllObjects];

  _actionStack.hidden = actions.count == 0;
  __weak typeof(self) weakSelf = self;
  [actions enumerateObjectsUsingBlock:^(NSDictionary *action, NSUInteger idx, BOOL *stop) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:action[@"title"] ?: @"" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.tag = idx;
    BOOL isPrimary = (idx == 0);
    button.backgroundColor = isPrimary
      ? [UIColor colorWithRed:0 green:0.48 blue:1 alpha:1]
      : [UIColor colorWithRed:0.95 green:0.96 blue:0.97 alpha:1];
    [button setTitleColor:isPrimary ? [UIColor whiteColor] : [UIColor colorWithRed:0.22 green:0.25 blue:0.32 alpha:1]
                 forState:UIControlStateNormal];
    button.layer.cornerRadius = MIN(16 * 0.5, 10);
    button.layer.masksToBounds = YES;
    [button addTarget:weakSelf action:@selector(handleActionTap:) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:40].active = YES;
    [weakSelf.actionStack addArrangedSubview:button];
    [weakSelf.actionButtons addObject:button];
  }];
}

- (void)handleTap {
  NSString *cardId = self.parsedCardData[@"cardId"] ?: @"";
#if __has_include(<react/renderer/components/MyRNAppSpecs/EventEmitters.h>)
  auto eventEmitter = std::static_pointer_cast<const BusinessCardFabricViewEventEmitter>(_eventEmitter);
  if (eventEmitter) {
    eventEmitter->onCardPress({.cardId = [cardId UTF8String]});
  }
#endif
}

- (void)handleActionTap:(UIButton *)sender {
  if (sender.tag >= self.parsedActions.count) return;
  NSDictionary *action = self.parsedActions[sender.tag];
  NSString *cardId = self.parsedCardData[@"cardId"] ?: @"";
  NSString *actionId = action[@"id"] ?: @"";
  int actionType = [action[@"actionType"] intValue] ?: 0;
#if __has_include(<react/renderer/components/MyRNAppSpecs/EventEmitters.h>)
  auto eventEmitter = std::static_pointer_cast<const BusinessCardFabricViewEventEmitter>(_eventEmitter);
  if (eventEmitter) {
    eventEmitter->onActionPress({
      .cardId = [cardId UTF8String],
      .actionId = [actionId UTF8String],
      .actionType = actionType
    });
  }
#endif
}

- (NSString *)formatTime:(double)timestampMs {
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestampMs / 1000.0];
  NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:date];
  if (diff < 60) return @"刚刚";
  if (diff < 3600) return [NSString stringWithFormat:@"%ld分钟前", (long)(diff/60)];
  if (diff < 86400) return [NSString stringWithFormat:@"%ld小时前", (long)(diff/3600)];
  if (diff < 86400 * 7) return [NSString stringWithFormat:@"%ld天前", (long)(diff/86400)];
  NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
  fmt.dateFormat = @"yyyy-MM-dd";
  return [fmt stringFromDate:date];
}

- (void)loadRemoteImage:(NSURL *)url {
  NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (data && !error) {
      UIImage *image = [UIImage imageWithData:data];
      if (image) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.coverImageView.image = image;
        });
      }
    }
  }];
  [task resume];
}

- (void)prepareForRecycle {
  self.hasReportedExposure = NO;
  [super prepareForRecycle];
}

@end
