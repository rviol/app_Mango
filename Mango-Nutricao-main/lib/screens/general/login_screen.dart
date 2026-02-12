import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart'; // [IMPORTANTE]
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _estaCarregando = false;

  Future<void> _fazerLogin() async {
    setState(() => _estaCarregando = true);
    try {
      await Provider.of<AuthService>(context, listen: false).login(
        _emailController.text.trim(),
        _senhaController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: AppColors.roxo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/imagem_logo_manga.png', fit: BoxFit.fill),
                ),
              ),
              
              const SizedBox(height: 25),
              const Text("Bem-vindo de volta!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Text("Faça login para continuar", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // INPUTS
              _buildTextField("E-mail", _emailController, Icons.email_outlined, type: TextInputType.emailAddress),
              const SizedBox(height: 15),
              _buildTextField("Senha", _senhaController, Icons.lock_outline, isPassword: true),

              // ESQUECI SENHA
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text("Esqueceu a senha?", style: TextStyle(color: AppColors.roxo, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 20),

              // BOTÃO ENTRAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _estaCarregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: AppStyles.shapeButton, // Radius 16
                    elevation: 0,
                  ),
                  child: _estaCarregando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ENTRAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 30),

              // RODAPÉ CADASTRO
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Não tem uma conta? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text("Cadastre-se", style: TextStyle(color: AppColors.roxo, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController ctrl, IconData icon, {bool isPassword = false, TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      keyboardType: type,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: AppColors.cinzaClaro,
        border: OutlineInputBorder(borderRadius: AppStyles.borderButton, borderSide: BorderSide.none), // Radius 16
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}