package com.protoolbag.protoolbag_crm

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biyometrik giriş) bir FragmentActivity ister: düz FlutterActivity ile
// `no_fragment_activity` hatası döner ve parmak izi / yüz ile giriş hiç çalışmaz.
class MainActivity : FlutterFragmentActivity()
