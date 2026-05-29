import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/features/bookings/bookings_page.dart';

class ReceiptPage extends StatefulWidget {
  final Booking booking;
  final String transactionRef;

  const ReceiptPage({
    super.key,
    required this.booking,
    required this.transactionRef,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  late String _currentRef;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentRef = widget.transactionRef;
    if (_currentRef == "N/A" || _currentRef.isEmpty) {
      _refreshBookingData();
    }
  }

  Future<void> _refreshBookingData() async {
    setState(() => _isRefreshing = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['paymentReference'] != null) {
          setState(() {
            _currentRef = data['paymentReference'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error refreshing receipt: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_GH', symbol: '₵');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("OFFICIAL RECEIPT", 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshBookingData,
            icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.black),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // THE RECEIPT CARD
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Section with Brand Color
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E2AB7), // Primary Brand
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("STAYHUB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                                Text("SECURE BOOKING", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text("ORIGINAL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            )
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
                        child: Column(
                          children: [
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 8),
                                  Text("PAID FULL", style: TextStyle(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Amount
                            Text(
                              currencyFormat.format(widget.booking.price),
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1.5),
                            ),
                            const Text("TRANSACTION SUCCESSFUL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                            const SizedBox(height: 40),
                            
                            // Detailed Rows
                            _buildInfoSection(isDark, [
                              _buildRow("BOOKING ID", widget.booking.id),
                              _buildRow("TRANSACTION REF", _currentRef == "N/A" && _isRefreshing ? "Verifying..." : _currentRef),
                              _buildRow("DATE & TIME", DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.now())),
                              _buildRow("HOSTEL", widget.booking.hostelName),
                              _buildRow("ROOM TYPE", widget.booking.roomType?.replaceAll('-', ' ').toUpperCase() ?? "STANDARD"),
                            ]),
                            
                            const SizedBox(height: 40),
                            
                            // QR CODE AREA
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: "STAYHUB|${widget.booking.id}|${_currentRef}",
                                    version: QrVersions.auto,
                                    size: 160.0,
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text("SCAN FOR ENTRY VERIFICATION", 
                                    style: TextStyle(
                                      color: Color(0xFF2E2AB7), 
                                      fontSize: 10, 
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    )
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Ticket is non-transferable and valid for one entry.", 
                                    style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // ACTIONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receipt saved to gallery!")));
                        },
                        icon: const Icon(Icons.file_download_rounded, size: 20),
                        label: const Text("SAVE RECEIPT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E2AB7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 10,
                          shadowColor: const Color(0xFF2E2AB7).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text("SHARE WITH AGENT", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
          Flexible(
            child: Text(
              value, 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            )
          ),
        ],
      ),
    );
  }
}
