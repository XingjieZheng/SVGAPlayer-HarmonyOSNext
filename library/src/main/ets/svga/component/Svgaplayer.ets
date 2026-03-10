/**
 * SVGA Player for HarmonyOS NEXT
 * SVGA 播放器组件 - 修复 Canvas Context 问题
 */

import { LogUtils } from '../utils/LogUtils'
import { Svgavideoentity } from '../entity/Svgavideoentity'
import { Svgadynamicentity, TextStyle } from '../entity/Svgadynamicentity'
import { Svgacanvasdrawer } from '../drawer/Svgacanvasdrawer'
import { image } from '@kit.ImageKit'

export enum FillMode {
  Backwards = 'backwards',
  Forwards = 'forwards',
  Clear = 'clear'
}

export interface PlayerCallbacks {
  onComplete?: () => void
  onError?: (error: Error) => void
  onFrame?: (frame: number, percentage: number) => void
  onStep?: (frame: number, percentage: number) => void
}

export interface SvgaplayerController {
  setVideoItem: (videoItem: Svgavideoentity) => void
  setCallbacks: (callbacks: PlayerCallbacks) => void
  startAnimation: () => void
  stopAnimation: (clear?: boolean) => void
  pauseAnimation: () => void
  resumeAnimation: () => void
  gotoFrame: (frame: number) => void
  setDynamicImage: (pixelMap: image.PixelMap, forKey: string) => void
  setDynamicText: (text: string, style: TextStyle, forKey: string) => void
  setDynamicHidden: (hidden: boolean, forKey: string) => void
}

@Component
export struct Svgaplayer {
  private static readonly TAG: string = 'Svgaplayer'

  @State private videoItem: Svgavideoentity | null = null
  @State private currentFrame: number = 0
  @State private isPlaying: boolean = false
  @State private isReady: boolean = false
  @State private drawerInitialized: boolean = false

  private dynamicEntity: Svgadynamicentity = new Svgadynamicentity()
  private drawer: Svgacanvasdrawer | null = null
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D()
  private canvasWidth: number = 300
  private canvasHeight: number = 300
  private intervalId: number = -1
  private startTime: number = 0
  private lastFrameTime: number = 0
  private callbacks: PlayerCallbacks = {}
  private controller: SvgaplayerController | null = null
  private canvasReady: boolean = false

  @Prop loops: number = 0
  @Prop fillMode: FillMode = FillMode.Forwards
  @Prop autoPlay: boolean = true
  @Prop antiAlias: boolean = true
  @Prop sourceVideoItem: Svgavideoentity | null = null

  aboutToAppear() {
    LogUtils.printDivider(Svgaplayer.TAG, '=== Component appeared ===')
    LogUtils.info(Svgaplayer.TAG, `Props - autoPlay: ${this.autoPlay}, loops: ${this.loops}`)
    LogUtils.info(Svgaplayer.TAG, `sourceVideoItem: ${this.sourceVideoItem ? 'exists' : 'null'}`)
    
    this.createController()
    
    if (this.sourceVideoItem !== null) {
      LogUtils.info(Svgaplayer.TAG, 'Setting video item from prop')
      this.videoItem = this.sourceVideoItem
      this.videoItem.antiAlias = this.antiAlias
      this.isReady = true
      this.tryInitializeDrawer()
    }
  }

  aboutToDisappear() {
    LogUtils.printDivider(Svgaplayer.TAG, '=== Component disappearing ===')
    this.stopAnimation(true)
    this.clearResources()
  }

