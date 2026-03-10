/**
 * SVGA Player for HarmonyOS NEXT
 * 类型定义
 */

// 布局参数
export interface LayoutParams {
  x?: number
  y?: number
  width?: number
  height?: number
}

// 变换矩阵参数
export interface TransformParams {
  a?: number
  b?: number
  c?: number
  d?: number
  tx?: number
  ty?: number
}

// 形状样式参数
export interface ShapeStyleParams {
  fill?: string
  stroke?: string
  strokeWidth?: number
  lineCap?: string
  lineJoin?: string
  miterLimit?: number
  lineDash?: number[]
}

// 形状实体参数
export interface ShapeEntityParams {
  styles?: ShapeStyleParams
  transform?: TransformParams
  shapePath?: string
  isKeep?: boolean
}

// 帧实体参数
export interface FrameEntityParams {
  alpha?: number
  layout?: LayoutParams
  transform?: TransformParams
  clipPath?: string
  shapes?: ShapeEntityParams[]
}

// 精灵实体参数
export interface SpriteEntityParams {
  imageKey?: string
  matteKey?: string
  frames?: FrameEntityParams[]
}

// 视频实体参数
export interface VideoEntityParams {
  version?: string
  fps?: number
  frames?: number
  videoSize?: LayoutParams
}

// 电影参数 (用于解析器)
export interface MovieParams {
  viewBoxWidth?: number
  viewBoxHeight?: number
  fps?: number
  frames?: number
}

// 电影实体 (用于解析器)
export interface MovieEntity {
  version?: string
  params?: MovieParams
  images?: Map<string, Uint8Array>
  sprites?: SpriteEntityParams[]
  audios?: AudioEntityParams[]
}

// 音频实体参数
export interface AudioEntityParams {
  audioKey?: string
  startFrame?: number
  endFrame?: number
  startTime?: number
  totalTime?: number
}


// 坐标点接口
export interface Point {
  x: number
  y: number
}

// 视频实体构造参数
export interface VideoEntityConstructorParams {
  version?: string
  fps?: number
  frames?: number
  videoSize?: LayoutParams
}