package io.mosip.tuvali.transfer

import android.util.Log
import io.mosip.tuvali.transfer.Util.Companion.intToTwoBytesBigEndian
import io.mosip.tuvali.transfer.Util.Companion.getLogTag
import org.bouncycastle.util.encoders.Hex
import kotlin.math.log

class Chunker(private val data: ByteArray, private val maxDataBytes: Int) :
  ChunkerBase(maxDataBytes) {
  private val logTag = getLogTag(javaClass.simpleName)
  private var chunksReadCounter: Int = 0
  private val lastChunkByteCount = getLastChunkByteCount(data.size)
  private val totalChunkCount = getTotalChunkCount(data.size).toInt()
  private val preSlicedChunks: Array<ByteArray?> = Array(totalChunkCount) { null }

  init {
    Log.i(logTag, "Total number of chunks calculated: $totalChunkCount")
    for (idx in 0 until totalChunkCount) {
      preSlicedChunks[idx] = chunk(idx)
    }
    //Log.d(logTag, "Chunks pre-populated in ${System.currentTimeMillis() - startTime} ms time")
  }

  fun next(): ByteArray {
    val seqNumber = chunksReadCounter
    chunksReadCounter++
    return preSlicedChunks[seqNumber]!!
  }

  fun chunkBySequenceNumber(num: Int): ByteArray {
    return preSlicedChunks[num]!!
  }

  private fun chunk(seqNumber: Int): ByteArray {
    val fromIndex = seqNumber * effectivePayloadSize

    return if (seqNumber == (totalChunkCount - 1) && lastChunkByteCount > 0) {
      Log.d(logTag, "fetching last chunk")
      frameChunk(seqNumber, fromIndex, fromIndex + lastChunkByteCount)
    } else {
      val toIndex = (seqNumber + 1) * effectivePayloadSize
      frameChunk(seqNumber, fromIndex, toIndex)
    }
  }

  /*
      <------------------------------- MTU ----------------------------------------------->
      + --------------------- + --------------------------- + --------------------------- +
      |                       |                             |                             |
      |  chunk sequence no    |        chunk payload        |   checksum value of data    |
      |      (2 bytes)        |      (upto MTU-4 bytes)     |        ( 2 bytes)           |
      |                       |                             |                             |
      + --------------------- + --------------------------- + --------------------------- +
   */
  private fun frameChunk(seqNumber: Int, fromIndex: Int, toIndex: Int): ByteArray {
    //Log.d(logTag, "fetching chunk size: ${toIndex - fromIndex}, chunkSequenceNumber(0-indexed): $seqNumber")
    val dataChunk = intToTwoBytesBigEndian(seqNumber) + data.copyOfRange(fromIndex, toIndex)
    val crc = CRCValidator.calculate(dataChunk)

    return dataChunk + intToTwoBytesBigEndian(crc.toInt())
  }

  fun isComplete(): Boolean {
    val isComplete = chunksReadCounter > (totalChunkCount - 1)
    if (isComplete) {
      Log.d(
        logTag,
        "isComplete: true, totalChunks: $totalChunkCount , chunkReadCounter(1-indexed): $chunksReadCounter"
      )
    }
    return isComplete
  }
}
