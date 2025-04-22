import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

class AuthService {
  static const String _userKey = 'current_user';
  static const String _usersKey = 'registered_users';
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'ai_assistant.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            password TEXT,
            name TEXT
          )
        ''');
      },
    );
  }

  Future<void> registerUser(User user) async {
    print('Registering user: ${user.email}');
    
    if (kIsWeb) {
      // For web, fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      
      for (var userJson in usersJson) {
        final existingUser = User.fromJson(jsonDecode(userJson));
        if (existingUser.email == user.email) {
          print('User already exists: ${user.email}');
          throw Exception('User with this email already exists');
        }
      }

      final userJson = jsonEncode(user.toJson());
      usersJson.add(userJson);
      await prefs.setStringList(_usersKey, usersJson);
      await prefs.setString(_userKey, userJson);
      print('User registered successfully on web');
    } else {
      // Mobile platform using SQLite
      final db = await database;
      try {
        await db.insert(
          'users',
          user.toJson(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
        print('User registered successfully on mobile');
      } catch (e) {
        print('Error registering user: $e');
        throw Exception('User with this email already exists');
      }
    }
  }

  Future<User?> loginUser(String email, String password) async {
    print('Attempting login for: $email');
    
    if (kIsWeb) {
      // For web, fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      
      for (var userJson in usersJson) {
        final user = User.fromJson(jsonDecode(userJson));
        if (user.email == email && user.password == password) {
          await prefs.setString(_userKey, userJson);
          print('Login successful for: $email');
          return user;
        }
      }
    } else {
      // Mobile platform using SQLite
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (maps.isNotEmpty) {
        final user = User.fromJson(maps.first);
        print('Login successful for: $email');
        return user;
      }
    }
    
    print('Login failed for: $email');
    throw Exception('Invalid email or password');
  }

  Future<void> logout() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    }
    print('User logged out');
  }

  Future<User?> getCurrentUser() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        print('Current user found on web: $userJson');
        return User.fromJson(jsonDecode(userJson));
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final user = User.fromJson(jsonDecode(userJson));
        // Verify user still exists in SQLite
        final db = await database;
        final List<Map<String, dynamic>> maps = await db.query(
          'users',
          where: 'email = ?',
          whereArgs: [user.email],
        );
        if (maps.isNotEmpty) {
          print('Current user found on mobile: $userJson');
          return user;
        }
      }
    }
    print('No current user found');
    return null;
  }

  Future<bool> isLoggedIn() async {
    final currentUser = await getCurrentUser();
    final isLoggedIn = currentUser != null;
    print('Is logged in: $isLoggedIn');
    return isLoggedIn;
  }

  Future<void> printRegisteredUsers() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      print('=== Registered Users (Web) ===');
      print('Total users: ${usersJson.length}');
      for (var userJson in usersJson) {
        print('User: $userJson');
      }
    } else {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('users');
      print('=== Registered Users (Mobile) ===');
      print('Total users: ${maps.length}');
      for (var user in maps) {
        print('User: ${jsonEncode(user)}');
      }
    }
    print('=======================');
  }

  Future<void> clearAllData() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_usersKey);
    } else {
      final db = await database;
      await db.delete('users');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    }
    print('All user data cleared');
  }
} 