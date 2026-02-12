class Antropometria {
  String? id_avaliacao;

  double? massaCorporal;
  double? massaGordura;
  double? percentualGordura;
  double? massaMuscular; // [NOVO]
  double? massaEsqueletica;
  double? imc;
  double? cmb;
  double? relacaoCinturaQuadril;
  
  String? classMassaCorporal;
  String? classMassaGordura;
  String? classPercentualGordura;
  String? classMassaMuscular; // [NOVO]
  String? classMassaEsqueletica;
  String? classImc;
  String? classCmb;
  String? classRcq;

  String? observacoes;
  DateTime? data;

  Antropometria({
    this.id_avaliacao,
    this.massaCorporal,
    this.massaGordura,
    this.percentualGordura,
    this.massaMuscular,
    this.massaEsqueletica,
    this.imc,
    this.cmb,
    this.relacaoCinturaQuadril,
    this.classMassaCorporal,
    this.classMassaGordura,
    this.classPercentualGordura,
    this.classMassaMuscular,
    this.classMassaEsqueletica,
    this.classImc,
    this.classCmb,
    this.classRcq,
    this.observacoes,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_avaliacao': id_avaliacao,
      'massaCorporal': massaCorporal,
      'massaGordura': massaGordura,
      'percentualGordura': percentualGordura,
      'massaMuscular': massaMuscular,
      'massaEsqueletica': massaEsqueletica,
      'imc': imc,
      'cmb': cmb,
      'relacaoCinturaQuadril': relacaoCinturaQuadril,
      'classMassaCorporal': classMassaCorporal,
      'classMassaGordura': classMassaGordura,
      'classPercentualGordura': classPercentualGordura,
      'classMassaMuscular': classMassaMuscular,
      'classMassaEsqueletica': classMassaEsqueletica,
      'classImc': classImc,
      'classCmb': classCmb,
      'classRcq': classRcq,
      'observacoes': observacoes,
      'data': data?.toIso8601String(),
    };
  }

  factory Antropometria.fromMap(Map<String, dynamic> map) {
    return Antropometria(
      id_avaliacao: map['id_avaliacao'],
      massaCorporal: (map['massaCorporal'] as num?)?.toDouble(),
      massaGordura: (map['massaGordura'] as num?)?.toDouble(),
      percentualGordura: (map['percentualGordura'] as num?)?.toDouble(),
      massaMuscular: (map['massaMuscular'] as num?)?.toDouble(),
      massaEsqueletica: (map['massaEsqueletica'] as num?)?.toDouble(),
      imc: (map['imc'] as num?)?.toDouble(),
      cmb: (map['cmb'] as num?)?.toDouble(),
      relacaoCinturaQuadril: (map['relacaoCinturaQuadril'] as num?)?.toDouble(),
      classMassaCorporal: map['classMassaCorporal'],
      classMassaGordura: map['classMassaGordura'],
      classPercentualGordura: map['classPercentualGordura'],
      classMassaMuscular: map['classMassaMuscular'],
      classMassaEsqueletica: map['classMassaEsqueletica'],
      classImc: map['classImc'],
      classCmb: map['classCmb'],
      classRcq: map['classRcq'],
      observacoes: map['observacoes'] as String?,
      data: map['data'] != null ? DateTime.parse(map['data']) : null,
    );
  }
}