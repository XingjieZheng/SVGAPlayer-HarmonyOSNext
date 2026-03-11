/**
 * SVGA Player for HarmonyOS NEXT
 * 精灵实体类
 */

import { Svgavideospriteframeentity } from './Svgavideospriteframeentity'
import { LogUtils } from '../utils/LogUtils'
import { SpriteEntityParams, FrameEntityParams, ShapeEntityParams } from '../types/SVGATypes'

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
        // 实现 shapes 跨帧继承机制：如果当前帧没有 shapes，继承上一帧的
        let lastShapes: ShapeEntityParams[] = []
        const processedFrames: FrameEntityParams[] = []

        for (let i = 0; i < entity.frames.length; i++) {
          const frame = entity.frames[i]
          // 检查当前帧是否有有效的 shapes（非空数组）
          const hasValidShapes = frame.shapes && frame.shapes.length > 0

          if (hasValidShapes) {
            // 有 shapes，更新 lastShapes 并使用原始帧
            lastShapes = frame.shapes as ShapeEntityParams[]
            processedFrames.push(frame)
          } else {
            // 无 shapes，继承上一帧的 shapes
            const inheritedFrame: FrameEntityParams = {
              alpha: frame.alpha,
              layout: frame.layout,
              transform: frame.transform,
              clipPath: frame.clipPath,
              shapes: lastShapes.length > 0 ? [...lastShapes] : []
            }
            processedFrames.push(inheritedFrame)
          }
        }

        // 调试：统计有多少个 frame 有 shapes
        const framesWithShapes = processedFrames.filter(f => f.shapes && f.shapes.length > 0).length
        LogUtils.info(Svgavideospriteentity.TAG, `Shapes inheritance: ${framesWithShapes}/${processedFrames.length} frames have shapes`)

        this.frames = processedFrames.map(frame => new Svgavideospriteframeentity(frame))
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