import 'package:firebase_database/firebase_database.dart';
import '../classes/antropometria.dart';

class AntropometriaRepository {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Salva ou Atualiza uma avaliação
  Future<void> salvarAvaliacao(String pacienteUid, Antropometria dados) async {
    try {
      // Se não tiver ID, gera um novo via timestamp
      // (Isso garante que o ID seja criado antes de salvar)
      if (dados.id_avaliacao == null || dados.id_avaliacao!.isEmpty) {
        dados.id_avaliacao = DateTime.now().millisecondsSinceEpoch.toString();
      }

      // Caminho: antropometria -> UID do Paciente -> ID da Avaliação
      DatabaseReference ref = _db.ref('antropometria/$pacienteUid/${dados.id_avaliacao}');
      
      await ref.set(dados.toMap());
      print("Avaliação ${dados.id_avaliacao} salva para o paciente $pacienteUid.");
      
    } catch (e) {
      print("Erro ao salvar avaliação: $e");
      rethrow;
    }
  }

  // Busca histórico do Firebase
  Future<List<Antropometria>> buscarHistorico(String pacienteUid) async {
    try {
      DatabaseReference ref = _db.ref('antropometria/$pacienteUid');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        List<Antropometria> lista = [];
        data.forEach((key, value) {
          if (value is Map) {
            final mapConvertido = Map<String, dynamic>.from(value as Map);
            // Garante que o ID da chave do banco esteja no objeto
            mapConvertido['id_avaliacao'] = key; 
            lista.add(Antropometria.fromMap(mapConvertido));
          }
        });
        
        // Ordena por data (mais recente primeiro)
        lista.sort((a, b) => (b.data ?? DateTime(2000)).compareTo(a.data ?? DateTime(2000)));
        return lista;
      }
      return [];
    } catch (e) {
      print("Erro ao buscar histórico: $e");
      return [];
    }
  }

  Future<Antropometria?> buscarUltimaAvaliacao(String pacienteUid) async {
    final lista = await buscarHistorico(pacienteUid);
    if (lista.isNotEmpty) {
      return lista.first;
    }
    return null;
  }

  // --- MÉTODO ADICIONADO PARA CORRIGIR O ERRO ---
  Future<void> excluirAvaliacao(String pacienteUid, String idAvaliacao) async {
    try {
      await _db.ref('antropometria/$pacienteUid/$idAvaliacao').remove();
      print("Avaliação $idAvaliacao excluída com sucesso.");
    } catch (e) {
      print("Erro ao excluir avaliação: $e");
      rethrow;
    }
  }
}