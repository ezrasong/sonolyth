import 'package:dio/dio.dart';

/// The zarz gateway backs every SpotiFLAC download provider. It gates requests
/// on a `SpotiFLAC-Mobile/<version>` User-Agent and rate-limits to roughly
/// 5 requests / 10s, so all provider traffic funnels through this one client.
class ZarzClient {
  static const userAgent = "SpotiFLAC-Mobile/4.5.6";

  final Dio _dio;

  ZarzClient([Dio? dio]) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers["User-Agent"] = userAgent;
  }

  Future<dynamic> getJson(String url, {Map<String, dynamic>? query}) async {
    final response = await _dio.get(
      url,
      queryParameters: query,
      options: Options(responseType: ResponseType.json),
    );
    return response.data;
  }

  Future<dynamic> postJson(String url, Map<String, dynamic> body) async {
    final response = await _dio.post(
      url,
      data: body,
      options: Options(
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
      ),
    );
    return response.data;
  }
}

final zarzClient = ZarzClient();
