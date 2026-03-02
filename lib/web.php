<?php

namespace App\Http\Controllers\Userumkm;

use App\Http\Controllers\Controller;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Session;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http; // ✅ TAMBAH INI
use Laravel\Socialite\Facades\Socialite;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function auth()
    {
        $dataview['page_title'] = 'Login';
        $dataview['cfg'] = DB::table('mall_umkm_kop_config')
            ->whereIn('params_config', ['LOGO', 'NAMA', 'ALAMAT'])
            ->pluck('value_config', 'params_config');

        // ✅ LOGO DINAMIS
        $dataview['logoAdmin'] = !empty($dataview['cfg']['LOGO'] ?? null)
            ? asset('assets/admin-umkm/img/logo/' . $dataview['cfg']['LOGO'])
            : asset('images/logo.png');

        return view('pages.user.umkm.login', $dataview);
    }

    public function regis()
    {
        $dataview['page_title'] = 'Register';
        $dataview['cfg'] = DB::table('mall_umkm_kop_config')
            ->whereIn('params_config', ['LOGO', 'NAMA', 'ALAMAT'])
            ->pluck('value_config', 'params_config');

        $dataview['logoAdmin'] = !empty($dataview['cfg']['LOGO'] ?? null)
            ? asset('assets/admin-umkm/img/logo/' . $dataview['cfg']['LOGO'])
            : asset('images/logo.png');

        return view('pages.user.umkm.register', $dataview);
    }

    public function login(Request $request)
    {
        // ✅ tambah validasi g-recaptcha-response
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
            'g-recaptcha-response' => 'required',
        ], [
            'g-recaptcha-response.required' => 'Mohon centang captcha terlebih dahulu.'
        ]);

        // ✅ verifikasi captcha ke Google
        try {
            $captchaResponse = $request->input('g-recaptcha-response');

            $verify = Http::asForm()->post('https://www.google.com/recaptcha/api/siteverify', [
                'secret'   => env('RECAPTCHA_SECRET_KEY'),
                'response' => $captchaResponse,
                'remoteip' => $request->ip(),
            ]);

            if (!data_get($verify->json(), 'success', false)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Verifikasi captcha gagal. Silakan coba lagi.'
                ], 422);
            }
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal memverifikasi captcha.',
                'error' => config('app.debug') ? $e->getMessage() : null
            ], 500);
        }

        // ✅ lanjut login seperti semula (tanpa ubah flow besar)
        $credentials = $request->only('email', 'password');

        try {
            if (Auth::attempt($credentials, $request->remember)) {

                $user = Auth::user();

                if (in_array($user->akses, ['ADMINISTRATOR', 'OPD', 'PIMPINAN', 'EKSEKUTIF'])) {
                    Auth::logout();
                    $request->session()->invalidate();

                    return response()->json([
                        'success' => false,
                        'message' => 'Admin atau pengelola tidak diizinkan login melalui halaman ini'
                    ], 403);
                }

                $request->session()->regenerate();

                return response()->json([
                    'success' => true,
                    'message' => 'Login berhasil',
                    'redirect' => '/home?user_id_to_push=' . $user->id_user
                ]);
            }

            return response()->json([
                'success' => false,
                'message' => 'Email atau password salah'
            ], 401);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan sistem',
                'error' => config('app.debug') ? $e->getMessage() : null
            ], 500);
        }
    }

    public function register(Request $request)
    {
        // ✅ tambah validasi g-recaptcha-response
        $validated = $request->validate([
            'nama' => 'required|string|max:255',
            'email' => 'required|email|max:255|unique:mall_umkm_kop_user,email',
            'nomor_hp' => [
                'required',
                'string',
                'min:10',
                'max:13',
                'regex:/^08[0-9]{8,11}$/'
            ],
            'password' => 'required|min:6|same:confirmPassword',

            // ✅ CAPTCHA required
            'g-recaptcha-response' => 'required',
        ], [
            'g-recaptcha-response.required' => 'Mohon centang captcha terlebih dahulu.'
        ]);

        // ✅ verifikasi captcha ke Google (sama seperti login)
        try {
            $captchaResponse = $request->input('g-recaptcha-response');

            $verify = Http::asForm()->post('https://www.google.com/recaptcha/api/siteverify', [
                'secret'   => env('RECAPTCHA_SECRET_KEY'),
                'response' => $captchaResponse,
                'remoteip' => $request->ip(),
            ]);

            if (!data_get($verify->json(), 'success', false)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Verifikasi captcha gagal. Silakan coba lagi.'
                ], 422);
            }
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal memverifikasi captcha.',
                'error' => config('app.debug') ? $e->getMessage() : null
            ], 500);
        }

        try {
            // Simpan user ke database
            $user = User::create([
                'nama' => $validated['nama'],
                'email' => $validated['email'],
                'nomor_hp' => $validated['nomor_hp'],
                'password' => Hash::make($validated['password']),
                'avatar' => 'images/avatar/default-avatar.png',
                'akses' => 'UMUM',
            ]);

            Auth::login($user);

            return response()->json([
                'success' => true,
                'message' => 'Berhasil registrasi!',
                'redirect' => '/home?user_id_to_push=' . $user->id_user
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Terjadi kesalahan: ' . $e->getMessage()
            ], 500);
        }
    }


    public function logout()
    {
        try {
            Auth::logout();
            request()->session()->invalidate();
            request()->session()->regenerateToken();

            return response()->json([
                'success' => true,
                'message' => 'Anda telah keluar',
                'redirect' => '/home?logout=true'
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal logout!',
                'error' => config('app.debug') ? $e->getMessage() : null
            ], 500);
        }
    }
    // public function googleRedirect()
    // {
    //     return Socialite::driver('google')
    //         ->scopes(['openid', 'profile', 'email'])
    //         ->redirect();
    // }

    // public function googleCallback(Request $request)
    // {
    //     try {
    //         $googleUser = Socialite::driver('google')->stateless()->user();

    //         $user = User::where('email', $googleUser->getEmail())
    //             ->orWhere('google_id', $googleUser->getId())
    //             ->first();

    //         if (!$user) {
    //             $user = User::create([
    //                 'nama' => $googleUser->getName() ?? 'User',
    //                 'email' => $googleUser->getEmail(),
    //                 'google_id' => $googleUser->getId(),
    //                 'nomor_hp' => null, // karena sudah nullable di tabelmu ✅
    //                 'password' => Hash::make(Str::random(32)),
    //                 'avatar' => $googleUser->getAvatar() ?? 'images/avatar/default-avatar.png',
    //                 'akses' => 'UMUM',
    //             ]);
    //         } else {
    //             if (empty($user->google_id)) {
    //                 $user->google_id = $googleUser->getId();
    //             }
    //             if (!empty($googleUser->getAvatar())) {
    //                 $user->avatar = $googleUser->getAvatar();
    //             }
    //             if (!empty($googleUser->getName())) {
    //                 $user->nama = $googleUser->getName();
    //             }
    //             $user->save();
    //         }

    //         // aturan kamu: cegah admin login dari sini
    //         if (in_array($user->akses, ['ADMINISTRATOR', 'OPD', 'PIMPINAN', 'EKSEKUTIF'])) {
    //             Auth::logout();
    //             $request->session()->invalidate();
    //             return redirect('/login')->with('error', 'Admin/pengelola tidak boleh login di sini');
    //         }

    //         Auth::login($user);
    //         $request->session()->regenerate();

    //         return redirect('/home?user_id_to_push=' . $user->id_user);
    //     } catch (\Exception $e) {
    //         return redirect('/login')->with('error', 'Login Google gagal: ' . $e->getMessage());
    //     }
    // }
    // AuthController.php
  public function googleCallback(Request $request)
{
    try {
        $googleUser = Socialite::driver('google')->stateless()->user();

        $user = User::where('email', $googleUser->getEmail())
            ->orWhere('google_id', $googleUser->getId())
            ->first();

        if (!$user) {
            $user = User::create([
                'nama'      => $googleUser->getName() ?? 'User',
                'email'     => $googleUser->getEmail(),
                'google_id' => $googleUser->getId(),
                'nomor_hp'  => null,
                'password'  => Hash::make(Str::random(32)),
                'avatar'    => $googleUser->getAvatar() ?? 'images/avatar/default-avatar.png',
                'akses'     => 'UMUM',
            ]);
        } else {
            if (empty($user->google_id))  $user->google_id = $googleUser->getId();
            if ($googleUser->getAvatar()) $user->avatar    = $googleUser->getAvatar();
            if ($googleUser->getName())   $user->nama      = $googleUser->getName();
            $user->save();
        }

        if (in_array($user->akses, ['ADMINISTRATOR', 'OPD', 'PIMPINAN', 'EKSEKUTIF'])) {
            return redirect('/login')->with('error', 'Admin tidak diizinkan login di sini');
        }

        // ✅ Deteksi dari app
        $fromApp = $request->query('state') && str_contains($request->query('state'), 'from_app');

        if ($fromApp) {
            // ✅ Simpan token ke DATABASE (bukan cache)
            $token = Str::random(64);
            
            DB::table('google_login_tokens')->insert([
                'token'      => $token,
                'user_id'    => $user->id_user,
                'expires_at' => now()->addMinutes(5),
            ]);

            return redirect("mallumkm://login?token={$token}");
        }

        // Login biasa web
        Auth::login($user);
        $request->session()->regenerate();
        return redirect('/home?user_id_to_push=' . $user->id_user);

    } catch (\Exception $e) {
        return redirect('/login')->with('error', 'Login Google gagal: ' . $e->getMessage());
    }
}

