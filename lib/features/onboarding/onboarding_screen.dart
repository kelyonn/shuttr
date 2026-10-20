import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shuttr/app/router.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/settings/settings_repository.dart';

/// Three short screens, shown once: what Shuttr is, how it works, then the
/// permission ask with the reason for each permission before the system
/// dialogs. Swipe or tap NEXT; back goes back a page.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = 3;
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish({required bool askPermissions}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (askPermissions) {
        await Permission.camera.request();
        // Saving photos is asked now, with the reason on screen, not in the
        // middle of the first KEEP. Refusing is fine: it is asked again
        // when the first photo is kept.
        try {
          if (!await Gal.hasAccess()) await Gal.requestAccess();
        } on Object {
          // Ignored on purpose.
        }
      }
      await ref.read(sharedPreferencesProvider).setBool(onboardedKey, true);
      if (mounted) context.go(AppRoutes.camera);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final last = _page == _pages - 1;
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_page - 1);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Palette.paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Palette.paper,
          body: Column(
            children: [
              ColoredBox(
                color: Palette.stage,
                child: SizedBox(
                  height: media.padding.top,
                  width: double.infinity,
                ),
              ),
              Container(
                height: 44,
                color: Palette.stage,
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SHUTTR',
                      style: Typo.label.copyWith(color: Palette.cream),
                    ),
                    if (!last)
                      TapCell(
                        onTap: () => _go(_pages - 1),
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        semanticLabel: 'Skip to the last step',
                        child: Text(
                          'SKIP',
                          style: Typo.label.copyWith(color: Palette.cream),
                        ),
                      ),
                  ],
                ),
              ),
              const HeavyRule(),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: const [_PageOne(), _PageTwo(), _PageThree()],
                ),
              ),
              _Dots(count: _pages, index: _page),
              const SizedBox(height: 16),
              Container(
                decoration: topRule,
                child: Row(
                  children: [
                    if (last)
                      Expanded(
                        child: TapCell(
                          onTap: _busy
                              ? null
                              : () => unawaited(_finish(askPermissions: false)),
                          height: 56,
                          alignment: Alignment.center,
                          child: const Text('NOT NOW', style: Typo.labelBold),
                        ),
                      ),
                    Expanded(
                      flex: 2,
                      child: TapCell(
                        onTap: _busy
                            ? null
                            : last
                            ? () => unawaited(_finish(askPermissions: true))
                            : () => _go(_page + 1),
                        height: 56,
                        alignment: Alignment.center,
                        background: Palette.ink,
                        child: Text(
                          last ? 'ALLOW ACCESS' : 'NEXT',
                          style: Typo.labelBold.copyWith(
                            fontSize: 12,
                            color: Palette.paper,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ColoredBox(
                color: Palette.paper,
                child: SizedBox(
                  height: media.padding.bottom,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SharedPreferences key: onboarding has been completed.
const onboardedKey = 'onboarded';

/// Display type with room between lines: the shared 0.82 leading is for one
/// line and makes two stacked lines touch.
const TextStyle _headline = TextStyle(
  fontFamily: 'Anton',
  fontSize: 72,
  height: 1,
  letterSpacing: 0.4,
);

/// Square progress marks: the current step is solid.
class _Dots extends StatelessWidget {
  const new({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 24 : 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: i == index ? Palette.ink : null,
                border: Border.all(color: Palette.ink),
              ),
            ),
        ],
      ),
    );
  }
}

/// One onboarding page: content centred in the space it has, scrolling if a
/// small phone or a large text size leaves too little.
class _Page extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _PageOne extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const _Page(
      children: [
        Text('THE\nDIGICAM', style: _headline, textAlign: TextAlign.center),
        SizedBox(height: 14),
        Text('you never had.', style: Typo.sub),
        SizedBox(height: 28),
        Text(
          'Flash, grain and a date stamp, made on your phone.',
          style: Typo.body,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PageTwo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    Widget step(String n, String head, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                n,
                style: Typo.display.copyWith(fontSize: 40, height: 1),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(head, style: Typo.labelBold),
                  const SizedBox(height: 4),
                  Text(body, style: Typo.body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _Page(
      children: [
        const Text(
          'PICK.\nSHOOT.\nKEEP.',
          style: _headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            children: [
              step(
                '1',
                'PICK A CAMERA',
                'Each one has its own look and flash.',
              ),
              step('2', 'SHOOT', 'The look is already on the screen.'),
              step('3', 'KEEP OR RETAKE', 'Or try the shot in another camera.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageThree extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    Widget reason(String head, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            Text(head, style: Typo.labelBold),
            const SizedBox(height: 4),
            Text(body, style: Typo.body, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return _Page(
      children: [
        const Text(
          'NO ADS.\nNO ACCOUNTS.',
          style: _headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        const Text(
          'everything stays on this phone.',
          style: Typo.sub,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            children: [
              reason('CAMERA', 'To shoot. Nothing is uploaded.'),
              reason('PHOTOS', 'To save your shots to your gallery.'),
            ],
          ),
        ),
      ],
    );
  }
}
