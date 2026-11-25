package com.example.map1

/**
 * Progress/status events from the casting transports.
 *
 * Same rule as [BleError]: senders publish structured values, the i18n layer
 * renders them. These are not failures — they are the snackbar/toast lines that
 * tell the operator what the link is doing.
 */

/** Status lines emitted by [NaviBleFrameSender]. */
sealed interface CastStatus {
    data object Initializing : CastStatus

    /** ATT payload too small for one protocol chunk; casting cannot start. */
    data object MtuTooSmall : CastStatus
    data object Started : CastStatus
    data object Stopped : CastStatus

    /** BLE link dropped while casting. */
    data object DeviceDisconnected : CastStatus

    /** BEGIN_RSP never arrived. */
    data object DeviceNoResponse : CastStatus

    /** BEGIN_RSP arrived with a non-zero status byte. */
    data class DeviceRejected(val status: Int) : CastStatus

    /** Device sent ABORT while a frame was in flight. */
    data class DeviceAborted(val reason: Int) : CastStatus

    /** Too many consecutive unconfirmed frames; a retry is under way. */
    data class FramesDropped(val failStreak: Int, val reason: FrameFailure) : CastStatus

    /** Confirmation is flowing again after a degraded window. */
    data object Recovered : CastStatus

    /** Device-reported casting area, in pixels. */
    data class DeviceArea(val width: Int, val height: Int) : CastStatus
}

/** Why a frame was not committed, surfaced inside [CastStatus.FramesDropped]. */
sealed interface FrameFailure {
    data object AckMissing : FrameFailure
    data object BeginWriteFailed : FrameFailure
    data object BeginRejected : FrameFailure
    data object DataWriteFailed : FrameFailure
    data object EndWriteFailed : FrameFailure

    /** Device answered with a non-zero accept status. */
    data class Rejected(val status: Int, val error: Int) : FrameFailure
}

//** Status lines emitted by [com.example.map1.navi.NaviJpgTcpSender]. */
sealed interface TcpStatus {
    data class Connected(val host: String, val port: Int, val sendBuffer: Int) : TcpStatus
    data class Disconnected(val reason: String?, val retryDelayMs: Long) : TcpStatus
    data object Stopped : TcpStatus
}
