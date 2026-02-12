import 'refeicao.dart';

class PlanoAlimentar {
  String id;
  String nome; // Ex: "Plano de Hipertrofia", "Fase 1"
  DateTime dataCriacao;
  List<Refeicao> refeicoes;

  PlanoAlimentar({
    required this.id,
    required this.nome,
    required this.dataCriacao,
    required this.refeicoes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'dataCriacao': dataCriacao.toIso8601String(),
      'refeicoes': refeicoes.map((x) => x.toMap()).toList(),
    };
  }

  factory PlanoAlimentar.fromMap(Map<String, dynamic> map) {
    return PlanoAlimentar(
      id: map['id']?.toString() ?? '',
      nome: map['nome'] ?? 'Plano Sem Nome',
      dataCriacao: map['dataCriacao'] != null
          ? DateTime.parse(map['dataCriacao'])
          : DateTime.now(),
      refeicoes: map['refeicoes'] != null
          ? (map['refeicoes'] as List)
              .map((x) => Refeicao.fromMap(Map<String, dynamic>.from(x as Map)))
              .toList()
          : [],
    );
  }
}