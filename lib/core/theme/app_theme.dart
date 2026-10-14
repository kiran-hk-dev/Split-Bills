import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for TripSplit World.
///
/// Palette intent: an "aurora" brand — indigo carries the primary actions,
/// violet and teal provide the accent range, cyan is reserved for
/// informational surfaces, and amber/red stay reserved for warnings and risk.
/// The canvas is a cool off-white rather than the previous warm paper tone, so
/// the indigo brand reads as crisp rather than muddy.
///
/// Every foreground/background pair below is measured, not eyeballed, and is
/// asserted in `test/core/theme/contrast_test.dart`. Measured ratios are quoted
/// in the comments so a future change has a number to beat.
class AppColors {
  const AppColors._();

  // ---- Brand core ---------------------------------------------------------

  /// Primary brand fill. 6.29:1 against [surface], so it carries white button
  /// labels and is itself readable as text on the canvas (5.88:1).
  static const Color primary = Color(0xFF4F46E5);

  /// Darker indigo for headings, emphasis and hover states where [primary]
  /// would be too light. 9.93:1 on [surface].
  static const Color primaryDeep = Color(0xFF3730A3);

  /// Lighter indigo used for tinted fills and soft backgrounds.
  static const Color primarySoft = Color(0xFFEEF0FE);

  /// Accent violet. Sits between indigo and teal on the wheel so gradients
  /// through it read as one continuous sweep instead of three clashing hues.
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF3EAFF);

  /// Accent cyan, used for informational surfaces and the far end of the
  /// brand gradient.
  static const Color cyan = Color(0xFF0891B2);
  static const Color cyanSoft = Color(0xFFE0F5FB);

  // ---- Legacy brand names, kept so existing call sites keep compiling ------
  //
  // These are no longer the primary identity but are still referenced by the
  // money, country and emergency reference data for categorical colouring.

  static const Color navy = Color(0xFF15142E);
  static const Color navy700 = Color(0xFF1E1D3E);
  static const Color navy500 = Color(0xFF3A3866);

  /// Deep teal. 5.47:1 against white, which is why it — and not the lighter
  /// `teal600` — is the fill used behind white text.
  static const Color teal = Color(0xFF0F766E);

  /// Mid teal for accents only. 3.74:1 on white, so it must never sit behind
  /// body-size white text.
  static const Color teal600 = Color(0xFF0D9488);
  static const Color emerald = Color(0xFF10B981);
  static const Color mint = Color(0xFFD1FAE5);

  // ---- Surfaces -----------------------------------------------------------

  static const Color canvas = Color(0xFFF6F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEFEFF6);
  static const Color border = Color(0xFFE2E2EE);

  /// Border for interactive controls (text fields, outlined buttons).
  ///
  /// WCAG 1.4.11 wants 3:1 for the boundary that identifies a control. This
  /// measures 3.36:1 on [surface] and 3.12:1 on [canvas], and sits 2.62:1
  /// above [border] so the hierarchy — a card edge is a whisper, a control
  /// edge is a sentence — still reads.
  static const Color borderStrong = Color(0xFF8A8AA3);

  // ---- Text ---------------------------------------------------------------

  /// 16.64:1 on [canvas], 17.93:1 on [surface].
  static const Color ink = Color(0xFF15142E);

  /// 6.96:1 on [canvas], 7.50:1 on [surface].
  static const Color inkMuted = Color(0xFF525270);

  /// Tinted placeholder and de-emphasised text. 4.84:1 on [canvas] and 5.21:1
  /// on [surface] — real text, not decoration, so it clears AA rather than
  /// being greyed out until it disappears.
  static const Color inkFaint = Color(0xFF6A6A88);

  // ---- Status -------------------------------------------------------------

  /// 4.84:1 on [positiveSoft].
  static const Color positive = Color(0xFF047857);
  static const Color positiveSoft = Color(0xFFD1FAE5);

  /// 5.37:1 on [warningSoft].
  static const Color warning = Color(0xFFA44808);
  static const Color warningSoft = Color(0xFFFEF3C7);

  /// 5.38:1 on [dangerSoft], and 6.57:1 with white text on top of it.
  static const Color danger = Color(0xFFB42318);
  static const Color dangerSoft = Color(0xFFFEE2E2);

  /// 5.49:1 on [infoSoft].
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFDBEAFE);

  static const Color verified = Color(0xFF166534);
  static const Color unverified = Color(0xFF92400E);

  // ---- Status, dark-theme variants ----------------------------------------
  //
  // The light-theme status colours above are dark enough to read as text on
  // white, which makes them far too dim on a near-black canvas: `inkFaint`-on-
  // dark measured 2.6:1 and was effectively invisible. These are the lifted
  // equivalents used when the active brightness is dark.

  static const Color positiveDark = Color(0xFF6EE7B7);
  static const Color warningDark = Color(0xFFFCD34D);
  static const Color dangerDark = Color(0xFFFCA5A5);
  static const Color infoDark = Color(0xFF93C5FD);

  /// The readable variant of each status colour for [brightness].
  ///
  /// Prefer these over the bare constants in any widget that draws status
  /// *text*. The bare constants are correct for tinted fills and for light
  /// mode, and using one of them directly on a dark surface is the bug these
  /// exist to prevent.
  static Color positiveFor(Brightness brightness) =>
      brightness == Brightness.dark ? positiveDark : positive;
  static Color warningFor(Brightness brightness) =>
      brightness == Brightness.dark ? warningDark : warning;
  static Color dangerFor(Brightness brightness) =>
      brightness == Brightness.dark ? dangerDark : danger;
  static Color infoFor(Brightness brightness) =>
      brightness == Brightness.dark ? infoDark : info;

  // ---- Dark theme surfaces ------------------------------------------------

  static const Color darkCanvas = Color(0xFF0B0B14);
  static const Color darkSurface = Color(0xFF15151F);
  static const Color darkSurfaceMuted = Color(0xFF1E1E2C);

  /// Dark-theme border for interactive controls.
  ///
  /// 3.19:1 on [darkSurface] and 3.45:1 on [darkCanvas]. Kept in the
  /// blue-violet family so it belongs to the brand instead of reading as
  /// neutral grey.
  static const Color darkBorder = Color(0xFF63638C);

  /// 16.84:1 on [darkCanvas].
  static const Color darkInk = Color(0xFFEDEDF7);

  /// 7.58:1 on [darkSurface].
  static const Color darkInkMuted = Color(0xFFA5A5C4);
}

