import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'verification_screen.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';

enum UserType { paciente, nutricionista }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  UserType _selectedUser = UserType.paciente;
  String _generoSelecionado = 'Feminino'; 
  bool _estaCarregando = false;

  final _nomeController = TextEditingController();
  final _dataNascController = TextEditingController();
  final _crnController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  final maskData = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // Se o CRN tiver um formato fixo (ex: 12345), usamos apenas digitsOnly.
  // Se quiser uma máscara específica (ex: UF-12345), pode criar outro MaskTextInputFormatter.

  bool _senhasNaoCoincidem = false;
  bool _formularioCompleto = false;
  String? _erroRequisitoSenha;
  String? _erroCrn; // Novo erro específico para CRN

  @override
  void initState() {
    super.initState();
    List<TextEditingController> controllers = [
      _nomeController, _dataNascController, _crnController,
      _emailController, _senhaController, _confirmarSenhaController,
    ];
    for (var c in controllers) c.addListener(_atualizarEstadoFormulario);
  }

  @override
  void dispose() {
    _nomeController.dispose(); _dataNascController.dispose(); _crnController.dispose();
    _emailController.dispose(); _senhaController.dispose(); _confirmarSenhaController.dispose();
    super.dispose();
  }

  // --- VALIDAÇÕES ---
  String? _validarRequisitosSenha(String senha) {
    if (senha.isEmpty) return null;
    if (senha.length < 8) return "Mínimo 8 caracteres";
    if (!RegExp(r'[A-Z]').hasMatch(senha)) return "Falta letra maiúscula";
    if (!RegExp(r'[a-z]').hasMatch(senha)) return "Falta letra minúscula";
    if (!RegExp(r'[0-9]').hasMatch(senha)) return "Falta número";
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(senha)) return "Falta caractere especial";
    return null;
  }

  String? _validarDataNascimento(String data) {
    if (data.isEmpty || data.length < 10) return null;
    try {
      List<String> p = data.split('/');
      final dt = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      if (dt.isAfter(DateTime.now()) || int.parse(p[2]) < 1900) return "Data inválida";
      return null;
    } catch (e) { return "Data inválida"; }
  }

  String? _validarCrn(String crn) {
    if (_selectedUser == UserType.paciente) return null;
    if (crn.isEmpty) return null; // Campo vazio ainda não é erro, só incompleto
    // Regra: Apenas números e tamanho mínimo razoável (ex: 4 dígitos)
    if (crn.length < 4) return "CRN muito curto";
    return null;
  }

  void _atualizarEstadoFormulario() {
    final senha = _senhaController.text;
    final confirmar = _confirmarSenhaController.text;
    
    setState(() {
      _erroRequisitoSenha = _validarRequisitosSenha(senha);
      _senhasNaoCoincidem = senha.isNotEmpty && confirmar.isNotEmpty && senha != confirmar;
      _erroCrn = _validarCrn(_crnController.text);

      final basicos = _nomeController.text.isNotEmpty && 
                      _dataNascController.text.length == 10 && 
                      _emailController.text.contains('@') && 
                      senha.isNotEmpty && 
                      confirmar.isNotEmpty;
      
      // Validação Específica do CRN
      final crnValido = _selectedUser == UserType.paciente || (_crnController.text.isNotEmpty && _erroCrn == null);
      
      _formularioCompleto = basicos && crnValido && _erroRequisitoSenha == null && !_senhasNaoCoincidem && _validarDataNascimento(_dataNascController.text) == null;
    });
  }

  Future<void> _cadastrarNoFirebase() async {
    setState(() => _estaCarregando = true);
    try {
      await Provider.of<AuthService>(context, listen: false).registrar(
        _emailController.text.trim(),
        _senhaController.text.trim(),
        _nomeController.text.trim(),
        _selectedUser == UserType.paciente ? 'paciente' : 'nutricionista',
        _selectedUser == UserType.nutricionista ? _crnController.text.trim() : null,
        _generoSelecionado, 
        _dataNascController.text.trim(),
      );
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VerificationScreen()));
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Criar Conta", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SELETOR DE TIPO
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.cinzaClaro,
                borderRadius: AppStyles.borderButton,
              ),
              child: Row(
                children: [
                  _buildToggleOption("Paciente", UserType.paciente),
                  _buildToggleOption("Nutricionista", UserType.nutricionista),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text("Dados Pessoais", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            
            _buildTextField("Nome Completo", _nomeController, Icons.person),
            _buildTextField("Data de Nascimento", _dataNascController, Icons.calendar_today, formatters: [maskData], type: TextInputType.number),
            if (_dataNascController.text.length == 10) _buildErrorMsg(_validarDataNascimento(_dataNascController.text)),

            // CAMPO CRN COM VALIDAÇÃO
            if (_selectedUser == UserType.nutricionista) ...[
              _buildTextField(
                "CRN (somente números)", 
                _crnController, 
                Icons.badge,
                type: TextInputType.number, 
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)] // Aceita só números, max 10
              ),
              if (_erroCrn != null) _buildErrorMsg(_erroCrn),
            ],

            const SizedBox(height: 10),
            const Text("Gênero", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGenderChip("Feminino"),
                const SizedBox(width: 10),
                _buildGenderChip("Masculino"),
              ],
            ),

            const SizedBox(height: 30),
            const Text("Acesso", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            
            _buildTextField("E-mail", _emailController, Icons.email, type: TextInputType.emailAddress),
            _buildTextField("Senha", _senhaController, Icons.lock, isPassword: true),
            _buildErrorMsg(_erroRequisitoSenha, color: Colors.orange),
            
            _buildTextField("Confirmar Senha", _confirmarSenhaController, Icons.lock_outline, isPassword: true),
            if (_senhasNaoCoincidem) _buildErrorMsg("As senhas não coincidem."),

            const SizedBox(height: 40),
            
            // BOTÃO CADASTRAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_formularioCompleto && !_estaCarregando) ? _cadastrarNoFirebase : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.roxo,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: AppStyles.shapeButton,
                  elevation: 0,
                ),
                child: _estaCarregando 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text("CADASTRAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildToggleOption(String label, UserType type) {
    bool isSelected = _selectedUser == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _selectedUser = type; _atualizarEstadoFormulario(); }),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: isSelected ? AppColors.roxo : Colors.grey)
          ),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    bool selected = _generoSelecionado == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _generoSelecionado = label),
      selectedColor: AppColors.roxo.withOpacity(0.2),
      labelStyle: TextStyle(color: selected ? AppColors.roxo : Colors.grey[700], fontWeight: FontWeight.bold),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? AppColors.roxo : Colors.grey[300]!)
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController ctrl, IconData icon, {bool isPassword = false, TextInputType type = TextInputType.text, List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        keyboardType: type,
        inputFormatters: formatters,
        onChanged: (_) => _atualizarEstadoFormulario(),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          hintText: hint,
          filled: true,
          fillColor: AppColors.cinzaClaro,
          border: OutlineInputBorder(borderRadius: AppStyles.borderButton, borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildErrorMsg(String? msg, {Color color = Colors.red}) {
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(msg, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}