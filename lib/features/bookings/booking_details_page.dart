import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/bookings/bookings_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
// import 'dart:io' show File;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingDetailsPage extends StatefulWidget {
  final Booking booking;

  const BookingDetailsPage({super.key, required this.booking});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final GlobalKey _ticketKey = GlobalKey();
  bool _isSaving = false;
  bool _isCancelling = false;

  Future<void> _captureAndSaveTicket() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket saving is currently only supported on mobile devices.")));
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      // 1. Wait for end of frame to ensure painting is done
      await Future.delayed(const Duration(milliseconds: 20));

      RenderRepaintBoundary? boundary = _ticketKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Could not find ticket boundary. Scroll to view ticket.");
      }

      // 2. Capture Image (Use 2.0 for better performance/compatibility)
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) throw Exception("Failed to generate image data");
      
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 3. Share directly from memory using XFile
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'stayhub_ticket_${widget.booking.id}.png',
      );

      await Share.shareXFiles(
        [xFile], 
        text: 'My StayHub Booking Ticket - ${widget.booking.hostelName}'
      );
      
    } catch (e) {
      debugPrint("Save Ticket Error: $e");
      if (mounted) {
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text("Error Saving Ticket"),
            content: Text(e.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _requestRefund(Booking currentBooking) async {
    setState(() => _isCancelling = true); // Show loading while checking time
    
    try {
      // 1. Enforce 24-Hour Rule
      final doc = await FirebaseFirestore.instance.collection('bookings').doc(currentBooking.id).get();
      final bookedAt = (doc.data()?['timestamp'] as Timestamp?)?.toDate();

      if (bookedAt != null) {
         final hoursSince = DateTime.now().difference(bookedAt).inHours;
         if (hoursSince > 24) {
             if (mounted) {
               showDialog(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   title: const Text("Refund Period Expired"),
                   content: Text("Refunds are only available within 24 hours of booking.\n\nTime elapsed: $hoursSince hours.\n\nPlease contact the agent directly for assistance."),
                   actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
                 )
               );
             }
             setState(() => _isCancelling = false);
             return;
         }
      }
    } catch (e) {
      // Ignore error and proceed if timestamp check fails (fallback to allow request)
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }

    // 2. Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Refund?"),
        content: const Text("This will cancel your booking immediately. Refunds are processed within 5-10 business days.\n\nNote: This is only permitted within 24 hours of booking."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep Booking")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Cancel Booking", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      // Update Firestore
      await FirebaseFirestore.instance.collection('bookings').doc(currentBooking.id).update({
        'status': 'CANCELLED', // Use uppercase to match other statuses
        'refund_status': 'REQUESTED',
        'cancelled_at': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancellation Request Sent."), backgroundColor: Colors.red));
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_GH', symbol: 'GHS ');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Your Ticket"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).snapshots(),
        builder: (context, snapshot) {
          // FALLBACK STRATEGY:
          // If we fail to load the fresh document (e.g. deleted, network error, permission),
          // we should still show the ticket using the data passed from the previous screen.
          
          Booking booking;
          
          if (snapshot.hasError || !snapshot.hasData || (snapshot.data != null && !snapshot.data!.exists)) {
             debugPrint("Using fallback booking data due to error/missing doc.");
             booking = widget.booking;
          } else {
             booking = Booking.fromFirestore(snapshot.data!);
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Ticket
                  RepaintBoundary(
                    key: _ticketKey,
                    child: _buildTicket(context, isDark, currencyFormat, booking),
                  ),
                  const SizedBox(height: 30),
                  
                  // Action Buttons
                  Row(
                    children: [
                       Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _captureAndSaveTicket,
                          icon: _isSaving 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                              : const Icon(Icons.share_rounded),
                          label: Text(_isSaving ? "Saving..." : "Save Ticket"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      
                      // Replaced Cancel Button with Policy Info
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                             showDialog(
                               context: context,
                               builder: (ctx) => AlertDialog(
                                 title: const Text("Cancellation Policy"),
                                 content: const Text(
                                   "To protect both students and agents, bookings cannot be cancelled via the app once paid.\n\n"
                                   "We strongly recommend visiting the hostel or contacting the agent to verify the room before making a payment.\n\n"
                                   "If you have a critical issue, please contact StayHub support."
                                 ),
                                 actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Understood"))],
                               )
                             );
                          },
                          icon: Icon(Icons.info_outline, color: isDark ? Colors.white70 : Colors.grey[700]),
                          label: Text("Policy", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[400]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (booking.status == 'CANCELLED' || booking.status == 'cancelled')
                     Padding(
                       padding: const EdgeInsets.only(top: 24),
                       child: Container(
                         width: double.infinity,
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withOpacity(0.3))),
                         child: Column(
                           children: [
                             const Icon(Icons.info_outline, color: Colors.red, size: 30),
                             const SizedBox(height: 8),
                             const Text("Booking Cancelled", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                             const SizedBox(height: 4),
                             Text("One of our agents will contact you regarding your refund status.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red[800])),
                           ],
                         ),
                       ),
                     )
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildTicket(BuildContext context, bool isDark, NumberFormat currencyFormat, Booking booking) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Image Header
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(
              booking.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                height: 180,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
          ),

          // 2. Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.hostelName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        booking.location,
                        style: TextStyle(color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (booking.roomType != null || booking.capacity != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.meeting_room_rounded, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (booking.roomType?.replaceAll('-', ' ') ?? "${booking.capacity ?? '?'} in a room"),
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn("Check In", booking.checkIn),
                    _buildInfoColumn("Check Out", booking.checkOut),
                  ],
                ),
                const SizedBox(height: 24),
                // Dashed line
                LayoutBuilder(builder: (context, constraints) {
                  return Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate((constraints.constrainWidth() / 10).floor(), (index) => SizedBox(width: 5, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey[400])))),
                  );
                }),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Paid", style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      currencyFormat.format(booking.price),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                // Status Stamp
                if (booking.status == 'CANCELLED')
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(8)),
                    child: const Text("CANCELLED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
              ],
            ),
          ),

          // 3. QR Code Section (Bottom)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [

              // Real QR Code
              Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(10), // Padding for quiet zone
                child: Center(
                  child: QrImageView(
                    data: booking.id, 
                    version: QrVersions.auto,
                    size: 140.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                         eyeShape: QrEyeShape.square,
                         color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                         dataModuleShape: QrDataModuleShape.square,
                         color: Colors.black,
                    ),
                  ),
                ),
              ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SelectableText(
                      "ID: ${booking.id}",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: booking.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Booking ID copied to clipboard"), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          DateFormat('MMM d, yyyy').format(date),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          DateFormat('h:mm a').format(date),
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
