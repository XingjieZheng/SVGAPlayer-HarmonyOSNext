# 鸿蒙SVGA播放器 (HarmonyOS SVGA Player)

基于Android SVGA播放器原理实现的鸿蒙原生SVGA动画播放器，不使用WebView方案。

## 功能特性

- 支持本地和网络SVGA动画播放
- 播放控制（播放/暂停/停止/跳转）
- 动态内容替换（图像、文本、自定义绘制）
- 事件监听
- 循环播放
- 性能优化的Canvas渲染

## 安装

将此库作为HAR（HarmonyOS Ability Resource）模块引入到您的项目中。

## 使用方法

### 1. 基础使用

```typescript
import { SVGAPlayer, SVGAPlayerOptions, SVGAEventType } from 'your-harmony-project/library';

// 创建播放器选项
const options: SVGAPlayerOptions = {
  url: 'https://example.com/animation.svga',  // 网络资源
  // 或者
  path: 'path/to/local/animation.svga',       // 本地资源
  autoPlay: true,                             // 自动播放
  loop: 0,                                   // 循环次数，0表示无限循环
  fillMode: 'Forward'                        // 填充模式
};

// 创建播放器实例
const player = new SVGAPlayer(options);

// 添加事件监听器
player.addEventListener(SVGAEventType.Loaded, (event) => {
  console.log('SVGA动画加载完成');
  player.play(); // 开始播放
});

player.addEventListener(SVGAEventType.Progress, (event) => {
  console.log(`播放进度: ${event.payload.progress}`);
});

// 加载资源
player.load(options);
```

### 2. 使用组件

```typescript
import { SVGAPlayerComponent } from 'your-harmony-project/library';

// 在ArkUI组件中使用
@Entry
@Component
struct MainPage {
  build() {
    Column() {
      SVGAPlayerComponent({
        options: {
          url: 'https://example.com/animation.svga',
          autoPlay: true
        }
      })
      .width('300px')
      .height('300px')
    }
  }
}
```

### 3. 播放控制

```typescript
// 播放
player.play();

// 暂停
player.pause();

// 停止
player.stop();

// 跳转到指定帧
player.stepToFrame(10, true); // 跳转到第10帧并继续播放

// 跳转到指定百分比
player.stepToPercentage(0.5, false); // 跳转到50%位置并停止
```

### 4. 动态内容替换

```typescript
// 替换图像
player.setDynamicImage('image_key', $r('app.media.new_image'));

// 替换文本
player.setDynamicText('text_key', '新的文本');

// 设置动态绘制函数
player.setDynamicDrawer('drawer_key', (context, frame) => {
  // 自定义绘制逻辑
  context.fillStyle = '#FF0000';
  context.fillRect(10, 10, 50, 50);
});

// 设置带尺寸的动态绘制函数
player.setDynamicDrawerSized('sized_drawer_key', (context, frame, width, height) => {
  // 根据尺寸进行自定义绘制
  context.fillStyle = '#00FF00';
  context.fillRect(0, 0, width, height);
});

// 隐藏元素
player.setHidden('element_key', true);
```

### 5. 事件监听

```typescript
player.addEventListener(SVGAEventType.LoadStart, (event) => {
  console.log('开始加载');
});

player.addEventListener(SVGAEventType.Loaded, (event) => {
  console.log('加载完成');
});

player.addEventListener(SVGAEventType.Play, (event) => {
  console.log('开始播放');
});

player.addEventListener(SVGAEventType.Pause, (event) => {
  console.log('暂停播放');
});

player.addEventListener(SVGAEventType.Stop, (event) => {
  console.log('停止播放');
});

player.addEventListener(SVGAEventType.Finish, (event) => {
  console.log('播放完成');
});

player.addEventListener(SVGAEventType.Progress, (event) => {
  console.log(`播放进度: ${event.payload.progress}`);
});

player.addEventListener(SVGAEventType.Error, (event) => {
  console.log(`播放错误: ${event.payload.message}`);
});
```

## API参考

### SVGAPlayerOptions

- `url`: 网络资源URL
- `path`: 本地资源路径
- `loop`: 循环次数，0表示无限循环
- `autoPlay`: 是否自动播放
- `clearsAfterStop`: 停止后是否清除
- `fillMode`: 填充模式 ('Forward' | 'Backward' | 'Clear')

### SVGAEventType

- `LoadStart`: 开始加载
- `Loaded`: 加载完成
- `Play`: 开始播放
- `Pause`: 暂停播放
- `Stop`: 停止播放
- `Finish`: 播放完成
- `Progress`: 播放进度
- `Error`: 错误事件

## 权限要求

在 `config.json` 或 `module.json5` 中添加网络访问权限：

```json
{
  "requestPermissions": [
    {
      "name": "ohos.permission.INTERNET"
    }
  ]
}
```

## 注意事项

1. 确保网络权限已正确配置
2. 对于大体积SVGA文件，请考虑内存使用情况
3. 在组件销毁时记得调用清理方法避免内存泄漏

## 技术实现

该实现参考了Android SVGA播放器的架构设计：
- SVGAParser: 解析SVGA文件
- SVGAVideoEntity: 存储动画数据
- SVGACanvasDrawer: Canvas绘制逻辑
- SVGAPlayer: 控制接口
- SVGAPlayerComponent: ArkUI组件封装