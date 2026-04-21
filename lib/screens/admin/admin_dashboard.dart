import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/complaint_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../config/routes.dart';
import '../../utils/app_theme.dart';
import 'complaint_review_screen.dart';
import 'user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  ComplaintStatus? _selectedStatus;
  String _searchStudentId = '';
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No authenticated user.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(context, user),
            _buildNotificationsTab(context),
            _buildAccountTab(context, authProvider, user),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey[400],
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, dynamic user) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Welcome section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Review and respond to complaints',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Stats cards
        StreamBuilder<List<ComplaintModel>>(
          stream: FirestoreService().allComplaints(),
          builder: (context, snapshot) {
            final complaints = snapshot.data ?? [];
            final submitted = complaints
                .where((c) => c.status == ComplaintStatus.submitted)
                .length;
            final inReview = complaints
                .where((c) => c.status == ComplaintStatus.inReview)
                .length;
            final resolved = complaints
                .where((c) => c.status == ComplaintStatus.resolved)
                .length;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total',
                        complaints.length.toString(),
                        Icons.folder_outlined,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Submitted',
                        submitted.toString(),
                        Icons.hourglass_empty,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'In Review',
                        inReview.toString(),
                        Icons.autorenew,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Resolved',
                        resolved.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Complaints list title
        Text(
          'All Complaints',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),

        // Search and filters
        StreamBuilder<List<ComplaintModel>>(
          stream: FirestoreService().allComplaints(),
          builder: (context, snapshot) {
            final complaints = snapshot.data ?? [];
            final categories =
                complaints
                    .map((complaint) => complaint.category)
                    .toSet()
                    .toList()
                  ..sort();
            final filteredComplaints = complaints.where((complaint) {
              final matchesCategory =
                  _selectedCategory == null ||
                  complaint.category == _selectedCategory;
              final matchesStatus =
                  _selectedStatus == null ||
                  complaint.status == _selectedStatus;
              final matchesSearch =
                  _searchStudentId.isEmpty ||
                  complaint.studentId.toLowerCase().contains(
                    _searchStudentId.toLowerCase(),
                  );
              return matchesCategory && matchesStatus && matchesSearch;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Search field
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            onChanged: (value) {
                              setState(() => _searchStudentId = value);
                            },
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search student ID',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Category filter
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String?>(
                          value: _selectedCategory,
                          isDense: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            ...categories.map(
                              (category) => DropdownMenuItem<String?>(
                                value: category,
                                child: Text(
                                  category.length > 8
                                      ? '${category.substring(0, 8)}...'
                                      : category,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategory = value);
                          },
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status filter
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<ComplaintStatus?>(
                          value: _selectedStatus,
                          isDense: true,
                          items: [
                            const DropdownMenuItem<ComplaintStatus?>(
                              value: null,
                              child: Text(
                                'All',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            ...ComplaintStatus.values.map(
                              (value) => DropdownMenuItem<ComplaintStatus?>(
                                value: value,
                                child: Text(
                                  value.name.length > 8
                                      ? '${value.name.substring(0, 8)}...'
                                      : value.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedStatus = value);
                          },
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Clear filters button
                      SizedBox(
                        width: 70,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchStudentId = '';
                              _selectedCategory = null;
                              _selectedStatus = null;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Showing ${filteredComplaints.length} of ${complaints.length} complaints',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (filteredComplaints.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No complaints match your search or filters',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(
                      filteredComplaints.length,
                      (index) => _buildComplaintCard(
                        context,
                        filteredComplaints[index],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNotificationsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No new notifications',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTab(
    BuildContext context,
    dynamic authProvider,
    dynamic user,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Account Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),

        // Profile card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 32,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? user.studentId,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _buildAccountOption(
                Icons.admin_panel_settings,
                'Admin ID',
                user.studentId,
              ),
              const SizedBox(height: 12),
              _buildAccountOption(
                Icons.security_outlined,
                'Role',
                user.role.toUpperCase(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // User Management button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              );
            },
            icon: const Icon(Icons.people),
            label: const Text('Manage Users & Admins'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sign out button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, Routes.login);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.red, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintCard(BuildContext context, ComplaintModel complaint) {
    final statusColor = _getStatusColor(complaint.status);
    final statusIcon = _getStatusIcon(complaint.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ComplaintReviewScreen(complaintId: complaint.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'From: ${complaint.studentId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    complaint.category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(
                          complaint.status.name.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: statusColor.withOpacity(0.1),
                        side: BorderSide(color: statusColor.withOpacity(0.3)),
                      ),
                      Text(
                        _formatDate(complaint.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAccountOption(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return Colors.orange;
      case ComplaintStatus.inReview:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.submitted:
        return Icons.hourglass_empty;
      case ComplaintStatus.inReview:
        return Icons.autorenew;
      case ComplaintStatus.resolved:
        return Icons.check_circle;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
