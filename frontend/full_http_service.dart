import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:quackfit_flutter/config/config.dart' as Config;

class HttpService {
  static final HttpService instance = HttpService._internal();
  HttpService._internal() {
    print("HttpService initialized with baseUrl: $baseUrl");
  }

  final String baseUrl = dotenv.env['AWS_API_BASE_URL']!
      .replaceAll(RegExp(r'/plan/?$'), ''); 

  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration planGenerationTimeout = Duration(seconds: 45);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Calculate age from date of birth
  int _calculateAge(String dateOfBirth) {
    try {
      final birthDate = DateTime.parse(dateOfBirth);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      
      // Adjust if birthday hasn't occurred this year
      if (today.month < birthDate.month || 
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      
      return age;
    } catch (e) {
      print("Error calculating age from dateOfBirth: $dateOfBirth - $e");
      return 25; // Default fallback age
    }
  }

  /// Process exclude workouts list
  List<String> _processExcludeWorkouts(dynamic excludeWorkouts) {
    print("Processing excludeWorkouts input: $excludeWorkouts (type: ${excludeWorkouts.runtimeType})");
    
    // Always return empty list for null values
    if (excludeWorkouts == null) {
      print("excludeWorkouts is null, returning empty list");
      return <String>[];
    }
    
    List<String> excludeWorkoutsList = <String>[];
    
    try {
      if (excludeWorkouts is List) {
        // Filter out null values and convert to strings
        excludeWorkoutsList = excludeWorkouts
            .where((item) => item != null && item.toString().trim().isNotEmpty)
            .map((item) => item.toString().trim())
            .toList();
      } else if (excludeWorkouts is Map) {
        // Filter out null keys and convert to strings
        excludeWorkoutsList = excludeWorkouts.keys
            .where((key) => key != null && key.toString().trim().isNotEmpty)
            .map((key) => key.toString().trim())
            .toList();
      } else if (excludeWorkouts is String) {
        // Handle case where it's a single string
        final trimmed = excludeWorkouts.trim();
        if (trimmed.isNotEmpty) {
          excludeWorkoutsList = [trimmed];
        }
      } else {
        print("Unexpected excludeWorkouts type: ${excludeWorkouts.runtimeType}, treating as empty");
        excludeWorkoutsList = <String>[];
      }
    } catch (e) {
      print("Error processing excludeWorkouts: $e");
      // Return empty list on error to prevent server-side issues
      excludeWorkoutsList = <String>[];
    }
    
    print("Final processed excludeWorkouts: $excludeWorkoutsList");
    return excludeWorkoutsList;
  }

  /// Enhanced GET request utility with timeout and retry logic
  Future<http.Response> get(
    String endpoint, {
    Duration? timeout,
    int maxRetries = HttpService.maxRetries,
  }) async {
    String normalizedBaseUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    String normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';

    final uri = Uri.parse("$normalizedBaseUrl$normalizedEndpoint");
    final requestTimeout = timeout ?? defaultTimeout;
    
    Exception? lastException;
    http.Response? lastResponse;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print("HTTP GET attempt ${attempt + 1}/$maxRetries to: $uri");
        
        final stopwatch = Stopwatch()..start();
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'QuackFit-Flutter/1.0'},
        ).timeout(requestTimeout);
        
        stopwatch.stop();
        lastResponse = response;
        
        print("""
✅ RESPONSE RECEIVED (${stopwatch.elapsedMilliseconds}ms)
Status: ${response.statusCode}
Headers: ${response.headers}
Body: ${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}
""");