public function loginFromApp(Request $request)
{
    $token = $request->query('token');

    if (!$token) {
        return redirect('/login')->with('error', 'Token tidak valid');
    }

    // ✅ Ambil dari database
    $row = DB::table('google_login_tokens')
        ->where('token', $token)
        ->where('expires_at', '>', now())
        ->first();

    if (!$row) {
        return redirect('/login')->with('error', 'Token kadaluarsa, silakan login ulang');
    }

    $user = User::find($row->user_id);

    if (!$user) {
        return redirect('/login')->with('error', 'User tidak ditemukan');
    }

    // ✅ Hapus token agar tidak bisa dipakai ulang
    DB::table('google_login_tokens')->where('token', $token)->delete();

    // ✅ Login
    Auth::login($user, true);
    $request->session()->regenerate();

    return redirect('/home?user_id_to_push=' . $user->id_user);
}
    // AuthController.php — tambahkan method ini
 public function loginFromApp(Request $request)
{
    $token = $request->query('token');

    if (!$token) {
        return redirect('/login')->with('error', 'Token tidak valid');
    }

    // ✅ Ambil dari database
    $row = DB::table('google_login_tokens')
        ->where('token', $token)
        ->where('expires_at', '>', now())
        ->first();

    if (!$row) {
        return redirect('/login')->with('error', 'Token kadaluarsa, silakan login ulang');
    }

    $user = User::find($row->user_id);

    if (!$user) {
        return redirect('/login')->with('error', 'User tidak ditemukan');
    }

    // ✅ Hapus token agar tidak bisa dipakai ulang
    DB::table('google_login_tokens')->where('token', $token)->delete();

    // ✅ Login
    Auth::login($user, true);
    $request->session()->regenerate();

    return redirect('/home?user_id_to_push=' . $user->id_user);
}
public function googleRedirect(Request $request)
{
    $fromApp = $request->query('from_app');

    $driver = Socialite::driver('google')
        ->scopes(['openid', 'profile', 'email']);

    if ($fromApp) {
        $driver = $driver->with(['state' => 'from_app_' . Str::random(8)]);
    }

    return $driver->redirect();
}
}

