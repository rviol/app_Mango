import 'package:firebase_database/firebase_database.dart';
import '../classes/nutricionista.dart';

class NutricionistaRepository {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Busca os dados do nutricionista pelo ID (UID do Firebase)
  Future<Nutricionista?> buscarPorId(String id) async {
    try {
      final ref = _db.ref('usuarios/$id');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        // Converte o retorno do Firebase para Map<String, dynamic>
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data['id'] = id; // Garante que o ID esteja no mapa

        // Verifica se o usuário tem perfil de nutricionista (opcional, mas recomendado)
        // Você pode remover a verificação de 'crn' se nem todos tiverem preenchido ainda
        return Nutricionista.fromMap(data);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar nutricionista: $e");
      return null;
    }
  }

  /// Atualiza os dados do nutricionista (incluindo a lista de pacientes vinculados)
  Future<void> atualizar(Nutricionista nutricionista) async {
    if (nutricionista.id == null) return;

    try {
      // O método toMap() da classe Nutricionista já deve lidar com a lista de IDs
      await _db.ref('usuarios/${nutricionista.id}').update(nutricionista.toMap());
    } catch (e) {
      print("Erro ao atualizar nutricionista: $e");
      rethrow;
    }
  }

  Future<Nutricionista?> buscarPorCRN(String crn) async {
    try {
      final ref = _db.ref('usuarios');
      // Filtra os usuários procurando onde o campo 'crn' é igual ao valor passado
      final snapshot = await ref.orderByChild('crn').equalTo(crn).get();

      if (snapshot.exists && snapshot.value != null) {
        // O Firebase retorna um Map onde a chave é o ID do usuário (ex: { "uid123": { ...dados... } })
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        // Pegamos o primeiro resultado encontrado
        final key = data.keys.first;
        final map = Map<String, dynamic>.from(data[key]);
        map['id'] = key; // Injeta o ID no mapa

        return Nutricionista.fromMap(map);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar nutricionista por CRN: $e");
      return null;
    }
  }
}