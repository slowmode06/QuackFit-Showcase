import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// HttpService - Flutter client for QuackFit backend
/// Works with backend/index.js AWS Lambda endpoints:
///  - /plan → AI-generated workout plan (OpenAI GPT-4)
///  - /quote → Motivational quote (ZenQuotes)
///  - /image → Fitness image (Unsplash)
class HttpService {
  static final HttpService instance = HttpService._internal();
  HttpService._internal() {
    print("HttpService initialized with baseUrl: $baseUrl");
  }

  /// Base URL for backend API (showcase repo uses placeholder)
  final String baseUrl =
      dotenv.env['AWS_API_BASE_URL'] ?? "https://api.placeholder.com";

  static const Duration defaultTimeout = Duration(seconds: 20);
  static const int maxRetries = 3;

  /// Core GET method with retries + timeout
  Future<http.Response> get(
    String endpoint, {
    Duration? timeout,
    int maxRetries = HttpService.maxRetries,
  }) async {
    final uri = Uri.parse("$baseUrl$endpoint");
    final requestTimeout = timeout ?? defaultTimeout;
    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print("HTTP GET attempt ${attempt + 1}/$maxRetries → $uri");
        final response = await http
            .get(uri, headers: {'User-Agent': 'QuackFit/Showcase'})
            .timeout(requestTimeout);
        return response;
      } on TimeoutException {
        lastException = TimeoutException("Timeout on attempt ${attempt + 1}");
      } catch (e) {
        lastException = Exception("Error: $e");
      }
      await Future.delayed(Duration(seconds: attempt + 1));
    }
    throw Exception("❌ All GET attempts failed → $lastException");
  }

  /// Core POST method with retries + timeout
  Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Duration? timeout,
    int maxRetries = HttpService.maxRetries,
  }) async {
    final uri = Uri.parse("$baseUrl$endpoint");
    final requestTimeout = timeout ?? defaultTimeout;
    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print("HTTP POST attempt ${attempt + 1}/$maxRetries → $uri");
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);
        return response;
      } on TimeoutException {
        lastException = TimeoutException("Timeout on attempt ${attempt + 1}");
      } catch (e) {
        lastException = Exception("Error: $e");
      }
      await Future.delayed(Duration(seconds: attempt + 1));
    }
    throw Exception("❌ All POST attempts failed → $lastException");
  }

  /// Call backend `/plan` (AI workout plan)
  Future<Map<String, dynamic>?> generateFitnessPlan(
      Map<String, dynamic> demographicData) async {
    try {
      final response = await post("/plan", body: demographicData);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {"error": "HTTP ${response.statusCode}"};
      }
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  /// Call backend `/quote` (Motivational Quote)
  Future<Map<String, String>?> fetchMotivationalQuote() async {
    try {
      final response = await get("/quote");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "quote": data["quote"] ?? "",
          "author": data["author"] ?? "Unknown"
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Call backend `/image` (Motivational Image)
  Future<Map<String, String>?> fetchMotivationImage() async {
    try {
      final response = await get("/image");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "imageUrl": data["imageUrl"] ?? "",
          "alt": data["alt"] ?? "Fitness motivation",
          "photographer": data["photographer"] ?? "Unknown",
          "photographerUrl": data["photographerUrl"] ?? ""
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}