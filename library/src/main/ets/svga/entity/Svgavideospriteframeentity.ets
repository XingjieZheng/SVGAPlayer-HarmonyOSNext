/**
 * SVGA Player for HarmonyOS NEXT
 * 帧实体类
 */

import { Svgarect } from '../utils/Svgarect'
import { Svgamatrix } from '../utils/Svgamatrix'
import { Svgapathentity } from './Svgapathentity'
import { Svgavideoshapeentity } from './Svgavideoshapeentity'
import { LogUtils } from '../utils/LogUtils'
import { FrameEntityParams, LayoutParams, TransformParams } from '../types/SVGATypes'

export class Svgavideospriteframeentity {
  private static readonly TAG: string = 'Svgavideospriteframeentity'

  alpha: number = 0
  layout: Svgarect = new Svgarect(0, 0, 0, 0)
  transform: Svgamatrix = new Svgamatrix()
  maskPath: Svgapathentity | null = null
  shapes: Array<Svgavideoshapeentity> = []

  constructor(entity?: FrameEntityParams) {
    if (entity) {
      this.alpha = entity.alpha ?? 0

      if (entity.layout) {
        this.layout = new Svgarect(
          entity.layout.x ?? 0,
          entity.layout.y ?? 0,
          entity.layout.width ?? 0,
          entity.layout.height ?? 0
        )
      }

      if (entity.transform) {
        const arr = new Float32Array([
          entity.transform.a ?? 1, entity.transform.c ?? 0, entity.transform.tx ?? 0,
          entity.transform.b ?? 0, entity.transform.d ?? 1, entity.transform.ty ?? 0,
          0, 0, 1
        ])
        this.transform = new Svgamatrix(arr)
      }

      if (entity.clipPath) {
        this.maskPath = new Svgapathentity(entity.clipPath)
      }

      if (entity.shapes) {
        this.shapes = entity.shapes.map(shape => new Svgavideoshapeentity(shape))
      }

      LogUtils.debug(Svgavideospriteframeentity.TAG,
        `Created frame entity: alpha=${this.alpha}, shapes=${this.shapes.length}`)
    }
  }

  /**
   * 是否有遮罩
   */
  hasMask(): boolean {
    return this.maskPath !== null
  }

  /**
   * 获取变换矩阵数组
   */
  getTransformArray(): number[] {
    return this.transform.toTransformArray()
  }
}