/// The brand gradient and the gradients derived from it.
///
/// The sweep runs indigo -> violet -> teal. Those three hues are roughly
/// evenly spaced neighbours on the colour wheel, which is what stops the
/// gradient from banding into two clashing colour zones in the middle.
class AppGradients {
  const AppGradients._();

  static const List<Color> brand = <Color>[
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF0D9488),
  ];

  /// Two-stop version for large fills where the three-stop sweep would read
  /// as a stripe rather than a gradient.
  static const List<Color> brandShort = <Color>[
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
  ];

  /// Same hue family, lifted for dark mode so it does not glow harshly.
  static const List<Color> brandDark = <Color>[
    Color(0xFF6D67F0),
    Color(0xFF9B6BF5),
    Color(0xFF2DD4BF),
  ];

  static LinearGradient linear({
    List<Color>? colors,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) => LinearGradient(begin: begin, end: end, colors: colors ?? brand);

  static LinearGradient vertical(List<Color> colors) =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors);

  /// The scrim laid over cover artwork so overlaid white text stays readable
  /// regardless of the photograph underneath.
  static const List<Color> coverScrim = <Color>[
    Color(0x00000000),
    Color(0x59000000),
    Color(0xB3000000),
  ];
}

/// Spacing scale (4pt base).
class AppSpacing {
  const AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Corner radii.
class AppRadius {
  const AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Elevation.
///
/// Shadows are tinted with the brand indigo rather than neutral black. A
/// neutral-black shadow over a cool canvas reads as grey dirt; an indigo one
/// reads as the card lifting toward the brand light.
class AppShadow {
  const AppShadow._();

  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x0F15142E), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: Color(0x1415142E), blurRadius: 22, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: Color(0x1F15142E), blurRadius: 40, offset: Offset(0, 18)),
  ];

  /// Hover/focus lift for cards and list tiles on pointer devices.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x1A4F46E5), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// Soft brand halo, used behind hero elements and the active nav item.
  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(color: Color(0x4D4F46E5), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Minimum interactive size. 48dp keeps every control comfortably above the
/// 44dp iOS / 48dp Android accessibility guidance.
class AppHitTarget {
  const AppHitTarget._();
  static const double minimum = 48;
}

class AppDurations {
  const AppDurations._();

  /// Ripple and micro-feedback.
  static const Duration fast = Duration(milliseconds: 140);

  /// Default page and container transition.
  static const Duration normal = Duration(milliseconds: 260);

  /// Larger surfaces — sheets, expansion, hero art.
  static const Duration slow = Duration(milliseconds: 420);

  /// Entrance animations. Long enough to read as motion arriving, short
  /// enough that a list of staggered cards is never a chore.
  static const Duration entrance = Duration(milliseconds: 520);

  /// One step of a stagger, multiplied by the child's index.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Emphasis — a value counting up or a bar filling.
  static const Duration emphasis = Duration(milliseconds: 700);

  static const Duration aiTimeout = Duration(seconds: 45);
}

/// Motion curves.
///
/// Every animation in the app uses one of these four. Picking curves
/// deliberately is what separates a UI that feels alive from one that feels
/// busy: [entrance] decelerates (fast start, soft landing), [exit]
/// accelerates, and the standard pair is used for anything the user is
/// directly manipulating.
class AppCurves {
  const AppCurves._();

  /// Content arriving. Decelerates so the element settles rather than stops.
  static const Curve entrance = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Content leaving. Accelerates away so it gets out of the way.
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);

  /// State the user is driving directly — taps, selections, drags.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasis — growing, filling, drawing attention.
  static const Curve emphasis = Curves.easeOutQuart;
}

