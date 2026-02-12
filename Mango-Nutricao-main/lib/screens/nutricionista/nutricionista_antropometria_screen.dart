import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../classes/antropometria.dart';
import '../../database/antropometria_repository.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';

class NutricionistaAntropometriaScreen extends StatefulWidget {
  final String pacienteId;
  final Antropometria? avaliacaoParaEditar;

  const NutricionistaAntropometriaScreen({
    super.key,
    required this.pacienteId,
    this.avaliacaoParaEditar,
  });

  @override
  State<NutricionistaAntropometriaScreen> createState() =>
      _NutricionistaAntropometriaScreenState();
}

class _NutricionistaAntropometriaScreenState
    extends State<NutricionistaAntropometriaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = AntropometriaRepository();

  List<Antropometria> _historico = [];
  bool _isLoading = true;
  String _generoPaciente = 'Masculino';

  String? _idAvaliacaoEmEdicao;
  DateTime _dataSelecionada = DateTime.now();

  final _obsCtrl = TextEditingController();
  final _massaCorporalCtrl = TextEditingController();
  final _massaGorduraCtrl = TextEditingController();
  final _massaMuscularCtrl = TextEditingController();
  final _percentualGorduraCtrl = TextEditingController();
  final _imcCtrl = TextEditingController();
  final _cmbCtrl = TextEditingController();
  final _rcqCtrl = TextEditingController();

  String _classMassaCorporal = 'Ideal';
  String _classMassaGordura = 'Ideal';
  String _classMassaMuscular = 'Ideal';
  String _classPercentualGordura = 'Ideal';
  String _classImc = 'Ideal';
  String _classCmb = 'Ideal';
  String _classRcq = 'Ideal';

  @override
  void initState() {
    super.initState();
    if (widget.avaliacaoParaEditar != null) {
      _carregarParaEdicao(widget.avaliacaoParaEditar!);
    }
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _massaCorporalCtrl.dispose();
    _massaGorduraCtrl.dispose();
    _massaMuscularCtrl.dispose();
    _percentualGorduraCtrl.dispose();
    _imcCtrl.dispose();
    _cmbCtrl.dispose();
    _rcqCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('usuarios/${widget.pacienteId}')
          .get();
      if (snapshot.exists) {
        final dados = snapshot.value as Map;
        setState(() {
          _generoPaciente = dados['genero'] ?? 'Masculino';
        });
      }

      final lista = await _repository.buscarHistorico(widget.pacienteId);
      lista.sort((a, b) => (b.data ?? DateTime(2000))
          .compareTo(a.data ?? DateTime(2000)));

      setState(() {
        _historico = lista;
      });
    } catch (e) {
      debugPrint("Erro ao carregar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.roxo,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dataSelecionada) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  // --- LÓGICA DE CÁLCULO PARA TODOS OS ÍNDICES ---
  void _calcularSugestaoAutomatica(String tipo, String valorTexto) {
    if (valorTexto.isEmpty) return;
    double? valor = double.tryParse(valorTexto.replaceAll(',', '.'));
    if (valor == null) return;

    String sugestao = 'Ideal';
    bool isFem = _generoPaciente == 'Feminino';

    switch (tipo) {
      case 'IMC':
        if (valor < 18.5) sugestao = 'Abaixo';
        else if (valor >= 25.0) sugestao = 'Acima';
        else sugestao = 'Ideal';
        setState(() => _classImc = sugestao);
        break;

      case 'GorduraPercent': // % Gordura
        double min = isFem ? 18.0 : 10.0;
        double max = isFem ? 28.0 : 20.0;
        if (valor < min) sugestao = 'Abaixo';
        else if (valor > max) sugestao = 'Acima';
        setState(() => _classPercentualGordura = sugestao);
        break;

      case 'MassaGorda': // Gordura em Kg (estimativa)
        // Referência aproximada: Homens 6-18kg, Mulheres 10-25kg (varia muito com altura)
        double minKg = isFem ? 10.0 : 6.0;
        double maxKg = isFem ? 25.0 : 18.0;
        if (valor < minKg) sugestao = 'Abaixo';
        else if (valor > maxKg) sugestao = 'Acima';
        setState(() => _classMassaGordura = sugestao);
        break;

      case 'MassaMuscular': // Massa Muscular em Kg
        // Referência aproximada para adultos
        double refMin = isFem ? 20.0 : 30.0; 
        if (valor < refMin) sugestao = 'Abaixo';
        else if (valor > refMin + 20) sugestao = 'Acima'; // Muito musculoso
        else sugestao = 'Ideal';
        setState(() => _classMassaMuscular = sugestao);
        break;

      case 'RCQ': // Relação Cintura Quadril
        // Risco alto: Homens > 0.90, Mulheres > 0.85
        double limite = isFem ? 0.85 : 0.90;
        double baixo = isFem ? 0.70 : 0.80;
        if (valor > limite) sugestao = 'Acima'; // Risco
        else if (valor < baixo) sugestao = 'Abaixo';
        else sugestao = 'Ideal';
        setState(() => _classRcq = sugestao);
        break;

      case 'CMB': // Circunferência Muscular do Braço
        double minCMB = isFem ? 20.0 : 23.0;
        double maxCMB = isFem ? 29.0 : 34.0;
        if (valor < minCMB) sugestao = 'Abaixo';
        else if (valor > maxCMB) sugestao = 'Acima';
        setState(() => _classCmb = sugestao);
        break;

      case 'Peso': // Massa Corporal
        // Sem altura é difícil definir "Ideal", usamos uma média segura apenas para preencher
        // O ideal é o Nutricionista ajustar manualmente se necessário
        double minPeso = isFem ? 45.0 : 55.0;
        double maxPeso = isFem ? 80.0 : 90.0;
        if (valor < minPeso) sugestao = 'Abaixo';
        else if (valor > maxPeso) sugestao = 'Acima';
        else sugestao = 'Ideal';
        setState(() => _classMassaCorporal = sugestao);
        break;
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final novaAvaliacao = Antropometria(
      id_avaliacao: _idAvaliacaoEmEdicao,
      massaCorporal: double.tryParse(_massaCorporalCtrl.text.replaceAll(',', '.')),
      massaGordura: double.tryParse(_massaGorduraCtrl.text.replaceAll(',', '.')),
      massaMuscular: double.tryParse(_massaMuscularCtrl.text.replaceAll(',', '.')),
      percentualGordura: double.tryParse(_percentualGorduraCtrl.text.replaceAll(',', '.')),
      massaEsqueletica: null,
      imc: double.tryParse(_imcCtrl.text.replaceAll(',', '.')),
      cmb: double.tryParse(_cmbCtrl.text.replaceAll(',', '.')),
      relacaoCinturaQuadril: double.tryParse(_rcqCtrl.text.replaceAll(',', '.')),
      
      classMassaCorporal: _classMassaCorporal,
      classMassaGordura: _classMassaGordura,
      classMassaMuscular: _classMassaMuscular,
      classPercentualGordura: _classPercentualGordura,
      classMassaEsqueletica: null,
      classImc: _classImc,
      classCmb: _classCmb,
      classRcq: _classRcq,
      
      observacoes: _obsCtrl.text,
      data: _dataSelecionada,
    );

    await _repository.salvarAvaliacao(widget.pacienteId, novaAvaliacao);
    _limparCampos();
    await _carregarDadosIniciais();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green),
    );
  }

  void _limparCampos() {
    setState(() {
      _idAvaliacaoEmEdicao = null;
      _dataSelecionada = DateTime.now();
      _classMassaCorporal = _classMassaGordura = _classMassaMuscular =
      _classPercentualGordura = _classImc = _classCmb = _classRcq = 'Ideal';
    });
    _massaCorporalCtrl.clear();
    _massaGorduraCtrl.clear();
    _massaMuscularCtrl.clear();
    _percentualGorduraCtrl.clear();
    _imcCtrl.clear();
    _cmbCtrl.clear();
    _rcqCtrl.clear();
    _obsCtrl.clear();
  }

  void _carregarParaEdicao(Antropometria item) {
    setState(() {
      _idAvaliacaoEmEdicao = item.id_avaliacao;
      _dataSelecionada = item.data ?? DateTime.now();
      _classMassaCorporal = item.classMassaCorporal ?? 'Ideal';
      _classMassaGordura = item.classMassaGordura ?? 'Ideal';
      _classMassaMuscular = item.classMassaMuscular ?? 'Ideal';
      _classPercentualGordura = item.classPercentualGordura ?? 'Ideal';
      _classImc = item.classImc ?? 'Ideal';
      _classCmb = item.classCmb ?? 'Ideal';
      _classRcq = item.classRcq ?? 'Ideal';
    });
    _massaCorporalCtrl.text = item.massaCorporal?.toString() ?? '';
    _massaGorduraCtrl.text = item.massaGordura?.toString() ?? '';
    _massaMuscularCtrl.text = item.massaMuscular?.toString() ?? '';
    _percentualGorduraCtrl.text = item.percentualGordura?.toString() ?? '';
    _imcCtrl.text = item.imc?.toString() ?? '';
    _cmbCtrl.text = item.cmb?.toString() ?? '';
    _rcqCtrl.text = item.relacaoCinturaQuadril?.toString() ?? '';
    _obsCtrl.text = item.observacoes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    String dataExibida = DateFormat('dd/MM/yyyy').format(_dataSelecionada);

    return Scaffold(
      backgroundColor: AppColors.roxo,
      appBar: AppBar(
        backgroundColor: AppColors.roxo,
        elevation: 0,
        title: const Text('Antropometria',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Text(
                    _idAvaliacaoEmEdicao != null
                        ? 'Editando Avaliação'
                        : 'Nova Avaliação',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppStyles.borderTopCard,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderCard(dataExibida),
                            const SizedBox(height: 25),
                            _buildSecaoTitulo(),
                            const SizedBox(height: 15),
                            
                            // Agora TODOS os inputs chamam _calcularSugestaoAutomatica
                            _buildInputComStatus(
                                'Massa Corporal (kg)',
                                _massaCorporalCtrl,
                                _classMassaCorporal,
                                (val) => setState(() => _classMassaCorporal = val),
                                (v) => _calcularSugestaoAutomatica('Peso', v)),
                            
                            _buildInputComStatus(
                                'Massa Muscular (kg)',
                                _massaMuscularCtrl,
                                _classMassaMuscular,
                                (val) => setState(() => _classMassaMuscular = val),
                                (v) => _calcularSugestaoAutomatica('MassaMuscular', v)),

                            _buildInputComStatus(
                                'Massa de Gordura (kg)',
                                _massaGorduraCtrl,
                                _classMassaGordura,
                                (val) => setState(() => _classMassaGordura = val),
                                (v) => _calcularSugestaoAutomatica('MassaGorda', v)),
                            
                            _buildInputComStatus(
                                'Percentual Gordura (%)',
                                _percentualGorduraCtrl,
                                _classPercentualGordura,
                                (val) => setState(() => _classPercentualGordura = val),
                                (v) => _calcularSugestaoAutomatica('GorduraPercent', v)),
                            
                            _buildInputComStatus(
                                'IMC (kg/m²)',
                                _imcCtrl,
                                _classImc,
                                (val) => setState(() => _classImc = val),
                                (v) => _calcularSugestaoAutomatica('IMC', v)),
                            
                            _buildInputComStatus(
                                'Relação Cintura/Quadril',
                                _rcqCtrl,
                                _classRcq,
                                (val) => setState(() => _classRcq = val),
                                (v) => _calcularSugestaoAutomatica('RCQ', v)),
                            
                            _buildInputComStatus(
                                'CMB (cm)',
                                _cmbCtrl,
                                _classCmb,
                                (val) => setState(() => _classCmb = val),
                                (v) => _calcularSugestaoAutomatica('CMB', v)),
                            
                            const SizedBox(height: 20),
                            _buildBotoesAcao(),
                            const SizedBox(height: 30),
                            const Divider(),
                            const SizedBox(height: 10),
                            _buildHistoricoList(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildHeaderCard(String dataTexto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _selecionarData,
          borderRadius: AppStyles.borderButton,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
                color: AppColors.roxo.withOpacity(0.1),
                borderRadius: AppStyles.borderButton,
                border: Border.all(color: AppColors.roxo.withOpacity(0.3))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Data da Avaliação:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.roxo)),
                Row(
                  children: [
                    const Icon(Icons.edit_calendar,
                        color: AppColors.roxo, size: 20),
                    const SizedBox(width: 8),
                    Text(dataTexto,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Observações Gerais",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _obsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Ex: Paciente relatou retenção de líquido...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
                borderRadius: AppStyles.borderButton,
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(15),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoTitulo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Classificação dos Índices',
              style: TextStyle(
                  color: AppColors.roxo,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text('Perfil: $_generoPaciente',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.roxo),
            onPressed: () => _mostrarLegenda(context)),
      ],
    );
  }

  Widget _buildInputComStatus(
      String label,
      TextEditingController ctrl,
      String statusAtual,
      Function(String) onStatusChanged,
      Function(String)? onChangedInput) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderButton,
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14))),
              SizedBox(
                  width: 90,
                  height: 40,
                  child: TextFormField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: onChangedInput,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.roxo),
                    decoration: InputDecoration(
                        contentPadding: const EdgeInsets.only(bottom: 5),
                        hintText: '0.0',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none)),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildChoiceChip('Abaixo', const Color(0xFF5E6EE6),
                    statusAtual, onStatusChanged),
                _buildChoiceChip('Ideal', const Color(0xFF4CAF50),
                    statusAtual, onStatusChanged),
                _buildChoiceChip('Acima', const Color(0xFFFF7043),
                    statusAtual, onStatusChanged),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChoiceChip(
      String label, Color color, String current, Function(String) onSelect) {
    bool selected = current == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBotoesAcao() {
    return Column(children: [
      SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(_idAvaliacaoEmEdicao != null
                  ? 'Atualizar Avaliação'
                  : 'Salvar Avaliação'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verde,
                  foregroundColor: Colors.white,
                  shape: AppStyles.shapeButton,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2))),
      if (_idAvaliacaoEmEdicao != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextButton(
              onPressed: _limparCampos,
              child: const Text('Cancelar Edição',
                  style: TextStyle(color: Colors.red))),
        ),
    ]);
  }

  Widget _buildHistoricoList() {
    if (_historico.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Histórico de Avaliações',
          style: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _historico.length,
          itemBuilder: (ctx, i) => _buildHistoricoItem(_historico[i])),
    ]);
  }

  Widget _buildHistoricoItem(Antropometria item) {
    bool isEditing = item.id_avaliacao == _idAvaliacaoEmEdicao;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isEditing ? AppColors.roxo.withOpacity(0.05) : Colors.white,
          borderRadius: AppStyles.borderButton,
          border: Border.all(
              color:
                  isEditing ? AppColors.roxo : Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.roxo.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.calendar_today,
                    size: 18, color: AppColors.roxo),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('dd/MM/yyyy').format(item.data!),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                    'Peso: ${item.massaCorporal ?? '-'}kg  •  IMC: ${item.imc ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
            ],
          ),
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => _carregarParaEdicao(item),
            )
          else
            const Chip(
                label: Text("Editando",
                    style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: AppColors.roxo)
        ],
      ),
    );
  }

  void _mostrarLegenda(BuildContext context) {
    bool isFem = _generoPaciente == 'Feminino';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Referências (${_generoPaciente})",
            style: const TextStyle(
                color: AppColors.roxo, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildTabelaRow("IMC", "< 18.5", "18.5-24.9", "≥ 25.0"),
            const Divider(),
            _buildTabelaRow("% Gordura", isFem ? "< 18%" : "< 10%",
                isFem ? "18-28%" : "10-20%", isFem ? "> 28%" : "> 20%"),
            const Divider(),
            _buildTabelaRow("RCQ", isFem ? "< 0.70" : "< 0.80",
                isFem ? "0.70-0.85" : "0.80-0.95", isFem ? "> 0.85" : "> 0.95"),
            const Divider(),
            _buildTabelaRow("CMB", isFem ? "< 20" : "< 23",
                isFem ? "20-29" : "23-34", isFem ? "> 29" : "> 34"),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fechar"))
        ],
      ),
    );
  }

  Widget _buildTabelaRow(String label, String b, String i, String a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _badge(b, const Color(0xFF5E6EE6)),
          _badge(i, const Color(0xFF4CAF50)),
          _badge(a, const Color(0xFFFF7043)),
        ]),
      ]),
    );
  }

  Widget _badge(String txt, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(txt,
          style: TextStyle(
              fontSize: 11, color: c, fontWeight: FontWeight.bold)));
}