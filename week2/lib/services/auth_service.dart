import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../config.dart';

/// Universal Auth Service
/// - Web: Dùng REST API
/// - Android/Desktop: Dùng MongoDB trực tiếp
class AuthService {
  final String apiUrl;
  final String mongoUri;
  
  late final Db _db;
  late final DbCollection _users;
  final _uuid = Uuid();
  final StreamController<UserModel?> _authController = StreamController.broadcast();
  UserModel? _currentUser;
  bool _isInitialized = false;

  AuthService({
    String? apiUrl,
    String? mongoUri,
  }) : apiUrl = apiUrl ?? AppConfig.getApiUrl(),
       mongoUri = mongoUri ?? AppConfig.getMongoUri();

  Future<void> init() async {
    if (_isInitialized) return;
    
    if (kIsWeb) {
      // Web: Kiểm tra API
      print('🌐 Running on WEB - Using REST API');
      try {
        final response = await http.get(Uri.parse('$apiUrl/health')).timeout(
          Duration(seconds: 5),
          onTimeout: () => throw 'API timeout',
        );
        if (response.statusCode == 200) {
          print('✅ API Backend connected!');
          _isInitialized = true;
        } else {
          throw 'API not responding';
        }
      } catch (e) {
        print('❌ Cannot connect to API: $e');
        print('⚠️ Make sure backend is running: node server.js');
        throw 'Backend API không hoạt động. Vui lòng chạy: node server.js';
      }
    } else {
      // Mobile/Desktop: Kết nối MongoDB trực tiếp
      print('📱 Running on MOBILE/DESKTOP - Direct MongoDB');
      try {
        _db = Db(mongoUri);
        await _db.open();
        _users = _db.collection('users');
        
        // Tạo index
        try {
          await _users.createIndex(
            keys: {'email': 1},
            unique: true,
            name: 'email_unique_index',
          );
        } catch (_) {}
        
        print('✅ MongoDB connected directly!');
        _isInitialized = true;
      } catch (e) {
        print('❌ Cannot connect to MongoDB: $e');
        throw 'Không thể kết nối MongoDB: $e';
      }
    }
  }

  Future<void> dispose() async {
    await _authController.close();
    if (!kIsWeb && _isInitialized) {
      await _db.close();
    }
  }

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _authController.stream;

  // ============= REGISTER =============
  Future<UserModel?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (!_isInitialized) await init();
    
