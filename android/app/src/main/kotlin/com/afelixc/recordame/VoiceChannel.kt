package com.afelixc.recordame

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dictado con pausas largas (canal `recordame/voz`).
 *
 * Es el mismo reconocimiento de voz de Android que usa el plugin, pero acá se
 * le pide que espere mucho más antes de cortar cuando uno hace una pausa. Hay
 * teléfonos que no hacen caso de ese pedido: en ese caso se corta como siempre
 * y Dart lo vuelve a prender (igual que con el plugin).
 */
class VoiceChannel(
    private val context: Context,
    private val channel: MethodChannel,
) {
    private var recognizer: SpeechRecognizer? = null

    fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "disponible" -> result.success(SpeechRecognizer.isRecognitionAvailable(context))
            "escuchar" -> {
                result.success(listen(call.argument<String>("idioma") ?: "es-AR"))
            }
            "parar" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "cancelar" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun release() {
        recognizer?.apply {
            setRecognitionListener(null)
            cancel()
            destroy()
        }
        recognizer = null
    }

    private fun listen(language: String): Boolean {
        release()
        if (!SpeechRecognizer.isRecognitionAvailable(context)) return false
        val rec = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}

            override fun onPartialResults(partialResults: Bundle?) {
                send(partialResults, false)
            }

            override fun onResults(results: Bundle?) {
                send(results, true)
                channel.invokeMethod("fin", null)
            }

            override fun onError(error: Int) {
                channel.invokeMethod("error", error)
                channel.invokeMethod("fin", null)
            }
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            // Cuánto silencio espera antes de dar por terminada la frase.
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 12000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 10000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 20000L)
        }
        rec.startListening(intent)
        return true
    }

    private fun send(bundle: Bundle?, last: Boolean) {
        val words = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?: return
        channel.invokeMethod("texto", mapOf("texto" to words, "final" to last))
    }
}
