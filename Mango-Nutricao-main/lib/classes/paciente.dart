import 'dart:convert';
import 'usuario.dart';
import 'refeicao.dart';
import 'antropometria.dart';

class Paciente extends Usuario {
  String? nutricionistaId;
  List<Refeicao> refeicoes;
  Antropometria? antropometria;

  Paciente({
    super.id, // ID agora é String (UID do Firebase)
    required super.nome,
    required super.email,
    required super.senha,
    required super.codigo,
    required super.dataNascimento,
    required super.genero,
    this.nutricionistaId,
    this.refeicoes = const [],
    this.antropometria,
  });

  // Cria um Paciente a partir de um objeto Usuario genérico (ex: no cadastro)
  factory Paciente.fromUsuario(
    Usuario usuario, {
    required String nutricionistaId,
  }) {
    return Paciente(
      id: usuario.id,
      nome: usuario.nome,
      email: usuario.email,
      senha: usuario.senha,
      codigo: usuario.codigo,
      genero: usuario.genero,
      nutricionistaId: nutricionistaId,
      refeicoes: [],
      dataNascimento: usuario.dataNascimento,
      antropometria: null,
    );
  }

  // Converte dados vindos do Firebase (Map) para o objeto Paciente
  factory Paciente.fromMap(Map<String, dynamic> map) {
    List<Refeicao> listaDecodificada = [];

    // Lógica para ler a lista de refeições do Firebase
    if (map['refeicoes'] != null) {
      try {
        // Firebase retorna listas como List<Object?>, então fazemos o cast seguro
        final rawList = map['refeicoes'] as List;
        
        listaDecodificada = rawList.map((item) {
          // Garante que o item seja tratado como Map<Object?, Object?> ou Map<String, dynamic>
          if (item is Map) {
            return Refeicao.fromMap(Map<Object?, Object?>.from(item));
          }
          // Caso venha algo inesperado, tenta converter
          return Refeicao.fromMap(item as Map<Object?, Object?>);
        }).toList();
        
      } catch (e) {
        print("Erro ao decodificar refeições do paciente: $e");
      }
    }

    // Lógica para ler antropometria (compatível com JSON antigo ou Map direto do Firebase)
    Antropometria? dadosAntropometria;
    if (map['antropometria'] != null) {
      try {
        var rawDados = map['antropometria'];
        
        // Se vier como String (JSON legado), decodifica. Se for Map (Firebase), usa direto.
        final decoded = (rawDados is String) ? jsonDecode(rawDados) : rawDados;
        
        if (decoded is Map) {
          dadosAntropometria = Antropometria.fromMap(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        print("Erro ao ler dados corporais: $e");
      }
    }

    return Paciente(
      id: map['id']?.toString(), 
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      codigo: map['codigo'] ?? '',
      genero: map['genero'] ?? '',
      nutricionistaId: map['nutricionistaId'] ?? '',
      refeicoes: listaDecodificada,
      dataNascimento: map['dataNascimento'] ?? '',
      antropometria: dadosAntropometria,
    );
  }

  // Prepara o objeto para ser salvo no Firebase
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['nutricionistaId'] = nutricionistaId;
    
    // Converte a lista de objetos Refeicao para lista de Maps
    map['refeicoes'] = refeicoes.map((e) => e.toMap()).toList();
    
    // Converte o objeto Antropometria para Map (se existir)
    map['antropometria'] = antropometria?.toMap();
    
    return map;
  }

  // Getter auxiliar para calcular idade
  int get idade {
    if (dataNascimento.isEmpty) return 0;
    try {
      DateTime nascimento;

      // Suporta formato BR (dd/MM/yyyy) e ISO (yyyy-MM-dd)
      if (dataNascimento.contains('/')) {
        List<String> partes = dataNascimento.split('/');
        nascimento = DateTime(
          int.parse(partes[2]),
          int.parse(partes[1]),
          int.parse(partes[0]),
        );
      } else {
        nascimento = DateTime.parse(dataNascimento);
      }

      DateTime hoje = DateTime.now();
      int idade = hoje.year - nascimento.year;

      if (hoje.month < nascimento.month ||
          (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
        idade--;
      }
      return idade;
    } catch (e) {
      print("Erro ao calcular idade: $e");
      return 0;
    }
  }
}