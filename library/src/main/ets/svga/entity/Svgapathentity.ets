/**
 * SVGA Player for HarmonyOS NEXT
 * 路径实体 - 使用 Path2D 替代自定义路径
 */

import { LogUtils } from '../utils/LogUtils'
import { Point } from '../types/SVGATypes'

export class Svgapathentity {
  private static readonly TAG: string = 'Svgapathentity'

  private pathString: string = ''
  private cachedPath2D: Path2D | null = null
  private isValidPath: boolean = false

  constructor(pathString?: string) {
    if (pathString) {
      this.setPathString(pathString)
    }
  }

  setPathString(pathString: string): void {
    this.pathString = pathString
    this.isValidPath = this.validatePath(pathString)
    this.cachedPath2D = null

    LogUtils.debug(Svgapathentity.TAG, `Path string set, length: ${pathString.length}, valid: ${this.isValidPath}`)
  }

  getPath2D(): Path2D | null {
    if (!this.isValidPath || !this.pathString) {
      return null
    }

    if (this.cachedPath2D) {
      return this.cachedPath2D
    }

    try {
      this.cachedPath2D = new Path2D(this.pathString)
      LogUtils.debug(Svgapathentity.TAG, 'Path2D created from path string')
      return this.cachedPath2D
    } catch (e) {
      LogUtils.error(Svgapathentity.TAG, 'Failed to create Path2D from path string', e as Error)
      return null
    }
  }

  buildPath(): Path2D | null {
    return this.getPath2D()
  }

  applyToContext(context: CanvasRenderingContext2D): void {
    const path = this.getPath2D()
    if (path) {
      context.clip(path)
      LogUtils.debug(Svgapathentity.TAG, 'Path applied to context as clip')
    }
  }

  private validatePath(pathString: string): boolean {
    if (!pathString || pathString.length === 0) {
      return false
    }
    const validCommands = /[MmLlHhVvCcSsQqTtAaZz\s\d\.\-\,]+/
    return validCommands.test(pathString)
  }

  static buildFromJson(json: object): Svgapathentity {
    const path = new Svgapathentity()
    const jsonStr = JSON.stringify(json)
    if (jsonStr && jsonStr.length > 0) {
      path.setPathString(jsonStr)
    }
    LogUtils.debug(Svgapathentity.TAG, `Path built from JSON: ${jsonStr.substring(0, 50)}...`)
    return path
  }

  static parseSvgPath(pathString: string): Path2D | null {
    if (!pathString || pathString.trim().length === 0) {
      return null
    }

    try {
      return new Path2D(pathString)
    } catch (e) {
      LogUtils.error(Svgapathentity.TAG, 'Failed to parse SVG path', e as Error)
      return null
    }
  }

  private executeCommand(
    path: Path2D,
    method: string,
    params: number[],
    currentX: number,
    currentY: number
  ): Point {
    let x = currentX
    let y = currentY

    switch (method) {
      case 'M':
        if (params.length >= 2) {
          x = params[0]
          y = params[1]
          path.moveTo(x, y)
        }
        break
      case 'm':
        if (params.length >= 2) {
          x += params[0]
          y += params[1]
          path.moveTo(x, y)
        }
        break
      case 'L':
        if (params.length >= 2) {
          x = params[0]
          y = params[1]
          path.lineTo(x, y)
        }
        break
      case 'l':
        if (params.length >= 2) {
          x += params[0]
          y += params[1]
          path.lineTo(x, y)
        }
        break
      case 'H':
        if (params.length >= 1) {
          x = params[0]
          path.lineTo(x, y)
        }
        break
      case 'h':
        if (params.length >= 1) {
          x += params[0]
          path.lineTo(x, y)
        }
        break
      case 'V':
        if (params.length >= 1) {
          y = params[0]
          path.lineTo(x, y)
        }
        break
      case 'v':
        if (params.length >= 1) {
          y += params[0]
          path.lineTo(x, y)
        }
        break
      case 'Z':
      case 'z':
        path.closePath()
        break
    }

    return { x, y }
  }
}