// namespace App\Http\Controllers\Userumkm;

// use App\Http\Controllers\Controller;

// use Illuminate\Http\Request;
// use Illuminate\Support\Facades\Auth;
// use Illuminate\Support\Facades\Hash;
// use Illuminate\Support\Facades\Session;
// use App\Models\User;
// use Illuminate\Support\Facades\DB;
// use Illuminate\Support\Facades\Http; // ✅ TAMBAH INI
// use Laravel\Socialite\Facades\Socialite;
// use Illuminate\Support\Str;

// class AuthController extends Controller
// {
//     public function auth()
//     {
//         $dataview['page_title'] = 'Login';
//         $dataview['cfg'] = DB::table('mall_umkm_kop_config')
//             ->whereIn('params_config', ['LOGO', 'NAMA', 'ALAMAT'])
//             ->pluck('value_config', 'params_config');

//         // ✅ LOGO DINAMIS
//         $dataview['logoAdmin'] = !empty($dataview['cfg']['LOGO'] ?? null)
//             ? asset('assets/admin-umkm/img/logo/' . $dataview['cfg']['LOGO'])
//             : asset('images/logo.png');

//         return view('pages.user.umkm.login', $dataview);
//     }

//     public function regis()
//     {
//         $dataview['page_title'] = 'Register';
//         $dataview['cfg'] = DB::table('mall_umkm_kop_config')
//             ->whereIn('params_config', ['LOGO', 'NAMA', 'ALAMAT'])
//             ->pluck('value_config', 'params_config');

