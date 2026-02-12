import 'package:firebase_database/firebase_database.dart';
import '../classes/paciente.dart';

class PacienteRepository {
  // Instância do banco de dados Firebase
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ---------------------------------------------------------------------------
  // Busca um paciente específico pelo ID (UID do Firebase Auth)
  // ---------------------------------------------------------------------------
  Future<Paciente?> buscarPorId(String id) async {
    try {
      // Referência ao nó do usuário específico
      final ref = _db.ref('usuarios/$id');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        // Converte o retorno do Firebase (Object?) para um Map utilizável
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Garante que o ID do objeto seja o mesmo da chave do nó
        data['id'] = id; 
        
        // Converte o Map para o objeto Paciente usando o factory
        return Paciente.fromMap(data);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar paciente: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Lista todos os usuários cadastrados que são do tipo "Paciente"
  // ---------------------------------------------------------------------------
  Future<List<Paciente>> listar() async {
    try {
      final ref = _db.ref('usuarios');
      
      // Realiza a consulta filtrando pelo campo 'tipo'
      // Importante: No Firebase Realtime Database, para usar orderByChild,
      // pode ser necessário criar um índice nas regras do banco (firebase.json)
      final snapshot = await ref.orderByChild('tipo').equalTo('Paciente').get();

      if (snapshot.exists && snapshot.value != null) {
        // O snapshot.value retorna um Map onde as chaves são os UIDs
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        // Mapeia cada entrada desse Map para um objeto Paciente
        return data.entries.map((e) {
          final map = Map<String, dynamic>.from(e.value as Map);
          map['id'] = e.key; // Define o ID com a chave do registro
          return Paciente.fromMap(map);
        }).toList();
      }
      return [];
    } catch (e) {
      print("Erro ao listar pacientes: $e");
      return [];
    }
  }
  
  // ---------------------------------------------------------------------------
  // Atualiza os dados do paciente no Firebase
  // Isso serve para salvar o Plano Alimentar, Antropometria ou dados cadastrais.
  // O método .update() faz um merge dos campos, mas como passamos o toMap()
  // completo, ele atualizará as listas (refeições) conforme o estado atual do objeto.
  // ---------------------------------------------------------------------------
  Future<void> atualizar(Paciente paciente) async {
    if (paciente.id == null) {
      print("Erro: Tentativa de atualizar paciente sem ID.");
      return;
    }
    
    try {
      // paciente.toMap() já deve retornar a estrutura correta (Listas e Maps)
      // para o Firebase, sem precisar converter para JSON String manualmente.
      await _db.ref('usuarios/${paciente.id}').update(paciente.toMap());
    } catch (e) {
      print("Erro ao atualizar paciente: $e");
      rethrow; // Relança o erro para que a tela possa exibir um aviso se necessário
    }
  }
}