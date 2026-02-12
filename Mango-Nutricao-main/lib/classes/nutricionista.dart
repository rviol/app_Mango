import 'dart:convert';
import 'usuario.dart';

class Nutricionista extends Usuario {
  String crn;
  List<String> pacientesIds; // IDs agora são Strings

  Nutricionista({
    super.id, 
    required super.dataNascimento,
    required super.nome,
    required super.email,
    required super.senha,
    required super.codigo,
    required super.genero,
    required this.crn,
    List<String>? pacientesIds,
  }) : pacientesIds = pacientesIds ?? [];

  factory Nutricionista.fromUsuario(Usuario usuario, {required String crn}) {
    return Nutricionista(
      id: usuario.id,
      nome: usuario.nome,
      dataNascimento: usuario.dataNascimento,
      email: usuario.email,
      senha: usuario.senha,
      codigo: usuario.codigo,
      genero: usuario.genero,
      crn: crn,
      pacientesIds: [],
    );
  }

  void adicionarPaciente(String pacienteId) {
    if (!pacientesIds.contains(pacienteId)) {
      pacientesIds.add(pacienteId);
    }
  }

  void removerPaciente(String pacienteId) {
    pacientesIds.remove(pacienteId);
  }

  factory Nutricionista.fromMap(Map<String, dynamic> map) {
    List<String> listaIds = [];
    var rawIds = map['pacientesIds'];

    if (rawIds != null) {
      if (rawIds is String && rawIds.isNotEmpty) {
        // Se vier como JSON string do banco
        try {
          listaIds = List<String>.from(jsonDecode(rawIds));
        } catch (_) {}
      } else if (rawIds is List) {
        // Se vier como Lista direta do Firebase
        listaIds = List<String>.from(rawIds.map((e) => e.toString()));
      }
    }

    return Nutricionista(
      id: map['id']?.toString(),
      nome: map['nome'] ?? '',
      dataNascimento: map['dataNascimento'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      codigo: map['codigo'] ?? '',
      genero: map['genero'] ?? '',
      crn: map['crn'] ?? '',
      pacientesIds: listaIds,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['crn'] = crn;
    // Salva como Lista direta no Firebase (mais fácil de ler no console)
    // Se preferir salvar como string JSON, use: jsonEncode(pacientesIds)
    map['pacientesIds'] = pacientesIds; 
    return map;
  }
}