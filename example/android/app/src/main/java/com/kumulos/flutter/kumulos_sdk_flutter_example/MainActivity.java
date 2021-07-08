package com.kumulos.flutter.kumulos_sdk_flutter_example;

import android.content.Intent;
import android.os.Bundle;

import com.kumulos.android.Kumulos;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Kumulos.seeIntent(this, getIntent(), savedInstanceState);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        Kumulos.seeInputFocus(this, hasFocus);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Kumulos.seeIntent(this, intent);
    }
}
