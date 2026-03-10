/**
 * SVGA Player for HarmonyOS NEXT
 * 动态元素实体类
 */

import { image } from '@kit.ImageKit'
import { Svgarect } from '../utils/Svgarect'
import { LogUtils } from '../utils/LogUtils'

export interface TextStyle {
  fontSize?: number
  fontFamily?: string
  color?: string
  textAlign?: CanvasTextAlign
  textBaseline?: CanvasTextBaseline
}

export class Svgadynamicentity {
  private static readonly TAG: string = 'Svgadynamicentity'

  // 动态图片替换
  dynamicImage: Map<string, image.PixelMap> = new Map()

  // 动态文本
  dynamicText: Map<string, string> = new Map()
  dynamicTextStyle: Map<string, TextStyle> = new Map()

  // 动态隐藏
  dynamicHidden: Map<string, boolean> = new Map()

  // 点击区域
  clickArea: Map<string, Svgarect> = new Map()

  // 文本是否已更新（用于缓存刷新）
  isTextDirty: boolean = false

  constructor() {
    LogUtils.debug(Svgadynamicentity.TAG, 'Created dynamic entity')
  }

  /**
   * 设置动态图片
   */
  setDynamicImage(pixelMap: image.PixelMap, forKey: string): void {
    this.dynamicImage.set(forKey, pixelMap)
    LogUtils.info(Svgadynamicentity.TAG, `Set dynamic image for key: ${forKey}`)
  }

  /**
   * 设置动态文本
   */
  setDynamicText(text: string, style: TextStyle, forKey: string): void {
    this.isTextDirty = true
    this.dynamicText.set(forKey, text)
    this.dynamicTextStyle.set(forKey, style)
    LogUtils.info(Svgadynamicentity.TAG, `Set dynamic text for key: ${forKey}`)
  }

  /**
   * 设置动态隐藏
   */
  setDynamicHidden(hidden: boolean, forKey: string): void {
    this.dynamicHidden.set(forKey, hidden)
    LogUtils.info(Svgadynamicentity.TAG, `Set dynamic hidden for key: ${forKey}: ${hidden}`)
  }

  /**
   * 设置点击区域
   */
  setClickArea(rect: Svgarect, forKey: string): void {
    this.clickArea.set(forKey, rect)
    LogUtils.info(Svgadynamicentity.TAG, `Set click area for key: ${forKey}`)
  }

  /**
   * 获取动态图片
   */
  getDynamicImage(forKey: string): image.PixelMap | undefined {
    return this.dynamicImage.get(forKey)
  }

  /**
   * 获取动态文本
   */
  getDynamicText(forKey: string): string | undefined {
    return this.dynamicText.get(forKey)
  }

  /**
   * 获取动态文本样式
   */
  getDynamicTextStyle(forKey: string): TextStyle | undefined {
    return this.dynamicTextStyle.get(forKey)
  }

  /**
   * 是否被隐藏
   */
  isHidden(forKey: string): boolean {
    return this.dynamicHidden.get(forKey) ?? false
  }

  /**
   * 清除文本脏标记
   */
  clearTextDirty(): void {
    this.isTextDirty = false
  }

  /**
   * 清空所有动态元素
   */
  clear(): void {
    this.dynamicImage.clear()
    this.dynamicText.clear()
    this.dynamicTextStyle.clear()
    this.dynamicHidden.clear()
    this.clickArea.clear()
    this.isTextDirty = false
    LogUtils.info(Svgadynamicentity.TAG, 'Cleared all dynamic elements')
  }
}
