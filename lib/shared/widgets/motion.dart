import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Whether the user has asked the OS to reduce motion.
///
/// Honouring this is not optional polish: every animation in the app routes
/// through here, so the whole UI degrades to instant, fully-functional state
/// for someone who has turned animation off at the system level.
bool reduceMotionOf(BuildContext context) {
  final MediaQueryData? media = MediaQuery.maybeOf(context);
  if (media == null) return false;
  return media.disableAnimations || media.accessibleNavigation;
}

/// Milliseconds of delay before the child at [index] starts its entrance.
///
/// Bounded by [maxStaggered]: past that index the delay stops growing, so the
/// twentieth card in a long list is not still waiting after the eleventh has
/// already appeared.
int staggerDelayFor(int index, {int maxStaggered = 8}) =>
    index.clamp(0, maxStaggered) * AppDurations.stagger.inMilliseconds;

/// Content that fades and rises into place on first build.
///
/// This is the app's single entrance primitive. It is a widget rather than a
/// helper function so every entrance shares one curve, one distance and one
/// duration — a screen whose sections each animate on their own schedule reads
/// as janky, not as designed.
///
/// With reduced motion on it renders the child immediately and never starts a
/// controller.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.06),
    this.duration = AppDurations.entrance,
  });

  final Widget child;

  /// Delay before the animation starts. Combine with [staggerDelayFor] to
  /// cascade a list.
  final Duration delay;

  /// How far below its final position the child starts, as a fraction of its
  /// own size.
  final Offset offset;

  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: AppCurves.entrance,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.entrance));

  /// Set in [didChangeDependencies], never in [initState] — see the comment
  /// there.
  bool _disabled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // MediaQuery must not be read here. Doing so registers an
    // inherited-widget dependency from initState, which Flutter forbids and
    // which throws in debug mode with a wall of advice about didChangeDependencies.
    // didChangeDependencies runs immediately after this and sets _disabled
    // before the first build, so nothing is painted in the meantime.
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context) && !_disabled) {
      // The setting can also change at runtime, so re-check rather than
      // latching it once.
      _disabled = true;
      _timer?.cancel();
      _controller.value = 1;
    }
  }

  void _schedule() {
    if (widget.delay > Duration.zero) {
      // A real Timer rather than Future.delayed, so it can be cancelled. A
      // pending delay that fires into a disposed State is a leak.
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disabled) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Lays children out vertically, cascading each one in.
///
/// A drop-in replacement for a plain `Column` in a list of cards or rows: it
/// only adds the stagger, so sizing, scrolling and each child's own layout are
/// untouched.
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
    this.spacing = 0,
    this.runSpacing,
    this.stagger = AppDurations.stagger,
    this.maxStaggered = 8,
    this.enabled = true,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  /// Fixed gap inserted between every pair of children.
  final double spacing;

  /// Overrides [spacing] for the whole column.
  final double? runSpacing;

  /// Delay added per index. [Duration.zero] disables the cascade.
  final Duration stagger;

  /// Index at which the delay stops growing.
  final int maxStaggered;

  /// Set false to render the children with no animation at all.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool animate =
        enabled && stagger > Duration.zero && !reduceMotionOf(context);

    if (!animate) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        spacing: runSpacing ?? spacing,
        children: children,
      );
    }

    final List<Widget> out = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0 && spacing > 0) out.add(SizedBox(height: spacing));
      out.add(
        FadeSlideIn(
          delay: Duration(
            milliseconds: staggerDelayFor(i, maxStaggered: maxStaggered),
          ),
          child: children[i],
        ),
      );
    }

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      spacing: runSpacing ?? spacing,
      children: out,
    );
  }
}

