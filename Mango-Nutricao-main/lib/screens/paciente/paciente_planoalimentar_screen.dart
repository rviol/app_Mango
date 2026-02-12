import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart'; // Importe fl_chart

import '../../widgets/app_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../classes/plano_alimentar.dart';
import '../../classes/refeicao.dart';
import '../../database/plano_alimentar_repository.dart';

class PacientePlanoAlimentarScreen extends StatefulWidget {
  const PacientePlanoAlimentarScreen({super.key});

  @override
  State<PacientePlanoAlimentarScreen> createState() =>
      _PacientePlanoAlimentarScreenState();
}

class _PacientePlanoAlimentarScreenState
    extends State<PacientePlanoAlimentarScreen> {
  final _repo = PlanoAlimentarRepository();
  bool _isLoading = true;
  List<PlanoAlimentar> _todosPlanos = [];
  PlanoAlimentar? _planoAtual;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDados();
    });
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final user = authService.usuario;
      String? idFinal;

      if (user != null) {
        dynamic u = user;
        try {
          idFinal = u.id;
        } catch (e) {
          try {
            idFinal = u.uid;
          } catch (e2) {}
        }
      }

      if (idFinal != null) {
        final lista = await _repo.listarPlanos(idFinal);
        if (mounted) {
          setState(() {
            _todosPlanos = lista;
            if (lista.isNotEmpty) _planoAtual = lista.first;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportarPDF() async {
    if (_planoAtual == null) return;
    final pdf = pw.Document();
    final dataPlano = DateFormat('dd/MM/yyyy').format(_planoAtual!.dataCriacao);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                "Plano Alimentar: ${_planoAtual!.nome}",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text("Data: $dataPlano"),
            pw.SizedBox(height: 20),
            ..._planoAtual!.refeicoes.map((refeicao) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "${refeicao.nome} (${refeicao.horario})",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.Divider(),
                    ...refeicao.alimentos.map(
                      (ali) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(ali.nome),
                          pw.Text("${ali.quantidade}g"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- NOVOS WIDGETS DE GRÁFICO (Cópia da tela do Nutri para consistência) ---
  Widget _buildGraficosNutricionais(PlanoAlimentar plano) {
    double totalCarb = 0, totalProt = 0, totalGord = 0;
    double totalFibra = 0, totalCalcio = 0, totalFerro = 0, totalVitC = 0;

    for (var ref in plano.refeicoes) {
      for (var ali in ref.alimentos) {
        totalCarb += ali.carboidratos;
        totalProt += ali.proteinas;
        totalGord += ali.gorduras;
        try {
          totalFibra += (ali.fibras);
        } catch (_) {}
        try {
          totalCalcio += (ali.calcio);
        } catch (_) {}
        try {
          totalFerro += (ali.ferro);
        } catch (_) {}
        try {
          totalVitC += (ali.vitC);
        } catch (_) {}
      }
    }

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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "Seus Macronutrientes (Dia)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
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
                            _buildPieSection(
                              kcalCarb,
                              totalKcal,
                              Colors.orange,
                              "Carb",
                            ),
                            _buildPieSection(
                              kcalProt,
                              totalKcal,
                              Colors.blue,
                              "Prot",
                            ),
                            _buildPieSection(
                              kcalGord,
                              totalKcal,
                              Colors.red,
                              "Gord",
                            ),
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
                          _buildLegendItem(
                            "Carboidratos",
                            Colors.orange,
                            "${totalCarb.toStringAsFixed(0)}g",
                          ),
                          _buildLegendItem(
                            "Proteínas",
                            Colors.blue,
                            "${totalProt.toStringAsFixed(0)}g",
                          ),
                          _buildLegendItem(
                            "Gorduras",
                            Colors.red,
                            "${totalGord.toStringAsFixed(0)}g",
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Total: ${totalKcal.toStringAsFixed(0)} Kcal",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "Micronutrientes Principais",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
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
                            PieChartSectionData(
                              value: totalFibra * 1000,
                              color: Colors.green,
                              radius: 15,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: totalCalcio,
                              color: Colors.indigo,
                              radius: 15,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: totalFerro,
                              color: Colors.brown,
                              radius: 15,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: totalVitC,
                              color: Colors.orangeAccent,
                              radius: 15,
                              showTitle: false,
                            ),
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
                          _buildLegendItem(
                            "Fibras",
                            Colors.green,
                            "${totalFibra.toStringAsFixed(1)}g",
                          ),
                          _buildLegendItem(
                            "Cálcio",
                            Colors.indigo,
                            "${totalCalcio.toStringAsFixed(0)}mg",
                          ),
                          _buildLegendItem(
                            "Ferro",
                            Colors.brown,
                            "${totalFerro.toStringAsFixed(1)}mg",
                          ),
                          _buildLegendItem(
                            "Vit. C",
                            Colors.orangeAccent,
                            "${totalVitC.toStringAsFixed(1)}mg",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PieChartSectionData _buildPieSection(
    double value,
    double total,
    Color color,
    String title,
  ) {
    final percent = total > 0 ? (value / total * 100) : 0.0;
    return PieChartSectionData(
      color: color,
      value: value,
      title: "${percent.toStringAsFixed(0)}%",
      radius: 40,
      titleStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.verde,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.verde,
        elevation: 0,
        title: const Text(
          'Plano Alimentar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _exportarPDF,
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text(
                            'Exportar como PDF',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.verde,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: AppStyles.shapeButton,
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_planoAtual == null)
                            _buildSemPlano()
                          else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                              'Refeições',
                              style: TextStyle(
                                color: AppColors.verde,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                                
                                Text(
                                  _planoAtual!.nome,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 10),

                            if (_planoAtual!.refeicoes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text("Nenhuma refeição neste plano."),
                                ),
                              )
                            else
                              ..._planoAtual!.refeicoes.map(
                                (ref) => _buildRefeicaoCardStyle(ref),
                              ),

                            const SizedBox(height: 25),

                            const Text(
                                  'Resumo Nutricional',
                                  style: TextStyle(
                                    color: AppColors.verde,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                            const SizedBox(height: 16),

                            _buildGraficosNutricionais(_planoAtual!),
                          ],
                          if (_todosPlanos.length > 1) ...[
                            const SizedBox(height: 30),
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: const Text(
                                  'Histórico',
                                  style: TextStyle(
                                    color: AppColors.verde,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ),
                            ..._todosPlanos
                                .skip(1)
                                .map(
                                  (antigo) => ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.grey[100],
                                      child: const Icon(
                                        Icons.history,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    title: Text(antigo.nome),
                                    subtitle: Text(
                                      "Data: ${_formatDate(antigo.dataCriacao)}",
                                    ),
                                    onTap:
                                        () =>
                                            _mostrarDetalhesPlanoAntigo(antigo),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSemPlano() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text(
              "Nenhum plano alimentar encontrado.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefeicaoCardStyle(Refeicao refeicao) {
    double cal = refeicao.totalCalorias;
    double carb = refeicao.totalCarboidratos;
    double prot = refeicao.totalProteinas;
    double gord = refeicao.totalGorduras;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.verde),
          ),
          title: Text(
            refeicao.nome,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            '${refeicao.horario} • ${cal.toStringAsFixed(0)} kcal',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          children: [
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroBadge(
                        "Carb",
                        "${carb.toStringAsFixed(1)}g",
                        Colors.orange,
                      ),
                      _buildMacroBadge(
                        "Prot",
                        "${prot.toStringAsFixed(1)}g",
                        Colors.blue,
                      ),
                      _buildMacroBadge(
                        "Gord",
                        "${gord.toStringAsFixed(1)}g",
                        Colors.red,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (refeicao.alimentos.isEmpty)
                    const Text(
                      "Sem alimentos",
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...refeicao.alimentos.map(
                      (alimento) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          alimento.nome,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text("${alimento.calorias} kcal / 100g"),
                        trailing: Text(
                          "${alimento.quantidade.toStringAsFixed(0)}g",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.verde,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            "$label: $value",
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  void _mostrarDetalhesPlanoAntigo(
    PlanoAlimentar p,
  ) {} // Implementação simplificada
}
