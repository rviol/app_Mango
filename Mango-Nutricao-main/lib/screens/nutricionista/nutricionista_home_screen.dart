import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../classes/nutricionista.dart';
import '../../classes/paciente.dart';
import '../../database/nutricionista_repository.dart';
import '../../database/paciente_repository.dart';
import '../../database/antropometria_repository.dart';
import '../../database/plano_alimentar_repository.dart';

import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';
import 'nutricionista_antropometria_screen.dart';
import 'nutricionista_editor_plano_screen.dart';
import 'nutricionista_perfil_paciente_screen.dart';

class NutricionistaHomeScreen extends StatefulWidget {
  final String nutriId;
  final Function(int) onMudarAba;

  const NutricionistaHomeScreen({
    super.key,
    required this.nutriId,
    required this.onMudarAba,
  });

  @override
  State<NutricionistaHomeScreen> createState() =>
      _NutricionistaHomeScreenState();
}

class _NutricionistaHomeScreenState extends State<NutricionistaHomeScreen> {
  final _nutriRepo = NutricionistaRepository();
  final _pacienteRepo = PacienteRepository();
  final _planoRepo = PlanoAlimentarRepository();
  final _antropometriaRepo = AntropometriaRepository();

  Nutricionista? _nutricionista;
  List<Paciente> _meusPacientes = [];
  bool _isLoading = true;
  bool _isLinking = false;

  // Cache de Datas para lógica de vencimento
  Map<String, DateTime?> _dataUltimaAvaliacao = {};
  Map<String, DateTime?> _dataUltimoPlano = {};

  final TextEditingController _idController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final nutri = await _nutriRepo.buscarPorId(widget.nutriId);

