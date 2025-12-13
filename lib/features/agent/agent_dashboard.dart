import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/agent/agent_wallet_page.dart';
import 'package:stayhub/features/agent/agent_profile_page.dart'; // Corrected Import
import 'package:stayhub/features/agent/agent_hostels_page.dart';
import 'package:stayhub/features/agent/agent_bookings_page.dart';
import 'package:stayhub/features/agent/add_hostel_page.dart';

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  int _selectedIndex = 0;
  final _user = FirebaseAuth.instance.currentUser;
  
  String _title = "Agent Portal";
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildOverviewTab(),
      const AgentHostelsPage(),
      const AgentBookingsPage(),
      const AgentWalletPage(),
      const AgentProfilePage(), // <-- Use the new AgentProfilePage
    ];
    
    _checkUserRole();
  }

  Widget _buildOverviewTab() {
     if (_user == null) return const SizedBox.shrink();
     
     return StreamBuilder<DocumentSnapshot>(
       stream: FirebaseFirestore.instance.collection('agents').doc(_user!.uid).snapshots(),
       builder: (context, snapshot) {
         Map<String, dynamic> data = {};
         if (snapshot.hasData && snapshot.data!.exists) {
           data = snapshot.data!.data() as Map<String, dynamic>;
         }
         return DashboardOverview(userData: data);
       },
     );
  }

  Future<void> _checkUserRole() async {
    if (_user == null) return;
    try {
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(_user!.uid).get();
      if (mounted && adminDoc.exists) {
        setState(() => _title = "Admin Portal");
      }
    } catch (e) {
      debugPrint("Role check error: $e");
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const AuthPage();

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview'
          ),
          NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment),
              label: 'Hostels'
          ),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Bookings'
          ),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet'
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'
          ),
        ],
      ),
    );
  }
}

class DashboardOverview extends StatelessWidget {
  final Map<String, dynamic> userData;
  const DashboardOverview({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'Agent';
    final double walletBalance = (userData['wallet_balance'] ?? 0.0).toDouble();
    final currencyFormat = NumberFormat.currency(locale: 'en_GH', symbol: '₵');
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              _buildCurvedHeader(context, name),
              Positioned(
                top: 140,
                left: 20,
                right: 20,
                child: _buildWalletCard(walletBalance, currencyFormat),
              ),
            ],
          ),
          const SizedBox(height: 100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text("View Report"))
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (uid != null)
            SizedBox(
              height: 140,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('hostels').where('agentId', isEqualTo: uid).snapshots(),
                builder: (context, hostelSnapshot) {
                  final activeHostels = hostelSnapshot.data?.docs.length ?? 0;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collectionGroup('bookings').where('agentId', isEqualTo: uid).snapshots(),
                    builder: (context, bookingSnapshot) {
                      final totalBookings = bookingSnapshot.data?.docs.length ?? 0;
                      
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildFluidStatCard("Active Hostels", activeHostels.toString(), Icons.apartment_rounded, const Color(0xFFFF7E5F), const Color(0xFFFEB47B)),
                          _buildFluidStatCard("Total Bookings", totalBookings.toString(), Icons.bookmarks_rounded, const Color(0xFF6A11CB), const Color(0xFF2575FC)),
                          _buildFluidStatCard("Avg. Rating", "4.8", Icons.star_rounded, const Color(0xFF11998E), const Color(0xFF38EF7D)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildActionTile(context, Icons.add_circle_outline, "Add New Hostel", "List a new property", () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHostelPage()));
                }),
                _buildActionTile(context, Icons.verified_user_outlined, "Verify Profile", "Increase trust score", () {}),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildCurvedHeader(BuildContext context, String name) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF232526), Color(0xFF414345)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withValues(alpha: 0.05))),
          Positioned(top: 40, left: -30, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05))),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 5),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(double balance, NumberFormat format) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFF4A00E0).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(top: 25, left: 25, child: Container(width: 40, height: 30, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withValues(alpha: 0.3))))),
          Positioned(bottom: -20, right: -20, child: Icon(Icons.blur_on, size: 150, color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Total Balance", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 5),
                Text(format.format(balance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidStatCard(String title, String value, IconData icon, Color c1, Color c2) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: Colors.blueGrey.shade800),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade300),
      ),
    );
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }
}
