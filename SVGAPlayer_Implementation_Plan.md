# HarmonyOS NEXT SVGA 播放器实现方案

> 基于 Android SVGAPlayer 移植的鸿蒙原生 SVGA 播放器方案
> 遵循 HarmonyOS NEXT (API 12+) 开发规范

---

## 目录

1. [整体架构设计](#1-整体架构设计)
2. [播放流程设计](#2-播放流程设计)
3. [核心类详细设计](#3-核心类详细设计)
4. [项目目录结构](#4-项目目录结构)
5. [关键技术实现](#5-关键技术实现)
6. [性能优化策略](#6-性能优化策略)

---

## 1. 整体架构设计

### 1.1 架构对比映射

| Android 组件 | HarmonyOS NEXT 对应组件 | 说明 |
|-------------|------------------------|------|
| `SVGAParser` | `Svgaparser` | 文件解析器，使用线程池异步解析 |
| `SVGAVideoEntity` | `Svgavideoentity` | 视频数据实体，存储动画元数据和资源 |
| `SVGAImageView` | `Svgaplayer` (自定义组件) | 播放控制器，基于鸿蒙动画驱动 |
| `SVGADrawable` | `Svgadrawable` | 桥接层，管理渲染状态 |
| `SVGACanvasDrawer` | `Svgacanvasdrawer` | 渲染引擎，使用 Canvas 绘制 |
| `ValueAnimator` | `Animator` + `@State` | 鸿蒙动画驱动方案 |
| `Android Canvas` | `Canvas` (ArkUI) | 鸿蒙 Canvas 组件 |
| `Bitmap` | `image.PixelMap` | 鸿蒙位图类型 |
| `ThreadPoolExecutor` | `taskpool` / `worker` | 鸿蒙并发任务机制 |

### 1.2 核心模块划分

```
┌─────────────────────────────────────────────────────────────┐
│                     SVGAPlayer 组件层                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Svgaplayer  │  │   Svgaparser  │  │   Svgacache   │       │
│  │  (播放控制器)  │  │   (解析器)    │  │   (缓存管理)  │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │               │
│         └─────────────────┼─────────────────┘               │
│                           │                                 │
│  ┌────────────────────────┴────────────────────────┐       │
│  │              Svgavideoentity                     │       │
│  │              (视频数据实体)                       │       │
│  └────────────────────────┬────────────────────────┘       │
│                           │                                 │
│  ┌────────────────────────┴────────────────────────┐       │
│  │              Svgacanvasdrawer                    │       │
│  │              (渲染引擎)                          │       │
│  └─────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 播放流程设计

### 2.1 完整播放流程时序图

```
用户调用                    Svgaplayer              Svgaparser            Svgavideoentity          Svgacanvasdrawer
   │                           │                       │                      │                      │
   │── setSource(url) ────────>│                       │                      │                      │
   │                           │── decodeFromUrl() ───>│                      │                      │
   │                           │                       │                      │                      │
   │                           │                       │── 下载文件 ─────────>│                      │
   │                           │                       │                      │                      │
   │                           │                       │── 解析ZIP/PB ───────>│                      │
   │                           │                       │                      │                      │
   │                           │                       │── buildEntities() ──>│                      │
   │                           │                       │                      │                      │
   │                           │── onComplete() ───────│                      │                      │
   │                           │                       │                      │                      │
   │                           │── startAnimation() ───│                      │                      │
   │                           │                       │                      │                      │
   │                           │── Animator 驱动 ──────│                      │                      │
   │                           │                       │                      │                      │
   │                           │── currentFrame 更新 ──│                      │                      │
   │                           │                       │                      │── drawFrame() ──────>│
   │                           │                       │                      │                      │
   │                           │                       │                      │── 绘制精灵/形状 ────>│
   │                           │                       │                      │                      │
   │                           │── invalidate() ───────│                      │                      │
   │                           │                       │                      │                      │
   │                           │── onDraw() ───────────│                      │                      │
   │                           │                       │                      │                      │
   │                           │                       │                      │── render to Canvas ─>│
```

### 2.2 文件下载流程

```typescript
// 使用 http kit 进行文件下载
class Svgaparser {
  async downloadFile(url: string): Promise<ArrayBuffer> {
    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/octet-stream' },
        usingProtocol: http.HttpProtocol.HTTP2
      })
      
      if (response.responseCode === 200) {
        return response.result as ArrayBuffer
      } else {
        throw new Error(`Download failed: ${response.responseCode}`)
      }
    } catch (error) {
      throw error
    }
  }
}
```

### 2.3 文件解析流程

```
输入: ArrayBuffer (SVGA 文件数据)
│
├─ 判断文件格式
│  ├─ ZIP 格式 (前4字节: 0x50 0x4B 0x03 0x04)
│  │  └─ 解压 ZIP 文件
│  │     ├─ movie.binary (Protocol Buffer 格式动画数据)
│  │     └─ images/ (图片资源)
│  │
│  └─ 直接 PB 格式
│     └─ 直接解析 Protocol Buffer
│
├─ 解析 Protocol Buffer
│  └─ 生成 MovieEntity
│     ├─ version: 版本号
│     ├─ params: 动画参数 (FPS、帧数、尺寸等)
│     ├─ images: 图片资源映射
│     ├─ sprites: 精灵列表
│     └─ audios: 音频列表
│
└─ 构建 Svgavideoentity
   ├─ 解析图片资源为 PixelMap
   ├─ 构建精灵对象树
   └─ 初始化音频资源
```

### 2.4 动画播放流程

```typescript
// 使用鸿蒙 Animator 驱动动画
class Svgaplayer {
  private animator: Animator | null = null
  private currentFrame: number = 0
  
  startAnimation(): void {
    if (!this.videoItem) return
    
    // 计算动画时长
    const duration = (this.videoItem.frames / this.videoItem.fps) * 1000
    
    // 创建 Animator
    this.animator = Animator.create({
      duration: duration,
      easing: 'linear',
      iterations: this.loops <= 0 ? -1 : this.loops,
      begin: 0,
      end: this.videoItem.frames - 1
    })
    
    // 监听动画帧更新
    this.animator.onFrame = (value: number) => {
      this.currentFrame = Math.floor(value)
      this.invalidate() // 触发重绘
    }
    
    this.animator.play()
  }
}
```

### 2.5 渲染流程

```
Canvas 绘制回调
│
├─ 获取当前帧索引
│
├─ 从 Svgavideoentity 获取精灵列表
│
├─ 遍历精灵进行绘制
│  ├─ 计算变换矩阵
│  │  └─ scale、translate、transform 组合
│  │
│  ├─ 绘制图片精灵
│  │  ├─ 获取 PixelMap
│  │  ├─ 应用透明度
│  │  ├─ 应用遮罩 (如果有)
│  │  └─ canvas.drawPixelMap()
│  │
│  ├─ 绘制矢量形状
│  │  ├─ 解析 SVG Path
│  │  ├─ 应用 fill/stroke 样式
│  │  └─ canvas.drawPath()
│  │
│  └─ 绘制动态元素
│     ├─ 动态图片替换
│     └─ 动态文本渲染
│
└─ 处理遮罩层 (Matte)
   ├─ saveLayer
   ├─ 绘制遮罩内容
   └─ restoreLayer
```

---

## 3. 核心类详细设计

### 3.1 Svgaparser (解析器)

**文件路径**: `ets/svga/parser/Svgaparser.ets`

**职责**: 负责 SVGA 文件的下载、解析和数据构建

**属性**:
```typescript
class Svgaparser {
  private static instance: Svgaparser | null = null
  private context: Context | null = null
  
  // 线程池（使用 taskpool）
  private taskPool: taskpool.TaskPool = new taskpool.TaskPool('SVGA_PARSER_POOL')
  
  // 缓存管理器
  private cacheManager: Svgacache = Svgacache.getInstance()
}
```

**方法**:
```typescript
// 获取单例
static getInstance(context?: Context): Svgaparser

// 从 URL 解析
async decodeFromUrl(
  url: string, 
  callback: ParseCompletion
): Promise<void>

// 从 Raw 资源解析
async decodeFromRaw(
  resource: Resource, 
  callback: ParseCompletion
): Promise<void>

// 从本地文件解析
async decodeFromPath(
  path: string, 
  callback: ParseCompletion
): Promise<void>

// 从 ArrayBuffer 解析（核心方法）
private async decodeFromBuffer(
  buffer: ArrayBuffer,
  cacheKey: string,
  callback: ParseCompletion
): Promise<void>

// 判断是否为 ZIP 格式
private isZipFile(buffer: ArrayBuffer): boolean

// 解压 ZIP 文件
private async unzipBuffer(buffer: ArrayBuffer): Promise<UnzipResult>

// 解析 Protocol Buffer
private parseProtoBuffer(buffer: ArrayBuffer): MovieEntity

// 构建视频实体
private buildVideoEntity(
  movieEntity: MovieEntity, 
  cacheDir: string
): Svgavideoentity
```

### 3.2 Svgavideoentity (视频数据实体)

**文件路径**: `ets/svga/entity/Svgavideoentity.ets`

**职责**: 存储 SVGA 动画的所有数据和资源

**属性**:
```typescript
class Svgavideoentity {
  // 动画元数据
  readonly version: string = ''
  readonly fps: number = 15
  readonly frames: number = 0
  readonly videoSize: Svgarect = new Svgarect(0, 0, 0, 0)
  
  // 资源数据
  private imageMap: Map<string, image.PixelMap> = new Map()
  private spriteList: Array<Svgavideospriteentity> = []
  private audioList: Array<Svgaaudioentity> = []
  
  // 缓存目录
  private cacheDir: string = ''
}
```

**方法**:
```typescript
// 构造函数
constructor(movieEntity: MovieEntity, cacheDir: string)

// 获取图片资源
getImage(key: string): image.PixelMap | undefined

// 获取精灵列表
getSprites(): Array<Svgavideospriteentity>

// 获取音频列表
getAudios(): Array<Svgaaudioentity>

// 释放资源
clear(): void

// 私有方法：解析图片
private async parserImages(entity: MovieEntity): Promise<void>

// 私有方法：构建精灵
private buildSprites(entity: MovieEntity): void
```

### 3.3 Svgaplayer (播放控制器)

**文件路径**: `ets/svga/component/Svgaplayer.ets`

**职责**: 提供 SVGA 动画播放的 UI 组件

**组件定义**:
```typescript
@Component
export struct Svgaplayer {
  // ========== 状态变量 ==========
  @State private videoItem: Svgavideoentity | null = null
  @State private currentFrame: number = 0
  @State private isPlaying: boolean = false
  @State private scaleType: ImageFit = ImageFit.Contain
  
  // ========== 私有变量 ==========
  private animator: Animator | null = null
  private canvasDrawer: Svgacanvasdrawer | null = null
  private settings: PlayerSettings = new PlayerSettings()
  
  // ========== 对外暴露属性 ==========
  @Prop loops: number = 0  // 0 表示无限循环
  @Prop fillMode: FillMode = FillMode.FORWARD
  @Prop autoPlay: boolean = true
  @Prop antiAlias: boolean = true
  
  // ========== 回调函数 ==========
  onComplete?: () => void
  onError?: (error: Error) => void
  onFrame?: (frame: number, percentage: number) => void
}
```

**方法**:
```typescript
// UI 构建
build() {
  Canvas(this.context)
    .width('100%')
    .height('100%')
    .onReady((context: CanvasRenderingContext2D) => {
      this.canvasContext = context
      this.canvasDrawer = new Svgacanvasdrawer(context)
    })
    .onDraw(() => {
      this.drawFrame()
    })
}

// 设置动画源
setSource(url: string): void
setSourceFromRaw(resource: Resource): void

// 播放控制
startAnimation(): void
startAnimationWithRange(range: Svgarange, reverse?: boolean): void
stopAnimation(clear?: boolean): void
pauseAnimation(): void
resumeAnimation(): void

// 跳转指定帧
gotoFrame(frame: number): void

// 设置动态元素
setDynamicImage(pixelMap: image.PixelMap, forKey: string): void
setDynamicText(text: string, textStyle: TextStyle, forKey: string): void

// 私有方法：绘制当前帧
private drawFrame(): void

// 私有方法：动画更新监听
private onAnimatorUpdate(value: number): void
```

### 3.4 Svgacanvasdrawer (渲染引擎)

**文件路径**: `ets/svga/drawer/Svgacanvasdrawer.ets`

**职责**: 负责将动画数据渲染到 Canvas

**属性**:
```typescript
class Svgacanvasdrawer {
  private canvasContext: CanvasRenderingContext2D
  private videoItem: Svgavideoentity | null = null
  private dynamicItem: Svgadynamicentity = new Svgadynamicentity()
  
  // 性能优化：共享对象
  private sharedPaint: Paint = new Paint()
  private sharedPath: Path2D = new Path2D()
  private sharedMatrix: Matrix = new Matrix()
  
  // 缓存
  private pathCache: Map<string, Path2D> = new Map()
  private textBitmapCache: Map<string, image.PixelMap> = new Map()
}
```

**方法**:
```typescript
// 构造函数
constructor(context: CanvasRenderingContext2D)

// 设置视频实体
setVideoItem(videoItem: Svgavideoentity): void

// 设置动态元素
setDynamicItem(dynamicItem: Svgadynamicentity): void

// 绘制指定帧
.drawFrame(frameIndex: number): void

// 私有方法：绘制精灵
private drawSprite(
  sprite: Svgavideospriteentity, 
  frameIndex: number
): void

// 私有方法：绘制图片
private drawImage(
  sprite: Svgavideospriteentity, 
  frameEntity: Svgavideospriteframeentity
): void

// 私有方法：绘制形状
private drawShape(
  shape: Svgavideoshapeentity, 
  frameMatrix: Matrix
): void

// 私有方法：绘制动态元素
private drawDynamic(
  sprite: Svgavideospriteentity, 
  frameIndex: number
): void

// 私有方法：处理遮罩
private applyMatteIfNeeded(
  sprites: Array<Svgavideospriteentity>, 
  index: number
): void

// 私有方法：计算变换矩阵
private shareFrameMatrix(transform: Matrix): Matrix
```

### 3.5 数据实体类

#### Svgavideospriteentity (精灵实体)

```typescript
// ets/svga/entity/Svgavideospriteentity.ets

class Svgavideospriteentity {
  readonly imageKey: string | null = null
  readonly matteKey: string | null = null
  readonly frames: Array<Svgavideospriteframeentity> = []
  
  constructor(entity: SpriteEntity) {
    this.imageKey = entity.imageKey ?? null
    this.matteKey = entity.matteKey ?? null
    this.frames = entity.frames?.map(frame => 
      new Svgavideospriteframeentity(frame)
    ) ?? []
  }
  
  // 获取指定帧数据
  getFrameAt(index: number): Svgavideospriteframeentity | null {
    if (index < 0 || index >= this.frames.length) {
      return null
    }
    return this.frames[index]
  }
}
```

#### Svgavideospriteframeentity (帧实体)

```typescript
// ets/svga/entity/Svgavideospriteframeentity.ets

class Svgavideospriteframeentity {
  alpha: number = 0
  layout: Svgarect = new Svgarect(0, 0, 0, 0)
  transform: Matrix = new Matrix()
  maskPath: Svgapathentity | null = null
  shapes: Array<Svgavideoshapeentity> = []
  
  constructor(entity: FrameEntity) {
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
      this.transform = Matrix.fromValues([
        entity.transform.a ?? 1, entity.transform.c ?? 0, entity.transform.tx ?? 0,
        entity.transform.b ?? 0, entity.transform.d ?? 1, entity.transform.ty ?? 0,
        0, 0, 1
      ])
    }
    
    if (entity.clipPath) {
      this.maskPath = new Svgapathentity(entity.clipPath)
    }
    
    this.shapes = entity.shapes?.map(shape => 
      new Svgavideoshapeentity(shape)
    ) ?? []
  }
}
```

#### Svgavideoshapeentity (形状实体)

```typescript
// ets/svga/entity/Svgavideoshapeentity.ets

class Svgavideoshapeentity {
  styles: ShapeStyles | null = null
  transform: Matrix | null = null
  shapePath: Svgapathentity | null = null
  isKeep: boolean = false
  
  constructor(entity: ShapeEntity) {
    if (entity.styles) {
      this.styles = new ShapeStyles(entity.styles)
    }
    
    if (entity.transform) {
      this.transform = Matrix.fromTransform(entity.transform)
    }
    
    if (entity.shapePath) {
      this.shapePath = new Svgapathentity(entity.shapePath)
    }
    
    this.isKeep = entity.isKeep ?? false
  }
  
  // 构建 Path2D
  buildPath(): Path2D | null {
    return this.shapePath?.buildPath() ?? null
  }
}
```

#### Svgapathentity (路径实体)

```typescript
// ets/svga/entity/Svgapathentity.ets

class Svgapathentity {
  private originValue: string = ''
  private cachedPath: Path2D | null = null
  
  constructor(pathValue: string) {
    // 将逗号替换为空格，统一分隔符
    this.originValue = pathValue.replace(/,/g, ' ')
  }
  
  // 构建 Path2D 对象
  buildPath(): Path2D {
    if (this.cachedPath) {
      return this.cachedPath
    }
    
    const path = new Path2D()
    const tokens = this.tokenize(this.originValue)
    let currentMethod = ''
    let i = 0
    
    while (i < tokens.length) {
      const token = tokens[i]
      
      if (this.isCommand(token)) {
        currentMethod = token
        i++
        
        if (currentMethod === 'Z' || currentMethod === 'z') {
          path.closePath()
        }
      } else {
        // 解析参数并执行命令
        const params = this.parseParams(tokens, i, currentMethod)
        this.executeCommand(path, currentMethod, params)
        i += params.length
      }
    }
    
    this.cachedPath = path
    return path
  }
  
  // 执行 SVG 路径命令
  private executeCommand(path: Path2D, method: string, params: number[]): void {
    switch (method) {
      case 'M': // 绝对移动
        path.moveTo(params[0], params[1])
        break
      case 'm': // 相对移动
        // 使用相对坐标需要跟踪当前点
        break
      case 'L': // 绝对直线
        path.lineTo(params[0], params[1])
        break
      case 'l': // 相对直线
        break
      case 'C': // 绝对三次贝塞尔曲线
        path.bezierCurveTo(
          params[0], params[1],
          params[2], params[3],
          params[4], params[5]
        )
        break
      case 'c': // 相对三次贝塞尔曲线
        break
      case 'Q': // 绝对二次贝塞尔曲线
        path.quadraticCurveTo(
          params[0], params[1],
          params[2], params[3]
        )
        break
      case 'q': // 相对二次贝塞尔曲线
        break
      case 'Z':
      case 'z':
        path.closePath()
        break
    }
  }
}
```

### 3.6 辅助类

#### Svgacache (缓存管理)

```typescript
// ets/svga/utils/Svgacache.ets

class Svgacache {
  private static instance: Svgacache | null = null
  private cacheDir: string = ''
  private memoryCache: Map<string, Svgavideoentity> = new Map()
  
  static getInstance(): Svgacache
  
  // 初始化缓存目录
  initialize(context: Context): void
  
  // 生成缓存键 (MD5)
  buildCacheKey(url: string): string
  
  // 检查是否已缓存
  isCached(cacheKey: string): boolean
  
  // 获取缓存实体
  getEntity(cacheKey: string): Svgavideoentity | null
  
  // 存入缓存
  putEntity(cacheKey: string, entity: Svgavideoentity): void
  
  // 保存到本地缓存
  async saveToLocal(cacheKey: string, data: ArrayBuffer): Promise<void>
  
  // 从本地缓存读取
  async loadFromLocal(cacheKey: string): Promise<ArrayBuffer | null>
  
  // 清理缓存
  clearCache(): void
}
```

#### Svgadynamicentity (动态元素)

```typescript
// ets/svga/entity/Svgadynamicentity.ets

class Svgadynamicentity {
  // 动态图片替换
  dynamicImage: Map<string, image.PixelMap> = new Map()
  
  // 动态文本
  dynamicText: Map<string, string> = new Map()
  dynamicTextStyle: Map<string, TextStyle> = new Map()
  
  // 动态隐藏
  dynamicHidden: Map<string, boolean> = new Map()
  
  // 点击区域
  clickArea: Map<string, Rect> = new Map()
  
  // 设置方法
  setDynamicImage(pixelMap: image.PixelMap, forKey: string): void
  setDynamicText(text: string, style: TextStyle, forKey: string): void
  setDynamicHidden(hidden: boolean, forKey: string): void
  setClickArea(rect: Rect, forKey: string): void
}
```

---

## 4. 项目目录结构

```
entry/src/main/ets/
├── svga/
│   ├── component/                    # UI 组件
│   │   └── Svgaplayer.ets           # 主播放器组件
│   │
│   ├── parser/                       # 解析器模块
│   │   ├── Svgaparser.ets           # 主解析器
│   │   └── ProtoParser.ets          # Protocol Buffer 解析
│   │
│   ├── entity/                       # 数据实体
│   │   ├── Svgavideoentity.ets      # 视频实体
│   │   ├── Svgavideospriteentity.ets # 精灵实体
│   │   ├── Svgavideospriteframeentity.ets # 帧实体
│   │   ├── Svgavideoshapeentity.ets # 形状实体
│   │   ├── Svgapathentity.ets       # 路径实体
│   │   ├── Svgaaudioentity.ets      # 音频实体
│   │   └── Svgadynamicentity.ets    # 动态元素
│   │
│   ├── drawer/                       # 渲染引擎
│   │   ├── Svgacanvasdrawer.ets     # Canvas 渲染器
│   │   └── Sgvadrawer.ets           # 基础渲染器
│   │
│   ├── utils/                        # 工具类
│   │   ├── Svgacache.ets            # 缓存管理
│   │   ├── Svgarect.ets             # 矩形工具
│   │   ├── Svgamatrix.ets           # 矩阵工具
│   │   ├── Ziputils.ets             # ZIP 解压
│   │   └── Logutils.ets             # 日志工具
│   │
│   ├── types/                        # 类型定义
│   │   ├── Index.ets                # 导出类型
│   │   ├── EntityTypes.ets          # 实体类型
│   │   └── CallbackTypes.ets        # 回调类型
│   │
│   └── proto/                        # Protocol Buffer 定义
│       ├── MovieEntity.ets          # 电影实体 PB
│       ├── SpriteEntity.ets         # 精灵实体 PB
│       └── FrameEntity.ets          # 帧实体 PB
│
├── pages/                            # 示例页面
│   └── Index.ets                    # 主页面
│
└── entryability/                     # EntryAbility
    └── EntryAbility.ets
```

---

## 5. 关键技术实现

### 5.1 ZIP 解压实现

```typescript
// ets/svga/utils/Ziputils.ets

import { zlib } from '@kit.ArkTS'

class Ziputils {
  // 解压 ArrayBuffer
  static async unzip(buffer: ArrayBuffer): Promise<Map<string, ArrayBuffer>> {
    const result = new Map<string, ArrayBuffer>()
    
    // 使用 zlib 解压
    const dataView = new DataView(buffer)
    let offset = 0
    
    // 解析 ZIP 文件结构
    while (offset < buffer.byteLength) {
      // 读取本地文件头签名 (0x04034b50)
      const signature = dataView.getUint32(offset, true)
      
      if (signature !== 0x04034b50) {
        break
      }
      
      // 解析文件头
      const fileNameLength = dataView.getUint16(offset + 26, true)
      const extraFieldLength = dataView.getUint16(offset + 28, true)
      const compressedSize = dataView.getUint32(offset + 18, true)
      const compressionMethod = dataView.getUint16(offset + 8, true)
      
      // 读取文件名
      const fileNameBytes = new Uint8Array(buffer, offset + 30, fileNameLength)
      const fileName = new TextDecoder().decode(fileNameBytes)
      
      // 计算数据偏移
      const dataOffset = offset + 30 + fileNameLength + extraFieldLength
      
      // 读取压缩数据
      const compressedData = new Uint8Array(buffer, dataOffset, compressedSize)
      
      // 解压数据
      let uncompressedData: Uint8Array
      if (compressionMethod === 0) {
        // 无压缩
        uncompressedData = compressedData
      } else if (compressionMethod === 8) {
        // DEFLATE 压缩
        uncompressedData = zlib.inflateRaw(compressedData)
      } else {
        throw new Error(`Unsupported compression method: ${compressionMethod}`)
      }
      
      result.set(fileName, uncompressedData.buffer)
      
      // 移动到下一个文件
      offset = dataOffset + compressedSize
    }
    
    return result
  }
}
```

### 5.2 Protocol Buffer 解析

```typescript
// ets/svga/parser/ProtoParser.ets

// 使用 protobufjs 或自研解析器
class Protoparser {
  // 解析 MovieEntity
  static parseMovieEntity(buffer: ArrayBuffer): MovieEntity {
    const reader = new ProtoReader(buffer)
    const entity = new MovieEntity()
    
    while (reader.hasNext()) {
      const tag = reader.readTag()
      const fieldNumber = tag >> 3
      const wireType = tag & 0x07
      
      switch (fieldNumber) {
        case 1: // version
          entity.version = reader.readString()
          break
        case 2: // params
          entity.params = this.parseMovieParams(reader)
          break
        case 3: // images
          const imageEntry = this.parseImageEntry(reader)
          entity.images.set(imageEntry.key, imageEntry.value)
          break
        case 4: // sprites
          entity.sprites.push(this.parseSpriteEntity(reader))
          break
        case 5: // audios
          entity.audios.push(this.parseAudioEntity(reader))
          break
        default:
          reader.skip(wireType)
      }
    }
    
    return entity
  }
}

// Protocol Buffer 读取器
class ProtoReader {
  private view: DataView
  private offset: number = 0
  
  constructor(buffer: ArrayBuffer) {
    this.view = new DataView(buffer)
  }
  
  hasNext(): boolean {
    return this.offset < this.view.byteLength
  }
  
  readTag(): number {
    return this.readVarint()
  }
  
  readVarint(): number {
    let result = 0
    let shift = 0
    
    while (true) {
      const byte = this.view.getUint8(this.offset++)
      result |= (byte & 0x7f) << shift
      if ((byte & 0x80) === 0) {
        break
      }
      shift += 7
    }
    
    return result
  }
  
  readString(): string {
    const length = this.readVarint()
    const bytes = new Uint8Array(
      this.view.buffer, 
      this.view.byteOffset + this.offset, 
      length
    )
    this.offset += length
    return new TextDecoder().decode(bytes)
  }
  
  readBytes(): Uint8Array {
    const length = this.readVarint()
    const bytes = new Uint8Array(
      this.view.buffer,
      this.view.byteOffset + this.offset,
      length
    )
    this.offset += length
    return bytes
  }
  
  skip(wireType: number): void {
    switch (wireType) {
      case 0: // Varint
        this.readVarint()
        break
      case 2: // Length-delimited
        const length = this.readVarint()
        this.offset += length
        break
      case 5: // 32-bit
        this.offset += 4
        break
      case 1: // 64-bit
        this.offset += 8
        break
      default:
        throw new Error(`Unknown wire type: ${wireType}`)
    }
  }
}
```

### 5.3 Canvas 绘制实现

```typescript
// ets/svga/drawer/Svgacanvasdrawer.ets - 核心绘制方法

class Svgacanvasdrawer {
  private ctx: CanvasRenderingContext2D
  
  // 绘制图片精灵
  private drawImage(
    sprite: Svgavideospriteentity,
    frameEntity: Svgavideospriteframeentity
  ): void {
    const imageKey = sprite.imageKey
    if (!imageKey) return
    
    // 检查动态隐藏
    if (this.dynamicItem.dynamicHidden.get(imageKey)) {
      return
    }
    
    // 获取位图（优先使用动态图片）
    const bitmapKey = imageKey.endsWith('.matte') 
      ? imageKey.slice(0, -6) 
      : imageKey
    
    const pixelMap = this.dynamicItem.dynamicImage.get(bitmapKey) 
      ?? this.videoItem?.getImage(bitmapKey)
    
    if (!pixelMap) return
    
    // 计算变换矩阵
    const matrix = this.shareFrameMatrix(frameEntity.transform)
    
    // 保存画布状态
    this.ctx.save()
    
    // 应用遮罩
    if (frameEntity.maskPath) {
      const maskPath = frameEntity.maskPath.buildPath()
      this.ctx.clip(maskPath)
    }
    
    // 应用变换
    this.ctx.transform(
      matrix[0], matrix[1], matrix[2],
      matrix[3], matrix[4], matrix[5]
    )
    
    // 设置透明度
    this.ctx.globalAlpha = frameEntity.alpha
    
    // 绘制图片
    const imageInfo = pixelMap.getImageInfo()
    this.ctx.drawPixelMap(
      pixelMap,
      0, 0,
      frameEntity.layout.width,
      frameEntity.layout.height
    )
    
    // 恢复画布状态
    this.ctx.restore()
  }
  
  // 绘制矢量形状
  private drawShape(
    shape: Svgavideoshapeentity,
    frameMatrix: Matrix
  ): void {
    const path = shape.buildPath()
    if (!path) return
    
    // 保存画布状态
    this.ctx.save()
    
    // 应用形状变换
    if (shape.transform) {
      this.ctx.transform(
        shape.transform[0], shape.transform[1], shape.transform[2],
        shape.transform[3], shape.transform[4], shape.transform[5]
      )
    }
    
    // 应用帧变换
    this.ctx.transform(
      frameMatrix[0], frameMatrix[1], frameMatrix[2],
      frameMatrix[3], frameMatrix[4], frameMatrix[5]
    )
    
    // 填充
    if (shape.styles?.fill) {
      this.ctx.fillStyle = shape.styles.fill
      this.ctx.fill(path)
    }
    
    // 描边
    if (shape.styles?.strokeWidth && shape.styles.strokeWidth > 0) {
      this.ctx.strokeStyle = shape.styles.stroke ?? '#000000'
      this.ctx.lineWidth = shape.styles.strokeWidth
      
      // 线条端点样式
      if (shape.styles.lineCap) {
        this.ctx.lineCap = shape.styles.lineCap as CanvasLineCap
      }
      
      // 线条连接样式
      if (shape.styles.lineJoin) {
        this.ctx.lineJoin = shape.styles.lineJoin as CanvasLineJoin
      }
      
      // 虚线样式
      if (shape.styles.lineDash && shape.styles.lineDash.length >= 2) {
        this.ctx.setLineDash([
          shape.styles.lineDash[0],
          shape.styles.lineDash[1]
        ])
      }
      
      this.ctx.stroke(path)
    }
    
    // 恢复画布状态
    this.ctx.restore()
  }
}
```

### 5.4 动画驱动实现

```typescript
// ets/svga/component/Svgaplayer.ets - 动画控制

@Component
export struct Svgaplayer {
  @State private currentFrame: number = 0
  @State private isPlaying: boolean = false
  
  private animator: animator.Animator | null = null
  
  // 启动动画
  startAnimation(): void {
    if (!this.videoItem) return
    
    // 停止现有动画
    this.stopAnimation()
    
    const totalFrames = this.videoItem.frames
    const fps = this.videoItem.fps
    const duration = (totalFrames / fps) * 1000
    
    // 创建 Animator 实例
    this.animator = animator.create({
      duration: duration,
      easing: 'linear',
      fill: 'forwards',
      iterations: this.loops <= 0 ? Infinity : this.loops
    })
    
    // 监听动画帧
    this.animator.onFrame = (progress: number) => {
      // progress: 0 ~ 1
      this.currentFrame = Math.floor(progress * (totalFrames - 1))
      
      // 触发回调
      if (this.onFrame) {
        const percentage = (this.currentFrame + 1) / totalFrames
        this.onFrame(this.currentFrame, percentage)
      }
      
      // 触发重绘
      this.invalidate()
    }
    
    // 监听动画完成
    this.animator.onFinish = () => {
      this.isPlaying = false
      if (this.onComplete) {
        this.onComplete()
      }
    }
    
    // 启动动画
    this.animator.play()
    this.isPlaying = true
  }
  
  // 停止动画
  stopAnimation(clear: boolean = false): void {
    if (this.animator) {
      this.animator.cancel()
      this.animator = null
    }
    
    this.isPlaying = false
    
    if (clear) {
      this.currentFrame = 0
      this.invalidate()
    }
  }
  
  // 暂停动画
  pauseAnimation(): void {
    if (this.animator && this.isPlaying) {
      this.animator.pause()
      this.isPlaying = false
    }
  }
  
  // 恢复动画
  resumeAnimation(): void {
    if (this.animator && !this.isPlaying) {
      this.animator.resume()
      this.isPlaying = true
    }
  }
  
  // 跳转到指定帧
  gotoFrame(frame: number): void {
    this.stopAnimation()
    
    if (this.videoItem) {
      this.currentFrame = Math.max(0, Math.min(frame, this.videoItem.frames - 1))
      this.invalidate()
    }
  }
  
  // 触发重绘
  private invalidate(): void {
    // 在鸿蒙中，修改 @State 变量会自动触发重绘
    // 或者可以强制刷新 Canvas
    this.canvasContext?.invalidate()
  }
}
```

---

## 6. 性能优化策略

### 6.1 对象池机制

```typescript
// ets/svga/utils/ObjectPool.ets

class ObjectPool<T> {
  private pool: T[] = []
  private factory: () => T
  private maxSize: number
  
  constructor(factory: () => T, maxSize: number = 10) {
    this.factory = factory
    this.maxSize = maxSize
  }
  
  // 获取对象
  acquire(): T {
    if (this.pool.length > 0) {
      return this.pool.pop()!
    }
    return this.factory()
  }
  
  // 回收对象
  release(obj: T): void {
    if (this.pool.length < this.maxSize) {
      this.pool.push(obj)
    }
  }
  
  // 批量回收
  releaseAll(objs: T[]): void {
    for (const obj of objs) {
      this.release(obj)
    }
  }
}

// 使用对象池
const spritePool = new ObjectPool(() => new Svgadrawersprite(), 20)
const pathPool = new ObjectPool(() => new Path2D(), 50)
```

### 6.2 路径缓存

```typescript
// ets/svga/drawer/PathCache.ets

class PathCache {
  private cache: Map<string, Path2D> = new Map()
  private lastCanvasWidth: number = 0
  private lastCanvasHeight: number = 0
  
  // 检查画布尺寸变化，清空缓存
  onSizeChanged(width: number, height: number): void {
    if (width !== this.lastCanvasWidth || height !== this.lastCanvasHeight) {
      this.cache.clear()
      this.lastCanvasWidth = width
      this.lastCanvasHeight = height
    }
  }
  
  // 获取缓存的路径
  getPath(key: string): Path2D | undefined {
    return this.cache.get(key)
  }
  
  // 存入缓存
  putPath(key: string, path: Path2D): void {
    this.cache.set(key, path)
  }
  
  // 构建路径（带缓存）
  buildPath(shape: Svgavideoshapeentity): Path2D | null {
    const key = shape.hashCode().toString()
    
    let path = this.cache.get(key)
    if (!path && shape.shapePath) {
      path = shape.shapePath.buildPath()
      this.cache.set(key, path)
    }
    
    return path
  }
  
  // 清空缓存
  clear(): void {
    this.cache.clear()
  }
}
```

### 6.3 位图缓存

```typescript
// ets/svga/utils/BitmapCache.ets

class BitmapCache {
  private memoryCache: Map<string, image.PixelMap> = new Map()
  private maxCacheSize: number = 50 * 1024 * 1024 // 50MB
  private currentCacheSize: number = 0
  
  // 获取位图
  get(key: string): image.PixelMap | undefined {
    return this.memoryCache.get(key)
  }
  
  // 存入位图
  put(key: string, bitmap: image.PixelMap): void {
    const bitmapSize = this.calculateBitmapSize(bitmap)
    
    // 如果超过缓存上限，清理最旧的缓存
    while (this.currentCacheSize + bitmapSize > this.maxCacheSize && 
           this.memoryCache.size > 0) {
      this.evictOldest()
    }
    
    this.memoryCache.set(key, bitmap)
    this.currentCacheSize += bitmapSize
  }
  
  // 计算位图大小
  private calculateBitmapSize(bitmap: image.PixelMap): number {
    const info = bitmap.getImageInfo()
    // 假设 ARGB_8888 格式，每像素4字节
    return info.size.width * info.size.height * 4
  }
  
  // 清理最旧的缓存
  private evictOldest(): void {
    const firstKey = this.memoryCache.keys().next().value
    if (firstKey) {
      const bitmap = this.memoryCache.get(firstKey)
      if (bitmap) {
        this.currentCacheSize -= this.calculateBitmapSize(bitmap)
      }
      this.memoryCache.delete(firstKey)
    }
  }
  
  // 清空缓存
  clear(): void {
    this.memoryCache.clear()
    this.currentCacheSize = 0
  }
}
```

### 6.4 离屏渲染

```typescript
// 使用 OffscreenCanvas 进行离屏渲染
class OffscreenRenderer {
  private offscreenCanvas: OffscreenCanvas | null = null
  private offscreenCtx: OffscreenCanvasRenderingContext2D | null = null
  
  // 初始化离屏画布
  initialize(width: number, height: number): void {
    this.offscreenCanvas = new OffscreenCanvas({
      width: width,
      height: height
    })
    this.offscreenCtx = this.offscreenCanvas.getContext('2d')
  }
  
  // 在离屏画布上绘制
  drawToOffscreen(drawFn: (ctx: OffscreenCanvasRenderingContext2D) => void): void {
    if (!this.offscreenCtx) return
    
    this.offscreenCtx.save()
    drawFn(this.offscreenCtx)
    this.offscreenCtx.restore()
  }
  
  // 将离屏内容绘制到目标画布
  drawToTarget(ctx: CanvasRenderingContext2D, x: number, y: number): void {
    if (!this.offscreenCanvas) return
    
    const bitmap = this.offscreenCanvas.transferToImageBitmap()
    ctx.drawImage(bitmap, x, y)
  }
}
```

---

## 总结

本方案完整移植了 Android SVGAPlayer 的核心功能到 HarmonyOS NEXT 平台，主要特点：

1. **架构清晰**：模块化设计，职责分离
2. **性能优化**：对象池、缓存机制、离屏渲染
3. **功能完整**：支持图片、矢量形状、遮罩、动态元素、音频
4. **符合规范**：严格遵循 HarmonyOS NEXT 开发规范
5. **易于使用**：声明式组件，API 设计友好

下一步可以开始根据此方案进行具体代码实现。
