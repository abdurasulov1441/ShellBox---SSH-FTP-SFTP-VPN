import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.accent,
    required this.green,
    required this.red,
    required this.yellow,
    required this.text,
    required this.textDim,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color accent;
  final Color green;
  final Color red;
  final Color yellow;
  final Color text;
  final Color textDim;
}

const AppPalette darkPalette = AppPalette(
  brightness: Brightness.dark,
  bg: Color(0xFF0D1117),
  surface: Color(0xFF151B23),
  surfaceHigh: Color(0xFF1C2330),
  border: Color(0xFF29313D),
  accent: Color(0xFF4F8CFF),
  green: Color(0xFF3FB950),
  red: Color(0xFFF85149),
  yellow: Color(0xFFD29922),
  text: Color(0xFFE6EDF3),
  textDim: Color(0xFF8B949E),
);

const AppPalette lightPalette = AppPalette(
  brightness: Brightness.light,
  bg: Color(0xFFF4F6F9),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFEDF1F6),
  border: Color(0xFFD5DCE5),
  accent: Color(0xFF2F6FEB),
  green: Color(0xFF1A7F37),
  red: Color(0xFFCF222E),
  yellow: Color(0xFF9A6700),
  text: Color(0xFF1C2230),
  textDim: Color(0xFF636C78),
);

class AppColors {
  static AppPalette active = darkPalette;

  static Brightness get brightness => active.brightness;
  static bool get isDark => active.brightness == Brightness.dark;

  static Color get bg => active.bg;
  static Color get surface => active.surface;
  static Color get surfaceHigh => active.surfaceHigh;
  static Color get border => active.border;
  static Color get accent => active.accent;
  static Color get green => active.green;
  static Color get red => active.red;
  static Color get yellow => active.yellow;
  static Color get text => active.text;
  static Color get textDim => active.textDim;

  static const hostColors = <int>[
    0xFF4F8CFF,
    0xFF3FB950,
    0xFFF85149,
    0xFFD29922,
    0xFFA371F7,
    0xFF39C5CF,
    0xFFF778BA,
    0xFFFF9F43,
  ];
}

class AppFonts {
  static String get mono => GoogleFonts.jetBrainsMono().fontFamily ?? 'monospace';

  static TextStyle monoStyle({double size = 13, Color? color, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.jetBrainsMono(fontSize: size, color: color ?? AppColors.text, fontWeight: weight);
  }
}

class AppTheme {
  static ThemeData dark() => build(darkPalette);
  static ThemeData light() => build(lightPalette);

  static ThemeData build(AppPalette p) {
    final base = ThemeData(brightness: p.brightness, useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text);
    final baseScheme = p.brightness == Brightness.dark ? const ColorScheme.dark() : const ColorScheme.light();
    final scheme = baseScheme.copyWith(
      primary: p.accent,
      onPrimary: Colors.white,
      secondary: p.accent,
      onSecondary: Colors.white,
      error: p.red,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textDim,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceHigh,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.border,
      outlineVariant: p.border,
    );
    final rounded12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: p.border,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: p.text),
        iconTheme: IconThemeData(color: p.text),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.border)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.border)),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.text),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceHigh,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: p.textDim),
        hintStyle: TextStyle(color: p.textDim),
        helperStyle: TextStyle(color: p.textDim),
        prefixIconColor: p.textDim,
        suffixIconColor: p.textDim,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.red, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: rounded12,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: p.border),
          shape: rounded12,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent, shape: rounded12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          shape: WidgetStatePropertyAll(rounded12),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.accent.withValues(alpha: 0.2) : p.surfaceHigh,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.text : p.textDim,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : p.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.accent : p.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.accent : p.border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.surfaceHigh,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.15),
      ),
      listTileTheme: ListTileThemeData(iconColor: p.textDim, textColor: p.text),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surfaceHigh,
        side: BorderSide(color: p.border),
        shape: rounded12,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.35),
        selectionHandleColor: p.accent,
      ),
    );
  }
}

class TerminalScheme {
  const TerminalScheme({required this.id, required this.name, required this.theme});

  final String id;
  final String name;
  final TerminalTheme theme;

  static TerminalScheme byId(String id) {
    for (final scheme in all) {
      if (scheme.id == id) {
        return scheme;
      }
    }
    return all.first;
  }