  private clearResources(): void {
    LogUtils.info(Svgaplayer.TAG, 'Clearing resources...')
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId)
      this.intervalId = -1
    }
    this.drawer = null
    this.canvasReady = false
  }

  private createController(): void {
    this.controller = {
      setVideoItem: (videoItem: Svgavideoentity) => {
        this.videoItem = videoItem
        this.videoItem.antiAlias = this.antiAlias
        this.isReady = true
        this.tryInitializeDrawer()
      },
      setCallbacks: (callbacks: PlayerCallbacks) => {
        this.callbacks = callbacks
      },
      startAnimation: () => {
        this.startAnimation()
      },
      stopAnimation: (clear?: boolean) => {
        this.stopAnimation(clear)
      },
      pauseAnimation: () => {
        this.pauseAnimation()
      },
      resumeAnimation: () => {
        this.resumeAnimation()
      },
      gotoFrame: (frame: number) => {
        this.gotoFrame(frame)
      },
      setDynamicImage: (pixelMap: image.PixelMap, forKey: string) => {
        this.setDynamicImage(pixelMap, forKey)
      },
      setDynamicText: (text: string, style: TextStyle, forKey: string) => {
        this.setDynamicText(text, style, forKey)
      },
      setDynamicHidden: (hidden: boolean, forKey: string) => {
        this.setDynamicHidden(hidden, forKey)
      }
    }
  }

  private tryInitializeDrawer(): void {
    LogUtils.info(Svgaplayer.TAG, `=== Try Initialize Drawer ===`)
    LogUtils.info(Svgaplayer.TAG, `Video ready: ${this.videoItem ? 'YES' : 'NO'}`)
    LogUtils.info(Svgaplayer.TAG, `Canvas ready: ${this.canvasReady}`)
    LogUtils.info(Svgaplayer.TAG, `Drawer initialized: ${this.drawerInitialized}`)
    
    if (!this.videoItem) {
      LogUtils.warn(Svgaplayer.TAG, 'Video not ready')
      return
    }
    
    if (!this.canvasReady) {
      LogUtils.warn(Svgaplayer.TAG, 'Canvas not ready')
      return
    }
    
    if (this.drawerInitialized) {
      LogUtils.warn(Svgaplayer.TAG, 'Drawer already initialized')
      return
    }
    
    this.setupDrawer()
  }

  private setupDrawer(): void {
    LogUtils.info(Svgaplayer.TAG, `=== Setup Drawer ===`)
    
    try {
      LogUtils.info(Svgaplayer.TAG, `Creating drawer with size ${this.canvasWidth}x${this.canvasHeight}`)
      this.drawer = new Svgacanvasdrawer(this.canvasContext)
      this.drawer.setCanvasSize(this.canvasWidth, this.canvasHeight)
      this.drawer.setVideoItem(this.videoItem!)
      this.drawer.setDynamicItem(this.dynamicEntity)
      this.drawerInitialized = true
      
      LogUtils.info(Svgaplayer.TAG, 'Drawer setup completed')
      
      // 强制刷新状态
      this.drawerInitialized = true
      
      // Drawer 准备好后，启动动画
      if (this.autoPlay && !this.isPlaying) {
        LogUtils.info(Svgaplayer.TAG, 'Starting animation...')
        this.startAnimation()
      }
    } catch (error) {
      LogUtils.error(Svgaplayer.TAG, 'Failed to setup drawer', error as Error)
    }
  }

  private onCanvasReady(): void {
    LogUtils.printDivider(Svgaplayer.TAG, '=== Canvas Ready ===')
    this.canvasReady = true
    this.tryInitializeDrawer()
  }

  private onCanvasAreaChange(area: Area): void {
    const w = area.width as number
    const h = area.height as number
    
    if (w > 0 && h > 0 && (w !== this.canvasWidth || h !== this.canvasHeight)) {
      LogUtils.info(Svgaplayer.TAG, `Canvas area changed: ${w}x${h}`)
      this.canvasWidth = w
      this.canvasHeight = h
      
      if (this.drawer) {
        this.drawer.setCanvasSize(w, h)
      }
    }
  }

  startAnimation(): void {
    LogUtils.info(Svgaplayer.TAG, `=== Start Animation ===`)
    
    if (!this.videoItem) {
      LogUtils.error(Svgaplayer.TAG, 'Cannot start: videoItem is null')
      return
    }
    
    if (this.isPlaying) {
      LogUtils.warn(Svgaplayer.TAG, 'Animation already playing')
      return
    }
    
    if (!this.drawer) {
      LogUtils.error(Svgaplayer.TAG, 'Cannot start: drawer is null')
      return
    }
    
    LogUtils.info(Svgaplayer.TAG, `Starting: ${this.videoItem.frames} frames @ ${this.videoItem.fps} FPS`)
    
    this.isPlaying = true
    this.startTime = Date.now()
    this.lastFrameTime = 0
    
    const frameInterval = 1000 / this.videoItem.fps
    this.intervalId = setInterval(() => {
      this.animate()
    }, frameInterval)
    
    // 立即绘制第一帧
    this.animate()
  }

  stopAnimation(clear: boolean = false): void {
    LogUtils.info(Svgaplayer.TAG, `=== Stop Animation ===`)
    
    this.isPlaying = false
    
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId)
      this.intervalId = -1
    }
    
    if (clear && this.drawer) {
      this.currentFrame = 0
      this.drawer.drawFrame(0)
    }
    
    this.callbacks.onComplete?.()
  }

  private animate(): void {
    if (!this.isPlaying || !this.videoItem || !this.drawer) {
      return
    }

    const now = Date.now()
    const elapsed = now - this.startTime
    const duration = this.videoItem.getDuration()

    let progress = elapsed / duration

    if (progress >= 1) {
      if (this.loops === 0 || Math.floor(progress) < this.loops) {
        progress = progress % 1
        this.startTime = now - (progress * duration)
      } else {
        this.currentFrame = this.videoItem.frames - 1
        this.drawer.drawFrame(this.currentFrame)
        this.stopAnimation()
        return
      }
    }

    const frameIndex = Math.floor(progress * this.videoItem.frames)
    
    if (frameIndex !== this.currentFrame) {
      this.currentFrame = frameIndex
      this.drawer.drawFrame(frameIndex)
      
      const percentage = (this.currentFrame + 1) / this.videoItem.frames
      this.callbacks.onFrame?.(this.currentFrame, percentage)
    }

    this.lastFrameTime = now
  }

  pauseAnimation(): void {
    if (this.isPlaying) {
      this.isPlaying = false
      if (this.intervalId !== -1) {
        clearInterval(this.intervalId)
        this.intervalId = -1
      }
      LogUtils.info(Svgaplayer.TAG, 'Animation paused')
    }
  }

  resumeAnimation(): void {
    if (!this.isPlaying && this.videoItem && this.drawer) {
      this.isPlaying = true
      this.startTime = Date.now() - (this.currentFrame / this.videoItem.fps * 1000)
      const frameInterval = 1000 / this.videoItem.fps
      
      this.intervalId = setInterval(() => {
        this.animate()
      }, frameInterval)
      
      LogUtils.info(Svgaplayer.TAG, 'Animation resumed')
    }
  }

  gotoFrame(frame: number): void {
    if (!this.videoItem || !this.drawer) return
    this.currentFrame = Math.max(0, Math.min(frame, this.videoItem.frames - 1))
    this.drawer.drawFrame(this.currentFrame)
  }

  setDynamicImage(pixelMap: image.PixelMap, forKey: string): void {
    this.dynamicEntity.setDynamicImage(pixelMap, forKey)
  }

  setDynamicText(text: string, style: TextStyle, forKey: string): void {
    this.dynamicEntity.setDynamicText(text, style, forKey)
  }

  setDynamicHidden(hidden: boolean, forKey: string): void {
    this.dynamicEntity.setDynamicHidden(hidden, forKey)
  }

  build() {
    Stack() {
      // Canvas 组件 - 使用状态变量绑定
      Canvas(this.canvasContext)
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .onReady(() => {
          this.onCanvasReady()
        })
        .onAreaChange((event: Area) => {
          this.onCanvasAreaChange(event)
        })

      // 调试信息
      Column() {
        Text(`Ready:${this.isReady} Play:${this.isPlaying} Drawer:${this.drawerInitialized}`)
          .fontSize(9)
          .fontColor('#00FF00')
          .backgroundColor('#000000')
        
        Text(`Frame:${this.currentFrame}/${this.videoItem?.frames ?? 0}`)
          .fontSize(9)
          .fontColor('#00FF00')
          .backgroundColor('#000000')
      }
      .position({ x: 5, y: 5 })
      .alignItems(HorizontalAlign.Start)

      // 加载中提示
      if (!this.drawerInitialized) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color(Color.Grey)
          Text(this.isReady ? 'Initializing...' : 'Loading...')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#f5f5f5')
      }
    }
    .width('100%')
    .height('100%')
  }
}