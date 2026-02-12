import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart'; // Necessário para desvincular

// Repositórios e Classes
import '../../classes/antropometria.dart';
import '../../database/antropometria_repository.dart';
import '../../database/paciente_repository.dart';
import '../../classes/paciente.dart';
import '../../classes/refeicao.dart';
import '../../classes/nutricionista.dart';
import '../../database/nutricionista_repository.dart';
import '../../classes/plano_alimentar.dart';
import '../../database/plano_alimentar_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';

class HomeTabScreen extends StatefulWidget {
  final String pacienteId;
  final Function(int) onMudarAba;

  const HomeTabScreen({
    super.key,
    required this.pacienteId,
    required this.onMudarAba,
  });

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  bool _isLoading = true;
  bool _isLinking = false;
  
  Paciente? _paciente;
  final PacienteRepository _pacienteRepo = PacienteRepository();
  final NutricionistaRepository _nutriRepo = NutricionistaRepository();
  Antropometria? _ultimaAvaliacao;
  Nutricionista? _nutricionista;
  Refeicao? _proximaRefeicao;

  final TextEditingController _idNutriController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDadosHome();
  }

  @override
  void dispose() {
    _idNutriController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosHome() async {
    setState(() => _isLoading = true);
    try {
      _paciente = await _pacienteRepo.buscarPorId(widget.pacienteId);
      
      _ultimaAvaliacao = await AntropometriaRepository().buscarUltimaAvaliacao(
        widget.pacienteId,
      );

      final crn = _paciente?.nutricionistaId; 
      // OBS: Aqui assumo que o "nutricionistaCrn" no objeto Paciente guarda o ID do Nutri
      // ou se guarda o CRN, precisamos da lógica certa. 
      // Vou assumir que o vínculo é feito pelo ID no banco em 'nutricionistaId' e o objeto Paciente reflete isso.
      
      // Se sua lógica usa 'nutricionistaId' no banco:
      if (_paciente != null) {
        // Busca direto no firebase para garantir o ID mais atual (caso tenha mudado)
        final snapshot = await FirebaseDatabase.instance.ref('usuarios/${widget.pacienteId}/nutricionistaId').get();
        if (snapshot.exists && snapshot.value != null) {
           String nutriIdVinculado = snapshot.value.toString();
           _nutricionista = await _nutriRepo.buscarPorId(nutriIdVinculado);
        } else {
           _nutricionista = null;
        }
      }

      List<PlanoAlimentar> planos = await PlanoAlimentarRepository()
          .listarPlanos(widget.pacienteId);
      if (planos.isNotEmpty) {
        _proximaRefeicao = _calcularProximaRefeicao(planos.first.refeicoes);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Erro ao carregar Home: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Lógica de Vincular Novo Nutricionista ---
  Future<void> _vincularNutricionista() async {
    final String idDigitado = _idNutriController.text.trim();
    if (idDigitado.isEmpty) return;

    setState(() => _isLinking = true);

    try {
      // 1. Verifica se o Nutricionista existe
      final nutriEncontrado = await _nutriRepo.buscarPorId(idDigitado);
      
      if (nutriEncontrado == null) {
        throw Exception("Nutricionista não encontrado com este ID.");
      }

      // 2. Atualiza o Paciente com o novo ID do Nutri
      await FirebaseDatabase.instance.ref('usuarios/${widget.pacienteId}').update({
        'nutricionistaId': idDigitado,
        'nutricionistaCrn': nutriEncontrado.crn // Opcional, se quiser manter redundância
      });

      // 3. Adiciona o Paciente na lista do Nutricionista (se não tiver)
      if (!nutriEncontrado.pacientesIds.contains(widget.pacienteId)) {
        nutriEncontrado.adicionarPaciente(widget.pacienteId);
        await _nutriRepo.atualizar(nutriEncontrado);
      }

      // Se já tinha um nutri antigo, a gente poderia remover o paciente da lista dele,
      // mas isso é opcional e depende da regra de negócio (pode manter histórico).

      _idNutriController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vinculado com sucesso!"), backgroundColor: Colors.green));
        Navigator.pop(context); // Fecha o modal de vínculo
        _carregarDadosHome(); // Recarrega a tela
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  // --- Lógica de Desvincular ---
  Future<void> _desvincularNutricionista() async {
    try {
      // Remove o ID do nutri do cadastro do paciente
      await FirebaseDatabase.instance.ref('usuarios/${widget.pacienteId}/nutricionistaId').remove();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Desvinculado."), backgroundColor: Colors.grey));
        _carregarDadosHome();
      }
    } catch (e) {
      debugPrint("Erro ao desvincular: $e");
    }
  }

  // Modal para inserir ID do novo Nutri
  void _mostrarModalVincular() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Vincular Novo Nutricionista", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.laranja)),
            const SizedBox(height: 10),
            const Text("Insira o ID fornecido pelo seu nutricionista:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: _idNutriController,
              cursorColor: AppColors.laranja,
              decoration: InputDecoration(
                hintText: "Cole o ID aqui...",
                border: OutlineInputBorder(borderRadius: AppStyles.borderButton, borderSide: BorderSide(color: AppColors.laranja)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLinking ? null : _vincularNutricionista,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.laranja, foregroundColor: Colors.white, shape: AppStyles.shapeButton),
                child: _isLinking ? const CircularProgressIndicator(color: Colors.white) : const Text("VINCULAR", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Refeicao? _calcularProximaRefeicao(List<Refeicao> refeicoes) {
    if (refeicoes.isEmpty) return null;
    final agora = DateTime.now();
    final horaAtualEmMinutos = agora.hour * 60 + agora.minute;
    Refeicao? proxima;
    int menorDiferenca = 9999;

    for (var ref in refeicoes) {
      final partes = ref.horario.split(':');
      if (partes.length < 2) continue;
      final horaRef = int.parse(partes[0]) * 60 + int.parse(partes[1]);
      final diferenca = horaRef - horaAtualEmMinutos;
      if (diferenca > -30 && diferenca < menorDiferenca) { 
        menorDiferenca = diferenca;
        proxima = ref;
      }
    }
    return proxima ?? refeicoes.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.laranja, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    String subtextoHeader = "Bem-vindo(a)";
    if (_paciente != null) {
      final idade = _paciente!.idade; 
      final genero = _paciente!.genero.isNotEmpty ? _paciente!.genero : "Gênero não informado";
      subtextoHeader = "$idade anos • $genero";
    }

    return Scaffold(
      backgroundColor: AppColors.laranja,
      appBar: AppBar(
        backgroundColor: AppColors.laranja,
        elevation: 0,
        title: const Text('Mango Nutri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => context.read<AuthService>().logout(),
          ),
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
                      _paciente?.nome.isNotEmpty == true ? _paciente!.nome[0].toUpperCase() : 'P',
                      style: const TextStyle(fontSize: 28, color: AppColors.laranja, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Olá, ${_paciente?.nome ?? "Paciente"}",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(subtextoHeader, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
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
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppStyles.borderTopCard, 
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Seu Nutricionista", Icons.assignment_ind, AppColors.laranja),
                  const SizedBox(height: 12),
                  
                  // LÓGICA DE EXIBIÇÃO DO NUTRI
                  if (_nutricionista != null)
                    _buildCardNutricionistaVinculado()
                  else
                    _buildCardSemNutri(),

                  const SizedBox(height: 30),

                  _buildSectionHeader("Próxima Refeição", Icons.restaurant, AppColors.verde),
                  const SizedBox(height: 12),
                  if (_proximaRefeicao != null)
                    _buildCardProximaRefeicao(_proximaRefeicao!)
                  else
                    _buildCardSemPlano(),
                  
                  if (_proximaRefeicao != null) ...[
                    const SizedBox(height: 12),
                    _buildBotaoAcao("Ver plano completo", AppColors.verde, () => widget.onMudarAba(2)),
                  ],

                  const SizedBox(height: 30),

                  _buildSectionHeader("Resumo Corporal", Icons.monitor_weight, AppColors.roxo),
                  const SizedBox(height: 12),
                  _ultimaAvaliacao != null
                      ? _buildCardAntropometriaGrid(_ultimaAvaliacao!)
                      : _buildCardSemDadosAntro(),
                  
                  if (_proximaRefeicao != null) ...[
                    const SizedBox(height: 12),
                    _buildBotaoAcao("Ver histórico e gráficos", AppColors.roxo, () => widget.onMudarAba(1)),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
      ],
    );
  }

  // [NOVO] Card quando JÁ existe vínculo
  Widget _buildCardNutricionistaVinculado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecorationPadrao(), 
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.laranja.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppColors.laranja, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nutricionista?.nome ?? "Nutricionista", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("CRN: ${_nutricionista?.crn ?? '--'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                      child: const Text("Vinculado", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _desvincularNutricionista,
                  icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                  label: const Text("Desvincular", style: TextStyle(color: Colors.red)),
                ),
              ),
              Container(height: 20, width: 1, color: Colors.grey[300]), // Separador vertical
              Expanded(
                child: TextButton.icon(
                  onPressed: _mostrarModalVincular, // Permite trocar de nutri
                  icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.laranja),
                  label: const Text("Trocar Nutri", style: TextStyle(color: AppColors.laranja)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Card quando NÃO tem vínculo (Mantido o estilo mas com botão de ação)
  Widget _buildCardSemNutri() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.laranja.withOpacity(0.05),
        borderRadius: AppStyles.borderCard,
        border: Border.all(color: AppColors.laranja.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text("Você não possui nutricionista", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.laranja)),
          const SizedBox(height: 8),
          const Text("Envie seu ID para ele ou insira o ID dele aqui:", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 15),
          
          // ID do Paciente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SEU ID:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      SelectableText(widget.pacienteId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.pacienteId));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seu ID copiado!')));
                  },
                  child: const Icon(Icons.copy, size: 20, color: AppColors.laranja),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _mostrarModalVincular,
              icon: const Icon(Icons.add_link),
              label: const Text("Vincular Nutricionista por ID"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.laranja,
                side: const BorderSide(color: AppColors.laranja),
                shape: AppStyles.shapeButton
              ),
            ),
          )
        ],
      ),
    );
  }

  // Restante dos widgets (Proxima Refeição, Antropometria) mantidos iguais...
  Widget _buildCardProximaRefeicao(Refeicao refeicao) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _boxDecorationPadrao(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(refeicao.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.verde.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.verde),
                    const SizedBox(width: 4),
                    Text(refeicao.horario, style: const TextStyle(color: AppColors.verde, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: refeicao.alimentos.map((ali) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
              child: Text(ali.nome, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
            )).toList(),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroBadge("Kcal", "${refeicao.totalCalorias.toInt()}", Colors.grey[700]!),
              _buildMacroBadge("Carb", "${refeicao.totalCarboidratos.toInt()}g", Colors.orange),
              _buildMacroBadge("Prot", "${refeicao.totalProteinas.toInt()}g", Colors.blue),
              _buildMacroBadge("Gord", "${refeicao.totalGorduras.toInt()}g", Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        )
      ],
    );
  }

  Widget _buildCardSemPlano() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: _boxDecorationPadrao(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.no_meals, color: Colors.grey, size: 30),
          ),
          const SizedBox(height: 12),
          const Text("Nenhum dado encontrado.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Seu plano alimentar aparecerá aqui quando seu nutricionista cadastrar.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
  Widget _buildCardAntropometriaGrid(Antropometria dados) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _boxDecorationPadrao(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatItem("Peso", "${dados.massaCorporal ?? '--'} kg", Icons.scale, Colors.blue)),
              const SizedBox(width: 15),
              Expanded(child: _buildStatItem("IMC", dados.imc?.toStringAsFixed(1) ?? '--', Icons.calculate, Colors.purple)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildStatItem("% Gordura", "${dados.percentualGordura?.toStringAsFixed(1) ?? '--'}%", Icons.opacity, Colors.orange)),
              const SizedBox(width: 15),
              Expanded(child: _buildStatItem("Massa Musc.", "${dados.massaMuscular?.toStringAsFixed(1) ?? '--'} kg", Icons.fitness_center, Colors.green)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
          Align(
            alignment: Alignment.centerRight,
            child: Text("Atualizado em: ${_formatarData(dados.data)}", style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
          )
        ],
      ),
    );
  }

  Widget _buildCardSemDadosAntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: _boxDecorationPadrao(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.monitor_weight_outlined, color: Colors.grey, size: 30),
          ),
          const SizedBox(height: 12),
          const Text("Nenhuma avaliação física encontrada.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Seu histórico corporal aparecerá aqui quando seu nutricionista cadastrar.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBotaoAcao(String texto, Color cor, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: cor,
          side: BorderSide(color: cor.withOpacity(0.5)),
          shape: AppStyles.shapeButton, 
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  BoxDecoration _boxDecorationPadrao() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: AppStyles.borderCard,
      border: Border.all(color: Colors.grey.withOpacity(0.1)),
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 4))],
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return "--/--/----";
    return "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
  }
}