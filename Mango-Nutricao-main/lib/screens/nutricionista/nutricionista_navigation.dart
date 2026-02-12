import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_colors.dart';
import '../../services/auth_service.dart';
import 'nutricionista_home_screen.dart';
import './nutricionista_listapacientes_screen.dart';

class NutricionistaNavigation extends StatefulWidget {
  final int currentPageIndex;

  const NutricionistaNavigation({super.key, this.currentPageIndex = 0});

  @override
  State<NutricionistaNavigation> createState() =>
      _NutricionistaNavigationState();
}

class _NutricionistaNavigationState extends State<NutricionistaNavigation> {
  late int _currentIndex;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentPageIndex;
  }

  Color _getIndicatorColor(int index) {
    return switch (index) {
      0 => AppColors.laranjaClaro,
      1 => AppColors.roxoClaro,
      2 => AppColors.verdeClaro,
      _ => Colors.black,
    };
  }

  void _navegarPara(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Obtém o ID do usuário logado (String)
    final authService = context.watch<AuthService>();
    final String uidUsuario = authService.usuario?.uid ?? '';

    // 2. Cria a lista de telas passando o ID correto (String)
    final List<Widget> screens = [
      NutricionistaHomeScreen(
        nutriId: uidUsuario,
        onMudarAba: _navegarPara,
      ), // Index 0
      const NutricionistaListaPacientesScreen(), // Index 1
    ];

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedIndex: _currentIndex,
        backgroundColor: Colors.white,
        indicatorColor: _getIndicatorColor(_currentIndex),
        surfaceTintColor: _getIndicatorColor(_currentIndex),
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.people_alt_outlined),
            icon: Icon(Icons.people_alt_rounded),
            label: 'Pacientes',
          ),
        ],
      ),
      // Exibe a tela correspondente ao índice atual
      body: screens[_currentIndex],
    );
  }
}
