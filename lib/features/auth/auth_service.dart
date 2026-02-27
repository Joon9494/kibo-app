// =====================================================
// 📁 lib/features/auth/auth_service.dart
// 역할: 구글 로그인 / 로그아웃 로직
//       로그인 성공 시 Firestore에 사용자 정보 자동 저장
// =====================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signInWithGoogle() async {
    // 구글 로그인 팝업
    final googleUser = await GoogleSignIn(
      scopes: [
        'email',
        'https://www.googleapis.com/auth/calendar',
      ],
    ).signIn();    if (googleUser == null) return null; // 취소

    // 인증 토큰 받기
    final googleAuth = await googleUser.authentication;

    // Firebase 자격증명 생성
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Firebase 로그인
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return null;

    // Firestore에 사용자 문서 생성/업데이트
    // merge: true = 기존 데이터 유지하면서 새 값만 업데이트
    await _db.collection('users').doc(user.uid).set(
      {
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'wakeWord': '키보야',  // 기본 호출명
        'lensQuota': 1,       // 기본 렌즈 1개
        'role': 'user',
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return user;
  }

  // 로그아웃 — 구글 + Firebase 양쪽 모두
  Future<void> signOut() async {
    await GoogleSignIn(
      scopes: [
        'email',
        'https://www.googleapis.com/auth/calendar',
      ],
    ).signOut();
    await _auth.signOut();
  }

  // 현재 로그인된 사용자 (없으면 null)
  User? get currentUser => _auth.currentUser;
}