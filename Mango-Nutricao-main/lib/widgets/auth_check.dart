import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/general/verification_screen.dart';
import '../screens/general/welcome_screen.dart';
import '../screens/nutricionista/nutricionista_navigation.dart';
import '../screens/paciente/paciente_navigation.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    // 1. Carregando inicial (Verificando Auth ou Baixando dados do Banco)
    if (auth.estaCarregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.purple)),
      );
    }

    // 2. Usuário não logado -> Tela de Login
    if (auth.usuario == null) {
      return const InitialScreen();
    } 
    
    // 3. Usuário logado, mas E-mail não verificado -> Tela de Verificação
    else if (!auth.usuario!.emailVerified) {
      return const VerificationScreen();
    } 
    
    // 4. Usuário logado e verificado -> Roteamento por TIPO
    else {
      // Acessamos o mapa que seu AuthService carregou
      final dados = auth.dadosUsuario;

      // Segurança: Se por algum motivo os dados ainda não chegaram (null)
      if (dados == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.purple)),
        );
      }

      final tipo = dados['tipo']; // 'paciente' ou 'nutricionista'

      if (tipo == 'paciente') {
        return PacienteNavigation();
      } else if (tipo == 'nutricionista') {
        return NutricionistaNavigation(); 
      } else {
        // Caso raro: Logado, mas sem tipo definido ou tipo desconhecido
        return Scaffold(
          body: Center(
            child: Text("Erro: Tipo de usuário desconhecido ($tipo)"),
          ),
        );
      }
    }
  }
}