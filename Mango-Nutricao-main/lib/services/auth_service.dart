import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  User? usuario;
  Map<dynamic, dynamic>? _dadosUsuario;

  bool _estaCarregando = true; 
  bool get estaCarregando => _estaCarregando;
  Map<dynamic, dynamic>? get dadosUsuario => _dadosUsuario;

  AuthService() {
    // Mantém os dados sincronizados localmente (Cache)
    _db.ref('usuarios').keepSynced(true);
    _monitorarEstado();
  }

  // Monitora se o usuário está logado ou não
  void _monitorarEstado() {
    _auth.authStateChanges().listen((User? user) async {
      _estaCarregando = true;
      notifyListeners();

      usuario = user;

      if (usuario != null) {
        // TIMER DE SEGURANÇA: Se o banco não responder em 8 segundos, 
        // destrava a tela de qualquer jeito para o app não ficar "infinito"
        Future.delayed(const Duration(seconds: 8), () {
          if (_estaCarregando) {
            _estaCarregando = false;
            notifyListeners();
            debugPrint("Timeout atingido: Destravando tela de carregamento.");
          }
        });

        await carregarDadosUsuario();
      } else {
        _dadosUsuario = null;
      }

      _estaCarregando = false;
      notifyListeners();
    });
  }

  // Busca Nome, Tipo, Gênero, Data de Nasc e CRN no Realtime Database
  Future<void> carregarDadosUsuario() async {
    if (usuario == null) return;
    try {
      final snapshot = await _db.ref('usuarios/${usuario!.uid}').get();
      if (snapshot.exists) {
        _dadosUsuario = snapshot.value as Map<dynamic, dynamic>;
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados do banco: $e");
    } finally {
      _estaCarregando = false;
      notifyListeners();
    }
  }

  // --- MÉTODOS DE AÇÃO ---

  // Login
  Future<void> login(String email, String senha) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: senha);
    } on FirebaseAuthException catch (e) {
      throw _tratarErro(e.code);
    }
  }

  // Registro Completo (Auth + Database) - ATUALIZADO COM GÊNERO E DATA DE NASCIMENTO
  Future<void> registrar(
    String email, 
    String senha, 
    String nome, 
    String tipo, 
    String? crn, 
    String genero,
    String dataNascimento, // <--- Novo parâmetro adicionado
  ) async {
    try {
      // 1. Cria o usuário no Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      // 2. Salva os dados no Realtime Database
      if (userCredential.user != null) {
        await _db.ref('usuarios/${userCredential.user!.uid}').set({
          'nome': nome,
          'tipo': tipo,
          'crn': crn, 
          'genero': genero,
          'dataNascimento': dataNascimento,
          'email': email,
          'uid': userCredential.user!.uid,
          'dataCriacao': ServerValue.timestamp, // Boa prática: salvar quando a conta foi criada
        });
        
        // 3. Envia e-mail de verificação
        await userCredential.user!.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _tratarErro(e.code);
    }
  }

  // Recuperar Senha
  Future<void> recuperarSenha(String email) async {
    try {
      await _auth.setLanguageCode("pt-BR");
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _tratarErro(e.code);
    }
  }

  // Verificação de E-mail
  Future<bool> checarEmailVerificado() async {
    await usuario?.reload();
    usuario = _auth.currentUser;
    if (usuario?.emailVerified ?? false) {
      await carregarDadosUsuario();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> reenviarEmailVerificacao() async {
    await usuario?.sendEmailVerification();
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    _dadosUsuario = null;
    _estaCarregando = false;
    notifyListeners();
  }

  // Tratamento de erros amigável
  String _tratarErro(String codigo) {
    switch (codigo) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'weak-password':
        return 'A senha é muito fraca (mínimo 6 caracteres).';
      case 'invalid-email':
        return 'O e-mail digitado é inválido.';
      case 'user-disabled':
        return 'Este usuário foi desativado.';
      default:
        return 'Ocorreu um erro inesperado ($codigo). Tente novamente.';
    }
  }
}