import 'dart:async';
import 'dart:convert';
import 'package:client_user/app/home/models/customer.dart';
import 'package:http/http.dart' as http;

import 'package:client_user/constants/urls.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthFlowStatus { googleSignIn, register, session }

class AuthState {
  final AuthFlowStatus authFlowStatus;
  AuthState({required this.authFlowStatus});
}

class AuthService {
  AuthService({required this.firebaseAuth}) {
    setGoogleSignIn();
  }
  final FirebaseAuth firebaseAuth;
  final authStateController = StreamController<AuthState>();
  User? user;

  void signInWithGoogle() async {
    try {
      var googleCurrentUser = GoogleSignIn().currentUser;
      googleCurrentUser ??= await GoogleSignIn().signIn();
      final googleAuth = await googleCurrentUser?.authentication;
      final authCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken, idToken: googleAuth?.idToken);
      final user =
          (await firebaseAuth.signInWithCredential(authCredential)).user;
      if (user == null) {
        setGoogleSignIn();
      } else {
        this.user = user;
        if (await customerExists()) {
          setSession();
        } else {
          setRegister();
        }
      }
    } catch (e) {
      setGoogleSignIn();
    }
  }

  void signOut() async {
    await GoogleSignIn().signOut();
    setGoogleSignIn();
  }

  Future<bool> customerExists() async {
    final user = firebaseAuth.currentUser!;
    final url = URLs.baseURL + "/user";
    final idToken = await user.getIdToken();
    final header = {"Authorization": "Bearer " + idToken};
    final response = await http.get(Uri.parse(url), headers: header);
    if (response.statusCode != 200) {
      return false;
    }
    return true;
  }

  void register(String name) async {
    final url = URLs.baseURL + "/user";
    final idToken = await firebaseAuth.currentUser!.getIdToken();
    final header = {"Authorization": "Bearer " + idToken};
    final body = Customer(name: name).toJson();
    final response = await http.post(Uri.parse(url),
        headers: header, body: jsonEncode(body));
    if (response.statusCode != 200) {
      setRegister();
    } else {
      setSession();
    }
  }

  void setGoogleSignIn() {
    final state = AuthState(authFlowStatus: AuthFlowStatus.googleSignIn);
    authStateController.add(state);
  }

  void setRegister() {
    final state = AuthState(authFlowStatus: AuthFlowStatus.register);
    authStateController.add(state);
  }

  void setSession() {
    final state = AuthState(authFlowStatus: AuthFlowStatus.session);
    authStateController.add(state);
  }
}
