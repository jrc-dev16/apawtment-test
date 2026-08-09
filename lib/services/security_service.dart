import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hashes the given password using SHA-256 with a secure static salt.
String hashPassword(String password) {
  const salt = 'apawtment_admin_salt_987234';
  final bytes = utf8.encode(password + salt);
  return sha256.convert(bytes).toString();
}

/// Validates whether a password meets the minimum required length (8 characters).
/// Users have complete freedom to use any combination of uppercase, lowercase,
/// digits, special characters, or symbols in any position.
bool isPasswordStrong(String password) {
  return password.length >= 8;
}

/// Checks if the given string is a valid SHA-256 hash.
bool isSha256(String value) {
  return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value);
}
