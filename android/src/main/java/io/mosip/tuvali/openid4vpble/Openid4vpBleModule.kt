package io.mosip.tuvali.openid4vpble

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import io.mosip.tuvali.common.safeExecute.TryExecuteSync
import io.mosip.tuvali.openid4vpble.exception.OpenIdBLEExceptionHandler
import org.json.JSONObject
import io.mosip.tuvali.transfer.Util.Companion.getLogTag
import io.mosip.tuvali.verifier.Verifier
import io.mosip.tuvali.wallet.Wallet

class Openid4vpBleModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {
  private val logTag = getLogTag(javaClass.simpleName)
  private var verifier: Verifier? = null
  private var wallet: Wallet? = null
  private var bleExceptionHandler = OpenIdBLEExceptionHandler(this::emitNearbyErrorEvent, this::stopBLE)
  private val tryExecuteSync = TryExecuteSync(bleExceptionHandler);

  //Inji contract requires double quotes around the states.
  enum class VCResponseStates(val value: String) {
    RECEIVED("\"RECEIVED\""),
    ACCEPTED("\"ACCEPTED\""),
    REJECTED("\"REJECTED\"")
  }

  enum class NearbyEvents(val value: String) {
    EXCHANGE_RECEIVER_INFO("exchange-receiver-info"),
    EXCHANGE_SENDER_INFO("exchange-sender-info"),
    SEND_VC("send-vc"),
    SEND_VC_RESPONSE("send-vc:response")
  }

  override fun getName(): String {
    return NAME
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun setTuvaliVersion(version: String){
    tuvaliVersion = version
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun getConnectionParameters(): String {
    Log.d(logTag, "getConnectionParameters new verifier object at ${System.nanoTime()}")

    return tryExecuteSync.run {
      if (verifier == null) {
        Log.d(logTag, "synchronized getConnectionParameters new verifier object at ${System.nanoTime()}")
        verifier = Verifier(reactContext, this::emitNearbyMessage, this::emitNearbyEvent, this::onException)
        verifier?.generateKeyPair()
      }

      val payload = verifier?.getAdvIdentifier("OVPMOSIP")
      Log.d(
        logTag,
        "synchronized getConnectionParameters called with adv identifier $payload at ${System.nanoTime()} and verifier hashcode: ${verifier.hashCode()}"
      )

      return@run "{\"cid\":\"ilB8l\",\"pk\":\"${payload}\"}"
    }.orEmpty()
  }

  private fun onException(exception: Throwable){
    if(exception.cause != null){
      Log.e(logTag, "Exception: ${exception.message}");
      bleExceptionHandler.handleException(exception.cause!!)
    } else {
      bleExceptionHandler.handleException(exception)
    }
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun getConnectionParametersDebug(): String {
    return getConnectionParameters()
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun setConnectionParameters(params: String) {
    Log.d(logTag, "setConnectionParameters at ${System.nanoTime()}")

    tryExecuteSync.run {
      if (wallet == null) {
        Log.d(logTag, "synchronized setConnectionParameters new wallet object at ${System.nanoTime()}")
        wallet = Wallet(reactContext, this::emitNearbyMessage, this::emitNearbyEvent, this::onException)
      }
      val paramsObj = JSONObject(params)
      val firstPartOfPk = paramsObj.getString("pk")
      Log.d(
        logTag,
        "synchronized setConnectionParameters called with $params and $firstPartOfPk at ${System.nanoTime()}"
      )
      wallet?.setAdvIdentifier(firstPartOfPk)
    }
  }

  @ReactMethod
  fun createConnection(mode: String, callback: Callback) {
    Log.d(logTag, "createConnection: received request with mode $mode at ${System.nanoTime()}")

    tryExecuteSync.run {
    Log.d(logTag, "synchronized createConnection: received request with mode $mode at ${System.nanoTime()}")
      when (mode) {
        "advertiser" -> {
          verifier?.startAdvertisement("OVPMOSIP", callback)
        }
        "discoverer" -> {
          wallet?.startScanning("OVPMOSIP", callback)
        }
        else -> {
          Log.e(logTag, "synchronizedcreateConnection: received unknown mode: $mode at ${System.nanoTime()}")
        }
      }
    }
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun destroyConnection(callback: Callback) {
    //TODO: Make sure callback can be called only once[Can be done once wallet and verifier split into different modules]
    Log.d(logTag, "destroyConnection called at ${System.nanoTime()}")
    tryExecuteSync.run {
      stopBLE(callback)
    }
  }

  private fun stopBLE(callback: Callback) {
    if (wallet == null && verifier == null) {
        callback()
    } else {
        if (wallet != null) {
          Log.d(logTag, "synchronized destroyConnection called for wallet at ${System.nanoTime()}")
          stopWallet { callback() }
        }
        if (verifier != null) {
          Log.d(logTag, "synchronized destroyConnection called for verifier at ${System.nanoTime()}")
          stopVerifier { callback() }
        }
      }
  }

  private fun stopVerifier(onDestroy: Callback) {
    try {
      verifier?.stop(onDestroy)
    } finally {
      Log.d(logTag, "stopVerifier: setting to null")
      verifier = null
    }
  }

  private fun stopWallet(onDestroy: Callback) {
    try {
      wallet?.stop(onDestroy)
    } catch (e: Throwable) {
      Log.e(logTag, "stopWallet: exception: ${e.message}")
      Log.e(logTag, "stopWallet: exception: ${e.stackTrace}")
      Log.e(logTag, "stopWallet: exception: $e")
    } finally {
      Log.d(logTag, "stopWallet: setting to null")
      wallet = null
    }
  }

  @ReactMethod
  fun send(message: String, callback: Callback) {
    Log.d(logTag, "send: message $message at ${System.nanoTime()}")

    tryExecuteSync.run {
      val messageSplits = message.split("\n", limit = 2)
      when (messageSplits[0]) {
        NearbyEvents.EXCHANGE_RECEIVER_INFO.value -> {
          callback()
        }
        NearbyEvents.EXCHANGE_SENDER_INFO.value -> {
          callback()
          wallet?.writeToIdentifyRequest()
        }
        NearbyEvents.SEND_VC.value -> {
          callback()
          wallet?.sendData(messageSplits[1])
        }
        NearbyEvents.SEND_VC_RESPONSE.value -> {
          verifier?.notifyVerificationStatus(messageSplits[1] == VCResponseStates.ACCEPTED.value)
        }
        else -> {
          Log.d(logTag, "send: received send with unrecognized event")
        }
      }
    }
  }

  private fun emitEvent(eventName: String, data: WritableMap?) {
    reactApplicationContext
      .getJSModule(RCTDeviceEventEmitter::class.java)
      .emit(eventName, data)
  }

  private fun emitNearbyMessage(eventType: String, data: String) {
    val writableMap = Arguments.createMap()
    writableMap.putString("data", "$eventType\n${data}")
    writableMap.putString("type", "msg")
    emitEvent("EVENT_NEARBY", writableMap)
  }

  private fun emitNearbyErrorEvent(message: String) {
    val writableMap = Arguments.createMap()
    writableMap.putString("message", message)
    writableMap.putString("type", "onError")
    emitEvent("EVENT_NEARBY", writableMap)
  }

  private fun emitNearbyEvent(eventType: String) {
    val writableMap = Arguments.createMap()
    writableMap.putString("type", eventType)
    emitEvent("EVENT_NEARBY", writableMap)
  }

  private fun emitLogEvent(eventType: String, data: Map<String, String>) {}

  companion object {
    var tuvaliVersion: String = "unknown"
    const val NAME = "Openid4vpBle"
  }
}
