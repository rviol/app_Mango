import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/app_styles.dart';
import 'nutricionista_perfil_paciente_screen.dart';


class NutricionistaListaPacientesScreen extends StatefulWidget {
  const NutricionistaListaPacientesScreen({super.key});

  @override
  State<NutricionistaListaPacientesScreen> createState() =>
      _NutricionistaListaPacientesScreenState();
}

class _NutricionistaListaPacientesScreenState
    extends State<NutricionistaListaPacientesScreen> {
  
  final TextEditingController _nomeController = TextEditingController();
  String _filtroBusca = "";

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _navegarParaPerfil(String idPaciente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NutricionistaPerfilPacienteScreen(pacienteId: idPaciente),
      ),
    );
  }

  // Helper para calcular idade
  String _calcularIdade(String? dataNasc) {
    if (dataNasc == null || dataNasc.length < 10) return "--";
    try {
      // Espera formato dd/MM/yyyy
      final partes = dataNasc.split('/');
      if (partes.length != 3) return "--";
      
      final dtNasc = DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
      final hoje = DateTime.now();
      
      int idade = hoje.year - dtNasc.year;
      if (hoje.month < dtNasc.month || (hoje.month == dtNasc.month && hoje.day < dtNasc.day)) {
        idade--;
      }
      return "$idade anos";
    } catch (e) {
      return "--";
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? nutricionistaUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.roxo, // Fundo Roxo
      appBar: AppBar(
        title: const Text(
          "Meus Pacientes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.roxo,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- BARRA DE BUSCA (No fundo roxo) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppStyles.borderButton, // Radius 16
              ),
              child: TextField(
                controller: _nomeController,
                onChanged: (value) => setState(() => _filtroBusca = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Buscar paciente por nome...",
                  prefixIcon: const Icon(Icons.search, color: AppColors.roxo),
                  suffixIcon: _filtroBusca.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => setState(() {
                            _nomeController.clear();
                            _filtroBusca = "";
                          }),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // --- CORPO BRANCO ---
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppStyles.borderTopCard, // Radius 25 top
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: StreamBuilder(
                stream: FirebaseDatabase.instance
                    .ref()
                    .child('usuarios')
                    .orderByChild('nutricionistaId')
                    .equalTo(nutricionistaUid)
                    .onValue,
                builder: (context, snapshot) {
                  // 1. Loading
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.roxo));
                  }

                  // 2. Erro
                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  // 3. Sem Dados
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return _buildEmptyState("Sua lista de pacientes está vazia.");
                  }

                  // 4. Processamento
                  final dadosMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  final List<Map<String, dynamic>> listaFiltrada = [];

                  dadosMap.forEach((key, value) {
                    final usuario = Map<String, dynamic>.from(value);
                    if (usuario['tipo'] == 'paciente') {
                      final nome = (usuario['nome'] ?? '').toString();
                      // Filtro local
                      if (_filtroBusca.isEmpty || nome.toLowerCase().contains(_filtroBusca)) {
                        listaFiltrada.add({
                          'id': key,
                          'nome': nome,
                          'email': usuario['email'] ?? '',
                          'genero': usuario['genero'] ?? '',
                          'dataNascimento': usuario['dataNascimento'] ?? '',
                        });
                      }
                    }
                  });

                  if (listaFiltrada.isEmpty) {
                    return _buildEmptyState("Nenhum paciente encontrado com '$_filtroBusca'.");
                  }

                  // Ordenação alfabética
                  listaFiltrada.sort((a, b) => a['nome'].toString().compareTo(b['nome'].toString()));

                  // 5. Lista Renderizada
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 15, bottom: 20),
                    itemCount: listaFiltrada.length,
                    itemBuilder: (context, index) {
                      return _buildPatientCard(listaFiltrada[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildPatientCard(Map<String, dynamic> paciente) {
    final iniciais = paciente['nome'].isNotEmpty ? paciente['nome'][0].toUpperCase() : '?';
    final idade = _calcularIdade(paciente['dataNascimento']);
    final genero = paciente['genero'] == 'Feminino' 
        ? Icons.female 
        : (paciente['genero'] == 'Masculino' ? Icons.male : Icons.person);
    final corGenero = paciente['genero'] == 'Feminino' ? Colors.pinkAccent : Colors.blueAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderButton, // Radius 16
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppStyles.borderButton,
          onTap: () => _navegarParaPerfil(paciente['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.roxo.withOpacity(0.1),
                  child: Text(
                    iniciais,
                    style: const TextStyle(color: AppColors.roxo, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paciente['nome'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paciente['email'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Chips de info (Idade e Gênero)
                      Row(
                        children: [
                          _buildMiniChip(Icons.cake, idade, Colors.orange),
                          const SizedBox(width: 8),
                          _buildMiniChip(genero, paciente['genero'] ?? 'N/A', corGenero),
                        ],
                      )
                    ],
                  ),
                ),
                // Seta
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 10),
          const Text("Erro ao carregar dados.", style: TextStyle(color: Colors.redAccent)),
          TextButton(
            onPressed: () => setState(() {}),
            child: const Text("Tentar novamente"),
          )
        ],
      ),
    );
  }
}