        return response;
        
      } on TimeoutException catch (e) {
        lastException = e;
        print("Request timeout on attempt ${attempt + 1}: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1)));
        }
      } on http.ClientException catch (e) {
        lastException = e;
        print("HTTP Client error on attempt ${attempt + 1}: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1)));
        }
      } catch (e) {
        lastException = Exception(e.toString());
        print("Unexpected error on attempt ${attempt + 1}: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1)));
        }
      }
    }

    final errorReport = {
      'error': 'All GET retry attempts failed',
      'exception': lastException.toString(),
      'last_response': lastResponse != null ? {
        'status_code': lastResponse!.statusCode,
        'body': lastResponse!.body.length > 500 
            ? '${lastResponse!.body.substring(0, 500)}...' 
            : lastResponse!.body,
      } : null,
      'request_details': {
        'method': 'GET',
        'url': uri.toString(),
      }
    };
    
    print("❌ ALL GET RETRIES FAILED: ${jsonEncode(errorReport)}");
    throw Exception(jsonEncode(errorReport));
  }

  Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
    Duration? timeout,
    int maxRetries = HttpService.maxRetries,
  }) async {
    String normalizedBaseUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    String normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';

    final uri = Uri.parse("$normalizedBaseUrl$normalizedEndpoint");
    final requestTimeout = timeout ?? defaultTimeout;
    
    Exception? lastException;
    http.Response? lastResponse;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print("HTTP POST attempt ${attempt + 1}/$maxRetries to: $uri");
        print("Request body: ${jsonEncode(body)}");
        
        final stopwatch = Stopwatch()..start();
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'QuackFit-Flutter/1.0',
          },
          body: jsonEncode(body),
        ).timeout(requestTimeout);
        
        stopwatch.stop();
        lastResponse = response;
        
        print("""
✅ RESPONSE RECEIVED (${stopwatch.elapsedMilliseconds}ms)
Status: ${response.statusCode}
Body: ${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}
""");

        return response;
        
      } on TimeoutException catch (e) {
        lastException = e;
        print("Request timeout on attempt ${attempt + 1}: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1)));
        }
      } on http.ClientException catch (e) {
        lastException = e;
        print("HTTP Client error on attempt ${attempt + 1}: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1)));
        }
      } catch (e) {
        lastException = Exception(e.toString());
        print("Unexpected error on attempt ${attempt + 1}: $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1)));
        }
      }
    }

    final errorReport = {
      'error': 'All retry attempts failed',
      'exception': lastException.toString(),
      'last_response': lastResponse != null ? {
        'status_code': lastResponse!.statusCode,
        'body': lastResponse!.body.length > 500 
            ? '${lastResponse!.body.substring(0, 500)}...' 
            : lastResponse!.body,
      } : null,
      'request_details': {
        'method': 'POST',
        'url': uri.toString(),
        'body': body,
      }
    };
    
    print("❌ ALL RETRIES FAILED: ${jsonEncode(errorReport)}");
    throw Exception(jsonEncode(errorReport));
  }

  Future<bool> basicConnectivityCheck() async {
    try {
      final response = await get(
        "/quote",
        timeout: const Duration(seconds: 10),
        maxRetries: 1,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Generate fitness plan using AWS Lambda
  Future<Map<String, dynamic>?> generateFitnessPlan({
    required Map<String, dynamic> demographicData,
    void Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call("Validating demographic data...");
      
      // Create a defensive copy of the input data
      final cleanedData = Map<String, dynamic>.from(demographicData);
      
      // Calculate age and add to cleaned data
      if (cleanedData.containsKey('dateOfBirth')) {
        final dateOfBirth = cleanedData['dateOfBirth'] as String;
        final age = _calculateAge(dateOfBirth);
        cleanedData['age'] = age;
      }
      
      onProgress?.call("Processing demographic data...");
      
      // Extract required fields with null safety
      final dateOfBirth = cleanedData['dateOfBirth'] as String;
      final sex = cleanedData['sex'] as String;
      final height = cleanedData['height'] as num;
      final weight = cleanedData['weight'] as num;
      final fitnessLevel = cleanedData['fitnessLevel'] as String;
      final goal = cleanedData['goal'] as String;
      final bodyFocus = cleanedData['bodyFocus'] as String;
      
      // Handle nullable integer values with defaults from config
      final minWorkouts = Config.minWorkouts;
      final maxWorkouts = Config.maxWorkouts;
      final intensity = (cleanedData['intensity'] as num?) ?? Config.defaultIntensity;

      // Calculate derived values
      final age = _calculateAge(dateOfBirth);
      cleanedData['age'] = age;

      // Get all available workouts from enum
      final availableWorkouts = Config.Workout.values.map((w) => w.name).toList();
      final excludeWorkoutsList = _processExcludeWorkouts(cleanedData["excludeWorkouts"]);

      final allowedWorkouts = availableWorkouts.where((w) => !excludeWorkoutsList.contains(w)).toList();

      print("Calculated values:");
      print("  - Age: $age years");
      print("  - Height: $height cm");
      print("  - Weight: $weight kg");
      print("  - minWorkouts: ${Config.minWorkouts}");
      print("  - maxWorkouts: ${Config.maxWorkouts}");
      print("  - minRepsPerWorkout: ${Config.minRepsPerWorkout}");
      print("  - maxRepsPerWorkout: ${Config.maxRepsPerWorkout}");
      print("  - minIntensity: ${Config.minIntensity}");
      print("  - maxIntensity: ${Config.maxIntensity}");

      // Create request body with explicit null checks and defaults
      final requestBody = <String, dynamic>{
        // Basic demographics - all guaranteed to be non-null
        "age": age,
        "sex": sex,
        "height": height, 
        "weight": weight,
        "fitnessLevel": fitnessLevel,
        "goal": goal,
        "bodyFocus": bodyFocus,
        "intensity": intensity,
        "minWorkouts": minWorkouts,
        "maxWorkouts": maxWorkouts,
        "allowedWorkouts": allowedWorkouts,
        
        // Add configuration constants from config.dart
        "minRepsPerWorkout": Config.minRepsPerWorkout,
        "maxRepsPerWorkout": Config.maxRepsPerWorkout,
        "minIntensity": Config.minIntensity,
        "maxIntensity": Config.maxIntensity,

        // Metadata for debugging
        "timestamp": DateTime.now().toIso8601String(),
        "app_version": "1.0.0",
      };

      print("Sending validated request body to Lambda:");
      print(jsonEncode(requestBody));

      onProgress?.call("Sending request to server...");
      final response = await post(
        "/plan",
        body: requestBody,
        timeout: planGenerationTimeout,
        maxRetries: 2,
      );

      // Handle response
      if (response.statusCode == 200) {
        try {
          onProgress?.call("Processing server response...");
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Validate response format
          if (responseData.containsKey('error')) {
            print("Server returned error: ${responseData['error']}");
            return responseData;
          }
          
          print("Successfully generated fitness plan: ${responseData.keys.join(', ')}");
          return responseData;
          
        } catch (e) {
          print("Error parsing response: $e");
          return {
            "error": "Invalid response format",
            "details": "Failed to parse JSON: ${e.toString()}",
            "response_body": response.body,
            "error_type": "parse_error"
          };
        }
      } else {
        print("HTTP Error ${response.statusCode}: ${response.body}");

        // Try to parse error response for better error handling
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            "error": errorData['error'] ?? "HTTP Error ${response.statusCode}",
            "message": errorData['message'] ?? response.body,
            "status_code": response.statusCode,
            "error_type": "http_error"
          };
        } catch (_) {
          return {
            "error": "HTTP Error ${response.statusCode}",
            "status_code": response.statusCode,
            "response_body": response.body,
            "error_type": "http_error"
          };
        }
      }
    } catch (e) {
      print("Unexpected error in generateFitnessPlan: $e");
      
      // Parse structured error if available
      try {
        final errorData = jsonDecode(e.toString()) as Map<String, dynamic>;
        return {
          ...errorData,
          "error_type": "network_error"
        };
      } catch (_) {
        return {
          "error": "Unexpected error",
          "details": e.toString(),
          "error_type": "unhandled_exception"
        };
      }
    }
  }

  /// Fetch a motivational image URL from AWS Lambda with enhanced error handling
  Future<String?> fetchMotivationImageUrl() async {
    try {
      print("Fetching motivational image URL...");
      
      final response = await get(
        "/image",
        timeout: const Duration(seconds: 15),
      );
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final imageUrl = data["imageUrl"] as String?;
          
          if (imageUrl != null && imageUrl.isNotEmpty) {
            print("Successfully fetched image URL: $imageUrl");
            return imageUrl;
          } else {
            print("Empty or null image URL received");
            return null;
          }
        } catch (e) {
          print("Error parsing image response: $e");
          return null;
        }
      } else {
        print("Failed to fetch image URL - Status: ${response.statusCode}");
        return null;
      }
    } on TimeoutException {
      print("Timeout while fetching motivational image");
      return null;
    } catch (e) {
      print("Error fetching motivational image: $e");
      return null;
    }
  }

  /// Fetch a motivational quote from AWS Lambda with enhanced error handling
  Future<Map<String, String>?> fetchMotivationalQuote() async {
    try {
      print("Fetching motivational quote...");
      
      final response = await get(
        "/quote",
        timeout: const Duration(seconds: 15),
      );
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          final quote = data['quote'] as String?;
          final author = data['author'] as String?;
          
          if (quote != null && quote.isNotEmpty) {
            print("Successfully fetched motivational quote");
            return {
              'quote': quote,
              'author': author ?? 'Unknown',
            };
          } else {
            print("Empty or null quote received");
            return null;
          }
        } catch (e) {
          print("Error parsing quote response: $e");
          return null;
        }
      } else {
        print("Failed to fetch quote - Status: ${response.statusCode}");
        return null;
      }
    } on TimeoutException {
      print("Timeout while fetching motivational quote");
      return null;
    } catch (e) {
      print("Error fetching motivational quote: $e");
      return null;
    }
  }

  /// Health check method to verify AWS Lambda connectivity
  Future<bool> checkConnectivity() async {
    try {
      // Try to fetch a quote as a simple connectivity test
      final response = await get(
        "/quote",
        timeout: const Duration(seconds: 10),
        maxRetries: 1,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Connectivity check failed: $e");
      return false;
    }
  }

  /// Get detailed error message for user display
  String getDisplayErrorMessage(Map<String, dynamic>? errorResponse) {
    if (errorResponse == null) return "An unknown error occurred.";
    
    final errorType = errorResponse['error_type'] as String?;
    final error = errorResponse['error'] as String?;
    final message = errorResponse['message'] as String?;
    final details = errorResponse['details'];
    
    // Show server message if available and meaningful
    if (message != null && message.isNotEmpty && message != error) {
      return message;
    }
    
    switch (errorType) {
      case 'validation':
        if (details is List) {
          return "Validation error: ${details.join(', ')}";
        }
        return error ?? "Please check your input data and try again.";
      case 'timeout':
        return "Request timed out. Please check your connection and try again.";
      case 'network_error':
        return "Network error. Please check your internet connection.";
      case 'http_error':
        final statusCode = errorResponse['status_code'] as int?;
        if (statusCode == 400) {
          return error ?? "Invalid request. Please check your input data.";
        } else if (statusCode == 500) {
          return error ?? "Server error. Please try again later.";
        }
        return error ?? "Server error (${statusCode ?? 'unknown'}). Please try again.";
      case 'parse_error':
        return "Received invalid response from server. Please try again.";
      case 'unhandled_exception':
        return "Something went wrong. Please try again later.";
      default:
        return error ?? "An error occurred while processing your request.";
    }
  }

  /// Check if an error suggests the user should retry
  bool shouldRetry(Map<String, dynamic>? errorResponse) {
    if (errorResponse == null) return false;
    
    final statusCode = errorResponse['status_code'] as int?;
    final errorType = errorResponse['error_type'] as String?;
    
    // Don't retry validation errors
    if (errorType == 'validation') return false;
    
    // Suggest retry for temporary issues
    return statusCode == 500 || // Server error
           statusCode == 502 || // Bad gateway
           statusCode == 503 || // Service unavailable
           statusCode == 408 || // Request timeout
             errorType == 'timeout' ||
             errorType == 'network_error' ||
             errorType == 'unhandled_exception';
    }
}