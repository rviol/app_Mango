// Classe base para todos os usuários do sistema
class Usuario {
  String? id; // ALTERADO: De int? para String? (Firebase UID)
  String nome;
  String email;
  String senha;
  String codigo;
  String dataNascimento;
  String genero;

  Usuario({
    this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.codigo,
    required this.dataNascimento,
    required this.genero,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'senha': senha,
      'codigo': codigo,
      'dataNascimento': dataNascimento,
      'genero': genero,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id']?.toString(), // Garante conversão segura
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      codigo: map['codigo'] ?? '',
      dataNascimento: map['dataNascimento'] ?? '',
      genero: map['genero'] ?? '',
    );
  }
}