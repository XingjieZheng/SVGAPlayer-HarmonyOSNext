# HarmonyOS NEXT SVGA Player

HarmonyOS NEXT 原生 SVGA 动画播放器，基于 ArkTS 语言开发。

## 📦 功能特性

- ✅ **完整播放控制**: 播放、暂停、停止、跳转
- ✅ **循环播放**: 支持无限循环或指定次数
- ✅ **Canvas 渲染**: 高性能 Canvas 2D 渲染
- ✅ **动态元素**: 支持动态替换图片、文本、隐藏元素
- ✅ **完整日志**: 详细的日志系统，便于排查问题
- ✅ **单元测试**: 全面的测试覆盖
- ✅ **符合规范**: 严格遵循 HarmonyOS NEXT 开发规范

## 📁 项目结构

```
SVGAPlayer_OpenCode2/
├── library/                      # SVGA 播放器库
│   ├── src/main/ets/svga/
│   │   ├── component/           # UI 组件
│   │   ├── drawer/              # 渲染引擎
│   │   ├── entity/              # 数据实体
│   │   ├── parser/              # 解析器
│   │   └── utils/               # 工具类
│   └── Index.ets                # 库入口
│
├── entry/                        # Demo 应用
│   └── src/main/ets/pages/
│       └── Index.ets            # 演示页面
│
└── entry/src/ohosTest/          # 单元测试
    └── ets/test/
        └── SvgaPlayerTest.ets
```

## 🚀 快速开始

### 1. 安装依赖

```bash
# 在项目根目录
cd library && ohpm install
cd ../entry && ohpm install
```

### 2. 在 entry 中使用

```typescript
import { Svgaplayer, Svgaparser, LogUtils, LogLevel } from '@svga/library'

@Entry
@Component
struct MyPage {
  private playerRef: Svgaplayer | null = null

  aboutToAppear() {
    // 启用调试日志
    LogUtils.setLogLevel(LogLevel.DEBUG)
    
    // 加载 SVGA 动画
    const parser = Svgaparser.getInstance()
    parser.decodeFromUrl('https://example.com/animation.svga', {
      onComplete: (videoItem) => {
        this.playerRef?.setVideoItem(videoItem)
      },
      onError: (error) => {
        console.error('加载失败:', error)
      }
    })
  }

  build() {
    Column() {
      Svgaplayer({ loops: 0, autoPlay: true })
        .width(300)
        .height(300)
        .onReady((ref) => {
          this.playerRef = ref
        })
    }
  }
}
```

### 3. 播放控制

```typescript
// 播放
this.playerRef?.startAnimation()

// 暂停
this.playerRef?.pauseAnimation()

// 停止
this.playerRef?.stopAnimation()

// 跳转到指定帧
this.playerRef?.gotoFrame(30)
```

### 4. 动态元素

```typescript
// 替换图片
this.playerRef?.setDynamicImage(pixelMap, 'imageKey')

// 设置动态文本
this.playerRef?.setDynamicText('Hello', {
  fontSize: 24,
  color: '#FF0000'
}, 'labelKey')

// 隐藏元素
this.playerRef?.setDynamicHidden(true, 'elementKey')
```

## 📋 API 文档

### Svgaplayer 组件

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| loops | number | 0 | 循环次数，0为无限 |
| autoPlay | boolean | true | 自动播放 |
| antiAlias | boolean | true | 抗锯齿 |
| fillMode | FillMode | FORWARD | 填充模式 |

### 回调函数

```typescript
interface PlayerCallbacks {
  onComplete?: () => void          // 播放完成
  onError?: (error: Error) => void  // 播放错误
  onFrame?: (frame: number, percentage: number) => void  // 帧更新
}
```

### LogUtils 日志工具

```typescript
// 设置日志级别
LogUtils.setLogLevel(LogLevel.DEBUG)

// 打印信息
LogUtils.info('TAG', 'message')
LogUtils.debug('TAG', 'message')
LogUtils.warn('TAG', 'message')
LogUtils.error('TAG', 'message', error)

// 打印分隔线（用于标记重要流程）
LogUtils.printDivider('TAG', '开始播放')

// 打印动画状态
LogUtils.logAnimationState('TAG', 'PLAYING', { frame: 10 })

// 打印性能信息
LogUtils.logPerformance('TAG', '渲染', 16.5)
```

## 🧪 运行测试

```bash
# 在 entry 目录下运行测试
cd entry
ohpm test
```

## 📊 测试覆盖

- ✅ Svgarect - 矩形工具
- ✅ Svgamatrix - 矩阵变换
- ✅ Svgapathentity - 路径解析
- ✅ Svgavideoshapeentity - 形状实体
- ✅ Svgavideospriteframeentity - 帧实体
- ✅ Svgavideospriteentity - 精灵实体
- ✅ Svgavideoentity - 视频实体
- ✅ Svgadynamicentity - 动态元素
- ✅ 集成测试

## 🎯 实现特性

### 动画驱动
使用鸿蒙 `requestAnimationFrame` 实现平滑动画循环，自动计算当前帧索引。

### Canvas 渲染
- 图片精灵渲染（支持动态替换）
- 矢量形状渲染（fill/stroke/lineDash）
- 遮罩处理（clip）
- 变换矩阵应用

### 性能优化
- Path2D 缓存
- 位图缓存
- 共享矩阵/路径对象

## 📝 日志排查

播放器内置完整的日志系统，开启 DEBUG 级别可查看：

```
[SVGAPlayer] [Svgaparser] ================ Decode from URL ================
[SVGAPlayer] [Svgaparser] Downloading: https://example.com/animation.svga
[SVGAPlayer] [Svgaparser] Download complete: 1024 bytes, took 150ms
[SVGAPlayer] [Svgaparser] Building video entity from JSON
[SVGAPlayer] [Svgaplayer] ================ Setting video item ================
[SVGAPlayer] [Svgaplayer] Video item set: 60 frames, 30 FPS
[SVGAPlayer] [Svgaplayer] ================ Starting animation ================
[SVGAPlayer] [Svgacanvasdrawer] Rendering frame 0, sprites: 5
[SVGAPlayer] [Svgacanvasdrawer] Draw frame 0 took 12.50ms
```

## 🔧 依赖要求

- HarmonyOS NEXT API 12+
- ArkTS 语言
- DevEco Studio 4.0+

## 📄 许可证

Apache-2.0

## 🤝 贡献

欢迎提交 Issue 和 PR！

## 📞 支持

如有问题，请查看日志输出或提交 Issue。

---

**基于 Android SVGAPlayer 移植，遵循 HarmonyOS NEXT 开发规范**