//         $dataview['logoAdmin'] = !empty($dataview['cfg']['LOGO'] ?? null)
//             ? asset('assets/admin-umkm/img/logo/' . $dataview['cfg']['LOGO'])
//             : asset('images/logo.png');

//         return view('pages.user.umkm.register', $dataview);
//     }

//     public function login(Request $request)
//     {
//         // ✅ tambah validasi g-recaptcha-response
//         $request->validate([
//             'email' => 'required|email',
//             'password' => 'required|string',
//             'g-recaptcha-response' => 'required',
//         ], [
//             'g-recaptcha-response.required' => 'Mohon centang captcha terlebih dahulu.'
//         ]);

//         // ✅ verifikasi captcha ke Google
//         try {
//             $captchaResponse = $request->input('g-recaptcha-response');

//             $verify = Http::asForm()->post('https://www.google.com/recaptcha/api/siteverify', [
//                 'secret'   => env('RECAPTCHA_SECRET_KEY'),
//                 'response' => $captchaResponse,
//                 'remoteip' => $request->ip(),
//             ]);

//             if (!data_get($verify->json(), 'success', false)) {
//                 return response()->json([
//                     'success' => false,
//                     'message' => 'Verifikasi captcha gagal. Silakan coba lagi.'
//                 ], 422);
//             }
//         } catch (\Exception $e) {
//             return response()->json([
//                 'success' => false,
//                 'message' => 'Gagal memverifikasi captcha.',
//                 'error' => config('app.debug') ? $e->getMessage() : null
//             ], 500);
//         }

//         // ✅ lanjut login seperti semula (tanpa ubah flow besar)
//         $credentials = $request->only('email', 'password');

//         try {
//             if (Auth::attempt($credentials, $request->remember)) {

//                 $user = Auth::user();

//                 if (in_array($user->akses, ['ADMINISTRATOR', 'OPD', 'PIMPINAN', 'EKSEKUTIF'])) {
//                     Auth::logout();
//                     $request->session()->invalidate();

//                     return response()->json([
//                         'success' => false,
//                         'message' => 'Admin atau pengelola tidak diizinkan login melalui halaman ini'
//                     ], 403);
//                 }

//                 $request->session()->regenerate();

