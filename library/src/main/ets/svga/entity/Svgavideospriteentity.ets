/**
 * SVGA Player for HarmonyOS NEXT
 * 精灵实体类
 */

import { Svgavideospriteframeentity } from './Svgavideospriteframeentity'
import { LogUtils } from '../utils/LogUtils'
import { SpriteEntityParams, FrameEntityParams } from '../types/SVGATypes'

export class Svgavideospriteentity {
  private static readonly TAG: string = 'Svgavideospriteentity'

  readonly imageKey: string | null = null
  readonly matteKey: string | null = null
  readonly frames: Array<Svgavideospriteframeentity> = []

  constructor(entity?: SpriteEntityParams) {
    if (entity) {
      this.imageKey = entity.imageKey ?? null
      this.matteKey = entity.matteKey ?? null

      if (entity.frames) {
        this.frames = entity.frames.map(frame => new Svgavideospriteframeentity(frame))
      }

      LogUtils.debug(Svgavideospriteentity.TAG,
        `Created sprite entity: imageKey=${this.imageKey}, frames=${this.frames.length}`)
    }
  }

  /**
   * 获取指定帧数据
   */
  getFrameAt(index: number): Svgavideospriteframeentity | null {
    if (index < 0 || index >= this.frames.length) {
      return null
    }
    return this.frames[index]
  }

  /**
   * 是否为遮罩精灵
   */
  isMatte(): boolean {
    return this.imageKey?.endsWith('.matte') ?? false
  }

  /**
   * 是否有遮罩
   */
  hasMatte(): boolean {
    return this.matteKey !== null && this.matteKey.length > 0
  }
}
