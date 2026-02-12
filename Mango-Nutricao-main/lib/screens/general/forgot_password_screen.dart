import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart'; // [IMPORTANTE] Importando os estilos

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _estaCarregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetarSenha() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, digite seu e-mail."), 
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _estaCarregando = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.recuperarSenha(_emailController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("E-mail enviado! Verifique sua caixa de entrada."), 
            backgroundColor: AppColors.verde, // Verde para sucesso
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _estaCarregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Recuperar Senha",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // --- ÍCONE ILUSTRATIVO ---
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.verde.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset,
                  size: 50,
                  color: AppColors.verde,
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text(
                "Esqueceu sua senha?",
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                "Não se preocupe! Digite seu e-mail abaixo e enviaremos instruções para redefinir sua senha.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
              ),
              
              const SizedBox(height: 40),
              
              // --- CAMPO DE E-MAIL ---
              _buildTextField("Digite seu e-mail", _emailController),
              
              const SizedBox(height: 30),
              
              // --- BOTÃO DE AÇÃO ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _estaCarregando ? null : _resetarSenha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    // PADRÃO: Radius 16 via AppStyles
                    shape: AppStyles.shapeButton,
                    elevation: 0,
                  ),
                  child: _estaCarregando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "ENVIAR LINK", 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: AppColors.cinzaClaro,
        // PADRÃO: Radius 16 via AppStyles
        border: OutlineInputBorder(
          borderRadius: AppStyles.borderButton, 
          borderSide: BorderSide.none
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}