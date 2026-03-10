# SVGA动画文件说明

## 本地SVGA示例文件

本目录用于存放本地SVGA动画文件。SVGA是一种矢量动画格式，专为移动应用优化。

### 获取示例SVGA文件

1. **官方示例**：
   - 访问 [SVGA官方示例库](https://github.com/svga/SVGA-Samples)
   - 下载示例SVGA文件到本目录

2. **常用示例文件**：
   - `EmptyState.svga` - 空状态动画
   - `Hippo.svga` - 河马动画
   - `PinJump.svga` - 跳跃动画
   - `Rainbow.svga` - 彩虹动画

### 使用方法

在代码中通过以下方式引用本地SVGA文件：

```typescript
// 加载本地SVGA文件
this.src = '$rawfile(local_animation.svga)';
```

### 注意事项

- SVGA文件是二进制格式，请勿修改文件扩展名
- 确保文件大小合理，避免影响应用性能
- 支持网络和本地SVGA文件混合使用