class AppBreakpoints {
  const AppBreakpoints._();
  static const double smallPhone = 360;
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1280;
  static const double wideDesktop = 1600;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// True when the primary pointer can hover — a mouse or trackpad.
  ///
  /// Used to switch on hover lifts and tooltips. Touch devices report the
  /// `hover` capability as false even with a stylus, so nothing hover-only is
  /// ever the sole way to reach a control.
  /// Whether the primary pointer is likely a mouse or trackpad.
  ///
  /// Used to switch on hover lifts and persistent scrollbars. Flutter's
  /// [MediaQueryData] does not track hover state, so this infers from the
  /// platform: touch-first platforms report false, and on the web the
  /// decision is made by width, because a narrow browser window on a laptop
  /// is still driven by a pointer. Nothing hover-only is ever the sole way to
  /// reach a control.
  static bool isPointerHovering(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.sizeOf(context).width >= tablet;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.android => false,
      _ => true,
    };
  }

  /// Widest a reading column should get.
  ///
  /// A single column of body text past roughly 70 characters per line is
  /// measurably harder to track, and an uncapped list card on a 1920px window
  /// stretches to roughly four times that. Every scrollable body is capped at
  /// this width and centred, which is what makes the same build feel designed
  /// on a phone and on a desktop browser.
  static const double maxContentWidth = 1080;

  /// Narrower cap for single-column forms and auth screens, where the ideal
  /// measure is closer to a comfortable 45-55 characters.
  static const double maxFormWidth = 560;
}

