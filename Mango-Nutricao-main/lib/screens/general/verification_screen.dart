import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_check.dart'; 
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart'; // [IMPORTANTE] Importando os estilos

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _estaCarregandoVerificacao = false;
  bool _estaCarregandoReenvio = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Verifica automaticamente a cada 3 segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _verificarStatus(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verificarStatus({bool silencioso = false}) async {
    if (!silencioso) setState(() => _estaCarregandoVerificacao = true);
    
    final auth = Provider.of<AuthService>(context, listen: false);
    // Nota: Certifique-se que seu AuthService tem o reload do user antes de checar
    // await auth.usuario?.reload(); 
    bool ok = await auth.checarEmailVerificado();
    
    if (mounted && ok) {
      _timer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthCheck()),
      );
    } else if (mounted && !silencioso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("O e-mail ainda não foi confirmado. Verifique sua caixa de entrada."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted && !silencioso) setState(() => _estaCarregandoVerificacao = false);
  }

  Future<void> _reenviarEmail() async {
    setState(() => _estaCarregandoReenvio = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.reenviarEmailVerificacao();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Novo link de ativação enviado!"),
            backgroundColor: AppColors.verde, // Verde para sucesso
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _estaCarregandoReenvio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Removemos o botão de voltar padrão pois o fluxo exige verificação ou logout
        automaticallyImplyLeading: false, 
        actions: [
          TextButton.icon(
            onPressed: () {
              _timer?.cancel();
              Provider.of<AuthService>(context, listen: false).logout();
            },
            icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
            label: const Text("Sair", style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2), // Empurra levemente para cima

              // --- ÍCONE ESTILIZADO ---
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.roxo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined, 
                  size: 70, 
                  color: AppColors.roxo,
                ),
              ),
              
              const SizedBox(height: 30),

              // --- TÍTULO E TEXTO ---
              const Text(
                "Verifique seu e-mail",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black87
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                "Enviamos um link de confirmação para o seu endereço de e-mail. Clique no link para ativar sua conta.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),
              
              // --- BOTÃO PRINCIPAL (JÁ VERIFIQUEI) ---
              SizedBox(
                width: double.infinity, 
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.roxo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    // PADRÃO: Radius 16
                    shape: AppStyles.shapeButton, 
                  ),
                  onPressed: _estaCarregandoVerificacao ? null : () => _verificarStatus(),
                  child: _estaCarregandoVerificacao 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("JÁ VERIFIQUEI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),

              // --- BOTÃO REENVIAR ---
              TextButton(
                onPressed: _estaCarregandoReenvio ? null : _reenviarEmail,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.roxo,
                  shape: AppStyles.shapeButton,
                ),
                child: _estaCarregandoReenvio 
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.roxo))
                  : const Text("Não recebeu? Reenviar e-mail", style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}