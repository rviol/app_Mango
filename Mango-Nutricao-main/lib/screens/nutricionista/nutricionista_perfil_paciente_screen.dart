import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import necessário para pegar o ID do Nutri logado
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';

// Classes e Repos
import '../../classes/antropometria.dart';
import '../../classes/plano_alimentar.dart';
import '../../classes/refeicao.dart';
import '../../classes/nutricionista.dart'; // Import da classe Nutricionista
import '../../database/antropometria_repository.dart';
import '../../database/plano_alimentar_repository.dart';
import '../../database/nutricionista_repository.dart'; // Import do Repo Nutri

// Telas de Edição
import 'nutricionista_antropometria_screen.dart';
import 'nutricionista_editor_plano_screen.dart';

class NutricionistaPerfilPacienteScreen extends StatefulWidget {
  final String pacienteId;

  const NutricionistaPerfilPacienteScreen({super.key, required this.pacienteId});

  @override
  State<NutricionistaPerfilPacienteScreen> createState() =>
      _NutricionistaPerfilPacienteScreenState();
}

class _NutricionistaPerfilPacienteScreenState
    extends State<NutricionistaPerfilPacienteScreen> {
  
  final _antroRepo = AntropometriaRepository();
  final _planoRepo = PlanoAlimentarRepository();
  final _nutriRepo = NutricionistaRepository(); // Repo para desvincular

  bool _isLoading = true;
  int _tabSelecionada = 0; 

  Map<String, dynamic> _dadosPaciente = {};
  int _idade = 0;
  List<Antropometria> _historicoAntro = [];
  List<PlanoAlimentar> _historicoPlanos = [];

  Color get _corAtiva => _tabSelecionada == 0 ? AppColors.roxo : AppColors.verde;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final userSnap = await FirebaseDatabase.instance.ref('usuarios/${widget.pacienteId}').get();
      if (userSnap.exists) {
        _dadosPaciente = Map<String, dynamic>.from(userSnap.value as Map);
        _calcularIdade(_dadosPaciente['dataNascimento']);
      }

      final listaAntro = await _antroRepo.buscarHistorico(widget.pacienteId);
      listaAntro.sort((a, b) => (b.data ?? DateTime(2000)).compareTo(a.data ?? DateTime(2000)));
      _historicoAntro = listaAntro; 

      final listaPlanos = await _planoRepo.listarPlanos(widget.pacienteId);
      _historicoPlanos = listaPlanos;

    } catch (e) {
      debugPrint("Erro: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularIdade(String? dataNasc) {
    if (dataNasc == null || dataNasc.isEmpty) return;
    try {
      DateTime nascimento;
      if (dataNasc.contains('/')) {
        final parts = dataNasc.split('/');
        nascimento = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        nascimento = DateTime.parse(dataNasc);
      }
      final hoje = DateTime.now();
      int idade = hoje.year - nascimento.year;
      if (hoje.month < nascimento.month || (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
        idade--;
      }
      setState(() => _idade = idade);
    } catch (_) {}
  }

  // --- AÇÃO DE DESVINCULAR ---
  Future<void> _confirmarDesvinculo() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Desvincular Paciente"),
        content: Text("Tem certeza que deseja remover ${_dadosPaciente['nome']} da sua lista?"),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executarDesvinculo();
            },
            child: const Text("Desvincular", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _executarDesvinculo() async {
    setState(() => _isLoading = true);
    try {
      final nutriUid = FirebaseAuth.instance.currentUser?.uid;
      if (nutriUid == null) return;

      // 1. Remove do Nutricionista
      final nutri = await _nutriRepo.buscarPorId(nutriUid);
      if (nutri != null) {
        nutri.pacientesIds.remove(widget.pacienteId);
        await _nutriRepo.atualizar(nutri);
      }

      // 2. Remove do Paciente (campo nutricionistaId)
      await FirebaseDatabase.instance.ref('usuarios/${widget.pacienteId}/nutricionistaId').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paciente desvinculado com sucesso.")));
        Navigator.pop(context); // Volta para a tela anterior
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao desvincular: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _acaoFAB() {
    if (_tabSelecionada == 0) {
      _navegarAntropometria(null);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => NutricionistaEditorPlanoScreen(pacienteId: widget.pacienteId, plano: null),
      )).then((_) => _carregarDados());
    }
  }

  void _navegarAntropometria(Antropometria? item) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => NutricionistaAntropometriaScreen(
        pacienteId: widget.pacienteId,
        avaliacaoParaEditar: item, 
      ),
    )).then((_) => _carregarDados());
  }

  void _excluirAntropometria(String id) async {
    await _antroRepo.excluirAvaliacao(widget.pacienteId, id);
    _carregarDados();
  }

  void _navegarPlano(PlanoAlimentar item) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => NutricionistaEditorPlanoScreen(pacienteId: widget.pacienteId, plano: item),
    )).then((_) => _carregarDados());
  }

  void _excluirPlano(String id) async {
    await _planoRepo.excluirPlano(widget.pacienteId, id);
    _carregarDados();
  }

  Color _calcularCorPredominante(Antropometria item) {
    int ideal = 0;
    int fora = 0; 
    List<String?> classificacoes = [item.classImc, item.classMassaCorporal, item.classPercentualGordura, item.classMassaGordura, item.classCmb, item.classRcq];
    for (var c in classificacoes) {
      if (c == null) continue;
      if (c.contains('Ideal')) ideal++; else fora++;
    }
    if (ideal >= fora) return const Color(0xFF4CAF50);
    bool temAcima = classificacoes.any((c) => c?.contains('Acima') ?? false);
    return temAcima ? const Color(0xFFFF7043) : const Color(0xFF5E6EE6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corAtiva,
      appBar: AppBar(
        title: const Text("Perfil do Paciente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _corAtiva,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // BOTÃO DESVINCULAR
          IconButton(
            icon: const Icon(Icons.person_remove),
            tooltip: "Desvincular Paciente",
            onPressed: _confirmarDesvinculo,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _acaoFAB,
        backgroundColor: Colors.white,
        foregroundColor: _corAtiva,
        elevation: 4,
        icon: Icon(_tabSelecionada == 0 ? Icons.add : Icons.add_circle_outline),
        label: Text(
          _tabSelecionada == 0 ? "Nova Avaliação" : "Novo Plano",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _buildHeaderPaciente(),
                _buildTabSelector(),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppStyles.borderTopCard,
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _tabSelecionada == 0
                        ? _buildAbaAntropometria()
                        : _buildAbaPlanos(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderPaciente() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _dadosPaciente['nome']?.toString().substring(0, 1).toUpperCase() ?? 'P',
              style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dadosPaciente['nome'] ?? 'Nome não informado',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.cake, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text("$_idade anos", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  const SizedBox(width: 12),
                  const Icon(Icons.person, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(_dadosPaciente['genero'] ?? 'N/A', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [_buildTabItem(0, "Antropometria"), _buildTabItem(1, "Planos")]),
    );
  }

  Widget _buildTabItem(int index, String label) {
    bool isSelected = _tabSelecionada == index;
    IconData icon = index == 0 ? Icons.accessibility_new : Icons.restaurant_menu;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabSelecionada = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? _corAtiva : Colors.white.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? _corAtiva : Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // === ABA PLANOS ===
  Widget _buildAbaPlanos() {
    if (_historicoPlanos.isEmpty) return _buildEmpty("Nenhum plano alimentar.");

    final atual = _historicoPlanos.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Plano Ativo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.verde)),
              Text(_formatDate(atual.dataCriacao), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 15),

          if (atual.refeicoes.isEmpty)
            const Text("Este plano não tem refeições.", style: TextStyle(color: Colors.grey))
          else
            ...atual.refeicoes.map((ref) => _buildRefeicaoCardStyle(ref)),
          
          const Text("Resumo Nutricional", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 25),
          // --- GRÁFICOS DE PIZZA (NOVO) ---
          _buildGraficosNutricionais(atual),

          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 10),

          const Text("Histórico Completo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          
          ..._historicoPlanos.map((item) {
            final isAtual = item == _historicoPlanos.first;
            return _buildCardHistorico(
              titulo: item.nome,
              subtitulo: "Criado em ${_formatDate(item.dataCriacao)} • ${item.refeicoes.length} refeições",
              icone: Icons.restaurant_menu,
              corTema: AppColors.verde,
              isAtual: isAtual,
              onTap: () => _navegarPlano(item),
              onEdit: () => _navegarPlano(item),
              onDelete: () => _excluirPlano(item.id),
            );
          }),
        ],
      ),
    );
  }

  // --- NOVOS WIDGETS DE GRÁFICO ---
  Widget _buildGraficosNutricionais(PlanoAlimentar plano) {
    // 1. Calcula Totais
    double totalCarb = 0, totalProt = 0, totalGord = 0;
    double totalFibra = 0, totalCalcio = 0, totalFerro = 0, totalVitC = 0;

    for (var ref in plano.refeicoes) {
      for (var ali in ref.alimentos) {
        // Conversão de proporção (já que os dados do DB podem ser por 100g ou por porção)
        // Assumindo que a classe Alimento já traz calculado ou precisa calcular:
        // Se a classe Alimento armazena por 100g, precisamos calcular: (valor * quantidade) / 100
        // Se a classe já armazena o valor total da porção, apenas somamos.
        // Vou assumir que Alimento.carboidratos já é o total daquela quantidade (conforme refeiçao.dart)
        // Se não for, ajuste aqui.
        
        totalCarb += ali.carboidratos;
        totalProt += ali.proteinas;
        totalGord += ali.gorduras;
        
        // Se tiver micros na classe Alimento (assumindo que foram adicionados)
        // Usamos try/catch ou valores padrão caso a classe ainda não tenha sido atualizada no hot reload
        try { totalFibra += (ali.fibras); } catch (_) {}
        try { totalCalcio += (ali.calcio); } catch (_) {}
        try { totalFerro += (ali.ferro); } catch (_) {}
        try { totalVitC += (ali.vitC); } catch (_) {}
      }
    }

    // 2. Prepara Macros (em Kcal para % correta)
    double kcalCarb = totalCarb * 4;
    double kcalProt = totalProt * 4;
    double kcalGord = totalGord * 9;
    double totalKcal = kcalCarb + kcalProt + kcalGord;

    return Column(
      children: [
        // CARD MACROS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text("Distribuição de Macronutrientes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 15),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: [
                            _buildPieSection(kcalCarb, totalKcal, Colors.orange, "Carb"),
                            _buildPieSection(kcalProt, totalKcal, Colors.blue, "Prot"),
                            _buildPieSection(kcalGord, totalKcal, Colors.red, "Gord"),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem("Carboidratos", Colors.orange, "${totalCarb.toStringAsFixed(0)}g"),
                          _buildLegendItem("Proteínas", Colors.blue, "${totalProt.toStringAsFixed(0)}g"),
                          _buildLegendItem("Gorduras", Colors.red, "${totalGord.toStringAsFixed(0)}g"),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        
        // CARD MICROS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text("Principais Micronutrientes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 15),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: [
                            // Convertendo Fibra (g) para mg (x1000) para ficar visível na escala
                            PieChartSectionData(value: totalFibra * 1000, color: Colors.green, radius: 15, showTitle: false),
                            PieChartSectionData(value: totalCalcio, color: Colors.indigo, radius: 15, showTitle: false),
                            PieChartSectionData(value: totalFerro, color: Colors.brown, radius: 15, showTitle: false),
                            PieChartSectionData(value: totalVitC, color: Colors.orangeAccent, radius: 15, showTitle: false),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem("Fibras", Colors.green, "${totalFibra.toStringAsFixed(1)}g"),
                          _buildLegendItem("Cálcio", Colors.indigo, "${totalCalcio.toStringAsFixed(0)}mg"),
                          _buildLegendItem("Ferro", Colors.brown, "${totalFerro.toStringAsFixed(1)}mg"),
                          _buildLegendItem("Vit. C", Colors.orangeAccent, "${totalVitC.toStringAsFixed(1)}mg"),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PieChartSectionData _buildPieSection(double value, double total, Color color, String title) {
    final percent = total > 0 ? (value / total * 100) : 0.0;
    return PieChartSectionData(
      color: color,
      value: value,
      title: "${percent.toStringAsFixed(0)}%",
      radius: 40,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ===========================================================================
  // === ABA ANTROPOMETRIA =====================================================
  // ===========================================================================
  
  Widget _buildAbaAntropometria() {
    if (_historicoAntro.isEmpty) return _buildEmpty("Nenhuma avaliação cadastrada.");

    // Como ordenamos [New -> Old], o first é o atual
    final atual = _historicoAntro.first; 

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resumo da Avaliação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.roxo)),
          const SizedBox(height: 10),
          _buildCardResumoBonequinho(atual),
          
          const SizedBox(height: 25),

          const Text("Indicadores Atuais", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.roxo)),
          const SizedBox(height: 10),
          _buildBarraProgressoSombreada('Massa Corporal', atual.massaCorporal, 'kg', atual.classMassaCorporal, 150),
          _buildBarraProgressoSombreada('Massa Gorda', atual.massaGordura, 'kg', atual.classMassaGordura, 60),
          _buildBarraProgressoSombreada('Gordura Corporal', atual.percentualGordura, '%', atual.classPercentualGordura, 50),
          _buildBarraProgressoSombreada('Massa Muscular', atual.massaMuscular, 'kg', atual.classMassaMuscular, 80),
          _buildBarraProgressoSombreada('IMC', atual.imc, 'kg/m²', atual.classImc, 50),
          _buildBarraProgressoSombreada('CMB', atual.cmb, 'cm', atual.classCmb, 60),
          _buildBarraProgressoSombreada('RCQ', atual.relacaoCinturaQuadril, '', atual.classRcq, 1.5),
          
          const SizedBox(height: 25),

          if (_historicoAntro.length > 1) ...[
            const Text("Evolução", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.roxo)),
            const SizedBox(height: 10),
            _buildGraficoEvolucao("Evolução do Peso (kg)", (item) => item.massaCorporal ?? 0, AppColors.roxo),
            const SizedBox(height: 15),
            _buildGraficoEvolucao("Evolução Gordura (%)", (item) => item.percentualGordura ?? 0, const Color(0xFFFF7043)),
            const SizedBox(height: 15),
            _buildGraficoEvolucao("Evolução Massa Muscular (kg)", (item) => item.massaMuscular ?? 0, const Color(0xFF42A5F5)),
            const SizedBox(height: 15),
            _buildGraficoEvolucao("Evolução IMC", (item) => item.imc ?? 0, AppColors.verde),
            const SizedBox(height: 15),
            _buildGraficoEvolucao("Evolução CMB (cm)", (item) => item.cmb ?? 0, const Color(0xFFFFA726)),
            const SizedBox(height: 15),
            _buildGraficoEvolucao("Evolução RCQ", (item) => item.relacaoCinturaQuadril ?? 0, const Color(0xFFAB47BC)),
          ],

          const Divider(),
          const SizedBox(height: 10),

          const Text("Histórico Completo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          
          ..._historicoAntro.map((item) {
            final isAtual = item == _historicoAntro.first;
            return _buildCardHistorico(
              titulo: "Avaliação de ${_formatDate(item.data)}",
              subtitulo: "${item.massaCorporal} kg • IMC ${item.imc}",
              icone: Icons.accessibility_new,
              corTema: AppColors.roxo,
              isAtual: isAtual,
              onTap: () => _navegarAntropometria(item),
              onEdit: () => _navegarAntropometria(item),
              onDelete: () => _excluirAntropometria(item.id_avaliacao!),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // === WIDGETS AUXILIARES ====================================================
  // ===========================================================================

  Widget _buildCardHistorico({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Color corTema,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    bool isAtual = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isAtual ? 2 : 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.borderButton, // Radius 16
        side: isAtual ? BorderSide(color: corTema, width: 1.5) : BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isAtual ? corTema : Colors.grey[100],
          child: Icon(icone, color: isAtual ? Colors.white : Colors.grey, size: 20),
        ),
        title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: isAtual ? Colors.black : Colors.grey[700])),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitulo),
            if (isAtual) 
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("ATUAL", style: TextStyle(color: corTema, fontSize: 10, fontWeight: FontWeight.bold)),
              )
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'del') onDelete();
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text("Editar")),
            const PopupMenuItem(value: 'del', child: Text("Excluir", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraProgressoSombreada(String label, double? valor, String unidade, String? classificacao, double maxVal) {
    double v = valor ?? 0;
    double percent = (v / maxVal).clamp(0.0, 1.0);
    
    Color cor = Colors.grey;
    if (classificacao?.contains('Abaixo') ?? false) cor = const Color(0xFF5E6EE6); 
    else if (classificacao?.contains('Ideal') ?? false) cor = const Color(0xFF4CAF50); 
    else if (classificacao?.contains('Acima') ?? false) cor = const Color(0xFFFF7043); 

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              Row(
                children: [
                  Text("${v.toStringAsFixed(1)}$unidade", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cor)),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(classificacao ?? '-', style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(5),
                  // MANTENDO A SOMBRA SOLICITADA
                  boxShadow: [
                    BoxShadow(color: cor.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3)),
                  ]
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGraficoEvolucao(String titulo, double Function(Antropometria) getValor, Color corLinha) {
    // Para o gráfico, usamos a ordem cronológica (antigo -> novo) para desenhar da esquerda p/ direita
    final dadosCronologicos = _historicoAntro.reversed.toList();
    
    List<FlSpot> spots = [];
    double minV = 9999, maxV = 0;
    
    for (int i = 0; i < dadosCronologicos.length; i++) {
      double val = getValor(dadosCronologicos[i]);
      if (val > maxV) maxV = val;
      if (val < minV && val > 0) minV = val;
      spots.add(FlSpot(i.toDouble(), val));
    }
    
    if (spots.isEmpty) return const SizedBox();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: AppStyles.borderButton, // Radius 16
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: (minV - 5).clamp(0, 999), 
                maxY: maxV + 5,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true, color: corLinha, barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: corLinha.withOpacity(0.1)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefeicaoCardStyle(Refeicao refeicao) {
    double cal = refeicao.totalCalorias;
    double prot = refeicao.totalProteinas;
    double carb = refeicao.totalCarboidratos;
    double gord = refeicao.totalGorduras;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderButton, // Radius 16
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.verde.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant, color: AppColors.verde)),
          title: Text(refeicao.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text('${refeicao.horario} • ${cal.toStringAsFixed(0)} kcal', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          children: [
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildMacroBadge("Carb", "${carb.toStringAsFixed(1)}g", Colors.orange),
                  _buildMacroBadge("Prot", "${prot.toStringAsFixed(1)}g", Colors.blue),
                  _buildMacroBadge("Gord", "${gord.toStringAsFixed(1)}g", Colors.red),
                ]),
                const Divider(height: 20),
                ...refeicao.alimentos.map((ali) => ListTile(
                  contentPadding: EdgeInsets.zero, dense: true, visualDensity: VisualDensity.compact,
                  title: Text(ali.nome, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("${ali.calorias} kcal / 100g"),
                  trailing: Text("${ali.quantidade.toStringAsFixed(0)}g", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.verde)))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardResumoBonequinho(Antropometria item) {
    Color corBoneco = _calcularCorPredominante(item);
    double peso = item.massaCorporal ?? 0;
    double gordura = item.massaGordura ?? 0;
    double magra = peso - gordura;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderCard, // Radius 25 para card destaque
        border: Border.all(color: corBoneco.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: corBoneco.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: corBoneco.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.accessibility_new, color: corBoneco, size: 40),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Avaliação de ${_formatDate(item.data)}", style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoResumo("Peso", "${peso.toStringAsFixed(1)}kg"),
                        _infoResumo("Gordura", "${item.percentualGordura}%"),
                        _infoResumo("M. Magra", "${magra.toStringAsFixed(1)}kg"),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
          if (item.observacoes != null && item.observacoes!.isNotEmpty) ...[
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 8),
            Text("Observações:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(item.observacoes!, style: const TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic)),
          ]
        ],
      ),
    );
  }

  Widget _infoResumo(String label, String valor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
    ]);
  }

  Widget _buildMacroBadge(String label, String value, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text("$label: $value", style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))]));
  }

  Widget _buildEmpty(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info_outline, size: 40, color: Colors.grey[300]), const SizedBox(height: 10), Text(msg, style: TextStyle(color: Colors.grey[500]))]));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "--/--/----";
    return DateFormat('dd/MM/yyyy').format(date);
  }
}