import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/agent/agent_wallet_page.dart';
import 'package:stayhub/features/agent/agent_profile_page.dart'; // Corrected Import
import 'package:stayhub/features/agent/agent_hostels_page.dart';
import 'package:stayhub/features/agent/agent_bookings_page.dart';
import 'package:stayhub/features/agent/add_hostel_page.dart';
import 'package:stayhub/features/agent/ticket_scanner_page.dart';
import 'package:stayhub/features/agent/agent_inbox_page.dart';
import 'package:stayhub/features/agent/add_clip_page.dart';

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
    final rawBal = userData['wallet_balance'];
    final double walletBalance = (rawBal is String ? double.tryParse(rawBal) : (rawBal as num?)?.toDouble()) ?? 0.0;
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
                      
                      // Calculate Real Average Rating
                      double totalRating = 0;
                      int ratedHostels = 0;
                      
                      if (hostelSnapshot.hasData) {
                        for (var doc in hostelSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data.containsKey('rating')) {
                             final ratingVal = data['rating'];
                             if (ratingVal is num) {
                               totalRating += ratingVal.toDouble();
                             } else if (ratingVal is String) {
                               totalRating += double.tryParse(ratingVal) ?? 0.0;
                             }
                             ratedHostels++;
                          }
                        }
                      }
                      
                      final String avgRatingDisplay = ratedHostels > 0 
                          ? (totalRating / ratedHostels).toStringAsFixed(1) 
                          : "New";

                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildFluidStatCard("Active Hostels", activeHostels.toString(), Icons.apartment_rounded, const Color(0xFFFF7E5F), const Color(0xFFFEB47B)),
                          _buildFluidStatCard("Total Bookings", totalBookings.toString(), Icons.bookmarks_rounded, const Color(0xFF6A11CB), const Color(0xFF2575FC)),
                          _buildFluidStatCard("Avg. Rating", avgRatingDisplay, Icons.star_rounded, const Color(0xFF11998E), const Color(0xFF38EF7D)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 30),
            
             // ANALYTICS CHART
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text("Revenue Analytics", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: _buildRevenueChart(),
            ),

            const SizedBox(height: 30),


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
                _buildActionTile(context, Icons.qr_code_scanner, "Scan Ticket", "Verify student check-in", () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScannerPage()));
                }),
                _buildActionTile(context, Icons.message_outlined, "Messages", "Student inquiries", () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentInboxPage()));
                }),
                _buildActionTile(context, Icons.video_camera_back_outlined, "Post Video Clip", "Showcase your hostel", () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClipPage()));
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
  Widget _buildRevenueChart() {
    // Mock Data for now, can be wired to real transactions later
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
                String text;
                switch (value.toInt()) {
                  case 0: text = 'JAN'; break;
                  case 2: text = 'MAR'; break;
                  case 4: text = 'MAY'; break;
                  case 6: text = 'JUL'; break;
                  case 8: text = 'SEP'; break;
                  case 10: text = 'NOV'; break;
                  default: return Container();
                }
                return Text(text, style: style);
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: 6,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(1, 1),
              FlSpot(2, 4),
              FlSpot(3, 2),
              FlSpot(4, 5),
              FlSpot(6, 3),
              FlSpot(8, 4),
              FlSpot(10, 5),
              FlSpot(11, 4),
            ],
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}