//                 return response()->json([
//                     'success' => true,
//                     'message' => 'Login berhasil',
//                     'redirect' => '/home?user_id_to_push=' . $user->id_user
//                 ]);
//             }

//             return response()->json([
//                 'success' => false,
//                 'message' => 'Email atau password salah'
//             ], 401);
//         } catch (\Exception $e) {
//             return response()->json([
//                 'success' => false,
//                 'message' => 'Terjadi kesalahan sistem',
//                 'error' => config('app.debug') ? $e->getMessage() : null
//             ], 500);
//         }
//     }

//     public function register(Request $request)
//     {
//         // ✅ tambah validasi g-recaptcha-response
//         $validated = $request->validate([
//             'nama' => 'required|string|max:255',
//             'email' => 'required|email|max:255|unique:mall_umkm_kop_user,email',
//             'nomor_hp' => [
//                 'required',
//                 'string',
//                 'min:10',
//                 'max:13',
//                 'regex:/^08[0-9]{8,11}$/'
//             ],
//             'password' => 'required|min:6|same:confirmPassword',

//             // ✅ CAPTCHA required
//             'g-recaptcha-response' => 'required',
//         ], [
//             'g-recaptcha-response.required' => 'Mohon centang captcha terlebih dahulu.'
//         ]);

//         // ✅ verifikasi captcha ke Google (sama seperti login)
//         try {
//             $captchaResponse = $request->input('g-recaptcha-response');

//             $verify = Http::asForm()->post('https://www.google.com/recaptcha/api/siteverify', [
//                 'secret'   => env('RECAPTCHA_SECRET_KEY'),
//                 'response' => $captchaResponse,
//                 'remoteip' => $request->ip(),
//             ]);

//             if (!data_get($verify->json(), 'success', false)) {
//                 return response()->json([
//                     'success' => false,
//                     'message' => 'Verifikasi captcha gagal. Silakan coba lagi.'
//                 ], 422);
//             }
//         } catch (\Exception $e) {
//             return response()->json([
//                 'success' => false,
//                 'message' => 'Gagal memverifikasi captcha.',
//                 'error' => config('app.debug') ? $e->getMessage() : null
//             ], 500);
//         }

//         try {
//             // Simpan user ke database
//             $user = User::create([
//                 'nama' => $validated['nama'],
//                 'email' => $validated['email'],
//                 'nomor_hp' => $validated['nomor_hp'],
//                 'password' => Hash::make($validated['password']),
//                 'avatar' => 'images/avatar/default-avatar.png',
//                 'akses' => 'UMUM',
//             ]);

//             Auth::login($user);

//             return response()->json([
//                 'success' => true,
//                 'message' => 'Berhasil registrasi!',
//                 'redirect' => '/home?user_id_to_push=' . $user->id_user
//             ], 201);
//         } catch (\Exception $e) {
//             return response()->json([
//                 'success' => false,
//                 'message' => 'Terjadi kesalahan: ' . $e->getMessage()
//             ], 500);
//         }
//     }


//     public function logout()
//     {
//         try {
//             Auth::logout();
//             request()->session()->invalidate();
//             request()->session()->regenerateToken();

//             return response()->json([
//                 'success' => true,
//                 'message' => 'Anda telah keluar',
//                 'redirect' => '/home?logout=true'
//             ]);
//         } catch (\Exception $e) {
//             return response()->json([
//                 'success' => false,
//                 'message' => 'Gagal logout!',
//                 'error' => config('app.debug') ? $e->getMessage() : null
//             ], 500);
//         }
//     }
//     public function googleRedirect()
//     {
//         return Socialite::driver('google')
//             ->scopes(['openid', 'profile', 'email'])
//             ->redirect();
//     }

//     // public function googleCallback(Request $request)
//     // {
//     //     try {
//     //         $googleUser = Socialite::driver('google')->stateless()->user();

//     //         $user = User::where('email', $googleUser->getEmail())
//     //             ->orWhere('google_id', $googleUser->getId())
//     //             ->first();

