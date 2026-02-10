import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'onboarding_screen_2.dart';

class OnboardingScreen1 extends StatelessWidget {
  const OnboardingScreen1({super.key});

  Route _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, animation, __, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isCompact = width < 360;
        final isWide = width >= 600;
        final horizontalPadding = isWide ? 96.0 : (isCompact ? 18.0 : 28.0);
        final titleSize = isWide ? 32.0 : (isCompact ? 22.0 : 26.0);
        final subtitleSize = isWide ? 16.0 : 14.0;
        final imageSize = (width * 0.8).clamp(240.0, isWide ? 360.0 : 320.0);
        final minHeight = height - MediaQuery.of(context).padding.vertical;
        final buttonVertical = isWide ? 16.0 : 14.0;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10142B), Color(0xFF1A2140)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  _BackgroundGlow(),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 18,
                    ),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight - 36),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              SizedBox(height: isWide ? 16 : 6),
                              Text(
                                "Smart Attendance System",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Track your attendance instantly using secure QR technology.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFB2B9D6),
                                  fontSize: subtitleSize,
                                  height: 1.4,
                                ),
                              ),
                              const Spacer(),
                              _HeroImage(size: imageSize),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacement(
                                      _slideRoute(const OnboardingScreen2()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6A4BFF),
                                    padding: EdgeInsets.symmetric(
                                      vertical: buttonVertical,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Next",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _PageDots(activeIndex: 0),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroImage extends StatelessWidget {
  final double size;

  const _HeroImage({this.size = 320});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          "assets/scanMan.png",
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6A4BFF).withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4E72FF).withOpacity(0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int activeIndex;
  const _PageDots({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 14 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFF5F6684),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}