      if (nutri != null) {
        List<Paciente> listaPacientes = [];
        Map<String, DateTime?> mapAvaliacao = {};
        Map<String, DateTime?> mapPlanos = {};

        for (String id in nutri.pacientesIds) {
          final p = await _pacienteRepo.buscarPorId(id);
          if (p != null) {
            // 1. Busca Data Última Avaliação
            final ultAvaliacao =
                await _antropometriaRepo.buscarUltimaAvaliacao(id);
            mapAvaliacao[id] = ultAvaliacao?.data;

            // 2. Busca Plano
            final planos = await _planoRepo.listarPlanos(id);
            if (planos.isNotEmpty) {
              // Assume o primeiro como o mais recente
              // Como a classe PlanoAlimentar não tem data, vamos usar a data atual como "ok"
              // ou, se quiser forçar atualização, pode deixar null
              // Para este exemplo, consideramos que se tem plano, a data é "hoje"
              // (Para ter vencimento real no plano, adicione um campo DateTime dataCriacao na classe PlanoAlimentar)
              mapPlanos[id] = DateTime.now(); // Placeholder
            } else {
              mapPlanos[id] = null;
            }

            listaPacientes.add(p);
          }
        }

        if (mounted) {
          setState(() {
            _nutricionista = nutri;
            _meusPacientes = listaPacientes;
            _dataUltimaAvaliacao = mapAvaliacao;
            _dataUltimoPlano = mapPlanos;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao recarregar dados: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vincularPaciente() async {
    final String idDigitado = _idController.text.trim();
    if (idDigitado.isEmpty) {
      _showSnack("Insira o ID.", isError: true);
      return;
    }

    if (_nutricionista != null &&
        _nutricionista!.pacientesIds.contains(idDigitado)) {
      _showSnack("Paciente já vinculado.", isError: true);
      return;
    }

    setState(() => _isLinking = true);
    try {
      final Paciente? pacienteEncontrado =
          await _pacienteRepo.buscarPorId(idDigitado);
      if (pacienteEncontrado == null)
        throw Exception("Paciente não encontrado.");

      _nutricionista!.adicionarPaciente(idDigitado);
      await _nutriRepo.atualizar(_nutricionista!);
      await FirebaseDatabase.instance
          .ref()
          .child('usuarios')
          .child(idDigitado)
          .update({'nutricionistaId': widget.nutriId});

      _idController.clear();
      FocusScope.of(context).unfocus();
      _showSnack("Vinculado com sucesso!");
      await _carregarDados();
    } catch (e) {
      _showSnack("Erro ao vincular.", isError: true);
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green));
  }

  // --- Lógica de Vencimento (> 30 dias) ---
  bool _isExpired(DateTime? date) {
    if (date == null) return false; // Null é "Pendente", não "Vencido"
    final trintaDiasAtras = DateTime.now().subtract(const Duration(days: 30));
    return date.isBefore(trintaDiasAtras);
  }

  String _formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  // --- Navegação ---
  void _navAvaliacao(Paciente p) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  NutricionistaAntropometriaScreen(pacienteId: p.id!)))
      .then((_) => _carregarDados());
  void _navPlano(Paciente p) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NutricionistaEditorPlanoScreen(
                  pacienteId: p.id!, plano: null)))
      .then((_) => _carregarDados());
  void _navPerfil(Paciente p) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  NutricionistaPerfilPacienteScreen(pacienteId: p.id!)))
      .then((_) => _carregarDados());

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
          backgroundColor: AppColors.laranja,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));

    // 1. Nunca Avaliados (Prioridade Alta - Roxo)
    final pendentesAvaliacao = _meusPacientes
        .where((p) => _dataUltimaAvaliacao[p.id] == null)
        .toList();

    // 2. Avaliações Vencidas (> 30 dias - Laranja)
    final vencidosAvaliacao = _meusPacientes
        .where((p) => _isExpired(_dataUltimaAvaliacao[p.id]))
        .toList();

    // 3. Sem Plano (Verde)
    final pendentesPlano =
        _meusPacientes.where((p) => _dataUltimoPlano[p.id] == null).toList();

    return Scaffold(
      backgroundColor: AppColors.laranja,
      appBar: AppBar(
        backgroundColor: AppColors.laranja,
        elevation: 0,
        title: const Text('Mango Nutri',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              onPressed: () => context.read<AuthService>().logout()),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Text(
                          _nutricionista?.nome[0].toUpperCase() ?? 'N',
                          style: const TextStyle(
                              fontSize: 28,
                              color: AppColors.laranja,
                              fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Nutricionista",
                            style: TextStyle(color: Colors.white70)),
                        Text(_nutricionista?.nome ?? "Usuário",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text("CRN: ${_nutricionista?.crn ?? '--'}",
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: AppStyles.borderTopCard),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                      "Vincular Paciente", Icons.link, AppColors.laranja),
                  const SizedBox(height: 10),
                  _buildVincularInput(),
                  const SizedBox(height: 30),

                  // --- AVALIAÇÕES ---

                  // Vencidas (Alerta Amarelo/Laranja)
                  if (vencidosAvaliacao.isNotEmpty) ...[
                    _buildSectionTitle("Atenção: Avaliações Vencidas",
                        Icons.warning_amber_rounded, Colors.orange),
                    const SizedBox(height: 10),
                    ...vencidosAvaliacao.map((p) => _buildCardAlerta(
                        p,
                        "Última: ${_formatDate(_dataUltimaAvaliacao[p.id]!)}",
                        "Atualizar",
                        Colors.orange,
                        () => _navAvaliacao(p))),
                    const SizedBox(height: 20),
                  ],

                  // Pendentes (Alerta Roxo - Nunca feito)
                  if (pendentesAvaliacao.isNotEmpty) ...[
                    _buildSectionTitle("Avaliações Pendentes",
                        Icons.accessibility_new, AppColors.roxo),
                    const SizedBox(height: 10),
                    ...pendentesAvaliacao.map((p) => _buildCardPendencia(
                        p,
                        "Nunca avaliado",
                        "Criar",
                        AppColors.roxo,
                        () => _navAvaliacao(p))),
                    const SizedBox(height: 20),
                  ],

                  // --- PLANOS ---

                  if (pendentesPlano.isNotEmpty) ...[
                    _buildSectionTitle("Planos Pendentes",
                        Icons.restaurant_menu, AppColors.verde),
                    const SizedBox(height: 10),
                    ...pendentesPlano.map((p) => _buildCardPendencia(
                        p,
                        "Sem plano ativo",
                        "Criar",
                        AppColors.verde,
                        () => _navPlano(p))),
                    const SizedBox(height: 20),
                  ],

                  // --- TODOS OS PACIENTES ---
                  _buildSectionTitle(
                      "Meus Pacientes", Icons.people, Colors.blue),
                  const SizedBox(height: 10),
                  if (_meusPacientes.isNotEmpty)
                    ..._meusPacientes.map((p) => _buildCardPacienteResumo(p))
                  else
                    const Center(
                        child: Text("Nenhum paciente vinculado.",
                            style: TextStyle(color: Colors.grey))),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildVincularInput() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: AppStyles.borderButton),
      child: Row(
        children: [
          Expanded(
              child: TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                      hintText: "ID do paciente",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16)))),
          ElevatedButton(
              onPressed: _isLinking ? null : _vincularPaciente,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.laranja,
                  shape: AppStyles.shapeButton,
                  elevation: 0),
              child: _isLinking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("Vincular", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // Card para Pendência (Nunca Feito)
  Widget _buildCardPendencia(
      Paciente p, String subtitle, String btnText, Color color, VoidCallback onTap) {
    return _baseCard(p, subtitle, btnText, color, onTap, isWarning: false);
  }

  // Card para Vencido (Alerta)
  Widget _buildCardAlerta(
      Paciente p, String subtitle, String btnText, Color color, VoidCallback onTap) {
    return _baseCard(p, subtitle, btnText, color, onTap, isWarning: true);
  }

  Widget _baseCard(Paciente p, String subtitle, String btnText, Color color,
      VoidCallback onTap,
      {required bool isWarning}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderButton,
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isWarning)
                const Icon(Icons.warning, color: Colors.orange, size: 20),
              if (isWarning) const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          color: isWarning ? Colors.orange[800] : color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: AppStyles.shapeButton,
                minimumSize: const Size(70, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                elevation: 0),
            child: Text(btnText,
                style: const TextStyle(fontSize: 11, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPacienteResumo(Paciente p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppStyles.borderButton,
          border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.all(8),
        leading: CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Text(p.nome[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold))),
        title:
            Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => _navPerfil(p),
      ),
    );
  }
}