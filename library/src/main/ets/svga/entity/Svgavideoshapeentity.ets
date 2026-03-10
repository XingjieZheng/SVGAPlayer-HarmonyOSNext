/**
 * SVGA Player for HarmonyOS NEXT
 * 形状实体类
 */

import { Svgapathentity } from './Svgapathentity'
import { Svgamatrix } from '../utils/Svgamatrix'
import { LogUtils } from '../utils/LogUtils'
import { ShapeEntityParams, ShapeStyleParams, TransformParams } from '../types/SVGATypes'

export class Svgavideoshapeentity {
  private static readonly TAG: string = 'Svgavideoshapeentity'

  styles: ShapeStyleParams | null = null
  transform: Svgamatrix | null = null
  shapePath: Svgapathentity | null = null
  isKeep: boolean = false
  private cachedPath: Path2D | null = null

  constructor(entity?: ShapeEntityParams) {
    if (entity) {
      if (entity.styles) {
        this.styles = entity.styles
      }

      if (entity.transform) {
        const arr = new Float32Array([
          entity.transform.a ?? 1, entity.transform.c ?? 0, entity.transform.tx ?? 0,
          entity.transform.b ?? 0, entity.transform.d ?? 1, entity.transform.ty ?? 0,
          0, 0, 1
        ])
        this.transform = new Svgamatrix(arr)
      }

      if (entity.shapePath) {
        this.shapePath = new Svgapathentity(entity.shapePath)
      }

      this.isKeep = entity.isKeep ?? false

      LogUtils.debug(Svgavideoshapeentity.TAG, `Created shape entity, isKeep: ${this.isKeep}`)
    }
  }

  /**
   * 构建 Path2D（带缓存）
   */
  buildPath(): Path2D | null {
    if (this.cachedPath) {
      return this.cachedPath
    }

    if (!this.shapePath) {
      return null
    }

    this.cachedPath = this.shapePath.buildPath()
    return this.cachedPath
  }

  /**
   * 清除缓存
   */
  clearCache(): void {
    this.cachedPath = null
  }
}
