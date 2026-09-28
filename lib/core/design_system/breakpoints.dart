/// Shared responsive breakpoints. One source of truth so the shell's
/// rail/bottom-bar switch and every module's master-detail decision can
/// never drift apart — a module that collapses its panes at a different
/// width than the shell swaps its chrome produces a broken in-between
/// layout (the "cramped Vault pane" bug).
class AppBreakpoints {
  AppBreakpoints._();

  /// Above this width the shell uses the NavigationRail and embedded
  /// modules may render master-detail panes. Below it: bottom bar and
  /// full-page list/push navigation.
  static const double wide = 600;
}
