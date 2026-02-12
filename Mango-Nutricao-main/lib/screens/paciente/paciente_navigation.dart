import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart'; 
import '../../widgets/app_colors.dart';
import 'paciente_antropometria_screen.dart';
import 'paciente_home_screen.dart';
import 'paciente_planoalimentar_screen.dart';

class PacienteNavigation extends StatefulWidget {
  final int currentPageIndex; 
  
  const PacienteNavigation({super.key, this.currentPageIndex = 0});

  @override
  State<PacienteNavigation> createState() => _PacienteNavigationState();
}

class _PacienteNavigationState extends State<PacienteNavigation> {
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
      HomeTabScreen(pacienteId: uidUsuario, onMudarAba: _navegarPara),           // Index 0
      AntropometriaVisualizacaoPage(pacienteId: uidUsuario), // Index 1
      const PacientePlanoAlimentarScreen(),            // Index 2
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
            selectedIcon: Icon(Icons.accessibility_new_rounded),
            icon: Icon(Icons.accessibility_new_outlined),
            label: 'Antropometria',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.restaurant_menu),
            icon: Icon(Icons.restaurant_menu_outlined),
            label: 'Plano Alimentar',
          ),
        ],
      ),
      // Exibe a tela correspondente ao índice atual
      body: screens[_currentIndex],
    );
  }
}