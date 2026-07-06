package com.example.map1.search

import android.content.Context
import com.amap.api.services.core.AMapException
import com.amap.api.services.help.Inputtips
import com.amap.api.services.help.InputtipsQuery
import com.amap.api.services.help.Tip

/**
 * 一个被选中的地点，封装了名称、地址以及经纬度。
 */
data class Place(
    val name: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
)

/**
 * 使用高德「输入提示」(Inputtips) 做地点搜索（即“边输入边联想”）。
 *
 * @param context  Context
 * @param keyword  搜索关键字
 * @param city     限定城市，传空串表示全国
 * @param onResult 搜索结果回调（主线程）。只返回带有有效经纬度的结果。
 */
fun searchPlaces(
    context: Context,
    keyword: String,
    city: String = "",
    onResult: (List<Place>) -> Unit,
) {
    if (keyword.isBlank()) {
        onResult(emptyList())
        return
    }

    val query = InputtipsQuery(keyword, city).apply {
        // false 表示不限定在某个城市内，全国范围联想。
        cityLimit = false
    }
    val inputTips = Inputtips(context.applicationContext, query)
    inputTips.setInputtipsListener { tips: MutableList<Tip>?, rCode: Int ->
        if (rCode != AMapException.CODE_AMAP_SUCCESS || tips == null) {
            onResult(emptyList())
            return@setInputtipsListener
        }
        val places = tips.mapNotNull { tip ->
            val point = tip.point ?: return@mapNotNull null // 行政区/无坐标的提示词过滤掉
            Place(
                name = tip.name ?: "",
                address = buildString {
                    if (!tip.district.isNullOrBlank()) append(tip.district)
                    if (!tip.address.isNullOrBlank()) {
                        if (isNotEmpty()) append(" ")
                        append(tip.address)
                    }
                },
                latitude = point.latitude,
                longitude = point.longitude,
            )
        }
        onResult(places)
    }
    inputTips.requestInputtipsAsyn()
}
