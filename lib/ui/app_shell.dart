import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/more_screen.dart';
import 'screens/news_screen.dart';
import 'screens/programs_screen.dart';
import 'widgets/mini_player.dart';

/// Estructura principal: cinco pestañas, cada una con su propia pila de
/// navegación, y el mini reproductor siempre visible encima de la barra.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _navigators = List.generate(5, (_) => GlobalKey<NavigatorState>());

  void _select(int i) {
    if (i == _index) {
      // Volver a pulsar la pestaña activa regresa a su inicio.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  Widget _tab(int i, Widget root) => Navigator(
        key: _navigators[i],
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
      );

  @override
  Widget build(BuildContext context) {
    final nav = _navigators[_index].currentState;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        } else {
          // En la raíz de Inicio, salir de la app (el audio sigue sonando).
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _tab(0, HomeScreen(onOpenTab: _select)),
            _tab(1, const ProgramsScreen()),
            _tab(2, const NewsScreen()),
            _tab(3, const LibraryScreen()),
            _tab(4, const MoreScreen()),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
                NavigationDestination(icon: Icon(Icons.podcasts_outlined), selectedIcon: Icon(Icons.podcasts_rounded), label: 'Programas'),
                NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper_rounded), label: 'Noticias'),
                NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Biblioteca'),
                NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Más'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
