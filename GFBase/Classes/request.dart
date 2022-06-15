import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mupingzilaishui/common/utils/global.dart';
import 'package:mupingzilaishui/common/utils/webconfig.dart';
import 'package:xml2json/xml2json.dart';

typedef ReceiveProgress<T> = void Function(T rec, T total);
class Request {
  static final Request _instance = Request._internal();
  factory Request() => _instance;
  final myTransformer = Xml2Json();

  late Dio dio;
  CancelToken cancelToken = CancelToken();
  var url;
  Request._internal() {
    // BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      // 请求基地址,可以包含子路径
      baseUrl: WebConfig().baseUrl,

      //连接服务器超时时间，单位是毫秒.
      connectTimeout: 120000,

      // 响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: 120000,

      // Http请求头.
      headers: {},
      contentType: 'text/xml; charset=utf-8',
      responseType: ResponseType.json,
    );

    dio = Dio(options);

    // 添加拦截器
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      // 在请求被发送之前做一些预处理

      // 1外网 0内网
      var type =  Global.getUrlSetup();
      if(type==1){
        url = Global.getBaseUrlSetup();
      }else{
        url = Global.getIntranetUrlSetup();
      }
      options.baseUrl = url;

      return handler.next(options); //continue
    }, onResponse: (response, handler) {
      // 在返回响应数据之前做一些预处理
      return handler.next(response);
    }, onError: (DioError e, handler) {
      // 当请求失败时做一些预处理
      ErrorEntity eInfo = createErrorEntity(e);
      // 错误提示
      EasyLoading.showInfo(eInfo.message.toString(),duration: const Duration(seconds: 3));
      // 错误交互处理
      switch (eInfo.code) {
        case 401: // 没有权限 重新登录

          break;
        default:
      }
      return handler.next(e);
    }));
  }

  /// restful get 操作
  Future get(String path, {dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response =
        await dio.get(path, queryParameters: params, options: requestOptions,cancelToken: cancelToken);

    myTransformer.parse(response.data.toString());
    var result = myTransformer.toParkerWithAttrs();
    if(result.contains('“')&&result.contains('”')){
     result = result.replaceAll('“', "");
     result = result.replaceAll('”', "");
    }
    if(result.contains("\\\\")){
      result = result.replaceAll("\\\\" , "\\\\\\\\");
    }
    if(result.contains("%")){
      result = result.replaceAll("%" , "");
    }

    var data = json.decode(result);

    var jsonData = json.decode(data['string']['value']);
    return jsonData;
  }

  /// restful post 操作
  Future post(String path, {dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response = await dio.post(path, data: params, options: requestOptions, cancelToken: cancelToken);

    myTransformer.parse(response.data.toString());
    var result = myTransformer.toParkerWithAttrs();
    var data = json.decode(result);
    var jsonData = json.decode(data['string']['value']);

    return jsonData;
  }

  /// restful download 操作
  Future download(String path,ReceiveProgress onReceiveProgress,{dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response =
    await dio.get(path, queryParameters: params, options: requestOptions,cancelToken: cancelToken,onReceiveProgress:onReceiveProgress);

    myTransformer.parse(response.data.toString());
    var result = myTransformer.toParkerWithAttrs();
    var data = json.decode(result);
    var jsonData = json.decode(data['string']['value']);

    return jsonData;
  }

  /// restful put 操作
  Future put(String path, {dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response = await dio.put(path, data: params, options: requestOptions, cancelToken: cancelToken);
    return response.data;
  }

  /// restful patch 操作
  Future patch(String path, {dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response = await dio.patch(path, data: params, options: requestOptions, cancelToken: cancelToken);

    return response.data;
  }

  /// restful delete 操作
  Future delete(String path, {dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response = await dio.delete(path, data: params, options: requestOptions, cancelToken: cancelToken);
    return response.data;
  }

  /// restful post form 表单提交操作
  Future postForm(String path, {dynamic params, Options? options}) async {
    Options requestOptions = options ?? Options();

    var response =
    await dio.post(path, data: FormData.fromMap(params), options: requestOptions, cancelToken: cancelToken);
    return response.data;
  }

  /*
   * error统一处理
   */
  ErrorEntity createErrorEntity(DioError error) {
    switch (error.type) {
      case DioErrorType.cancel:
        {
          return ErrorEntity(code: -1, message: "请求取消");
        }
      case DioErrorType.connectTimeout:
        {
          return ErrorEntity(code: -1, message: "连接超时");
        }
      case DioErrorType.sendTimeout:
        {
          return ErrorEntity(code: -1, message: "请求超时");
        }

      case DioErrorType.receiveTimeout:
        {
          return ErrorEntity(code: -1, message: "响应超时");
        }
      case DioErrorType.response:
        {
          try {
            int? errCode = error.response?.statusCode;
            if (errCode == null) {
              return ErrorEntity(code: -2, message: error.message);
            }
            switch (errCode) {
              case 400:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message'] ?? "请求语法错误");
                }

              case 401:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message'] ?? "没有权限");
                }

              case 403:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message'] ?? "服务器拒绝执行");
                }
              case 404:
                {
                  return ErrorEntity(code: errCode, message: "无法连接服务器");
                }
              case 405:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message'] ?? "请求方法被禁止");
                }
              case 500:
                {
                  return ErrorEntity(code: errCode, message: "服务器内部错误");
                }
              case 502:
                {
                  return ErrorEntity(code: errCode, message: "无效的请求");
                }
              case 503:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message'] ?? "服务器挂了");
                }
              case 505:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message'] ?? "不支持HTTP协议请求");
                }
              default:
                {
                  return ErrorEntity(code: errCode, message: error.response?.data['message']);
                }
            }
          } on Exception catch (_) {
            return ErrorEntity(code: -1, message: "未知错误");
          }
        }
      default:
        {
          return ErrorEntity(code: -1, message: error.message);
        }
    }
  }
}

// 异常处理
class ErrorEntity implements Exception {
  int code;
  String? message;
  ErrorEntity({required this.code, this.message});

  @override
  String toString() {
    if (message == null) return "Exception";
    return "Exception: code $code, $message";
  }
}

