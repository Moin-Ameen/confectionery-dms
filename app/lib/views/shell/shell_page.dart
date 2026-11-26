import 'package:flutter/material.dart';

/// Global key of the home shell scaffold (to open the drawer from any screen).
final shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Standard page used by every top-level module screen.
class ShellPage extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? fab;
  final PreferredSizeWidget? bottom;

  const ShellPage({super.key, required this.title, required this.body, this.actions, this.fab, this.bottom});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? null
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
              ),
        title: Text(title),
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: fab,
      body: body,
    );
  }
}
