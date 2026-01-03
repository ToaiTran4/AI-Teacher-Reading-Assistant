import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../theme/theme_provider.dart'; // Import ThemeProvider
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Avatar mặc định
  String _currentAvatarUrl = 'https://i.pravatar.cc/300?img=12';

  final List<String> _sampleAvatars = [
    'https://i.pravatar.cc/300?img=1',
    'https://i.pravatar.cc/300?img=3',
    'https://i.pravatar.cc/300?img=8',
    'https://i.pravatar.cc/300?img=12',
    'https://i.pravatar.cc/300?img=33',
    'https://i.pravatar.cc/300?img=47',
  ];

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;

    // Lấy ThemeProvider để xử lý nút đổi theme
    final themeProvider = context.watch<ThemeProvider>();

    // Lấy màu từ Theme hiện tại (Do AppTheme quy định)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Màu nền tự động đổi theo theme
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text('Hồ sơ học tập',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.transparent, // Trong suốt để thấy nền
        elevation: 0,
        actions: [
          // NÚT ĐỔI THEME (Sáng/Tối)
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: colorScheme.onSurface,
            ),
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. AVATAR PICKER
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(_currentAvatarUrl),
                      backgroundColor: colorScheme.surface,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showAvatarBottomSheet, // Mở bảng chọn avatar
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.scaffoldBackgroundColor, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Chưa đặt tên',
              style: theme.textTheme.displaySmall?.copyWith(fontSize: 22),
            ),
            Text(
              user?.email ?? 'email@example.com',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 30),

            // 2. DASHBOARD (Thống kê)
            Row(
              children: [
                _buildStatCard(
                    context, 'Đã đọc', '12', Icons.book, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard(context, 'Điểm Quiz', '8.5', Icons.emoji_events,
                    Colors.amber),
                const SizedBox(width: 12),
                _buildStatCard(
                    context, 'Giờ học', '45h', Icons.access_time, Colors.green),
              ],
            ),

            const SizedBox(height: 30),

            // 3. MENU ITEMS
            _buildMenuSection(context),

            const SizedBox(height: 30),

            // 4. LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET CON & LOGIC ---

  // Thẻ thống kê (Card)
  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color, // Màu card tự động theo theme
          borderRadius: BorderRadius.circular(16),
          boxShadow: theme.brightness == Brightness.light
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  // Khu vực Menu
  Widget _buildMenuSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMenuItem(context, Icons.history, 'Lịch sử hoạt động',
              () => _navigateTo('Lịch sử')),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildMenuItem(context, Icons.bookmark, 'Mục đã lưu',
              () => _navigateTo('Mục đã lưu')),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildMenuItem(context, Icons.help_outline, 'Trợ giúp & Phản hồi',
              () => _navigateTo('Trợ giúp')),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  // Logic chọn Avatar (BottomSheet)
  void _showAvatarBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            children: [
              Text('Chọn Avatar mới',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: _sampleAvatars.length,
                  itemBuilder: (ctx, index) {
                    final url = _sampleAvatars[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentAvatarUrl = url);
                        Navigator.pop(ctx);
                      },
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(url),
                        radius: 30,
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Logic điều hướng
  void _navigateTo(String title) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (ctx) => Scaffold(
                  appBar: AppBar(title: Text(title)),
                  body: Center(child: Text('Tính năng $title đang phát triển')),
                )));
  }

  // Logic đăng xuất
  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthController>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
