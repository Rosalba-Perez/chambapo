import 'package:dio/dio.dart';
import 'config.dart';
import 'supabase_client.dart';

class ApiClient {
  final Dio _dio = Dio(BaseOptions(baseUrl: Config.apiUrl, connectTimeout: const Duration(seconds: 10)));

  ApiClient() {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      final token = supabase.auth.currentSession?.accessToken;
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    }));
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) => _llamar(() => _dio.post(path, data: body));

  Future<Map<String, dynamic>> get(String path) => _llamar(() => _dio.get(path));

  Future<Map<String, dynamic>> _llamar(Future<Response> Function() peticion) async {
    try {
      final r = await peticion();
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      throw ApiException(e.response?.data is Map ? (e.response!.data['detail'] ?? 'Error') : 'Sin conexión con el servidor',
          e.response?.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String mensaje;
  final int? codigo;
  ApiException(this.mensaje, [this.codigo]);
  @override
  String toString() => mensaje;
}

final api = ApiClient();
