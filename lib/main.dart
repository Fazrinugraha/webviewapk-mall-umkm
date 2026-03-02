import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid && !kReleaseMode) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _controller;
  double _progress = 0;

  final String baseUrl = "https://mall-umkm.arunikacyber.my.id";
  final String url = "https://mall-umkm.arunikacyber.my.id/";

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    _requestPermissions();
    _initDeepLink();
  }

  // =========================================================
  // DEEP LINK — Tangkap mallumkm://login?token=xxx
  // =========================================================
  void _initDeepLink() async {
    _appLinks = AppLinks();

    // App dibuka dari kondisi mati via deep link
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      debugPrint("LOG: Initial deep link -> $uri");
      _handleUri(uri);
    }

    // App sudah terbuka, deep link masuk
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("LOG: Stream deep link -> $uri");
      _handleUri(uri);
    }, onError: (err) => debugPrint("Deep link error: $err"));
  }

  void _handleUri(Uri uri) async {
    debugPrint("LOG: _handleUri dipanggil -> $uri");

    if (uri.scheme == "mallumkm" && uri.host == "login") {
      final token = uri.queryParameters['token'];
      debugPrint("LOG: Token -> $token");

      if (token == null) return;

      // Tunggu controller siap (kalau app baru dibuka dari mati)
      int retry = 0;
      while (_controller == null && retry < 20) {
        await Future.delayed(const Duration(milliseconds: 300));
        retry++;
        debugPrint("LOG: Menunggu controller... retry $retry");
      }

      if (_controller != null) {
        debugPrint("LOG: Load login-from-app");
        await _controller!.loadUrl(
          urlRequest: URLRequest(
            url: WebUri("$baseUrl/login-from-app?token=$token"),
          ),
        );
      } else {
        debugPrint("LOG: Controller masih null setelah retry!");
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // =========================================================
  // SYSTEM UI
  // =========================================================
  void _setSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    if (Platform.isAndroid) {
      await Permission.photos.request();
      await Permission.storage.request();
    }
  }

  Future<bool> _onWillPop() async {
    if (_controller != null && await _controller!.canGoBack()) {
      _controller!.goBack();
      return false;
    }
    return true;
  }

  // Future<void> _handleDownload(String payload) async {
  //   try {
  //     final parts = payload.split('::');
  //     if (parts.length < 3) return;

  //     final filename = parts[0];
  //     final base64Data = parts.sublist(2).join('::');
  //     final bytes = base64Decode(base64Data);

  //     // Simpan ke folder Downloads Android
  //     Directory dir = Directory('/storage/emulated/0/Download');
  //     if (!await dir.exists()) {
  //       dir = (await getExternalStorageDirectory())!;
  //     }

  //     final filePath = '${dir.path}/$filename';
  //     await File(filePath).writeAsBytes(bytes);
  //     debugPrint("LOG: File tersimpan -> $filePath");

  //     // Buka file
  //     await OpenFile.open(filePath);

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('File tersimpan: $filename'),
  //           action: SnackBarAction(
  //             label: 'Buka',
  //             onPressed: () => OpenFile.open(filePath),
  //           ),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint("LOG: Error download -> $e");
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
  //     }
  //   }
  // }
  Future<void> _handleDownload(String payload) async {
    try {
      final payloadParts = payload.split('::');
      if (payloadParts.length < 3) return;

      final filename = payloadParts[0];
      final base64Data = payloadParts.sublist(2).join('::');
      final bytes = base64Decode(base64Data);

      // ✅ Simpan ke app-private directory (TIDAK butuh permission apapun)
      // Path: /storage/emulated/0/Android/data/com.xxx/files/
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Storage tidak tersedia');

      final filePath = '${dir.path}/$filename';
      await File(filePath).writeAsBytes(bytes);
      debugPrint("LOG: File tersimpan -> $filePath");

      // Buka file
      final result = await OpenFile.open(filePath);
      debugPrint("LOG: OpenFile result -> ${result.message}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File tersimpan: $filename'),
            action: SnackBarAction(
              label: 'Buka',
              onPressed: () => OpenFile.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("LOG: Error download -> $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
      }
    }
  }

  bool _isExternalUrl(String url) {
    return url.contains("wa.me") ||
        url.contains("whatsapp:") ||
        url.contains("instagram.com") ||
        url.contains("facebook.com") ||
        url.contains("tiktok.com") ||
        url.contains("twitter.com") ||
        url.contains("t.me") ||
        url.contains("youtube.com") ||
        url.startsWith("tel:") ||
        url.startsWith("mailto:") ||
        url.startsWith("sms:") ||
        url.contains("google.com/maps");
  }

  Future<void> _openExternalApp(String url) async {
    final uri = Uri.parse(url);

    if (url.contains("instagram.com")) {
      final username =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : "";
      final igUri = Uri.parse("instagram://user?username=$username");
      if (await canLaunchUrl(igUri)) {
        await launchUrl(igUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // =========================================================
  // INJECT from_app ke tombol Google di halaman login
  // =========================================================
  Future<void> _injectFromAppToGoogleButton(
    InAppWebViewController controller,
  ) async {
    await controller.evaluateJavascript(
      source: """
      (function() {
        // Cari semua link yang mengarah ke google/redirect
        var links = document.querySelectorAll('a[href*="google/redirect"]');
        links.forEach(function(link) {
          var href = link.getAttribute('href');
          if (href && !href.includes('from_app=1')) {
            link.setAttribute('href', href + (href.includes('?') ? '&' : '?') + 'from_app=1');
          }
        });
      })();
    """,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(url)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useHybridComposition: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  clearCache: false, // ✅ WAJIB false agar session tidak hilang
                  saveFormData: false,
                  thirdPartyCookiesEnabled: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  userAgent:
                      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36",
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  debugPrint("LOG: WebView controller siap");

                  // ✅ TAMBAH INI — terima file dari web lalu simpan
                  controller.addJavaScriptHandler(
                    handlerName: 'FlutterDownload',
                    callback: (args) async {
                      if (args.isEmpty) return;
                      await _handleDownload(args[0].toString());
                    },
                  );
                },
                onLoadStop: (controller, loadedUrl) async {
                  final urlStr = loadedUrl.toString();
                  debugPrint("LOG: onLoadStop -> $urlStr");

                  // Inject from_app ke tombol Google jika halaman login
                  if (urlStr.contains("/login") || urlStr.contains("/auth")) {
                    await _injectFromAppToGoogleButton(controller);
                  }

                  // Inject CSS fix
                  await controller.evaluateJavascript(
                    source: """
                    (function(){
                      function applyFix(){
                        if(document.getElementById("fix-style")) return;
                        document.body.classList.add("app-webview");
                        var style = document.createElement("style");
                        style.id = "fix-style";
                        style.innerHTML = `
                          .page-header-shop .header-inner {
                            display:flex!important;
                            align-items:center!important;
                            gap:10px!important;
                          }
                          .page-header-shop { padding-top:6px!important; padding-bottom:6px!important; }
                          .page-header-shop .h-logo { height:34px!important; }
                          .bottom-bar { padding-bottom:env(safe-area-inset-bottom)!important; }
                          body { padding-bottom:env(safe-area-inset-bottom)!important; }
                        `;
                        document.head.appendChild(style);
                      }
                      applyFix();
                      new MutationObserver(applyFix).observe(document.documentElement, {childList:true, subtree:true});
                    })();
                  """,
                  );
                },
                onProgressChanged: (controller, progress) {
                  setState(() => _progress = progress / 100);
                },
                androidOnPermissionRequest: (
                  controller,
                  origin,
                  resources,
                ) async {
                  return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.DENY,
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.ALLOW;

                  final urlString = uri.toString();
                  debugPrint("LOG: shouldOverride -> $urlString");

                  // ✅ 1. Izinkan jembatan login diproses di WebView
                  if (urlString.contains("/login-from-app")) {
                    debugPrint("LOG: ALLOW login-from-app");
                    return NavigationActionPolicy.ALLOW;
                  }

                  // ✅ 2. Lempar Google OAuth ke Chrome (WAJIB — Google blokir WebView)
                  if (urlString.contains("accounts.google.com")) {
                    debugPrint("LOG: Buka Google di Chrome eksternal");
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }

                  // ✅ 3. Tangkap deep link mallumkm:// di dalam WebView
                  if (urlString.startsWith("mallumkm://")) {
                    debugPrint("LOG: Deep link dari WebView -> $urlString");
                    _handleUri(Uri.parse(urlString));
                    return NavigationActionPolicy.CANCEL;
                  }

                  // ✅ 4. Intent Android
                  if (urlString.startsWith("intent:")) {
                    try {
                      final fixedUrl =
                          urlString
                              .replaceFirst("intent://", "https://")
                              .split("#Intent")[0];
                      await launchUrl(
                        Uri.parse(fixedUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      debugPrint("Intent error: $e");
                    }
                    return NavigationActionPolicy.CANCEL;
                  }

                  // // ✅ 5. Link eksternal lainnya
                  // if (_isExternalUrl(urlString)) {
                  //   await _openExternalApp(urlString);
                  //   return NavigationActionPolicy.CANCEL;
                  // }

                  // return NavigationActionPolicy.ALLOW;
                  // ✅ 5. Intercept URL export Excel/PDF → buka di browser native
                  // if (urlString.contains('/export-excel') ||
                  //     urlString.contains('/export-pdf') ||
                  //     urlString.contains('exportExcel') ||
                  //     urlString.contains('exportPdf')) {
                  //   debugPrint("LOG: Export file -> buka di browser eksternal");
                  //   await launchUrl(uri, mode: LaunchMode.externalApplication);
                  //   return NavigationActionPolicy.CANCEL;
                  // }
                  // ✅ 5. EXPORT FILE — buka di browser native
                  // if (urlString.contains('/umkm/keuangan/export-excel') ||
                  //     urlString.contains('/umkm/keuangan/export-pdf')) {
                  //   debugPrint("LOG: Export -> browser eksternal: $urlString");
                  //   await launchUrl(uri, mode: LaunchMode.externalApplication);
                  //   return NavigationActionPolicy.CANCEL;
                  // }

                  // ✅ 6. Link eksternal lainnya
                  if (_isExternalUrl(urlString)) {
                    await _openExternalApp(urlString);
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
              ),
              if (_progress < 1.0)
                LinearProgressIndicator(value: _progress, minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