  static const all = <TerminalScheme>[
    TerminalScheme(
      id: 'midnight',
      name: 'Midnight',
      theme: TerminalTheme(
        cursor: Color(0xFF4F8CFF),
        selection: Color(0x664F8CFF),
        foreground: Color(0xFFE6EDF3),
        background: Color(0xFF0D1117),
        black: Color(0xFF484F58),
        red: Color(0xFFFF7B72),
        green: Color(0xFF3FB950),
        yellow: Color(0xFFD29922),
        blue: Color(0xFF58A6FF),
        magenta: Color(0xFFBC8CFF),
        cyan: Color(0xFF39C5CF),
        white: Color(0xFFB1BAC4),
        brightBlack: Color(0xFF6E7681),
        brightRed: Color(0xFFFFA198),
        brightGreen: Color(0xFF56D364),
        brightYellow: Color(0xFFE3B341),
        brightBlue: Color(0xFF79C0FF),
        brightMagenta: Color(0xFFD2A8FF),
        brightCyan: Color(0xFF56D4DD),
        brightWhite: Color(0xFFF0F6FC),
        searchHitBackground: Color(0xFFD29922),
        searchHitBackgroundCurrent: Color(0xFF3FB950),
        searchHitForeground: Color(0xFF0D1117),
      ),
    ),
    TerminalScheme(
      id: 'dracula',
      name: 'Dracula',
      theme: TerminalTheme(
        cursor: Color(0xFFF8F8F2),
        selection: Color(0x6644475A),
        foreground: Color(0xFFF8F8F2),
        background: Color(0xFF282A36),
        black: Color(0xFF21222C),
        red: Color(0xFFFF5555),
        green: Color(0xFF50FA7B),
        yellow: Color(0xFFF1FA8C),
        blue: Color(0xFFBD93F9),
        magenta: Color(0xFFFF79C6),
        cyan: Color(0xFF8BE9FD),
        white: Color(0xFFF8F8F2),
        brightBlack: Color(0xFF6272A4),
        brightRed: Color(0xFFFF6E6E),
        brightGreen: Color(0xFF69FF94),
        brightYellow: Color(0xFFFFFFA5),
        brightBlue: Color(0xFFD6ACFF),
        brightMagenta: Color(0xFFFF92DF),
        brightCyan: Color(0xFFA4FFFF),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFF1FA8C),
        searchHitBackgroundCurrent: Color(0xFF50FA7B),
        searchHitForeground: Color(0xFF282A36),
      ),
    ),
    TerminalScheme(
      id: 'nord',
      name: 'Nord',
      theme: TerminalTheme(
        cursor: Color(0xFFD8DEE9),
        selection: Color(0x6681A1C1),
        foreground: Color(0xFFD8DEE9),
        background: Color(0xFF2E3440),
        black: Color(0xFF3B4252),
        red: Color(0xFFBF616A),
        green: Color(0xFFA3BE8C),
        yellow: Color(0xFFEBCB8B),
        blue: Color(0xFF81A1C1),
        magenta: Color(0xFFB48EAD),
        cyan: Color(0xFF88C0D0),
        white: Color(0xFFE5E9F0),
        brightBlack: Color(0xFF4C566A),
        brightRed: Color(0xFFBF616A),
        brightGreen: Color(0xFFA3BE8C),
        brightYellow: Color(0xFFEBCB8B),
        brightBlue: Color(0xFF81A1C1),
        brightMagenta: Color(0xFFB48EAD),
        brightCyan: Color(0xFF8FBCBB),
        brightWhite: Color(0xFFECEFF4),
        searchHitBackground: Color(0xFFEBCB8B),
        searchHitBackgroundCurrent: Color(0xFFA3BE8C),
        searchHitForeground: Color(0xFF2E3440),
      ),
    ),
    TerminalScheme(
      id: 'solarized',
      name: 'Solarized',
      theme: TerminalTheme(
        cursor: Color(0xFF93A1A1),
        selection: Color(0x66268BD2),
        foreground: Color(0xFF93A1A1),
        background: Color(0xFF002B36),
        black: Color(0xFF073642),
        red: Color(0xFFDC322F),
        green: Color(0xFF859900),
        yellow: Color(0xFFB58900),
        blue: Color(0xFF268BD2),
        magenta: Color(0xFFD33682),
        cyan: Color(0xFF2AA198),
        white: Color(0xFFEEE8D5),
        brightBlack: Color(0xFF586E75),
        brightRed: Color(0xFFCB4B16),
        brightGreen: Color(0xFFA0B41E),
        brightYellow: Color(0xFFD9A514),
        brightBlue: Color(0xFF4CA6E8),
        brightMagenta: Color(0xFF6C71C4),
        brightCyan: Color(0xFF3FC4BA),
        brightWhite: Color(0xFFFDF6E3),
        searchHitBackground: Color(0xFFB58900),
        searchHitBackgroundCurrent: Color(0xFF859900),
        searchHitForeground: Color(0xFF002B36),
      ),
    ),
    TerminalScheme(
      id: 'tokyonight',
      name: 'Tokyo Night',
      theme: TerminalTheme(
        cursor: Color(0xFFC0CAF5),
        selection: Color(0x66364A82),
        foreground: Color(0xFFC0CAF5),
        background: Color(0xFF1A1B26),
        black: Color(0xFF414868),
        red: Color(0xFFF7768E),
        green: Color(0xFF9ECE6A),
        yellow: Color(0xFFE0AF68),
        blue: Color(0xFF7AA2F7),
        magenta: Color(0xFFBB9AF7),
        cyan: Color(0xFF7DCFFF),
        white: Color(0xFFA9B1D6),
        brightBlack: Color(0xFF565F89),
        brightRed: Color(0xFFFF899D),
        brightGreen: Color(0xFFB9F27C),
        brightYellow: Color(0xFFFFC777),
        brightBlue: Color(0xFF8DB0FF),
        brightMagenta: Color(0xFFC7A9FF),
        brightCyan: Color(0xFFA4DAFF),
        brightWhite: Color(0xFFC0CAF5),
        searchHitBackground: Color(0xFFE0AF68),
        searchHitBackgroundCurrent: Color(0xFF9ECE6A),
        searchHitForeground: Color(0xFF1A1B26),
      ),
    ),
    TerminalScheme(
      id: 'onedark',
      name: 'One Dark',
      theme: TerminalTheme(
        cursor: Color(0xFF61AFEF),
        selection: Color(0x663E4451),
        foreground: Color(0xFFABB2BF),
        background: Color(0xFF282C34),
        black: Color(0xFF3F4451),
        red: Color(0xFFE06C75),
        green: Color(0xFF98C379),
        yellow: Color(0xFFE5C07B),
        blue: Color(0xFF61AFEF),
        magenta: Color(0xFFC678DD),
        cyan: Color(0xFF56B6C2),
        white: Color(0xFFABB2BF),
        brightBlack: Color(0xFF4F5666),
        brightRed: Color(0xFFFF7A85),
        brightGreen: Color(0xFFA9D68A),
        brightYellow: Color(0xFFF0CA8C),
        brightBlue: Color(0xFF72BFFF),
        brightMagenta: Color(0xFFD68AED),
        brightCyan: Color(0xFF66C7D3),
        brightWhite: Color(0xFFE6E6E6),
        searchHitBackground: Color(0xFFE5C07B),
        searchHitBackgroundCurrent: Color(0xFF98C379),
        searchHitForeground: Color(0xFF282C34),
      ),
    ),
    TerminalScheme(
      id: 'gruvbox',
      name: 'Gruvbox',
      theme: TerminalTheme(
        cursor: Color(0xFFEBDBB2),
        selection: Color(0x66504945),
        foreground: Color(0xFFEBDBB2),
        background: Color(0xFF1D2021),
        black: Color(0xFF3C3836),
        red: Color(0xFFFB4934),
        green: Color(0xFFB8BB26),
        yellow: Color(0xFFFABD2F),
        blue: Color(0xFF83A598),
        magenta: Color(0xFFD3869B),
        cyan: Color(0xFF8EC07C),
        white: Color(0xFFD5C4A1),
        brightBlack: Color(0xFF665C54),
        brightRed: Color(0xFFFB4934),
        brightGreen: Color(0xFFB8BB26),
        brightYellow: Color(0xFFFABD2F),
        brightBlue: Color(0xFF83A598),
        brightMagenta: Color(0xFFD3869B),
        brightCyan: Color(0xFF8EC07C),
        brightWhite: Color(0xFFFBF1C7),
        searchHitBackground: Color(0xFFFABD2F),
        searchHitBackgroundCurrent: Color(0xFFB8BB26),
        searchHitForeground: Color(0xFF1D2021),
      ),
    ),
    TerminalScheme(
      id: 'monokai',
      name: 'Monokai',
      theme: TerminalTheme(
        cursor: Color(0xFFF8F8F0),
        selection: Color(0x6649483E),
        foreground: Color(0xFFF8F8F2),
        background: Color(0xFF272822),
        black: Color(0xFF414339),
        red: Color(0xFFF92672),
        green: Color(0xFFA6E22E),
        yellow: Color(0xFFE6DB74),
        blue: Color(0xFF66D9EF),
        magenta: Color(0xFFAE81FF),
        cyan: Color(0xFF66D9EF),
        white: Color(0xFFF8F8F2),
        brightBlack: Color(0xFF75715E),
        brightRed: Color(0xFFFF669D),
        brightGreen: Color(0xFFBEED5F),
        brightYellow: Color(0xFFF3EA98),
        brightBlue: Color(0xFF8DE6F7),
        brightMagenta: Color(0xFFC2A1FF),
        brightCyan: Color(0xFF8DE6F7),
        brightWhite: Color(0xFFF9F8F5),
        searchHitBackground: Color(0xFFE6DB74),
        searchHitBackgroundCurrent: Color(0xFFA6E22E),
        searchHitForeground: Color(0xFF272822),
      ),
    ),
    TerminalScheme(
      id: 'catppuccin',
      name: 'Catppuccin',
      theme: TerminalTheme(
        cursor: Color(0xFFF5E0DC),
        selection: Color(0x66414559),
        foreground: Color(0xFFCDD6F4),
        background: Color(0xFF1E1E2E),
        black: Color(0xFF45475A),
        red: Color(0xFFF38BA8),
        green: Color(0xFFA6E3A1),
        yellow: Color(0xFFF9E2AF),
        blue: Color(0xFF89B4FA),
        magenta: Color(0xFFCBA6F7),
        cyan: Color(0xFF94E2D5),
        white: Color(0xFFBAC2DE),
        brightBlack: Color(0xFF585B70),
        brightRed: Color(0xFFF38BA8),
        brightGreen: Color(0xFFA6E3A1),
        brightYellow: Color(0xFFF9E2AF),
        brightBlue: Color(0xFF89B4FA),
        brightMagenta: Color(0xFFCBA6F7),
        brightCyan: Color(0xFF94E2D5),
        brightWhite: Color(0xFFA6ADC8),
        searchHitBackground: Color(0xFFF9E2AF),
        searchHitBackgroundCurrent: Color(0xFFA6E3A1),
        searchHitForeground: Color(0xFF1E1E2E),
      ),
    ),
  ];
}