//     //         if (!$user) {
//     //             $user = User::create([
//     //                 'nama' => $googleUser->getName() ?? 'User',
//     //                 'email' => $googleUser->getEmail(),
//     //                 'google_id' => $googleUser->getId(),
//     //                 'nomor_hp' => null, // karena sudah nullable di tabelmu ✅
//     //                 'password' => Hash::make(Str::random(32)),
//     //                 'avatar' => $googleUser->getAvatar() ?? 'images/avatar/default-avatar.png',
//     //                 'akses' => 'UMUM',
//     //             ]);
//     //         } else {
//     //             if (empty($user->google_id)) {
//     //                 $user->google_id = $googleUser->getId();
//     //             }
//     //             if (!empty($googleUser->getAvatar())) {
//     //                 $user->avatar = $googleUser->getAvatar();
//     //             }
//     //             if (!empty($googleUser->getName())) {
//     //                 $user->nama = $googleUser->getName();
//     //             }
//     //             $user->save();
//     //         }

//     //         // aturan kamu: cegah admin login dari sini
//     //         if (in_array($user->akses, ['ADMINISTRATOR', 'OPD', 'PIMPINAN', 'EKSEKUTIF'])) {
//     //             Auth::logout();
//     //             $request->session()->invalidate();
//     //             return redirect('/login')->with('error', 'Admin/pengelola tidak boleh login di sini');
//     //         }

//     //         Auth::login($user);
//     //         $request->session()->regenerate();

//     //         return redirect('/home?user_id_to_push=' . $user->id_user);
//     //     } catch (\Exception $e) {
//     //         return redirect('/login')->with('error', 'Login Google gagal: ' . $e->getMessage());
//     //     }
//     // }
//     public function googleCallback(Request $request)
//     {
//         try {
//             $googleUser = Socialite::driver('google')->stateless()->user();
    
//             $user = User::where('email', $googleUser->getEmail())
//                 ->orWhere('google_id', $googleUser->getId())
//                 ->first();
    
//             if (!$user) {
//                 $user = User::create([
//                     'nama' => $googleUser->getName() ?? 'User',
//                     'email' => $googleUser->getEmail(),
//                     'google_id' => $googleUser->getId(),
//                     'nomor_hp' => null,
//                     'password' => Hash::make(Str::random(32)),
//                     'avatar' => $googleUser->getAvatar() ?? 'images/avatar/default-avatar.png',
//                     'akses' => 'UMUM',
//                 ]);
//             } else {
//                 if (empty($user->google_id)) {
//                     $user->google_id = $googleUser->getId();
//                 }
//                 if ($googleUser->getAvatar()) {
//                     $user->avatar = $googleUser->getAvatar();
//                 }
//                 if ($googleUser->getName()) {
//                     $user->nama = $googleUser->getName();
//                 }
//                 $user->save();
//             }
    
//             // ❌ blok admin login
//             if (in_array($user->akses, ['ADMINISTRATOR','OPD','PIMPINAN','EKSEKUTIF'])) {
//                 Auth::logout();
//                 $request->session()->invalidate();
//                 return redirect('/login')->with('error','Admin tidak diizinkan login di sini');
//             }
    
//             Auth::login($user);
//             $request->session()->regenerate();
    
//             // 🔥 DETEKSI LOGIN DARI APP
//             $isFromApp =
//                 $request->has('from_app') ||
//                 str_contains($request->userAgent(), 'wv') ||
//                 str_contains($request->userAgent(), 'Flutter');
    
// if ($isFromApp || session('is_from_app')) {
//     $token = encrypt($user->id_user);
//              // Ganti baris redirect-nya menjadi ini (samakan dengan host di manifest):
// // Kita arahkan ke URL https biasa, tapi HP bakal nangkep kalau ini punya APK
//     return redirect("https://mall-umkm.arunikacyber.my.id/login-from-app?token=" . $token);


