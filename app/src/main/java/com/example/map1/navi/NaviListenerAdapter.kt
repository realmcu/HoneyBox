package com.example.map1.navi

import com.amap.api.navi.AMapNaviListener
import com.amap.api.navi.AMapNaviViewListener
import com.amap.api.navi.AmapPageType
import com.amap.api.navi.model.AMapCalcRouteResult
import com.amap.api.navi.model.AMapLaneInfo
import com.amap.api.navi.model.AMapModelCross
import com.amap.api.navi.model.AMapNaviCameraInfo
import com.amap.api.navi.model.AMapNaviCross
import com.amap.api.navi.model.AMapNaviLocation
import com.amap.api.navi.model.AMapNaviRouteNotifyData
import com.amap.api.navi.model.AMapNaviTrafficFacilityInfo
import com.amap.api.navi.model.AMapServiceAreaInfo
import com.amap.api.navi.model.AimLessModeCongestionInfo
import com.amap.api.navi.model.AimLessModeStat
import com.amap.api.navi.model.NaviInfo

/**
 * AMapNaviListener 接口方法非常多，这里提供一个空实现的适配器，
 * 业务代码只需重写真正关心的回调即可。
 */
open class NaviListenerAdapter : AMapNaviListener {
    override fun onInitNaviFailure() {}
    override fun onInitNaviSuccess() {}
    override fun onStartNavi(type: Int) {}
    override fun onTrafficStatusUpdate() {}
    override fun onLocationChange(location: AMapNaviLocation?) {}
    override fun onGetNavigationText(type: Int, text: String?) {}
    override fun onGetNavigationText(text: String?) {}
    override fun onEndEmulatorNavi() {}
    override fun onArriveDestination() {}
    override fun onCalculateRouteFailure(errorCode: Int) {}
    override fun onReCalculateRouteForYaw() {}
    override fun onReCalculateRouteForTrafficJam() {}
    override fun onArrivedWayPoint(wayID: Int) {}
    override fun onGpsOpenStatus(enabled: Boolean) {}
    override fun onNaviInfoUpdate(naviInfo: NaviInfo?) {}
    override fun updateCameraInfo(cameraInfos: Array<out AMapNaviCameraInfo>?) {}
    override fun updateIntervalCameraInfo(
        start: AMapNaviCameraInfo?,
        end: AMapNaviCameraInfo?,
        distance: Int
    ) {}
    override fun onServiceAreaUpdate(serviceAreaInfos: Array<out AMapServiceAreaInfo>?) {}
    override fun showCross(cross: AMapNaviCross?) {}
    override fun hideCross() {}
    override fun showModeCross(cross: AMapModelCross?) {}
    override fun hideModeCross() {}
    override fun showLaneInfo(laneInfos: Array<out AMapLaneInfo>?, laneBackgroundInfo: ByteArray?, laneRecommendedInfo: ByteArray?) {}
    override fun showLaneInfo(laneInfo: AMapLaneInfo?) {}
    override fun hideLaneInfo() {}
    override fun onCalculateRouteSuccess(ints: IntArray?) {}
    override fun notifyParallelRoad(type: Int) {}
    override fun OnUpdateTrafficFacility(infos: Array<out AMapNaviTrafficFacilityInfo>?) {}
    override fun OnUpdateTrafficFacility(info: AMapNaviTrafficFacilityInfo?) {}
    override fun updateAimlessModeStatistics(stat: AimLessModeStat?) {}
    override fun updateAimlessModeCongestionInfo(info: AimLessModeCongestionInfo?) {}
    override fun onPlayRing(type: Int) {}
    override fun onCalculateRouteSuccess(result: AMapCalcRouteResult?) {}
    override fun onCalculateRouteFailure(result: AMapCalcRouteResult?) {}
    override fun onNaviRouteNotify(data: AMapNaviRouteNotifyData?) {}
    override fun onGpsSignalWeak(weak: Boolean) {}
}

/**
 * AMapNaviViewListener 空实现适配器。
 */
open class NaviViewListenerAdapter : AMapNaviViewListener {
    override fun onNaviSetting() {}
    override fun onNaviCancel() {}
    override fun onNaviBackClick(): Boolean = false
    override fun onNaviMapMode(mode: Int) {}
    override fun onNaviTurnClick() {}
    override fun onNextRoadClick() {}
    override fun onScanViewButtonClick() {}
    override fun onLockMap(locked: Boolean) {}
    override fun onNaviViewLoaded() {}
    override fun onMapTypeChanged(type: Int) {}
    override fun onNaviViewShowMode(mode: Int) {}
    override fun onStopSpeaking() {}
    override fun onViewTypeChanged(type: AmapPageType?) {}
    override fun onAMapNaviViewExit() {}
    override fun onStrategyChanged(strategy: Int) {}
    override fun onBroadcastModeChanged(mode: Int) {}
    override fun onDayAndNightModeChanged(mode: Int) {}
    override fun onScaleAutoChanged(scaleAuto: Boolean) {}
    override fun onListenToVoiceDuringCallChanged(enabled: Boolean) {}
    override fun onControlMusicVolumeModeChanged(mode: Int) {}
    override fun onEagleChanged(eagle: Boolean) {}
    override fun onNaviRouteHighlightChange(id: Long, type: Int) {}
}
