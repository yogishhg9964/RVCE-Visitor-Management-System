import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/image_carousel.dart';
import '../widgets/app_drawer.dart';
import 'quick_checkin_screen.dart';
import 'qr_scanner_screen.dart';
import 'cab_entry_screen.dart';
import 'todays_visitors_screen.dart';
import 'pending_approvals_screen.dart';

class VisitorManagementScreen extends ConsumerWidget {
  const VisitorManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final screenWidth = ResponsiveUtils.getScreenWidth(context);
    final isSmallScreen = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    // Dynamic grid calculations
    final crossAxisCount = ResponsiveUtils.isDesktop(context)
        ? screenWidth > 1600
            ? 5 // Extra large screens
            : 4 // Normal desktop
        : isTablet
            ? screenWidth > 900
                ? 3 // Large tablets
                : 2 // Regular tablets
            : 2; // Mobile

    // Dynamic aspect ratio based on screen size and orientation
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final childAspectRatio = isLandscape ? 1.4 : 1.0;

    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Image Carousel with responsive height
                  SizedBox(
                    width: constraints.maxWidth,
                    child: const ImageCarousel(),
                  ),
                  const SizedBox(height: 20),
                  // Dashboard Grid
                  Padding(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: isSmallScreen ? 12 : 16,
                        crossAxisSpacing: isSmallScreen ? 12 : 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      children: [
                        _buildDashboardCard(
                          context: context,
                          title: 'Quick Check-In',
                          subtitle: 'Fast track visitor entry',
                          icon: Icons.flash_on,
                          onTap: () =>
                              _navigateTo(context, const QuickCheckInScreen()),
                        ),
                        
                        _buildDashboardCard(
                          context: context,
                          title: 'Cab Entry',
                          subtitle: 'Register campus cabs',
                          icon: Icons.local_taxi,
                          onTap: () =>
                              _navigateTo(context, const CabEntryScreen()),
                        ),
                        _buildDashboardCard(
                          context: context,
                          title: 'Pending Approvals',
                          subtitle: 'View pending requests',
                          icon: Icons.access_time,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PendingApprovalsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildDashboardCard(
                          context: context,
                          title: "Today's Visitors",
                          subtitle: 'View active visitors',
                          icon: Icons.people,
                          onTap: () => _navigateTo(
                              context, const TodaysVisitorsScreen()),
                        ),
                      ],
                    ),
                  ),
                  // Bottom padding for scrolling
                  SizedBox(height: isSmallScreen ? 16 : 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSmallScreen = ResponsiveUtils.isMobile(context);

    return DashboardCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      titleStyle: TextStyle(
        fontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          baseFontSize: isSmallScreen ? 14 : 16,
        ),
        fontWeight: FontWeight.w600,
      ),
      subtitleStyle: TextStyle(
        fontSize: ResponsiveUtils.getResponsiveFontSize(
          context,
          baseFontSize: isSmallScreen ? 12 : 14,
        ),
        color: Colors.grey[600],
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {  // Change to ConsumerStatefulWidget
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _showQuickCheckInDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Phone Number'),
        content: const TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Phone Number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Handle phone number submission
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCheckInCard(BuildContext context) {  // Add context parameter
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showQuickCheckInDialog(context),
                  icon: const Icon(Icons.phone),
                  label: const Text('Phone Number'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRScannerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildQuickCheckInCard(context),  // Pass context here
            // ...other widgets
          ],
        ),
      ),
    );
  }
}
