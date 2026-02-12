import 'package:flutter/material.dart';
import '../../classes/plano_alimentar.dart';
import '../../classes/refeicao.dart';
import '../../classes/alimento.dart';
import '../../database/plano_alimentar_repository.dart';
import '../../database/taco_db.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';

class NutricionistaEditorPlanoScreen extends StatefulWidget {
  final String pacienteId;
  final PlanoAlimentar? plano;

  const NutricionistaEditorPlanoScreen({
    super.key,
    required this.pacienteId,
    this.plano,
  });

  @override
  State<NutricionistaEditorPlanoScreen> createState() =>
      _NutricionistaEditorPlanoScreenState();
}

class _NutricionistaEditorPlanoScreenState
    extends State<NutricionistaEditorPlanoScreen> {
  final _repo = PlanoAlimentarRepository();
  final _nomePlanoController = TextEditingController();

  late PlanoAlimentar _planoEmEdicao;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.plano != null) {
      _planoEmEdicao = widget.plano!;
      _nomePlanoController.text = _planoEmEdicao.nome;
    } else {
      _planoEmEdicao = PlanoAlimentar(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: "",
        dataCriacao: DateTime.now(),
        refeicoes: [],
      );
    }
  }

  Future<void> _salvarPlano() async {
    if (_nomePlanoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dê um nome ao plano")),
      );
      return;
    }

    setState(() => _isSaving = true);
    _planoEmEdicao.nome = _nomePlanoController.text;

    try {
      await _repo.salvarPlano(widget.pacienteId, _planoEmEdicao);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Salvo com sucesso!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Modal Nova Refeição ---
  void _addRefeicao() {
    final nomeCtrl = TextEditingController();
    final horaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, 
        surfaceTintColor: Colors.transparent, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nova Refeição', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.verde)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome (ex: Café da Manhã)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: horaCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Horário', prefixIcon: Icon(Icons.access_time)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  horaCtrl.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (nomeCtrl.text.isNotEmpty && horaCtrl.text.isNotEmpty) {
                setState(() {
                  _planoEmEdicao.refeicoes.add(Refeicao(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nome: nomeCtrl.text,
                    horario: horaCtrl.text,
                    alimentos: [],
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, shape: AppStyles.shapeButton),
            child: const Text('Criar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _abrirSelecaoAlimento(Refeicao refeicao) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (ctx) => _AlimentoSelectionModal(
        onAlimentoSelected: (alimento) {
          setState(() => refeicao.alimentos.add(alimento));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ordena refeições por horário
    _planoEmEdicao.refeicoes.sort((a, b) => a.horario.compareTo(b.horario));

    return Scaffold(
      backgroundColor: AppColors.verde,
      appBar: AppBar(
        backgroundColor: AppColors.verde,
        elevation: 0,
        title: Text(widget.plano != null ? 'Editar Plano' : 'Novo Plano', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      // Botão Salvar Fixo no Rodapé
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _salvarPlano,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verde,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: AppStyles.shapeButton, 
          ),
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("SALVAR PLANO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _nomePlanoController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: "Nome do Plano (ex: Hipertrofia)",
                hintStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                prefixIcon: Icon(Icons.edit, color: Colors.white),
              ),
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
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addRefeicao,
                        icon: const Icon(Icons.add),
                        label: const Text("ADICIONAR REFEIÇÃO"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.verde,
                          side: const BorderSide(color: AppColors.verde),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: AppStyles.shapeButton,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_planoEmEdicao.refeicoes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("Nenhuma refeição adicionada.", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),

                    ..._planoEmEdicao.refeicoes.map((ref) => _buildRefeicaoCard(ref)),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefeicaoCard(Refeicao ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderButton,
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.verde, borderRadius: BorderRadius.circular(8)),
                      child: Text(ref.horario, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Text(ref.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _planoEmEdicao.refeicoes.remove(ref)),
                ),
              ],
            ),
          ),
          
          if (ref.alimentos.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text("Sem alimentos nesta refeição", style: TextStyle(color: Colors.grey, fontSize: 12)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: ref.alimentos.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final ali = ref.alimentos[i];
                return ListTile(
                  dense: true,
                  title: Text(ali.nome, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("${ali.quantidade.toStringAsFixed(0)}g  •  ${ali.calorias.toStringAsFixed(0)} kcal"),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () => setState(() => ref.alimentos.remove(ali)),
                  ),
                );
              },
            ),
          
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () => _abrirSelecaoAlimento(ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Adicionar Alimento"),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.verde,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }
}

// --- MODAL DE SELEÇÃO DE ALIMENTO ---
class _AlimentoSelectionModal extends StatefulWidget {
  final Function(Alimento) onAlimentoSelected;
  const _AlimentoSelectionModal({required this.onAlimentoSelected});

  @override
  State<_AlimentoSelectionModal> createState() => _AlimentoSelectionModalState();
}

class _AlimentoSelectionModalState extends State<_AlimentoSelectionModal> {
  String _searchText = "";
  List<Alimento> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = TacoDB.list; 
  }

  void _filter(String text) {
    setState(() {
      _searchText = text;
      _filteredList = TacoDB.list.where((ali) => ali.nome.toLowerCase().contains(text.toLowerCase())).toList();
    });
  }

  void _abrirCriacaoPersonalizada() async {
    final Alimento? novo = await Navigator.push(context, MaterialPageRoute(builder: (context) => const _CriarAlimentoScreen()));
    if (novo != null && mounted) {
      widget.onAlimentoSelected(novo); 
      Navigator.pop(context); 
    }
  }

  void _confirmarQtd(Alimento base) {
    final ctrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(base.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantidade (g)', suffixText: 'g', border: OutlineInputBorder()),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              double qtd = double.tryParse(ctrl.text) ?? 100;
              final novo = Alimento(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                nome: base.nome, calorias: base.calorias, proteinas: base.proteinas,
                carboidratos: base.carboidratos, gorduras: base.gorduras,
                quantidade: qtd, unidade: 'g', categoria: base.categoria,
                // Copia os micros também
                fibras: base.fibras, calcio: base.calcio, magnesio: base.magnesio,
                ferro: base.ferro, potassio: base.potassio, vitA: base.vitA, vitC: base.vitC,
              );
              Navigator.pop(ctx); 
              widget.onAlimentoSelected(novo);
              Navigator.pop(context); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, shape: AppStyles.shapeButton),
            child: const Text("Adicionar", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          const Text("Adicionar Alimento", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.verde)),
          const SizedBox(height: 15),
          
          TextField(
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: "Pesquisar (ex: Frango, Arroz...)",
              prefixIcon: const Icon(Icons.search, color: AppColors.verde),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: AppStyles.borderButton, borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 10),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _abrirCriacaoPersonalizada,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Criar Alimento Personalizado"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.verde,
                side: const BorderSide(color: AppColors.verde),
                shape: AppStyles.shapeButton
              ),
            ),
          ),
          
          const Divider(height: 30),
          
          Expanded(
            child: _filteredList.isEmpty
              ? const Center(child: Text("Nenhum alimento encontrado."))
              : ListView.separated(
                  itemCount: _filteredList.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = _filteredList[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text("${item.calorias.toInt()} kcal / 100g", style: TextStyle(color: Colors.grey[600])),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.verde),
                      onTap: () => _confirmarQtd(item),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// --- TELA CRIAR ALIMENTO PERSONALIZADO (ATUALIZADA) ---
class _CriarAlimentoScreen extends StatefulWidget {
  const _CriarAlimentoScreen();
  @override
  State<_CriarAlimentoScreen> createState() => _CriarAlimentoScreenState();
}

class _CriarAlimentoScreenState extends State<_CriarAlimentoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Macros
  final _nomeCtrl = TextEditingController();
  final _caloriasCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _gordCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController(text: "100");

  // Micros (Novos)
  final _fibraCtrl = TextEditingController();
  final _calcioCtrl = TextEditingController();
  final _magnesioCtrl = TextEditingController();
  final _ferroCtrl = TextEditingController();
  final _potassioCtrl = TextEditingController();
  final _vitACtrl = TextEditingController();
  final _vitCCtrl = TextEditingController();

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      final novo = Alimento(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: _nomeCtrl.text,
        categoria: 'Personalizado',
        quantidade: double.tryParse(_qtdCtrl.text) ?? 100,
        unidade: 'g',
        
        // Macros
        calorias: double.tryParse(_caloriasCtrl.text) ?? 0,
        proteinas: double.tryParse(_protCtrl.text) ?? 0,
        carboidratos: double.tryParse(_carbCtrl.text) ?? 0,
        gorduras: double.tryParse(_gordCtrl.text) ?? 0,

        // Micros
        fibras: double.tryParse(_fibraCtrl.text) ?? 0,
        calcio: double.tryParse(_calcioCtrl.text) ?? 0,
        magnesio: double.tryParse(_magnesioCtrl.text) ?? 0,
        ferro: double.tryParse(_ferroCtrl.text) ?? 0,
        potassio: double.tryParse(_potassioCtrl.text) ?? 0,
        vitA: double.tryParse(_vitACtrl.text) ?? 0,
        vitC: double.tryParse(_vitCCtrl.text) ?? 0,
      );
      Navigator.pop(context, novo);
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.verde,
      appBar: AppBar(
        title: const Text("Novo Alimento", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.verde,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      // MUDANÇA AQUI: Usamos Column + Expanded para forçar o branco até o rodapé
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity, // Garante que o branco ocupe a largura toda
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppStyles.borderTopCard,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Informações Básicas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 15),
                      TextFormField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome (ex: Whey)", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Obrigatório" : null),
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _caloriasCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Kcal (100g)", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Obrigatório" : null)),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: _qtdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qtd (g)", border: OutlineInputBorder()))),
                      ]),
                      
                      const SizedBox(height: 25),
                      const Text("Macronutrientes (por 100g)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: _buildInput(_carbCtrl, "Carb (g)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_protCtrl, "Prot (g)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_gordCtrl, "Gord (g)")),
                      ]),

                      const SizedBox(height: 25),
                      const Text("Micronutrientes (por 100g)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 15),
                      
                      // Linha 1: Fibras, Cálcio
                      Row(children: [
                        Expanded(child: _buildInput(_fibraCtrl, "Fibras (g)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_calcioCtrl, "Cálcio (mg)")),
                      ]),
                      const SizedBox(height: 10),
                      
                      // Linha 2: Magnésio, Ferro
                      Row(children: [
                        Expanded(child: _buildInput(_magnesioCtrl, "Magnésio (mg)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_ferroCtrl, "Ferro (mg)")),
                      ]),
                      const SizedBox(height: 10),

                      // Linha 3: Potássio
                      _buildInput(_potassioCtrl, "Potássio (mg)"),
                      const SizedBox(height: 10),

                      // Linha 4: Vitaminas
                      Row(children: [
                        Expanded(child: _buildInput(_vitACtrl, "Vit. A (RAE)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_vitCCtrl, "Vit. C (mg)")),
                      ]),

                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _salvar,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, padding: const EdgeInsets.symmetric(vertical: 16), shape: AppStyles.shapeButton),
                          child: const Text("ADICIONAR AO PLANO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 40), // Espaço extra final
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

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}