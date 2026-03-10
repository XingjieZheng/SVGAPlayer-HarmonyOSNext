/**
 * SVGA Player for HarmonyOS NEXT
 * Canvas 渲染引擎 - 带详细日志版
 */

import { image } from '@kit.ImageKit'
import { Sgvadrawer } from './Sgvadrawer'
import { Svgavideospriteentity } from '../entity/Svgavideospriteentity'
import { Svgavideospriteframeentity } from '../entity/Svgavideospriteframeentity'
import { Svgavideoshapeentity } from '../entity/Svgavideoshapeentity'
import { Svgadynamicentity } from '../entity/Svgadynamicentity'
import { Svgavideoentity } from '../entity/Svgavideoentity'
import { Svgamatrix } from '../utils/Svgamatrix'
import { Svgarect } from '../utils/Svgarect'
import { LogUtils } from '../utils/LogUtils'

export class Svgacanvasdrawer extends Sgvadrawer {
  static readonly TAG: string = 'Svgacanvasdrawer'

  private ctx: CanvasRenderingContext2D | null = null
  private canvasWidth: number = 0
  private canvasHeight: number = 0

  // 性能优化：共享对象
  private sharedPath: Path2D = new Path2D()
  private sharedMatrix: Svgamatrix = new Svgamatrix()

  // 文本位图缓存
  private textBitmapCache: Map<string, image.PixelMap> = new Map()

  constructor(ctx: CanvasRenderingContext2D) {
    super(new Svgavideoentity(), new Svgadynamicentity())
    this.ctx = ctx
    LogUtils.printDivider(Svgacanvasdrawer.TAG, '=== Canvas Drawer Created ===')
    LogUtils.info(Svgacanvasdrawer.TAG, `Context valid: ${ctx ? 'YES' : 'NO'}`)
  }

  /**
   * 设置 Canvas 上下文
   */
  setContext(ctx: CanvasRenderingContext2D): void {
    this.ctx = ctx
    LogUtils.debug(Svgacanvasdrawer.TAG, 'Canvas context updated')
  }

  /**
   * 设置画布尺寸
   */
  setCanvasSize(width: number, height: number): void {
    this.canvasWidth = width
    this.canvasHeight = height
    LogUtils.info(Svgacanvasdrawer.TAG, `Canvas size set: ${width}x${height}`)
  }

  /**
   * 绘制指定帧
   */
  drawFrame(frameIndex: number): void {
    LogUtils.debug(Svgacanvasdrawer.TAG, `=== Draw Frame ${frameIndex} ===`)
    
    if (!this.ctx) {
      LogUtils.error(Svgacanvasdrawer.TAG, 'Cannot draw: context is null')
      return
    }
    
    if (!this.videoItem) {
      LogUtils.error(Svgacanvasdrawer.TAG, 'Cannot draw: videoItem is null')
      return
    }

    this.currentFrame = frameIndex
    const startTime = Date.now()

    // 清除画布
    LogUtils.debug(Svgacanvasdrawer.TAG, `Clearing canvas ${this.canvasWidth}x${this.canvasHeight}`)
    this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight)

    // 如果没有可用图片资源，绘制兜底背景以避免黑屏
    try {
      const imageCount = this.videoItem?.getImageCount?.() ?? 0
      if (imageCount === 0) {
        this.drawFallbackBackground()
        LogUtils.info(Svgacanvasdrawer.TAG, 'Fallback background rendered due to missing images')
        return
      }
    } catch (e) {
      // 不阻塞正常渲染，继续绘制帧
    }

    // 获取精灵列表
    const sprites = this.videoItem.getSprites()
    LogUtils.info(Svgacanvasdrawer.TAG, `Video: ${this.videoItem.frames} frames, ${sprites.length} sprites`)
    
    if (sprites.length === 0) {
      LogUtils.warn(Svgacanvasdrawer.TAG, 'No sprites to draw!')
      return
    }