/// Wraps a tappable widget so it dips slightly under the finger.
///
/// Ink ripples alone are easy to miss, and on a card-sized target the ripple
/// is the only feedback for several hundred milliseconds. A scale change is
/// legible at a glance and gives the touch physicality.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.fast,
    reverseDuration: AppDurations.fast,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: widget.scale,
  ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.standard));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool tappable = widget.onTap != null || widget.onLongPress != null;
    if (!tappable || reduceMotionOf(context)) {
      return GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// A number that counts up to its value when it changes.
///
/// Used for the money figures that decide whether someone feels good or bad
/// about their trip. The point is not the number arriving — it is that the
/// change is *noticed*. A figure silently swapping between two values is easy
/// to miss, and these figures sit next to one another on a card.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.style,
    this.duration = AppDurations.emphasis,
  });

  /// The value to interpolate towards.
  final double value;

  /// Builds the text for an intermediate value.
  final String Function(double value) builder;

  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) {
      return Text(builder(value), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: AppCurves.emphasis,
      builder:
          (BuildContext context, double v, Widget? _) =>
              Text(builder(v), style: style),
    );
  }
}

/// Eases between two widgets with a cross-fade and a short directional slide.
///
/// Direction-aware: a swap that moves forward slides in from the right, one
/// that moves back slides in from the left. This is what stops a tab switch or
/// a filter change from reading as a hard cut.
class AnimatedSwitcherSlide extends StatelessWidget {
  const AnimatedSwitcherSlide({
    super.key,
    required this.child,
    this.duration = AppDurations.normal,
    this.forward = true,
  });

  final Widget child;
  final Duration duration;

  /// True when the new content is further along the flow.
  final bool forward;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return child;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppCurves.entrance,
      switchOutCurve: AppCurves.exit,
      // `animation` is the switcher's own incoming/outgoing animation, already
      // shaped by switchInCurve/switchOutCurve. Driving the slide off it
      // rather than a fresh controller is what keeps the two in lockstep.
      transitionBuilder:
          (Widget current, Animation<double> animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(forward ? 0.05 : -0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: current,
            ),
          ),
      layoutBuilder:
          (Widget? current, List<Widget> previous) => Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[...previous, ?current],
          ),
      child: child,
    );
  }
}

/// Constrains and centres a page body, scaling its gutters with the window.
///
/// This is the most important layout fix in the app. Without it a list card or
/// a form stretches the full width of a desktop browser, putting the content
/// 1900px from the navigation. Phones are unaffected — their gutter is just
/// [AppSpacing.lg].
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.verticalPadding = 0,
    this.alignment = Alignment.topCenter,
  }) : _horizontalPadding = null;

  /// Narrower cap for single-column forms, where a comfortable measure is
  /// closer to 45-55 characters than to a full dashboard row.
  const PageBody.form({
    super.key,
    required this.child,
    this.padding,
    this.verticalPadding = 0,
  }) : maxWidth = AppBreakpoints.maxFormWidth,
       alignment = Alignment.topCenter,
       _horizontalPadding = null;

  final Widget child;

  /// Defaults to [AppBreakpoints.maxContentWidth].
  final double? maxWidth;

  /// Overrides both horizontal and vertical padding.
  final EdgeInsets? padding;

  /// An explicit horizontal gutter. Null picks one from the breakpoint.
  final double? _horizontalPadding;

  final double verticalPadding;
  final Alignment alignment;

  /// The gutter a given window should use.
  static double gutterFor(double width) {
    if (width >= AppBreakpoints.desktop) return AppSpacing.xxxl;
    if (width >= AppBreakpoints.tablet) return AppSpacing.xxl;
    return AppSpacing.lg;
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppBreakpoints.maxContentWidth,
        ),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: _horizontalPadding ?? gutterFor(width),
                vertical: verticalPadding,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// A card whose border is painted with the brand gradient.
///
/// Material's [Card] only supports a flat [BorderSide], so the ring is painted
/// by hand. Meant for the one or two elements on a screen that should read as
/// the focal point — a primary summary, the active selection — rather than for
/// every card, which would flatten the hierarchy.
class GradientBorderCard extends StatelessWidget {
  const GradientBorderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.colors,
    this.borderRadius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final List<Color>? colors;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Color> ring = colors ?? <Color>[AppGradientsTheme.of(context).brand];
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    final Widget content = Padding(padding: padding, child: child);