//             }
    
//             // 🌐 LOGIN WEB BIASA
//             return redirect('/home?user_id_to_push=' . $user->id_user);
    
//         } catch (\Exception $e) {
//             return redirect('/login')->with('error', 'Login Google gagal: ' . $e->getMessage());
//         }
//     }
//     // 1. Arahkan ke Google
//     public function redirectToGoogle(Request $request)
//     {
//         // Tandai jika request datang dari App (WebView)
//         if ($request->has('from_app')) {
//             session(['is_from_app' => true]);
//         }
//         return Socialite::driver('google')->redirect();
//     }

//     // 2. Callback dari Google
//  public function handleGoogleCallback(Request $request)
// {
//     try {
//         // Ambil data user dari Google
//         $googleUser = Socialite::driver('google')->user();
        
//         $user = User::updateOrCreate([
//             'email' => $googleUser->getEmail(),
//         ], [
//             'nama' => $googleUser->getName(),
//             'password' => Hash::make(Str::random(24)),
//             'avatar' => $googleUser->getAvatar() ?? 'images/avatar/default-avatar.png',
//             'akses' => 'UMUM',
//         ]);

//         Auth::login($user);

//         // 🔥 CEK: Jika dari APK, balik ke mallumkm://
//         // Ini dideteksi dari session 'is_from_app' yang diset saat klik di aplikasi
//         if (session('is_from_app') || $request->has('from_app')) {
//             session()->forget('is_from_app');
//             $token = encrypt($user->id_user);
//          // Ganti baris redirect-nya menjadi ini (samakan dengan host di manifest):
// // Kita arahkan ke URL https biasa, tapi HP bakal nangkep kalau ini punya APK
//     return redirect("https://mall-umkm.arunikacyber.my.id/login-from-app?token=" . $token);
//         }

//         // 🌐 CEK: Jika dari WEB BIASA, balik ke home web
//         return redirect()->route('welcome');

//     } catch (\Exception $e) {
//         \Log::error("Google Login Error: " . $e->getMessage());
//         return redirect('/login')->with('error', 'Gagal login Google');
//     }
// }

// // 3. Jembatan Login untuk WebView (Menghilangkan 404)
// public function loginFromApp(Request $request)
// {
//     $token = $request->query('token');
//     try {
//         $userId = decrypt($token);
//         $user = User::find($userId);

//         if ($user) {
//             // 1. Paksa Login dengan Cookie 'Remember Me' (PENTING!)
//             Auth::login($user, true); 
            
//             // 2. Regenerasi session agar WebView punya ID Session baru
//             $request->session()->regenerate();
            
//             // 3. Simpan data ke session manual
//             session([
//                 'id_user' => $user->id_user,
//                 'akses_user' => $user->akses
//             ]);

//             // 4. PAKSA SIMPAN SESSION KE SERVER (Ini yang sering kelewat)
//             $request->session()->save();

//             // 5. Kirim respon balik ke WebView
//             // Kita pakai HTML kecil agar WebView benar-benar mencatat perubahan cookie
//             return response("
//                 <html>
//                 <body style='display:flex; justify-content:center; align-items:center; height:100vh; font-family:sans-serif;'>
//                     <div style='text-align:center;'>
//                         <h2>Menghubungkan Akun...</h2>
//                         <p>Mohon tunggu sebentar.</p>
//                         <script>
//                             // Simpan tanda di storage browser
//                             localStorage.setItem('app_logged_in', 'true');
//                             // Redirect ke home setelah 1 detik
//                             setTimeout(function(){
//                                 window.location.href = '/home?user_id_to_push=" . $user->id_user . "';
//                             }, 1000);
//                         </script>
//                     </div>
//                 </body>
//                 </html>
//             ");
//         }
//     } catch (\Exception $e) {
//         \Log::error("LoginFromApp Error: " . $e->getMessage());
//         return redirect('/login');
//     }
//     return redirect('/login');
// }
// }