    // 处理遮罩
    const matteSprites = new Map<string, Svgavideospriteentity>()
    let hasMatteLayer = false

    // 检查是否有遮罩层
    for (const sprite of sprites) {
      if (sprite.isMatte()) {
        hasMatteLayer = true
        const key = sprite.imageKey
        if (key) {
          matteSprites.set(key, sprite)
        }
      }
    }

    LogUtils.debug(Svgacanvasdrawer.TAG, `Processing ${sprites.length} sprites (matte layers: ${matteSprites.size})`)

    // 绘制每个精灵
    let drawnCount = 0
    for (let i = 0; i < sprites.length; i++) {
      const sprite = sprites[i]

      // 跳过遮罩精灵
      if (sprite.isMatte()) {
        continue
      }

      // 处理遮罩
      if (hasMatteLayer && sprite.hasMatte()) {
        this.drawWithMatte(sprite, frameIndex, matteSprites)
      } else {
        this.drawSprite(sprite, frameIndex, false)
      }
      drawnCount++
    }

    const duration = Date.now() - startTime
    LogUtils.debug(Svgacanvasdrawer.TAG, `Frame ${frameIndex} drawn: ${drawnCount} sprites in ${duration}ms`)
  }

  /**
   * 绘制带遮罩的精灵
   */
  private drawWithMatte(
    sprite: Svgavideospriteentity,
    frameIndex: number,
    matteSprites: Map<string, Svgavideospriteentity>
  ): void {
    if (!this.ctx) return

    const matteKey = sprite.matteKey
    if (!matteKey) {
      this.drawSprite(sprite, frameIndex, false)
      return
    }

    const matteSprite = matteSprites.get(matteKey)
    if (!matteSprite) {
      LogUtils.warn(Svgacanvasdrawer.TAG, `Matte sprite not found: ${matteKey}`)
      this.drawSprite(sprite, frameIndex, false)
      return
    }

    LogUtils.debug(Svgacanvasdrawer.TAG, `Drawing with matte: ${matteKey}`)

    // 保存画布状态
    this.ctx.save()

    // 绘制遮罩
    this.drawSprite(matteSprite, frameIndex, true)

    // 绘制被遮罩的内容
    this.drawSprite(sprite, frameIndex, false)

    // 恢复画布状态
    this.ctx.restore()
  }

  /**
   * 绘制精灵
   */
  private drawSprite(sprite: Svgavideospriteentity, frameIndex: number, isMaskMode: boolean): void {
    if (!this.ctx) return

    const frame = sprite.getFrameAt(frameIndex)
    if (!frame) {
      LogUtils.debug(Svgacanvasdrawer.TAG, `No frame at index ${frameIndex} for sprite ${sprite.imageKey}`)
      return
    }

    // 保存画布状态
    this.ctx.save()

    // 应用遮罩
    if (frame.maskPath && !isMaskMode) {
      const maskPath = frame.maskPath.buildPath()
      if (maskPath) {
        this.ctx.clip(maskPath)
      }
    }

    // 应用变换
    const transform = frame.getTransformArray()
    this.ctx.transform(transform[0], transform[1], transform[2], transform[3], transform[4], transform[5])

    // 设置透明度
    this.ctx.globalAlpha = frame.alpha

    // 绘制图片
    if (sprite.imageKey && !isMaskMode) {
      this.drawImage(sprite, frame)
    }

    // 绘制形状
    this.drawShapes(frame)

    // 恢复画布状态
    this.ctx.restore()
  }

  /**
   * 绘制图片
   */
  private drawImage(sprite: Svgavideospriteentity, frame: Svgavideospriteframeentity): void {
    if (!this.ctx || !this.videoItem || !this.dynamicItem) {
      LogUtils.warn(Svgacanvasdrawer.TAG, 'Cannot draw image: missing context or items')
      return
    }

    const imageKey = sprite.imageKey
    if (!imageKey) {
      LogUtils.debug(Svgacanvasdrawer.TAG, 'Sprite has no imageKey')
      return
    }

    // 检查是否被动态隐藏
    if (this.dynamicItem.isHidden(imageKey)) {
      LogUtils.debug(Svgacanvasdrawer.TAG, `Image hidden: ${imageKey}`)
      return
    }

    // 获取位图
    const bitmapKey = imageKey.endsWith('.matte') ? imageKey.slice(0, -6) : imageKey
    const pixelMap = this.dynamicItem.getDynamicImage(bitmapKey) || this.videoItem.getImage(bitmapKey)

    const layout = frame.layout
    
    LogUtils.debug(Svgacanvasdrawer.TAG, `Drawing image: ${bitmapKey}, layout: ${layout.width}x${layout.height}, hasPixelMap: ${pixelMap ? 'YES' : 'NO'}`)

    // 保存当前状态
    this.ctx.save()

    if (pixelMap) {
      // 有图片资源，绘制实际图片
      this.drawPixelMap(pixelMap, layout)
    } else {
      // 无图片，绘制错误占位符
      LogUtils.warn(Svgacanvasdrawer.TAG, `No image found for key: ${bitmapKey}, drawing error placeholder`)
      this.drawErrorPlaceholder(layout, bitmapKey)
    }

    this.ctx.restore()
  }

  /**
   * 绘制图片占位符
   */
  private drawPixelMapPlaceholder(layout: Svgarect, key: string): void {
    if (!this.ctx) return

    LogUtils.debug(Svgacanvasdrawer.TAG, `Drawing placeholder for ${key}: ${layout.width}x${layout.height}`)

    // 绘制半透明背景
    this.ctx.fillStyle = 'rgba(0, 150, 255, 0.2)'
    this.ctx.fillRect(0, 0, layout.width, layout.height)

    // 绘制边框
    this.ctx.strokeStyle = '#0096FF'
    this.ctx.lineWidth = 1
    this.ctx.strokeRect(0, 0, layout.width, layout.height)

    // 绘制文字提示
    this.ctx.fillStyle = '#0096FF'
    this.ctx.font = '10px sans-serif'
    this.ctx.textAlign = 'center'
    this.ctx.textBaseline = 'middle'
    
    const displayKey = key.length > 15 ? key.substring(0, 12) + '...' : key
    this.ctx.fillText(displayKey, layout.width / 2, layout.height / 2 - 8)
    this.ctx.fillText(`${Math.round(layout.width)}x${Math.round(layout.height)}`, layout.width / 2, layout.height / 2 + 8)
  }

  /**
   * 绘制 PixelMap 图片
   */
  private drawPixelMap(pixelMap: image.PixelMap, layout: Svgarect): void {
    if (!this.ctx) return

    try {
      LogUtils.debug(Svgacanvasdrawer.TAG, `Drawing PixelMap: ${layout.width}x${layout.height}`)
      
      // 创建 ImageBitmap 从 PixelMap
      const imageBitmap = new ImageBitmap(pixelMap)
      
      // 使用 drawImage 绘制
      this.ctx.drawImage(imageBitmap, 0, 0, layout.width, layout.height)
      
      LogUtils.debug(Svgacanvasdrawer.TAG, 'PixelMap drawn successfully')
    } catch (e) {
      LogUtils.error(Svgacanvasdrawer.TAG, 'Failed to draw PixelMap', e as Error)
      // 绘制错误占位符
      this.drawErrorPlaceholder(layout, 'PixelMap Error')
    }
  }

  /**
   * 绘制错误占位符
   */
  private drawErrorPlaceholder(layout: Svgarect, key: string): void {
    if (!this.ctx) return

    // 绘制红色半透明背景
    this.ctx.fillStyle = 'rgba(255, 0, 0, 0.2)'
    this.ctx.fillRect(0, 0, layout.width, layout.height)

    // 绘制红色边框
    this.ctx.strokeStyle = '#FF0000'
    this.ctx.lineWidth = 1
    this.ctx.setLineDash([5, 5])
    this.ctx.strokeRect(0, 0, layout.width, layout.height)
    this.ctx.setLineDash([])

    // 绘制文字提示
    this.ctx.fillStyle = '#FF0000'
    this.ctx.font = '10px sans-serif'
    this.ctx.textAlign = 'center'
    this.ctx.textBaseline = 'middle'
    this.ctx.fillText('No Image', layout.width / 2, layout.height / 2)
  }

  /**
   * 绘制形状
   */
  private drawShapes(frame: Svgavideospriteframeentity): void {
    if (!this.ctx) return

    if (frame.shapes.length === 0) {
      return
    }

    LogUtils.debug(Svgacanvasdrawer.TAG, `Drawing ${frame.shapes.length} shapes`)

    for (const shape of frame.shapes) {
      this.drawShape(shape)
    }
  }

  /**
   * 绘制单个形状
   */
  private drawShape(shape: Svgavideoshapeentity): void {
    if (!this.ctx) return

    const path = shape.buildPath()
    if (!path) {
      return
    }

    this.ctx.save()

    // 应用形状变换
    if (shape.transform) {
      const transform = shape.transform.toTransformArray()
      this.ctx.transform(transform[0], transform[1], transform[2], transform[3], transform[4], transform[5])
    }

    // 填充
    if (shape.styles?.fill) {
      this.ctx.fillStyle = shape.styles.fill
      this.ctx.fill(path)
      LogUtils.debug(Svgacanvasdrawer.TAG, `Shape filled with ${shape.styles.fill}`)
    }

    // 描边
    if (shape.styles?.strokeWidth && shape.styles.strokeWidth > 0) {
      this.ctx.strokeStyle = shape.styles.stroke ?? '#000000'
      this.ctx.lineWidth = shape.styles.strokeWidth

      if (shape.styles.lineCap) {
        this.ctx.lineCap = shape.styles.lineCap as CanvasLineCap
      }

      if (shape.styles.lineJoin) {
        this.ctx.lineJoin = shape.styles.lineJoin as CanvasLineJoin
      }

      if (shape.styles.lineDash && shape.styles.lineDash.length >= 2) {
        this.ctx.setLineDash([shape.styles.lineDash[0], shape.styles.lineDash[1]])
      }

      this.ctx.stroke(path)
    }

    this.ctx.restore()
  }

  /**
   * 清除画布
   */
  clear(): void {
    if (!this.ctx) return
    this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight)
    LogUtils.debug(Svgacanvasdrawer.TAG, 'Canvas cleared')
  }

  // Fallback rendering when no image resources are available
  private drawFallbackBackground(): void {
    if (!this.ctx) return
    const w = this.canvasWidth || 1
    const h = this.canvasHeight || 1
    // Gradient background to indicate rendering is active
    const grad = this.ctx.createLinearGradient(0, 0, w, h)
    grad.addColorStop(0, '#1e1e1e')
    grad.addColorStop(1, '#3a3a3a')
    this.ctx.fillStyle = grad
    this.ctx.fillRect(0, 0, w, h)
    // Subtle grid overlay
    this.ctx.strokeStyle = 'rgba(255,255,255,0.15)'
    const step = 40
    for (let x = 0; x < w; x += step) {
      this.ctx.beginPath()
      this.ctx.moveTo(x, 0)
      this.ctx.lineTo(x, h)
      this.ctx.stroke()
    }
    for (let y = 0; y < h; y += step) {
      this.ctx.beginPath()
      this.ctx.moveTo(0, y)
      this.ctx.lineTo(w, y)
      this.ctx.stroke()
    }
  }

  /**
   * 释放资源
   */
  release(): void {
    this.textBitmapCache.clear()
    LogUtils.info(Svgacanvasdrawer.TAG, 'Drawer resources released')
  }
}
