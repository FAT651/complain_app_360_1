import 'package:flutter/material.dart';

/// A responsive scaffold that shows a sidebar on desktop and bottom navigation on mobile
class ResponsiveScaffold extends StatefulWidget {
  /// The main content of the scaffold
  final List<Widget> pages;

  /// The current selected page index
  final int selectedIndex;

  /// Callback when page index changes
  final ValueChanged<int> onPageChanged;

  /// Navigation items with icon, label, and optional color
  final List<NavigationItem> navigationItems;

  /// The background color
  final Color? backgroundColor;

  /// Floating action button (only shown on mobile for specific pages)
  final FloatingActionButton? floatingActionButton;

  /// The width of the sidebar on desktop (default: 250)
  final double sidebarWidth;

  /// Whether to show the sidebar on desktop
  final bool showSidebar;

  /// Optional app bar for desktop
  final PreferredSizeWidget? desktopAppBar;

  const ResponsiveScaffold({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onPageChanged,
    required this.navigationItems,
    this.backgroundColor,
    this.floatingActionButton,
    this.sidebarWidth = 250,
    this.showSidebar = true,
    this.desktopAppBar,
  });

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop && widget.showSidebar) {
      // Desktop layout with sidebar
      return Scaffold(
        backgroundColor: widget.backgroundColor,
        floatingActionButton: widget.floatingActionButton,
        body: Row(
          children: [
            // Sidebar
            Container(
              width: widget.sidebarWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // App title/logo area
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: const Text(
                      'Complaint App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // Navigation items
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.navigationItems.length,
                      itemBuilder: (context, index) {
                        final item = widget.navigationItems[index];
                        final isSelected = widget.selectedIndex == index;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onPageChanged(index),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? item.color?.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? item.activeIcon ?? item.icon
                                          : item.icon,
                                      color: isSelected
                                          ? item.color ?? Colors.blue
                                          : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? item.color ?? Colors.blue
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: IndexedStack(
                index: widget.selectedIndex,
                children: widget.pages,
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile layout with bottom navigation
      return Scaffold(
        backgroundColor: widget.backgroundColor,
        body: SafeArea(
          child: IndexedStack(
            index: widget.selectedIndex,
            children: widget.pages,
          ),
        ),
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: widget.selectedIndex,
          onTap: widget.onPageChanged,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          items: widget.navigationItems
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon ?? item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      );
    }
  }
}

/// Model for navigation items
class NavigationItem {
  final IconData icon;
  final String label;
  final IconData? activeIcon;
  final Color? color;

  NavigationItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.color,
  });
}