/// Central place to register the Material 3 light and dark themes.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    // In dark mode the primary is a light indigo with dark ink on top, rather
    // than the deep indigo with white text. A saturated #4F46E5 fill on a near
    // black canvas vibrates, and white-on-indigo only clears 4.5:1 with room
    // to spare for large text only.
    final Color primaryFill = isDark
        ? const Color(0xFF818CF8)
        : AppColors.primary;
    final Color onPrimary = isDark
        ? const Color(0xFF12102B)
        : Colors.white;
    final Color secondaryFill = isDark
        ? const Color(0xFF5EEAD4)
        : AppColors.teal;
    final Color onSecondary = isDark
        ? const Color(0xFF04231F)
        : Colors.white;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: primaryFill,
          onPrimary: onPrimary,
          primaryContainer: isDark
              ? const Color(0xFF2B2A63)
              : AppColors.primarySoft,
          onPrimaryContainer: isDark
              ? const Color(0xFFDDDCFF)
              : AppColors.primaryDeep,
          secondary: secondaryFill,
          onSecondary: onSecondary,
          // Material draws the selected segment of every SegmentedButton, and
          // every ChoiceChip row, from secondaryContainer. It was set to mint
          // green, so "Balanced" and every other trip-style / itinerary-pace
          // option rendered green next to an indigo brand - the exact clash
          // this palette exists to avoid.
          //
          // Mint stays available as [AppColors.positiveSoft] for places that
          // genuinely mean "good", rather than being the default accent.
          secondaryContainer: isDark
              ? const Color(0xFF2E2456)
              : AppColors.violetSoft,
          onSecondaryContainer: isDark
              ? const Color(0xFFE4DBFF)
              : const Color(0xFF5B21B6),
          tertiary: isDark ? const Color(0xFFC4B5FD) : AppColors.violet,
          onTertiary: isDark ? const Color(0xFF1F1147) : Colors.white,
          tertiaryContainer: isDark
              ? const Color(0xFF3B2470)
              : AppColors.violetSoft,
          onTertiaryContainer: isDark
              ? const Color(0xFFE9DDFF)
              : const Color(0xFF5B21B6),
          surface: isDark ? AppColors.darkSurface : AppColors.surface,
          onSurface: isDark ? AppColors.darkInk : AppColors.ink,
          surfaceContainerLowest: isDark
              ? const Color(0xFF08080F)
              : AppColors.surface,
          surfaceContainerLow: isDark
              ? AppColors.darkSurface
              : AppColors.canvas,
          surfaceContainer: isDark
              ? AppColors.darkSurfaceMuted
              : AppColors.canvas,
          surfaceContainerHigh: isDark
              ? const Color(0xFF262638)
              : AppColors.surfaceMuted,
          surfaceContainerHighest: isDark
              ? const Color(0xFF2F2F45)
              : const Color(0xFFE6E6F0),
          error: isDark ? const Color(0xFFFF8A80) : AppColors.danger,
          onError: isDark ? const Color(0xFF3B0A06) : Colors.white,
          // `outline` draws the boundaries that identify an interactive
          // control - text field outlines and outlined-button borders. WCAG
          // 1.4.11 requires 3:1 for those, and `AppColors.border` alone is
          // nowhere near it. Decorative card edges still use `border` directly
          // and stay subtle, because a card is identified by its fill, not its
          // edge.
          outline: isDark ? AppColors.darkBorder : AppColors.borderStrong,
          // Variant stays subtle: it is for dividers and fills, not controls.
          outlineVariant: isDark ? AppColors.darkBorder : AppColors.border,
        );

    final Color canvas = isDark ? AppColors.darkCanvas : AppColors.canvas;
    final Color ink = isDark ? AppColors.darkInk : AppColors.ink;
    final Color inkMuted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final List<Color> brandGradient =
        isDark ? AppGradients.brandDark : AppGradients.brand;

    final TextTheme base = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final TextTheme text = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: ink,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: ink,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: ink,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5, color: inkMuted),
      bodySmall: base.bodySmall?.copyWith(height: 1.45, color: inkMuted),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,

      // Smooth, low-travel page transitions. The default zoom-and-fade on
      // Android reads as dated on a web canvas; these settle instead of
      // moving, which keeps navigation feeling quick.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        // A hairline edge plus a very soft shadow. Edge alone made cards read
        // as flat outlines; shadow alone made them float. Together they read
        // as a surface.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceMuted : AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          // Double-width so the focus ring is obvious to a keyboard user who
          // never sees a ripple.
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        labelStyle: TextStyle(color: inkMuted),
        helperMaxLines: 2,
        errorMaxLines: 3,
      ),

      // Buttons carry a soft shadow so they read as the raised, primary
      // action on a flat canvas.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppHitTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppHitTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: isDark
              ? AppColors.darkSurfaceMuted
              : AppColors.surface,
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppHitTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge,
        ),
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelMedium ?? const TextStyle(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.outlineVariant),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: inkMuted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: inkMuted),
      ),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // A dialog opened on a 1920px window was previously full-bleed; this
        // keeps it a dialog.
        constraints: const BoxConstraints(maxWidth: 480),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.titleLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceMuted : AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.surfaceMuted,
        circularTrackColor: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.surfaceMuted,
        linearMinHeight: 8,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceMuted : AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      extensions: <ThemeExtension<dynamic>>[
        AppGradientsTheme(
          brand: brandGradient,
          shadowTint: ink,
        ),
      ],
    );
  }
}

/// Brand gradients carried on the [ThemeData] itself.
///
/// Putting these in a [ThemeExtension] rather than reading [AppGradients]
/// statically means a widget asking for `theme.extension<...>()?.brand` always
/// gets the variant that matches the active brightness, instead of having to
/// re-derive it at every call site.
@immutable
class AppGradientsTheme extends ThemeExtension<AppGradientsTheme> {
  const AppGradientsTheme({required this.brand, required this.shadowTint});

  /// Indigo -> violet -> teal, lifted for dark mode.
  final List<Color> brand;

  /// What shadows are tinted with. Ink in light, dark ink in dark, so a shadow
  /// never lightens a dark surface.
  final Color shadowTint;

  /// Convenience accessor that falls back to the light brand if the app is
  /// ever rendered outside a themed subtree.
  static AppGradientsTheme of(BuildContext context) {
    return Theme.of(context).extension<AppGradientsTheme>() ??
        const AppGradientsTheme(brand: AppGradients.brand, shadowTint: AppColors.ink);
  }

  @override
  AppGradientsTheme copyWith({List<Color>? brand, Color? shadowTint}) =>
      AppGradientsTheme(
        brand: brand ?? this.brand,
        shadowTint: shadowTint ?? this.shadowTint,
      );

  @override
  AppGradientsTheme lerp(ThemeExtension<AppGradientsTheme>? other, double t) {
    if (other is! AppGradientsTheme) return this;
    return AppGradientsTheme(
      brand: <Color>[
        for (int i = 0; i < brand.length; i++)
          Color.lerp(brand[i], other.brand[i], t) ?? brand[i],
      ],
      shadowTint: Color.lerp(shadowTint, other.shadowTint, t) ?? shadowTint,
    );
  }
}
