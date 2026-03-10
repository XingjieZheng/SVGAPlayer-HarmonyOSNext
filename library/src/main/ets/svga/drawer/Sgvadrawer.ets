/**
 * SVGA Player for HarmonyOS NEXT
 * 基础渲染器类
 */

import { Svgavideoentity } from '../entity/Svgavideoentity'
import { Svgadynamicentity } from '../entity/Svgadynamicentity'
import { Svgarect } from '../utils/Svgarect'
import { LogUtils } from '../utils/LogUtils'

export abstract class Sgvadrawer {
  protected static readonly TAG: string = 'Sgvadrawer'

  protected videoItem: Svgavideoentity | null = null
  protected dynamicItem: Svgadynamicentity | null = null
  protected scaleInfo: Svgarect = new Svgarect(0, 0, 1, 1)
  protected currentFrame: number = 0

  constructor(videoItem: Svgavideoentity, dynamicItem: Svgadynamicentity) {
    this.videoItem = videoItem
    this.dynamicItem = dynamicItem
    LogUtils.debug(Sgvadrawer.TAG, 'Created drawer')
  }

  /**
   * 设置视频实体
   */
  setVideoItem(videoItem: Svgavideoentity): void {
    this.videoItem = videoItem
    LogUtils.debug(Sgvadrawer.TAG, 'Video item set')
  }

  /**
   * 设置动态元素
   */
  setDynamicItem(dynamicItem: Svgadynamicentity): void {
    this.dynamicItem = dynamicItem
    LogUtils.debug(Sgvadrawer.TAG, 'Dynamic item set')
  }

  /**
   * 设置缩放信息
   */
  setScaleInfo(scaleInfo: Svgarect): void {
    this.scaleInfo = scaleInfo
    LogUtils.debug(Sgvadrawer.TAG, `Scale info set: ${scaleInfo.toString()}`)
  }

  /**
   * 绘制指定帧
   */
  abstract drawFrame(frameIndex: number): void

  /**
   * 获取当前帧
   */
  getCurrentFrame(): number {
    return this.currentFrame
  }
}
