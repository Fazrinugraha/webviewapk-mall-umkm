import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

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

  final String url = "https://mall-umkm.arunikacyber.my.id/";

  // 🔥 TAMBAHAN UNTUK DEEP LINK
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();

    _setSystemUI();
    _requestPermissions();
    _initDeepLink(); // 🔥 TAMBAHAN
  }

  // ================= DEEP LINK GOOGLE LOGIN =================

  void _initDeepLink() async {
    _appLinks = AppLinks();

    // Jika app dibuka dari kondisi mati
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      _handleUri(uri);
    }

    // Jika app sudah terbuka
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint("Deep link error: $err");
      },
    );
  }

  // void _handleUri(Uri uri) async {
  //   if (uri.scheme == "mallumkm") {
  //     final token = uri.queryParameters['token'];

  //     if (token != null && _controller != null) {
  //       await _controller!.loadUrl(
  //         urlRequest: URLRequest(
  //           url: WebUri(
  //             "https://mall-umkm.arunikacyber.my.id/login-from-app?token=$token",
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }
  // void _handleUri(Uri uri) async {
  //   debugPrint(
  //     "LOG: Deep link masuk -> ${uri.toString()}",
  //   ); // Tambahkan ini buat cek!

  //   if (uri.scheme == "mallumkm") {
  //     final token = uri.queryParameters['token'];
  //     debugPrint("LOG: Token ditemukan -> $token");

  //     if (token != null && _controller != null) {
  //       await _controller!.loadUrl(
  //         urlRequest: URLRequest(
  //           url: WebUri(
  //             "https://mall-umkm.arunikacyber.my.id/login-from-app?token=$token",
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }
  // void _handleUri(Uri uri) async {
  //   debugPrint("LOG: Deep link terdeteksi -> ${uri.toString()}");

  //   // Cek apakah link mengandung path login-from-app
  //   if (uri.toString().contains("login-from-app")) {
  //     final token = uri.queryParameters['token'];
  //     debugPrint("LOG: Token ditemukan -> $token");

  //     if (token != null && _controller != null) {
  //       // 🔥 LANGKAH SAKTI: Bersihkan cookie lama agar tidak bentrok
  //       CookieManager cookieManager = CookieManager.instance();
  //       await cookieManager.deleteAllCookies();

  //       // 1. Tembak URL Jembatan Login
  //       await _controller!.loadUrl(
  //         urlRequest: URLRequest(
  //           url: WebUri(
  //             "https://mall-umkm.arunikacyber.my.id/login-from-app?token=$token",
  //           ),
  //         ),
  //       );

  //       // 2. JEDA 2 DETIK: Memberi waktu Laravel nulis file session di storage HP
  //       Future.delayed(const Duration(seconds: 2), () async {
  //         debugPrint("LOG: Membuka Halaman Home...");
  //         await _controller!.loadUrl(
  //           urlRequest: URLRequest(
  //             url: WebUri(
  //               "https://mall-umkm.arunikacyber.my.id/home?user_id_to_push=${uri.queryParameters['user_id_to_push'] ?? ''}",
  //             ),
  //           ),
  //         );
  //       });
  //     }
  //   }
  // }
  // Perbaiki _handleUri
  void _handleUri(Uri uri) async {
    debugPrint("LOG: Deep link masuk -> ${uri.toString()}");

    // Tangkap mallumkm://login?token=xxx
    if (uri.scheme == "mallumkm" && uri.host == "login") {
      final token = uri.queryParameters['token'];
      debugPrint("LOG: Token ditemukan -> $token");

      if (token != null && _controller != null) {
        // Muat URL jembatan login di dalam WebView
        await _controller!.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(
              "https://mall-umkm.arunikacyber.my.id/login-from-app?token=$token",
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ================= SYSTEM UI =================

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
    // await Permission.camera.request();
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
        url.startsWith("intent:") ||
        url.contains("google.com/maps");
  }

  Future<void> _openExternalApp(String url) async {
    final uri = Uri.parse(url);

    /// INSTAGRAM → paksa buka app
    if (url.contains("instagram.com")) {
      final username =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : "";

      final igUri = Uri.parse("instagram://user?username=$username");

      if (await canLaunchUrl(igUri)) {
        await launchUrl(igUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    /// EMAIL
    if (url.startsWith("mailto:")) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    /// TELEPON / SMS
    if (url.startsWith("tel:") || url.startsWith("sms:")) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    /// DEFAULT → semua link eksternal
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
                  domStorageEnabled: true, // 🔥 TAMBAHKAN INI (WAJIB)
                  databaseEnabled: true, // 🔥 TAMBAHKAN INI (WAJIB)
                  userAgent:
                      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36", // Tambahkan ini
                  clearCache: true,
                  saveFormData: false,
                  thirdPartyCookiesEnabled: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                ),
                onWebViewCreated: (controller) async {
                  _controller = controller;

                  await _controller?.evaluateJavascript(
                    source: """
                    (function() {
                      let meta = document.querySelector('meta[name="viewport"]');
                      if (!meta) {
                        meta = document.createElement('meta');
                        meta.name = 'viewport';
                        meta.content = 'width=device-width, initial-scale=1.0, viewport-fit=cover';
                        document.head.appendChild(meta);
                      }

                      let style = document.createElement('style');
                      style.innerHTML = `
                        html, body {
                          margin:0 !important;
                          padding:0 !important;
                          height:100% !important;
                          overflow-x:hidden !important;
                        }
                      `;
                      document.head.appendChild(style);
                    })();
                    """,
                  );
                },
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(
                    source: """

(function(){

function applyFix(){

  if(document.getElementById("fix-style")) return;

  document.body.classList.add("app-webview");

  var style=document.createElement("style");
  style.id="fix-style";

  style.innerHTML=`

  .page-header-shop .header-inner{
    display:flex!important;
    align-items:center!important;
    gap:10px!important;
  }

  .page-header-shop{
    padding-top:6px!important;
    padding-bottom:6px!important;
  }

  .page-header-shop .h-logo{
    height:34px!important;
  }

  .bottom-bar{
    padding-bottom:env(safe-area-inset-bottom)!important;
  }

  body{
    padding-bottom:env(safe-area-inset-bottom)!important;
  }

  `;

  document.head.appendChild(style);
}

applyFix();

new MutationObserver(applyFix)
.observe(document.documentElement,{
  childList:true,
  subtree:true
});

})();
""",
                  );
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                // androidOnPermissionRequest: (
                //   controller,
                //   origin,
                //   resources,
                // ) async {
                //   return PermissionRequestResponse(
                //     resources: resources,
                //     action: PermissionRequestResponseAction.GRANT,
                //   );
                // },
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

                // shouldOverrideUrlLoading: (controller, navigationAction) async {
                //   final uri = navigationAction.request.url;

                //   if (uri != null) {
                //     final urlString = uri.toString();

                //     if (urlString.startsWith("mallumkm://")) {
                //       // buka app via deep link
                //       await launchUrl(
                //         Uri.parse(urlString),
                //         mode: LaunchMode.externalApplication,
                //       );
                //       return NavigationActionPolicy
                //           .CANCEL; // jangan lanjutkan webview
                //     }

                //     // if (urlString.contains("/login/google")) {
                //     //   final newUrl =
                //     //       urlString.contains("?")
                //     //           ? "$urlString&from_app=1"
                //     //           : "$urlString?from_app=1";

                //     //   await controller.loadUrl(
                //     //     urlRequest: URLRequest(url: WebUri(newUrl)),
                //     //   );

                //     //   return NavigationActionPolicy.CANCEL;
                //     // }
                //     // 1. CEK INI DULU: Izinkan URL jembatan login diproses di dalam WebView
                //     if (urlString.contains("/login-from-app?token=")) {
                //       debugPrint("LOG: Memproses login di dalam WebView...");
                //       return NavigationActionPolicy.ALLOW;
                //     }

                //     /// 🔥 HANDLE GOOGLE LOGIN
                //     // if (urlString.contains("accounts.google.com") ||
                //     //     urlString.contains("googleusercontent.com") ||
                //     //     urlString.contains("googleapis.com")) {
                //     //   await launchUrl(
                //     //     uri,
                //     //     mode: LaunchMode.externalApplication,
                //     //   );
                //     //   return NavigationActionPolicy.CANCEL;
                //     // }
                //     /// 🔥 HANDLE GOOGLE LOGIN
                //     // if (urlString.contains("accounts.google.com") ||
                //     //     urlString.contains("googleusercontent.com") ||
                //     //     urlString.contains("googleapis.com")) {
                //     //   // Tambahkan query param 'from_app=1' agar Laravel bisa membedakan
                //     //   // antara login via web murni vs login via webview app
                //     //   final String googleUrlWithParam =
                //     //       urlString.contains("?")
                //     //           ? "$urlString&from_app=1"
                //     //           : "$urlString?from_app=1";

                //     //   await launchUrl(
                //     //     Uri.parse(googleUrlWithParam),
                //     //     mode: LaunchMode.externalApplication,
                //     //   );
                //     //   return NavigationActionPolicy.CANCEL;
                //     // }
                //     // 2. CEK GOOGLE LOGIN: Baru setelah itu lempar ke Chrome untuk pilih akun
                //     if (urlString.contains("accounts.google.com")) {
                //       final String googleUrlWithParam =
                //           urlString.contains("?")
                //               ? "$urlString&from_app=1"
                //               : "$urlString?from_app=1";

                //       await launchUrl(
                //         Uri.parse(googleUrlWithParam),
                //         mode: LaunchMode.externalApplication,
                //       );
                //       return NavigationActionPolicy.CANCEL;
                //     }

                //     if (urlString.startsWith("intent:")) {
                //       try {
                //         final fixedUrl =
                //             urlString
                //                 .replaceFirst("intent://", "https://")
                //                 .split("#Intent")[0];

                //         await launchUrl(
                //           Uri.parse(fixedUrl),
                //           mode: LaunchMode.externalApplication,
                //         );
                //       } catch (e) {
                //         debugPrint("Intent error: $e");
                //       }
                //       return NavigationActionPolicy.CANCEL;
                //     }

                //     if (_isExternalUrl(urlString)) {
                //       await _openExternalApp(urlString);
                //       return NavigationActionPolicy.CANCEL;
                //     }
                //   }

                //   return NavigationActionPolicy.ALLOW;
                // },
                // Ganti shouldOverrideUrlLoading dan _handleUri
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;

                  if (uri != null) {
                    final urlString = uri.toString();

                    // ✅ Izinkan URL jembatan login diproses di dalam WebView
                    if (urlString.contains("/login-from-app")) {
                      debugPrint("LOG: Proses login-from-app di WebView");
                      return NavigationActionPolicy.ALLOW;
                    }

                    // ✅ Lempar Google login ke browser eksternal (WAJIB, Google blokir WebView)
                    if (urlString.contains("accounts.google.com")) {
                      // Tambahkan from_app agar Laravel tahu ini dari app
                      final String googleUrl =
                          urlString.contains("?")
                              ? "$urlString&from_app=1"
                              : "$urlString?from_app=1";

                      await launchUrl(
                        Uri.parse(googleUrl),
                        mode: LaunchMode.externalApplication, // ← buka Chrome
                      );
                      return NavigationActionPolicy.CANCEL;
                    }

                    // ✅ Tangkap deep link mallumkm:// yang masuk ke WebView
                    if (urlString.startsWith("mallumkm://")) {
                      _handleUri(Uri.parse(urlString));
                      return NavigationActionPolicy.CANCEL;
                    }

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

                    if (_isExternalUrl(urlString)) {
                      await _openExternalApp(urlString);
                      return NavigationActionPolicy.CANCEL;
                    }
                  }

                  return NavigationActionPolicy.ALLOW;
                },
              ),
              if (_progress < 1)
                LinearProgressIndicator(value: _progress, minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
