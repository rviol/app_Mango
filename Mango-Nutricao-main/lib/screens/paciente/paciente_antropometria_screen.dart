import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart'; // Gráficos na tela (Flutter)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Widgets do PDF
import 'package:printing/printing.dart';

import '../../classes/antropometria.dart';
import '../../database/antropometria_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';


class AntropometriaVisualizacaoPage extends StatefulWidget {
  final String pacienteId;

  const AntropometriaVisualizacaoPage({Key? key, required this.pacienteId})
      : super(key: key);

  @override
  State<AntropometriaVisualizacaoPage> createState() =>
      _AntropometriaVisualizacaoPageState();
}

class _AntropometriaVisualizacaoPageState
    extends State<AntropometriaVisualizacaoPage> {
  final _repository = AntropometriaRepository();

  Antropometria? _ultimaAvaliacao;
  List<Antropometria> _historico = [];
  bool _isLoading = true;
  String _generoPaciente = 'Masculino';
  String _nomePaciente = 'Paciente';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    try {
      final userSnapshot = await FirebaseDatabase.instance
          .ref('usuarios/${widget.pacienteId}')
          .get();

      if (userSnapshot.exists) {
        final dadosUser = userSnapshot.value as Map;
        _generoPaciente = dadosUser['genero'] ?? 'Masculino';
        _nomePaciente = dadosUser['nome'] ?? 'Paciente';
      }

      final historico = await _repository.buscarHistorico(widget.pacienteId);

      if (historico.isNotEmpty) {
        historico.sort((a, b) =>
            (a.data ?? DateTime(2000)).compareTo(b.data ?? DateTime(2000)));

        _ultimaAvaliacao = historico.last;
      } else {
        _ultimaAvaliacao = null;
      }

      if (mounted) {
        setState(() {
          _historico = historico;
        });
      }
    } catch (e) {
      debugPrint("Erro: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// --- PDF EXPORT (ABORDAGEM MANUAL DE GRID) ---
  Future<void> _exportarPDF() async {
    if (_ultimaAvaliacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem dados para exportar.')));
      return;
    }

    final pdf = pw.Document();
    final dataFormatada = DateFormat('dd/MM/yyyy').format(_ultimaAvaliacao!.data!);
    
    // Preparando dados cronológicos (Antigo -> Novo)
    final dadosCronologicos = _historico.reversed.toList();

    // Função para formatar o eixo X (Datas)
    String getLabelX(num value) {
      int idx = value.toInt();
      if (idx >= 0 && idx < dadosCronologicos.length) {
        return DateFormat('dd/MM').format(dadosCronologicos[idx].data!);
      }
      return '';
    }

    // 1. DADOS DE TABELA
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Relatório de Antropometria',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paciente: $_nomePaciente', style: const pw.TextStyle(fontSize: 14)),
                  pw.Text('Data: $dataFormatada', style: const pw.TextStyle(fontSize: 14)),
                ]
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              pw.Text('Resultados Atuais:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
              pw.SizedBox(height: 10),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8)
                ),
                child: pw.Column(children: [
                  _buildPdfRow('Massa Corporal', '${_ultimaAvaliacao!.massaCorporal?.toStringAsFixed(1)} kg'),
                  _buildPdfRow('Massa Gorda', '${_ultimaAvaliacao!.massaGordura?.toStringAsFixed(1)} kg'),
                  _buildPdfRow('% de Gordura', '${_ultimaAvaliacao!.percentualGordura?.toStringAsFixed(1)} %'),
                  _buildPdfRow('Massa Muscular', '${_ultimaAvaliacao!.massaMuscular?.toStringAsFixed(1)} kg'),
                  _buildPdfRow('IMC', '${_ultimaAvaliacao!.imc?.toStringAsFixed(1)} kg/m²'),
                  _buildPdfRow('CMB', '${_ultimaAvaliacao!.cmb?.toStringAsFixed(1)} cm'),
                  _buildPdfRow('RCQ', '${_ultimaAvaliacao!.relacaoCinturaQuadril?.toStringAsFixed(2)}'),
                ]),
              ),
              
              pw.SizedBox(height: 20),
              pw.Text('Observações:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_ultimaAvaliacao!.observacoes ?? 'Nenhuma observação.'),
            ],
          );
        },
      ),
    );

    // 2. GRÁFICOS (PÁGINA 2)
    if (dadosCronologicos.length > 1) {
      
      // Prepara os dados para cada gráfico
      final charts = <pw.Widget>[];

      // Helper interno para extrair dados
      List<pw.PointChartValue> extractData(double? Function(Antropometria) selector) {
        final list = <pw.PointChartValue>[];
        for (int i = 0; i < dadosCronologicos.length; i++) {
          final val = selector(dadosCronologicos[i]);
          if (val != null && val > 0) {
            list.add(pw.PointChartValue(i.toDouble(), val));
          }
        }
        return list;
      }

      // Adiciona os gráficos à lista se tiverem dados
      final dPeso = extractData((a) => a.massaCorporal);
      if (dPeso.isNotEmpty) charts.add(_buildPdfChart("Peso (kg)", dPeso, PdfColors.purple, getLabelX));

      final dGordura = extractData((a) => a.percentualGordura);
      if (dGordura.isNotEmpty) charts.add(_buildPdfChart("% Gordura", dGordura, PdfColors.orange, getLabelX));

      final dMassaGorda = extractData((a) => a.massaGordura);
      if (dMassaGorda.isNotEmpty) charts.add(_buildPdfChart("Massa Gorda (kg)", dMassaGorda, PdfColors.red, getLabelX));

      final dMassaMuscular = extractData((a) => a.massaMuscular);
      if (dMassaMuscular.isNotEmpty) charts.add(_buildPdfChart("Massa Muscular (kg)", dMassaMuscular, PdfColors.teal, getLabelX));

      final dImc = extractData((a) => a.imc);
      if (dImc.isNotEmpty) charts.add(_buildPdfChart("IMC", dImc, PdfColors.blue, getLabelX));

      final dCmb = extractData((a) => a.cmb);
      if (dCmb.isNotEmpty) charts.add(_buildPdfChart("CMB (cm)", dCmb, PdfColors.green, getLabelX));

      final dRcq = extractData((a) => a.relacaoCinturaQuadril);
      if (dRcq.isNotEmpty) charts.add(_buildPdfChart("RCQ", dRcq, PdfColors.pink, getLabelX));

      // Gera a página com layout manual (Rows de 2 colunas)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 1, child: pw.Text("Evolução Gráfica", style: pw.TextStyle(color: PdfColors.purple800, fontWeight: pw.FontWeight.bold, fontSize: 18))),
                pw.SizedBox(height: 20),
                ..._generateChartRows(charts),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Helper para organizar os gráficos em linhas de 2
  List<pw.Widget> _generateChartRows(List<pw.Widget> charts) {
    final rows = <pw.Widget>[];
    for (int i = 0; i < charts.length; i += 2) {
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: charts[i]),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: (i + 1 < charts.length) ? charts[i + 1] : pw.Container(),
            ),
          ],
        ),
      );
      rows.add(pw.SizedBox(height: 20));
    }
    return rows;
  }

  // Construtor do Gráfico PDF (Robusto)
  pw.Widget _buildPdfChart(
    String title, 
    List<pw.PointChartValue> data, 
    PdfColor color, 
    String Function(num) labelFormatter
  ) {
    // Cálculo seguro dos limites do Eixo Y
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (var p in data) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    // Margem de segurança para o gráfico não encostar nas bordas
    double margin = (maxY - minY) * 0.2;
    if (margin == 0) margin = 5.0; // Caso todos os valores sejam iguais
    
    // Arredonda para ficar bonito no eixo
    minY = (minY - margin).floorToDouble();
    if (minY < 0) minY = 0;
    maxY = (maxY + margin).ceilToDouble();

    // Cria os ticks do eixo Y manualmente
    final step = (maxY - minY) / 4;
    final yTicks = [
      minY,
      minY + step,
      minY + (step * 2),
      minY + (step * 3),
      maxY
    ];

    // Cor de preenchimento (manual pois withOpacity não existe no PdfColor padrão dessa versão)
    final surfaceColor = PdfColor(color.red, color.green, color.blue, 0.1);

    return pw.Container(
      height: 180, // Altura fixa garantida
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  List.generate(data.length, (i) => i),
                  format: labelFormatter,
                  textStyle: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  margin: 2,
                ),
                yAxis: pw.FixedAxis(
                  yTicks,
                  format: (v) => v.toStringAsFixed(0),
                  textStyle: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  divisions: true, 
                ),
              ),
              datasets: [
                pw.LineDataSet(
                  drawSurface: true,
                  surfaceColor: surfaceColor,
                  isCurved: true,
                  drawPoints: true,
                  pointSize: 4,
                  color: color,
                  data: data,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // --- SAIBA MAIS (MODAL BOTTOM SHEET) ---
  void _mostrarLegenda(BuildContext context) {
    bool isFem = _generoPaciente == 'Feminino';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Entenda os Gráficos", style: TextStyle(color: AppColors.roxo, fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Referências para: $_generoPaciente", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 25),
              
              const Text("Legenda de Cores:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendaItemCor("Abaixo", const Color(0xFF5E6EE6)),
                  _buildLegendaItemCor("Ideal", const Color(0xFF4CAF50)),
                  _buildLegendaItemCor("Acima", const Color(0xFFFF7043)),
                ],
              ),
              const Divider(height: 30),
              
              const Text("Intervalos Saudáveis (Ideal):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              _buildItemIntervalo("IMC", "18.5 - 24.9 kg/m²"),
              _buildItemIntervalo("% Gordura", isFem ? "18% - 28%" : "10% - 20%"),
              _buildItemIntervalo("Massa Muscular", isFem ? "20 - 30 kg" : "30 - 40 kg"),
              _buildItemIntervalo("RCQ", isFem ? "0.70 - 0.85" : "0.80 - 0.95"),
              _buildItemIntervalo("CMB", isFem ? "20 - 29 cm" : "23 - 34 cm"),
              
              const Divider(height: 30),
              const Text("Escala Visual (Máximos):", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildItemEscala("Peso Total", "até 150 kg"),
              _buildItemEscala("Massa Gorda", "até 50 kg"),
              _buildItemEscala("Gordura %", "até 50%"),
              _buildItemEscala("Massa Muscular", "até 80 kg"),
              _buildItemEscala("IMC", "até 50 kg/m²"),
              _buildItemEscala("CMB", "até 60 cm"),
              _buildItemEscala("RCQ", "até 1.2"),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendaItemCor(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildItemIntervalo(String titulo, String range) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(range, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
        ],
      ),
    );
  }

  Widget _buildItemEscala(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.bar_chart, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 12),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: valor, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roxo,
      appBar: AppBar(
        backgroundColor: AppColors.roxo,
        elevation: 0,
        title: const Text('Antropometria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
    style: TextStyle(fontWeight: FontWeight.bold), // Texto em negrito
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.roxo,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: AppStyles.shapeButton, // Padronizado (Radius 16)
    elevation: 2, // Sombra suave para destacar o branco
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
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Última Avaliação Física', style: TextStyle(color: AppColors.roxo, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildCardResumo(),
                          const SizedBox(height: 24),
                          
                          Row(
                            children: [
                              const Text('Legenda: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              _buildLegendaChip('Abaixo', const Color(0xFF5E6EE6)),
                              _buildLegendaChip('Ideal', const Color(0xFF4CAF50)),
                              _buildLegendaChip('Acima', const Color(0xFFFF7043)),
                              const Spacer(),
                              InkWell(
                                onTap: () => _mostrarLegenda(context),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline, size: 16, color: AppColors.roxo),
                                    SizedBox(width: 4),
                                    Text('+ Saiba mais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.roxo)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (_ultimaAvaliacao != null) ...[
                            _buildIndicadorBarra('Massa Corporal Total', _ultimaAvaliacao!.massaCorporal, 'kg', _ultimaAvaliacao!.classMassaCorporal, maxVal: 150.0),
                            _buildIndicadorBarra('Massa de Gordura', _ultimaAvaliacao!.massaGordura, 'kg', _ultimaAvaliacao!.classMassaGordura, maxVal: 50.0),
                            _buildIndicadorBarra('Percentual de Gordura', _ultimaAvaliacao!.percentualGordura, '%', _ultimaAvaliacao!.classPercentualGordura, maxVal: 50.0),
                            _buildIndicadorBarra('Massa Muscular', _ultimaAvaliacao!.massaMuscular, 'kg', _ultimaAvaliacao!.classMassaMuscular, maxVal: 80.0),
                            _buildIndicadorBarra('IMC', _ultimaAvaliacao!.imc, '', _ultimaAvaliacao!.classImc, maxVal: 50.0),
                            _buildIndicadorBarra('CMB (Braço)', _ultimaAvaliacao!.cmb, ' cm', _ultimaAvaliacao!.classCmb, maxVal: 60.0),
                            _buildIndicadorBarra('Relação C/Q', _ultimaAvaliacao!.relacaoCinturaQuadril, '', _ultimaAvaliacao!.classRcq, maxVal: 1.2),
                          ] else
                            const Text("Nenhuma avaliação cadastrada.", style: TextStyle(color: Colors.grey)),
                          
                          const SizedBox(height: 30),
                          const Text('Evolução Gráfica', style: TextStyle(color: AppColors.roxo, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          
                          if (_historico.length < 2)
                            Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                              child: const Column(
                                children: [
                                  Icon(Icons.show_chart, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text("Cadastre pelo menos 2 avaliações para visualizar a evolução.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          else ...[
                            _buildGraficoCard("Peso (kg)", _historico, (a) => a.massaCorporal ?? 0, AppColors.roxo, 'kg'),
                            _buildGraficoCard("Gordura Corporal (%)", _historico, (a) => a.percentualGordura ?? 0, const Color(0xFFFF7043), '%'),
                            _buildGraficoCard("Massa Gorda (kg)", _historico, (a) => a.massaGordura ?? 0, const Color(0xFFFF7043), 'kg'),
                            _buildGraficoCard("Massa Muscular (kg)", _historico, (a) => a.massaMuscular ?? 0, const Color(0xFF4CAF50), 'kg'),
                            _buildGraficoCard("IMC (kg/m²)", _historico, (a) => a.imc ?? 0, const Color(0xFF5E6EE6), ''),
                            _buildGraficoCard("CMB (cm)", _historico, (a) => a.cmb ?? 0, const Color(0xFF4CAF50), 'cm'),
                            _buildGraficoCard("RCQ", _historico, (a) => a.relacaoCinturaQuadril ?? 0, const Color(0xFFE91E63), ''),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardResumo() {
    if (_ultimaAvaliacao == null) return const SizedBox();
    double gordura = _ultimaAvaliacao!.percentualGordura ?? 0;
    double magra = 100 - gordura;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60, height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.roxo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.accessibility_new, color: AppColors.roxo, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Avaliação Física", style: TextStyle(color: AppColors.roxo, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(DateFormat('dd/MM/yyyy').format(_ultimaAvaliacao!.data ?? DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(children: [
                  _buildBadge('Massa Magra: ${magra.toStringAsFixed(0)}%', const Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  _buildBadge('Massa Gorda: ${gordura.toStringAsFixed(0)}%', const Color(0xFFFF7043)),
                ]),
                const SizedBox(height: 12),
                Text(_ultimaAvaliacao!.observacoes ?? '', style: const TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIndicadorBarra(String label, double? valor, String unidade, String? classificacao, {double maxVal = 100.0}) {
    Color cor;
    if (classificacao == 'Abaixo') cor = const Color(0xFF5E6EE6);
    else if (classificacao == 'Acima') cor = const Color(0xFFFF7043);
    else cor = const Color(0xFF4CAF50);

    double v = valor ?? 0;
    double percent = (v / maxVal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Text('${v.toStringAsFixed(1)}$unidade', style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 12)),
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
          const SizedBox(height: 6),
          // Barra com sombra suave da cor do status
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
                    boxShadow: [
                      BoxShadow(
                          color: cor.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoCard(String titulo, List<Antropometria> dados, double Function(Antropometria) getValor, Color corLinha, String unidade) {
    List<FlSpot> spots = [];
    double maxY = 0;
    double minY = 9999;

    for (int i = 0; i < dados.length; i++) {
      final val = getValor(dados[i]);
      if (val > maxY) maxY = val;
      if (val < minY) minY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (maxY == 0) maxY = 100;
    double intervalY = (maxY - minY) / 4;
    if (intervalY <= 0) intervalY = 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text("Evolução temporal", style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: (minY - intervalY).clamp(0, 9999),
                maxY: maxY + intervalY,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: intervalY, getTitlesWidget: (v, m) => (v == m.min || v == m.max) ? const SizedBox() : Text(v.toStringAsFixed(0), style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, m) {
                    final index = v.toInt();
                    if (index >= 0 && index < dados.length) {
                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('dd/MM').format(dados[index].data!), style: const TextStyle(fontSize: 10, color: Colors.grey)));
                    }
                    return const SizedBox();
                  })),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true, color: corLinha, barWidth: 3, isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: corLinha.withOpacity(0.1)),
                  ),
                ],
                lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(tooltipBgColor: Colors.white, getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} $unidade', TextStyle(color: corLinha, fontWeight: FontWeight.bold))).toList())),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLegendaChip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}