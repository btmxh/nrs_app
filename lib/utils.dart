import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpException implements Exception {
  int statusCode;
  String message;
  HttpException(this.statusCode, this.message);

  @override
  String toString() {
    // TODO: implement toString
    return "Status code $statusCode: $message";
  }
}

extension IsOk on http.Response {
  bool get ok {
    return (statusCode ~/ 100) == 2;
  }

  String get bodyOrThrow {
    if (!ok) {
      throw HttpException(statusCode, body);
    }

    return body;
  }

  Future<dynamic> get jsonOrThrow async {
    return compute(jsonDecode, bodyOrThrow);
  }
}