    if (kIsWeb) {
      return _registerViaAPI(email, password, displayName);
    } else {
      return _registerViaMongo(email, password, displayName);
    }
  }

  Future<UserModel?> _registerViaAPI(String email, String password, String displayName) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'displayName': displayName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromMap(data['user']);
        
        _currentUser = user;
        _authController.add(_currentUser);
        
        print('✅ Đăng ký thành công (API): $email');
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? 'Lỗi đăng ký';
      }
    } catch (e) {
      print('❌ Lỗi đăng ký (API): $e');
      rethrow;
    }
  }

  Future<UserModel?> _registerViaMongo(String email, String password, String displayName) async {
    try {
      final existing = await _users.findOne(where.eq('email', email.toLowerCase()));
      if (existing != null) {
        throw 'Email đã được sử dụng';
      }

      final uid = _uuid.v4();
      final user = UserModel(
        uid: uid,
        email: email.toLowerCase(),
        displayName: displayName,
        createdAt: DateTime.now(),
      );

      final doc = user.toMap();
      doc['password'] = password;

      await _users.insertOne(doc);
      
      _currentUser = user;
      _authController.add(_currentUser);
      
      print('✅ Đăng ký thành công (MongoDB): $email');
      return user;
      
    } catch (e) {
      print('❌ Lỗi đăng ký (MongoDB): $e');
      rethrow;
    }
  }

  // ============= LOGIN =============
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) await init();
    
    if (kIsWeb) {
      return _loginViaAPI(email, password);
    } else {
      return _loginViaMongo(email, password);
    }
  }

  Future<UserModel?> _loginViaAPI(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromMap(data['user']);
        
        _currentUser = user;
        _authController.add(_currentUser);
        
        print('✅ Đăng nhập thành công (API): $email');
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? 'Email hoặc mật khẩu không đúng';
      }
    } catch (e) {
      print('❌ Lỗi đăng nhập (API): $e');
      rethrow;
    }
  }

  Future<UserModel?> _loginViaMongo(String email, String password) async {
    try {
      final doc = await _users.findOne(
        where.eq('email', email.toLowerCase()).eq('password', password)
      );
      
      if (doc == null) {
        throw 'Email hoặc mật khẩu không đúng';
      }
      
      final user = UserModel.fromMap(Map<String, dynamic>.from(doc));
      
      _currentUser = user;
      _authController.add(_currentUser);
      
      print('✅ Đăng nhập thành công (MongoDB): $email');
      return user;
      
    } catch (e) {
      print('❌ Lỗi đăng nhập (MongoDB): $e');
      rethrow;
    }
  }

  // ============= LOGOUT =============
  Future<void> logout() async {
    _currentUser = null;
    _authController.add(null);
    print('✅ Đã đăng xuất');
  }

  // ============= GET USER DATA =============
  Future<UserModel?> getUserData(String uid) async {
    if (!_isInitialized) await init();
    
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$apiUrl/users/$uid'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return UserModel.fromMap(data);
        }
        return null;
      } catch (e) {
        print('❌ Lỗi lấy user (API): $e');
        return null;
      }
    } else {
      try {
        final doc = await _users.findOne(where.eq('uid', uid));
        if (doc == null) return null;
        return UserModel.fromMap(Map<String, dynamic>.from(doc));
      } catch (e) {
        print('❌ Lỗi lấy user (MongoDB): $e');
        return null;
      }
    }
  }

  // ============= CHANGE PASSWORD =============
  Future<bool> changePassword({
    required String uid,
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!_isInitialized) await init();
    
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$apiUrl/users/$uid/change-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'oldPassword': oldPassword,
            'newPassword': newPassword,
          }),
        );
        return response.statusCode == 200;
      } catch (e) {
        print('❌ Lỗi đổi mật khẩu (API): $e');
        return false;
      }
    } else {
      try {
        final user = await _users.findOne(
          where.eq('uid', uid).eq('password', oldPassword)
        );
        
        if (user == null) {
          throw 'Mật khẩu cũ không đúng';
        }

        await _users.updateOne(
          where.eq('uid', uid),
          modify.set('password', newPassword),
        );

        print('✅ Đổi mật khẩu thành công (MongoDB)');
        return true;
      } catch (e) {
        print('❌ Lỗi đổi mật khẩu (MongoDB): $e');
        return false;
      }
    }
  }

  // ============= UPDATE PROFILE =============
  Future<bool> updateUserProfile({
    required String uid,
    String? displayName,
  }) async {
    if (!_isInitialized) await init();
    
    if (kIsWeb) {
      try {
        final response = await http.patch(
          Uri.parse('$apiUrl/users/$uid'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'displayName': displayName}),
        );

        if (response.statusCode == 200 && _currentUser?.uid == uid) {
          final data = jsonDecode(response.body);
          _currentUser = UserModel.fromMap(data);
          _authController.add(_currentUser);
        }

        return response.statusCode == 200;
      } catch (e) {
        print('❌ Lỗi cập nhật profile (API): $e');
        return false;
      }
    } else {
      try {
        await _users.updateOne(
          where.eq('uid', uid),
          modify.set('displayName', displayName),
        );

        if (_currentUser?.uid == uid) {
          final updatedDoc = await _users.findOne(where.eq('uid', uid));
          if (updatedDoc != null) {
            _currentUser = UserModel.fromMap(Map<String, dynamic>.from(updatedDoc));
            _authController.add(_currentUser);
          }
        }

        print('✅ Cập nhật profile thành công (MongoDB)');
        return true;
      } catch (e) {
        print('❌ Lỗi cập nhật profile (MongoDB): $e');
        return false;
      }
    }
  }
}