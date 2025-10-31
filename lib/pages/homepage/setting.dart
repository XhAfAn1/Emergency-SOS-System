import 'package:flutter/material.dart';
import '../../Class Models/user.dart';
import '../../backend/gesture setup.dart';
import '../homepage/drawer.dart';

class Setting extends StatefulWidget {
  final UserModel? currentUser;
  const Setting({super.key, required this.currentUser});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(currentUser: widget.currentUser, activePage: 7),
      backgroundColor: const Color(0xFFF8FAFC),
      body:CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            _buildContentSection(),
          ],
        ),

    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      collapsedHeight: 75,
      expandedHeight: 75,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0, top: 10, right: 0),
        child: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFF1F2937),
                  size: 24,
                ),
              ),
            );
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'SETTING',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Color(0xFFF8FAFC),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate(
          [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE1E1E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Turn on Accessibility',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings_suggest, size: 18),
                    label: const Text('Set up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff25282b),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      AccessibilityServiceHelper.openAccessibilitySettings();
                    },
                  ),

              ]
              ),
            )
          ]
      ),
    ));
  }

}