class MonoFont {
  const MonoFont(this.id, this.name);

  final String id;
  final String name;
}

class MonoFonts {
  static const String defaultId = 'jetbrains';

  static const List<MonoFont> all = [
    MonoFont('jetbrains', 'JetBrains Mono'),
    MonoFont('fira', 'Fira Code'),
    MonoFont('source', 'Source Code Pro'),
    MonoFont('ibm', 'IBM Plex Mono'),
    MonoFont('roboto', 'Roboto Mono'),
    MonoFont('ubuntu', 'Ubuntu Mono'),
    MonoFont('space', 'Space Mono'),
    MonoFont('inconsolata', 'Inconsolata'),
  ];

  static TextStyle style(String id, {double? size, Color? color, FontWeight? weight}) {
    switch (id) {
      case 'fira':
        return GoogleFonts.firaCode(fontSize: size, color: color, fontWeight: weight);
      case 'source':
        return GoogleFonts.sourceCodePro(fontSize: size, color: color, fontWeight: weight);
      case 'ibm':
        return GoogleFonts.ibmPlexMono(fontSize: size, color: color, fontWeight: weight);
      case 'roboto':
        return GoogleFonts.robotoMono(fontSize: size, color: color, fontWeight: weight);
      case 'ubuntu':
        return GoogleFonts.ubuntuMono(fontSize: size, color: color, fontWeight: weight);
      case 'space':
        return GoogleFonts.spaceMono(fontSize: size, color: color, fontWeight: weight);
      case 'inconsolata':
        return GoogleFonts.inconsolata(fontSize: size, color: color, fontWeight: weight);
      case 'jetbrains':
      default:
        return GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);
    }
  }

  static String family(String id) => style(id).fontFamily ?? 'monospace';

  static String nameFor(String id) {
    for (final font in all) {
      if (font.id == id) {
        return font.name;
      }
    }
    return all.first.name;
  }
}
