package com.example.juice_shop

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.juice_shop/printer"
    private var outputStream: OutputStream? = null
    private var socket: BluetoothSocket? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "connectPrinter" -> {
                    val mac = call.argument<String>("macAddress")
                    connectPrinter(mac!!)
                    result.success(true)
                }

                "printText" -> {
                    val text = call.argument<String>("text")
                    printText(text!!)
                    result.success(true)
                }

                "disconnectPrinter" -> {
                    disconnectPrinter()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    // 🔹 Connect to Bluetooth Printer
    private fun connectPrinter(mac: String) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        val device: BluetoothDevice = adapter.getRemoteDevice(mac)

        val uuid: UUID = device.uuids[0].uuid
        socket = device.createRfcommSocketToServiceRecord(uuid)
        socket!!.connect()

        outputStream = socket!!.outputStream
    }

    // 🔹 Print Text
    private fun printText(text: String) {
        outputStream?.write(text.toByteArray())
        outputStream?.flush()
    }

    // 🔹 Disconnect
    private fun disconnectPrinter() {
        outputStream?.close()
        socket?.close()
    }
}

