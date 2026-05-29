import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/core/image_utils.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: "Discover Your Space",
      description: "Browse the best student hostels near your campus. Safe, affordable, and vetted for you.",
      imageUrl: "https://images.pexels.com/photos/276724/pexels-photo-276724.jpeg?auto=compress&cs=tinysrgb&w=1000",
      color: Colors.blueAccent,
    ),
    OnboardingItem(
      title: "Verified & Secure",
      description: "We verify every listing and agent to ensure your peace of mind. No scams, just homes.",
      imageUrl: "https://images.pexels.com/photos/60504/security-protection-anti-virus-software-60504.jpeg?auto=compress&cs=tinysrgb&w=1000",
      color: Colors.greenAccent,
    ),
    OnboardingItem(
      title: "Seamless Booking",
      description: "Secure your room instantly with our transparent and secure payment system.",
      imageUrl: "https://images.pexels.com/photos/164501/pexels-photo-164501.jpeg?auto=compress&cs=tinysrgb&w=1000",
      color: Colors.purpleAccent,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: Stack(
        children: [
          // 1. Image Background with Cached Support
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ImageUtils.getSecureUrl(item.imageUrl),
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                         gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F2027), Color(0xFF2C5364)])
                      ),
                      child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white.withOpacity(0.1), size: 100)),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          const Color(0xFF0F2027).withOpacity(0.8),
                          const Color(0xFF0F2027),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 180), // Space for bottom nav
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          
          // 4. Bottom Glass Navigation
          Positioned(
             bottom: 0, left: 0, right: 0,
             child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 50),
                decoration: BoxDecoration(
                   gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
                ),
                child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      // Indicators
                      Row(
                         children: List.generate(_items.length, (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 6,
                            width: _currentIndex == index ? 30 : 6,
                            decoration: BoxDecoration(
                                color: _currentIndex == index ? _items[index].color : Colors.white24, 
                                borderRadius: BorderRadius.circular(3)
                            )
                         )),
                      ),
                      
                      // FAB Button
                      FloatingActionButton(
                         onPressed: () {
                             if (_currentIndex == _items.length - 1) {
                                 _completeOnboarding();
                             } else {
                                 _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
                             }
                         },
                         backgroundColor: Colors.white,
                         elevation: 0,
                         child: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
                      )
                   ],
                ),
             ),
          ),
          
          // Skip Button Top Right
          if (_currentIndex != _items.length - 1)
          Positioned(
             top: 50, right: 20,
             child: TextButton(onPressed: _completeOnboarding, child: const Text("Skip", style: TextStyle(color: Colors.white70))),
          )
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String imageUrl;
  final Color color;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.color,
  });
}
