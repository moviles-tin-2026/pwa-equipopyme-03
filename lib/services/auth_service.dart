/// Contrato de API esperado por los screens — implementar en el equipo backend.
library;

class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

abstract class AuthService {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;

  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> registerWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
}