    return PressableScale(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ring.first.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            content,
            // The ring, inset by 1px so it sits just inside the rounded corner
            // rather than colliding with it.
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius - 1),
                      gradient: AppGradients.linear(colors: ring),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's wordmark: a gradient tile with the mark inside it.
///
/// Used in the navigation rail, the splash screen and the auth header, so the
/// brand reads as one object rather than three different hand-drawn icons.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.iconSize});

  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppGradientsTheme.of(context).brand,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ringShadowOf(context, size),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: Icon(
        Icons.explore_rounded,
        size: iconSize ?? size * 0.58,
        color: Colors.white,
      ),
    );
  }

  static Color ringShadowOf(BuildContext context, double size) {
    final Color brand = AppGradientsTheme.of(context).brand;
    return brand.withValues(alpha: size > 40 ? 0.32 : 0.40);
  }
}

/// A shimmering loading placeholder: a highlight sweeping across the box.
///
/// Replaces the previous symmetric pulse, which made every loading state look
/// frozen. The sweep reads as progress, which is what someone waiting on a
/// network call actually wants to see.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color base = theme.colorScheme.surfaceContainerHighest;

    if (reduceMotionOf(context)) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    final Color highlight = Color.lerp(base, theme.colorScheme.surface, 0.6)!;

    return _Shimmer(
      width: width,
      height: height,
      borderRadius: borderRadius,
      base: base,
      highlight: highlight,
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.base,
    required this.highlight,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color base;
  final Color highlight;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        // Sweep the highlight from fully left of the box to fully right of it.
        final double sweep = _controller.value * 3.2 - 1.6;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(sweep, -0.3),
              end: Alignment(sweep + 1, 0.3),
              colors: <Color>[widget.base, widget.highlight, widget.base],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A network image that cross-fades in and leaves whatever is layered
/// underneath visible if it cannot load.
///
/// Returns nothing on error, so the caller decides what to show rather than
/// getting a grey box that is indistinguishable from a merely slow image.
class CrossfadeImage extends StatelessWidget {
  const CrossfadeImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      // Without a cache these are re-downloaded on every rebuild, which on a
      // list of cards is dozens of requests per scroll.
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: AppDurations.normal,
              curve: AppCurves.entrance,
              child: child,
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? _) =>
              const SizedBox.shrink(),
    );
  }
}

/// A network image that always has something to show.
///
/// Three states, all designed:
///
///  * loading — a shimmer sweep, so the placeholder reads as work in progress
///  * loaded — cross-faded in over the placeholder
///  * failed — a brand gradient with an icon, rather than the bare tinted
///    rectangle the old `errorBuilder`s returned, which was indistinguishable
///    from an image that was merely slow
class NetworkArtwork extends StatelessWidget {
  const NetworkArtwork({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.landscape_outlined,
    this.borderRadius = 0,
  });

  final String url;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color brand = AppGradientsTheme.of(context).brand;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Positioned.fill, not an explicit height: a Container asking for
          // infinite height inside an unbounded parent is invalid constraints.
          Positioned.fill(
            child: ShimmerBox(
              height: null,
              borderRadius: borderRadius,
            ),
          ),
          Image.network(
            url,
            fit: fit,
            frameBuilder:
                (
                  BuildContext context,
                  Widget child,
                  int? frame,
                  bool wasSynchronouslyLoaded,
                ) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: AppDurations.normal,
                    curve: AppCurves.entrance,
                    child: child,
                  );
                },
            errorBuilder:
                (BuildContext context, Object error, StackTrace? _) =>
                    DecoratedBox(
decoration: BoxDecoration(
        color: brand,
      ),
                      child: Center(
                        child: Icon(
                          fallbackIcon,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 32,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

/// Scroll behaviour shared by every tab page.
class ScrollAwareShell extends StatelessWidget {
  const ScrollAwareShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _TripSplitScrollBehavior(),
      child: child,
    );
  }
}

class _TripSplitScrollBehavior extends MaterialScrollBehavior {
  const _TripSplitScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  /// Momentum tuned for a short phone list flings a desktop browser far past
  /// the end of the content and leaves it sitting on blank canvas.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // On a pointer device a persistent scrollbar is the only cue that there is
    // more content below the fold.
    if (!AppBreakpoints.isPointerHovering(context)) return child;
    if (details.controller == null) return child;

    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      radius: const Radius.circular(AppRadius.pill),
      thickness: 6,
      child: child,
    );
  }
}
