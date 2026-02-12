import 'package:firebase_database/firebase_database.dart';
import '../classes/plano_alimentar.dart';

class PlanoAlimentarRepository {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Caminho: planos_alimentares/{pacienteId}/{planoId}

  Future<void> salvarPlano(String pacienteId, PlanoAlimentar plano) async {
    try {
      print("DEBUG: Salvando plano ${plano.id} para paciente $pacienteId");
      await _db
          .ref('planos_alimentares/$pacienteId/${plano.id}')
          .set(plano.toMap());
    } catch (e) {
      print("DEBUG: Erro ao salvar plano: $e");
      throw Exception("Erro ao salvar plano: $e");
    }
  }

  Future<void> excluirPlano(String pacienteId, String planoId) async {
    await _db.ref('planos_alimentares/$pacienteId/$planoId').remove();
  }

  Future<List<PlanoAlimentar>> listarPlanos(String pacienteId) async {
    try {
      print("DEBUG: Buscando planos em 'planos_alimentares/$pacienteId'...");
      final snapshot = await _db.ref('planos_alimentares/$pacienteId').get();

      if (snapshot.exists && snapshot.value != null) {
        print("DEBUG: Dados encontrados! Processando...");
        final data = snapshot.value;
        
        List<PlanoAlimentar> planos = [];

        // Verifica se veio como Lista (List) ou Mapa (Map)
        if (data is List) {
           // Caso raro no Firebase Realtime DB, mas possível se chaves forem inteiros sequenciais
           for (var item in data) {
             if (item != null) {
               planos.add(PlanoAlimentar.fromMap(Map<String, dynamic>.from(item)));
             }
           }
        } else if (data is Map) {
           // Padrão mais comum
           data.forEach((key, value) {
            final map = Map<String, dynamic>.from(value as Map);
            map['id'] = key;
            planos.add(PlanoAlimentar.fromMap(map));
          });
        }

        // Ordena por data (mais recente primeiro)
        planos.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
        
        print("DEBUG: ${planos.length} planos carregados.");
        return planos;
      }
      
      print("DEBUG: Nenhum plano encontrado nesse caminho.");
      return [];
    } catch (e) {
      print("DEBUG: Erro crítico ao listar planos: $e");
      return [];
    }
  }
}