/**
 * SVGA Player for HarmonyOS NEXT
 * 视频数据实体类 - 存储 SVGA 动画的所有数据
 */

import { image } from '@kit.ImageKit'
import { Svgarect } from '../utils/Svgarect'
import { Svgavideospriteentity } from './Svgavideospriteentity'
import { LogUtils } from '../utils/LogUtils'
import { VideoEntityConstructorParams } from '../types/SVGATypes'

export class Svgavideoentity {
  private static readonly TAG: string = 'Svgavideoentity'

  // 动画元数据
  readonly version: string = ''
  readonly fps: number = 15
  readonly frames: number = 0
  readonly videoSize: Svgarect = new Svgarect(0, 0, 0, 0)

  // 资源数据
  private imageMap: Map<string, image.PixelMap> = new Map()
  private spriteList: Array<Svgavideospriteentity> = []

  // 抗锯齿
  antiAlias: boolean = true

  constructor(params?: VideoEntityConstructorParams) {
    if (params) {
      this.version = params.version ?? ''
      this.fps = params.fps ?? 15
      this.frames = params.frames ?? 0

      if (params.videoSize) {
        this.videoSize = new Svgarect(
          params.videoSize.x ?? 0,
          params.videoSize.y ?? 0,
          params.videoSize.width ?? 0,
          params.videoSize.height ?? 0
        )
      }
    }

    LogUtils.printDivider(Svgavideoentity.TAG, 'Created Video Entity')
    LogUtils.info(Svgavideoentity.TAG,
      `Version: ${this.version}, FPS: ${this.fps}, Frames: ${this.frames}, Size: ${this.videoSize.toString()}`)
  }

  /**
   * 添加图片资源
   */
  addImage(key: string, pixelMap: image.PixelMap): void {
    // 移除 .matte 后缀
    const bitmapKey = key.endsWith('.matte') ? key.slice(0, -6) : key
    this.imageMap.set(bitmapKey, pixelMap)
    LogUtils.debug(Svgavideoentity.TAG, `Added image: ${bitmapKey}`)
  }

  /**
   * 获取图片资源
   */
  getImage(key: string): image.PixelMap | undefined {
    return this.imageMap.get(key)
  }

  /**
   * 检查是否有图片
   */
  hasImage(key: string): boolean {
    return this.imageMap.has(key)
  }

  /**
   * 添加精灵
   */
  addSprite(sprite: Svgavideospriteentity): void {
    this.spriteList.push(sprite)
  }

  /**
   * 设置精灵列表
   */
  setSprites(sprites: Array<Svgavideospriteentity>): void {
    this.spriteList = sprites
    LogUtils.info(Svgavideoentity.TAG, `Set ${sprites.length} sprites`)
  }

  /**
   * 获取精灵列表
   */
  getSprites(): Array<Svgavideospriteentity> {
    return this.spriteList
  }

  /**
   * 获取指定索引的精灵
   */
  getSpriteAt(index: number): Svgavideospriteentity | null {
    if (index < 0 || index >= this.spriteList.length) {
      return null
    }
    return this.spriteList[index]
  }

  /**
   * 获取图片数量
   */
  getImageCount(): number {
    return this.imageMap.size
  }

  /**
   * 获取精灵数量
   */
  getSpriteCount(): number {
    return this.spriteList.length
  }

  /**
   * 计算动画时长（毫秒）
   */
  getDuration(): number {
    return (this.frames / this.fps) * 1000
  }

  /**
   * 释放资源
   */
  clear(): void {
    LogUtils.printDivider(Svgavideoentity.TAG, 'Clearing Video Entity')

    // 释放图片资源
    this.imageMap.forEach((pixelMap, key) => {
      try {
        pixelMap.release()
        LogUtils.debug(Svgavideoentity.TAG, `Released image: ${key}`)
      } catch (e) {
        LogUtils.error(Svgavideoentity.TAG, `Failed to release image: ${key}`, e as Error)
      }
    })
    this.imageMap.clear()

    // 清空精灵列表
    this.spriteList = []

    LogUtils.info(Svgavideoentity.TAG, 'Video entity cleared')
  }
}
