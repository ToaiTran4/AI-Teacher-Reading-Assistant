import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'documents_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart'; // <--- MỚI: Import màn hình Profile

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình chính
  final List<Widget> _screens = [
    const ChatScreen(), // Index 0
    const DocumentsScreen(), // Index 1
    const ProfileScreen(), // Index 2: Màn hình Hồ sơ & Đăng xuất
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Hàm đăng xuất (Vẫn giữ lại để dùng cho Drawer nếu cần)
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Đăng xuất', style: AppTheme.h3),
        content:
            Text('Bạn có chắc muốn đăng xuất?', style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      await context.read<AuthController>().logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;

    return Scaffold(
      // SỬ DỤNG INDEXED STACK: Giữ trạng thái các trang khi chuyển tab
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle:
              AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTheme.bodySmall,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Documents',
            ),
            // <--- MỚI: Thêm Tab User vào đây
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),

      // Giữ nguyên Drawer cũ (nếu bạn muốn xóa Drawer để dùng hẳn Tab User thì cứ xóa phần này đi)
      drawer: Drawer(
        backgroundColor: AppTheme.surfaceColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryColor),
              accountName: Text(
                user?.displayName ?? 'User',
                style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textOnPrimary, fontWeight: FontWeight.w600),
              ),
              accountEmail: Text(
                user?.email ?? '',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textOnPrimary.withOpacity(0.9)),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppTheme.backgroundColor,
                child: Text(
                  user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                  style: AppTheme.h3.copyWith(color: AppTheme.primaryColor),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline,
                  color: _selectedIndex == 0
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary),
              title: Text('Chat',
                  style: AppTheme.bodyMedium.copyWith(
                      color: _selectedIndex == 0
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary)),
              selected: _selectedIndex == 0,
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined,
                  color: _selectedIndex == 1
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary),
              title: Text('Documents',
                  style: AppTheme.bodyMedium.copyWith(
                      color: _selectedIndex == 1
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary)),
              selected: _selectedIndex == 1,
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            // <--- MỚI: Thêm tùy chọn Hồ sơ vào Drawer cho đồng bộ
            ListTile(
              leading: Icon(Icons.person_outline,
                  color: _selectedIndex == 2
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary),
              title: Text('Hồ sơ cá nhân',
                  style: AppTheme.bodyMedium.copyWith(
                      color: _selectedIndex == 2
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary)),
              selected: _selectedIndex == 2,
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context);
              },
            ),
            const Divider(color: AppTheme.dividerColor),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text('Đăng xuất',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
