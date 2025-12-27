import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
      title: "Welcome to StayHub",
      description: "Discover the best student hostels near your campus. Safe, affordable, and just a tap away.",
      icon: FontAwesomeIcons.magnifyingGlassLocation,
      color: Colors.blueAccent,
    ),
    OnboardingItem(
      title: "Verified & Secure",
      description: "We verify every listing to ensure your safety. Say goodbye to fake agents and scams.",
      icon: FontAwesomeIcons.shieldHalved,
      color: Colors.green,
    ),
    OnboardingItem(
      title: "Book Instantly",
      description: "Secure your room with our seamless payment system. Move in stress-free.",
      icon: FontAwesomeIcons.creditCard,
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
      backgroundColor: const Color(0xFF0F2027), // Deep dark
      body: Stack(
        children: [
          // 1. Dynamic Background (Gradient)
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F2027),
                  _items[_currentIndex].color.withOpacity(0.2), // Bleed item color into bg
                  const Color(0xFF2C5364),
                ],
              ),
            ),
          ),
          
          // 2. Abstract Shapes (Orbs)
          Positioned(
            top: -100,
            right: -100,
            child: _buildOrb(_items[_currentIndex].color.withOpacity(0.3)),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _buildOrb(Colors.white.withOpacity(0.05)),
          ),

          // 3. Content
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with Glow
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                           BoxShadow(color: item.color.withOpacity(0.4), blurRadius: 50, spreadRadius: 10)
                        ],
                      ),
                      child: FaIcon(item.icon, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
                         child: Icon(Icons.arrow_forward_ios, color: Colors.black, size: 20),
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
      )
    );
  }

  Widget _buildOrb(Color color) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 10)],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
