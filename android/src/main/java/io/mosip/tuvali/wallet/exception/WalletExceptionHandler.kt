package io.mosip.tuvali.wallet.exception

import android.util.Log
import io.mosip.tuvali.openid4vpble.exception.StateHandlerException
import io.mosip.tuvali.openid4vpble.exception.TransferHandlerException
import io.mosip.tuvali.transfer.Util

class WalletExceptionHandler(val sendError: (String) -> Unit) {
  private val logTag = Util.getLogTag(javaClass.simpleName)

  fun handleException(e: WalletException){
    when (e.cause?.javaClass?.simpleName) {
      StateHandlerException::class.simpleName -> Log.e(logTag, "Wallet State Handler Exception: ", e.cause)
      TransferHandlerException::class.simpleName -> Log.e(logTag, "Wallet Transfer Handler Exception: ", e.cause)
      else -> Log.e(logTag, "Wallet Exception:", e)
    }
    sendError(e.message ?: "Something went wrong in Wallet: ${e.cause}")
  }
}
