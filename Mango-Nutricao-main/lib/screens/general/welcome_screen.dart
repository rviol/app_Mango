import 'package:flutter/material.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart'; // Importando seus estilos padronizados
import 'login_screen.dart';
import 'register_screen.dart';

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // --- LOGO COM SOMBRA SUAVE ---
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.roxo.withOpacity(0.1), // Fundo Roxo Claro
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.roxo.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Transform.scale(
                      scale: 1.0, 
                      child: Image.asset(
                        'assets/imagem_logo_manga.png',
                        fit: BoxFit.scaleDown,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              // --- TÍTULO E SUBTÍTULO ---
              const Text(
                "Mango Nutri",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.roxo, // Usando a cor do tema
                  letterSpacing: -0.5,
                ),
              ),
              
              const SizedBox(height: 12),

              Text(
                "Seu acompanhamento nutricional\ninteligente e simplificado.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // --- BOTÃO ENTRAR ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde, // Verde do tema
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.verde.withOpacity(0.4),
                    // PADRÃO: Usando o shape definido no AppStyles (radius 16)
                    shape: AppStyles.shapeButton, 
                  ),
                  child: const Text(
                    "Entrar",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- BOTÃO CADASTRAR ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.verde,
                    side: const BorderSide(color: AppColors.verde, width: 2),
                    // PADRÃO: Usando o shape definido no AppStyles (radius 16)
                    shape: AppStyles.shapeButton,
                  ),
                  child: const Text(
                    "Criar Conta",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}