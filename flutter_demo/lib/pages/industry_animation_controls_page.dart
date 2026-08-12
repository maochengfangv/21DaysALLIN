import 'package:flutter/material.dart';

class _AnimationTokens {
  const _AnimationTokens._();

  static const Duration press = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration emphasized = Duration(milliseconds: 280);
  static const Duration fade = Duration(milliseconds: 200);
  static const Duration progress = Duration(milliseconds: 900);

  static const Duration delayNone = Duration.zero;
  static const Duration delayShort = Duration(milliseconds: 80);
  static const Duration delayMedium = Duration(milliseconds: 160);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve pressCurve = Curves.easeOut;
}

class IndustryAnimationControlsPage extends StatelessWidget {
  static const routeName = '/industry-animation-controls';

  const IndustryAnimationControlsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大厂 Flutter 动画控件 Demo'),
      ),
      body: const _IndustryAnimationControlsView(),
    );
  }
}

class _IndustryAnimationControlsView extends StatefulWidget {
  const _IndustryAnimationControlsView();

  @override
  State<_IndustryAnimationControlsView> createState() =>
      _IndustryAnimationControlsViewState();
}

class _IndustryAnimationControlsViewState
    extends State<_IndustryAnimationControlsView> {
  _DemoViewState _state = _DemoViewState.content;
  bool _noticeVisible = true;
  bool _expanded = false;

  void _showActionPanel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return const _ActionPanel();
      },
    );
  }

  void _openHeroDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _HeroDetailPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: '为什么这些控件是 P0',
          subtitle: '交互反馈、状态切换、弹层、通知条、展开收起、共享元素，基本覆盖内容型与商城型 App 的高频动画场景。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TagChip(label: '交互反馈'),
              _TagChip(label: '状态过渡'),
              _TagChip(label: '弹层转场'),
              _TagChip(label: '通知提示'),
              _TagChip(label: '展开收起'),
              _TagChip(label: 'Hero 转场'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '1. 点击反馈控件',
          subtitle: '大厂高频做法：按下轻缩放，抬起恢复，同时保留轻量阴影与圆角。',
          child: _PressFeedbackCard(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('点击反馈已触发')),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '2. 状态过渡控件',
          subtitle: '首屏、搜索、列表页最常见：loading / content / empty / error 平滑切换。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatePill(
                    text: 'Loading',
                    selected: _state == _DemoViewState.loading,
                    onTap: () => setState(() => _state = _DemoViewState.loading),
                  ),
                  _StatePill(
                    text: 'Content',
                    selected: _state == _DemoViewState.content,
                    onTap: () => setState(() => _state = _DemoViewState.content),
                  ),
                  _StatePill(
                    text: 'Empty',
                    selected: _state == _DemoViewState.empty,
                    onTap: () => setState(() => _state = _DemoViewState.empty),
                  ),
                  _StatePill(
                    text: 'Error',
                    selected: _state == _DemoViewState.error,
                    onTap: () => setState(() => _state = _DemoViewState.error),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: _AnimationTokens.standard,
                switchInCurve: _AnimationTokens.enter,
                switchOutCurve: _AnimationTokens.exit,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: _StateView(
                  key: ValueKey<_DemoViewState>(_state),
                  state: _state,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '3. 浮层通知控件',
          subtitle: '用于优惠提醒、运营提示、网络恢复通知，通常采用 slide + fade 组合。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.tonal(
                onPressed: () =>
                    setState(() => _noticeVisible = !_noticeVisible),
                child: Text(_noticeVisible ? '隐藏通知' : '显示通知'),
              ),
              const SizedBox(height: 12),
              AnimatedSlide(
                duration: _AnimationTokens.emphasized,
                curve: _AnimationTokens.enter,
                offset: _noticeVisible ? Offset.zero : const Offset(0, -0.25),
                child: AnimatedOpacity(
                  duration: _AnimationTokens.fade,
                  opacity: _noticeVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_noticeVisible,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '限时活动开始，首页会场已更新，点击查看最新推荐内容。',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '4. 展开收起控件',
          subtitle: 'FAQ、商品说明、评论详情、大段文案折叠是典型高频场景。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '收起内容' : '展开内容'),
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: _AnimationTokens.standard,
                curve: _AnimationTokens.standardCurve,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _expanded ? 240 : 72,
                  ),
                  child: Text(
                    'Flutter 在业务侧最常见的动画，不一定是复杂特效，而是让状态切换更自然、让操作反馈更明确。'
                    '真正的大厂动画体系，重点通常是统一规范、减少突兀感、控制重绘范围，并对低端机提供合理降级。'
                    '所以在工程实践里，动画从来不是单独存在的，它一定和组件封装、性能治理、埋点观测放在一起看。',
                    style: theme.textTheme.bodyMedium,
                    overflow:
                        _expanded ? TextOverflow.visible : TextOverflow.fade,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '5. 底部弹层控件',
          subtitle: '筛选、操作面板、分享面板、支付确认，通常都要有统一转场风格。',
          child: FilledButton(
            onPressed: _showActionPanel,
            child: const Text('打开底部操作面板'),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '6. Hero 共享元素',
          subtitle: '内容卡片进入详情页，是大厂内容流、商城、社区里非常高频的过渡模式。',
          child: GestureDetector(
            onTap: _openHeroDetail,
            child: Hero(
              tag: 'industry_hero_card',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 160,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 34),
                      Spacer(),
                      Text(
                        '共享元素转场',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '点击进入详情页',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _DemoViewState {
  loading,
  content,
  empty,
  error,
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label),
      ),
    );
  }
}

class _PressFeedbackCard extends StatefulWidget {
  final VoidCallback onTap;

  const _PressFeedbackCard({required this.onTap});

  @override
  State<_PressFeedbackCard> createState() => _PressFeedbackCardState();
}

class _PressFeedbackCardState extends State<_PressFeedbackCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: _AnimationTokens.press,
        curve: _AnimationTokens.pressCurve,
        scale: _pressed ? 0.97 : 1,
        child: AnimatedContainer(
          duration: _AnimationTokens.quick,
          curve: _AnimationTokens.enter,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.06 : 0.12),
                blurRadius: _pressed ? 10 : 20,
                offset: Offset(0, _pressed ? 4 : 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.touch_app_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('按下缩放 + 抬起恢复，是最常见也最实用的交互反馈动画。'),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _StatePill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StateView extends StatelessWidget {
  final _DemoViewState state;

  const _StateView({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DemoViewState.loading:
        return const _LoadingPanel();
      case _DemoViewState.content:
        return const _ContentPanel();
      case _DemoViewState.empty:
        return const _EmptyPanel();
      case _DemoViewState.error:
        return const _ErrorPanel();
    }
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '推荐内容已加载完成',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('这里通常对应首页 Feed、商品列表、搜索结果页的正常内容态。'),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 0.9),
            duration: _AnimationTokens.progress,
            curve: _AnimationTokens.enter,
            builder: (context, value, _) {
              return LinearProgressIndicator(value: value);
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 28),
            SizedBox(height: 8),
            Text('暂无内容，试试切换筛选条件'),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 28),
            SizedBox(height: 8),
            Text('请求失败，请稍后重试'),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _ActionTile(icon: Icons.bookmark_border, title: '收藏'),
          _ActionTile(icon: Icons.share_outlined, title: '分享'),
          _ActionTile(icon: Icons.link_outlined, title: '复制链接'),
          _ActionTile(icon: Icons.report_gmailerrorred_outlined, title: '举报'),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ActionTile({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pop(),
    );
  }
}

class _HeroDetailPage extends StatelessWidget {
  const _HeroDetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('共享元素详情')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Hero(
          tag: 'industry_hero_card',
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 44),
                  SizedBox(height: 24),
                  Text(
                    'Hero 动画详情页',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '这是大厂内容流和商城最常见的共享元素转场模式：卡片进详情，视觉连续，用户不会“丢位置”。',
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}