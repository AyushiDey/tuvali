package io.mosip.tuvali.openid4vpble.exception

import android.util.Log
import com.facebook.react.bridge.Callback
import io.mosip.tuvali.transfer.Util
import io.mosip.tuvali.verifier.exception.VerifierException
import io.mosip.tuvali.verifier.exception.VerifierExceptionHandler
import io.mosip.tuvali.wallet.exception.WalletException
import io.mosip.tuvali.wallet.exception.WalletExceptionHandler

class OpenIdBLEExceptionHandler(private val sendError: (String) -> Unit, private val stopBle: (Callback) -> Unit) {
  private val logTag = Util.getLogTag(javaClass.simpleName)
  private var walletExceptionHandler: WalletExceptionHandler = WalletExceptionHandler(sendError)
  private var verifierExceptionHandler: VerifierExceptionHandler = VerifierExceptionHandler(sendError)

  private fun handleWalletException(e: WalletException) {
    walletExceptionHandler.handleException(e)
  }

  private fun handleVerifierException(e: VerifierException) {
    verifierExceptionHandler.handleException(e)
  }

  fun handleException(e: Exception) {
    when (e) {
      is WalletException -> {
        handleWalletException(e)
      }
      is VerifierException -> {
        handleVerifierException(e)
      }
      else -> {
        handleUnknownException(e)
      }
    }

    try{
      stopBle {}
    } catch (e: Exception) {
      Log.d(logTag,"Failed to stop BLE connection while handling exception: $e")
    }
  }

  private fun handleUnknownException(e: Exception) {
    Log.e(logTag, "Unknown exception: ", e)
    sendError(e.message ?: "Something went wrong in BLE: ${e.cause}")
  }
}
