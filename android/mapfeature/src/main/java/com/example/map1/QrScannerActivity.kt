package com.example.map1

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.unit.dp
import com.example.map1.ui.theme.Map1Theme
import com.google.zxing.BarcodeFormat
import com.google.zxing.client.android.Intents
import com.journeyapps.barcodescanner.DecoratedBarcodeView
import com.journeyapps.barcodescanner.DefaultDecoderFactory

/** In-app, QR-only capture screen. The camera is always released when this activity pauses. */
class QrScannerActivity : ComponentActivity() {
    private var barcodeView: DecoratedBarcodeView? = null
    private var resultDelivered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Map1Theme {
                BackHandler { finish() }
                Column(modifier = Modifier.fillMaxSize().safeDrawingPadding()) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        TextButton(onClick = { finish() }) {
                            Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "返回")
                            Text("返回")
                        }
                        Text(
                            text = "扫描接收端二维码",
                            style = MaterialTheme.typography.titleLarge,
                            modifier = Modifier.padding(start = 8.dp),
                        )
                    }
                    AndroidView(
                        factory = { context ->
                            DecoratedBarcodeView(context).also { view ->
                                barcodeView = view
                                view.barcodeView.decoderFactory =
                                    DefaultDecoderFactory(listOf(BarcodeFormat.QR_CODE))
                                view.setStatusText("将二维码放入取景框内")
                                view.decodeContinuous { result ->
                                    if (!resultDelivered && result.text != null) {
                                        resultDelivered = true
                                        setResult(
                                            Activity.RESULT_OK,
                                            Intent().putExtra(Intents.Scan.RESULT, result.text)
                                                .putExtra(Intents.Scan.RESULT_FORMAT, BarcodeFormat.QR_CODE.toString()),
                                        )
                                        finish()
                                    }
                                }
                                view.resume()
                            }
                        },
                        modifier = Modifier.fillMaxWidth().weight(1f),
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        barcodeView?.resume()
    }

    override fun onPause() {
        barcodeView?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        barcodeView?.pause()
        barcodeView = null
        super.onDestroy()
    }
}
