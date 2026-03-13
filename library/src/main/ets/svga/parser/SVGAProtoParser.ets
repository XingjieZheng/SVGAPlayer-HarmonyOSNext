/**
 * SVGA Player for HarmonyOS NEXT
 * 基于静态解析逻辑的 SVGA Protobuf 解析器
 *
 * 方案二：使用手动实现的静态解析逻辑（基于 protobuf 格式规范）
 */

import protobuf from '@ohos/protobufjs'
import { LogUtils } from '../utils/LogUtils'
import {
  FullParseResult,
  SpriteEntityParams,
  FrameEntityParams,
  ShapeEntityParams,
  ShapeStyleParams,
  LayoutParams,
  TransformParams,
} from '../types/SVGATypes'

// MovieParams 接口
interface MovieParams {
  width: number
  height: number
  fps: number
  frames: number
}

export class SVGAProtoParser {
  private static readonly TAG: string = 'SVGAProtoParser'

  /**
   * 解析完整的 MovieEntity 数据
   * 使用静态解析逻辑
   */
  static parseFullData(data: Uint8Array): FullParseResult {
    try {
      const result = SVGAProtoParser.parseMovieEntity(data)

      LogUtils.info(SVGAProtoParser.TAG,
        'Parsed (static): ' + result.width + 'x' + result.height + ', ' + result.fps + 'fps, ' +
        result.frames + 'frames, ' + result.images.size + ' images, ' + result.sprites.length + ' sprites')
      return result
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e)
      LogUtils.error(SVGAProtoParser.TAG, 'Failed to parse full data: ' + errorMessage)
      throw new Error('Failed to parse full data: ' + errorMessage)
    }
  }

  /**
   * 解析 MovieEntity
   */
  private static parseMovieEntity(data: Uint8Array): FullParseResult {
    const reader = protobuf.Reader.create(data)

    let version: string = ''
    let params: MovieParams | null = null
    const images: Map<string, Uint8Array> = new Map()
    const sprites: SpriteEntityParams[] = []

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      LogUtils.debug(SVGAProtoParser.TAG, `parseMovieEntity: tag=${tag}, fieldNum=${fieldNum}, wireType=${wireType}, pos=${reader.pos}`)

      switch (fieldNum) {
        case 1: // version
          if (wireType === 2) { // LENGTH_DELIMITED
            version = reader.string()
          }
          break
        case 2: // params (nested message or group)
          LogUtils.debug(SVGAProtoParser.TAG, `parseMovieEntity: field 2 (params), wireType=${wireType}`)
          if (wireType === 2) { // LENGTH_DELIMITED
            params = SVGAProtoParser.parseMovieParams(reader)
            LogUtils.info(SVGAProtoParser.TAG, `parseMovieEntity: params parsed via LENGTH_DELIMITED: ${JSON.stringify(params)}`)
          } else if (wireType === 3) { // START_GROUP (proto2 group)
            params = SVGAProtoParser.parseMovieParamsGroup(reader)
            LogUtils.info(SVGAProtoParser.TAG, `parseMovieEntity: params parsed via START_GROUP: ${JSON.stringify(params)}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseMovieEntity: unexpected wireType=${wireType} for params`)
          }
          break
        case 3: // images
          if (wireType === 2) { // LENGTH_DELIMITED
            SVGAProtoParser.parseImagesEntry(reader, images)
          }
          break
        case 4: // sprites
          if (wireType === 2) { // LENGTH_DELIMITED
            const sprite = SVGAProtoParser.parseSpriteEntity(reader)
            sprites.push(sprite)
          }
          break
        default:
          LogUtils.debug(SVGAProtoParser.TAG, `parseMovieEntity: skipping unknown field ${fieldNum}, wireType=${wireType}`)
          SVGAProtoParser.skipField(reader, wireType)
          break
      }
    }

    const result = new FullParseResult()
    result.fps = params?.fps ?? 0
    result.frames = params?.frames ?? 0
    result.width = params?.width ?? 0
    result.height = params?.height ?? 0

    // 复制 images
    const imageEntries = images.entries()
    for (const entry of imageEntries) {
      result.images.set(entry[0], entry[1])
    }

    result.sprites = sprites

    return result
  }

  /**
   * 解析 MovieParams (LENGTH_DELIMITED 格式)
   */
  private static parseMovieParams(reader: protobuf.Reader): MovieParams {
    const nestedData = reader.bytes()
    LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParams: LENGTH_DELIMITED, nestedData.length=${nestedData.length}, bytes=[${nestedData.slice(0, Math.min(10, nestedData.length)).join(',')}]`)

    if (nestedData.length === 0) {
      LogUtils.warn(SVGAProtoParser.TAG, `parseMovieParams: nestedData is empty, returning default params`)
      return { width: 0, height: 0, fps: 0, frames: 0 }
    }

    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseMovieParamsFromReader(nestedReader)
  }

  /**
   * 解析 MovieParams (GROUP 格式 - proto2)
   */
  private static parseMovieParamsGroup(reader: protobuf.Reader): MovieParams {
    LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsGroup: START_GROUP`)
    const params = SVGAProtoParser.parseMovieParamsFromReader(reader)
    // 读取 END_GROUP 标记 (field 2, wire type 4)
    const endTag = reader.uint32()
    const endFieldNum = endTag >>> 3
    const endWireType = endTag & 7
    LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsGroup: END_GROUP, tag=${endTag}, fieldNum=${endFieldNum}, wireType=${endWireType}`)
    return params
  }

  /**
   * 从 Reader 解析 MovieParams
   */
  private static parseMovieParamsFromReader(reader: protobuf.Reader): MovieParams {
    const params: MovieParams = { width: 0, height: 0, fps: 0, frames: 0 }

    LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: starting, reader.pos=${reader.pos}, reader.len=${reader.len}`)

    // 检查是否有数据可读
    if (reader.len === 0 || reader.pos >= reader.len) {
      LogUtils.warn(SVGAProtoParser.TAG, `parseMovieParamsFromReader: no data to read, returning defaults`)
      return params
    }

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: tag=${tag}, fieldNum=${fieldNum}, wireType=${wireType}, pos=${reader.pos}`)

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: END_GROUP detected, stopping`)
        reader.pos-- // 回退 tag 位置
        break
      }

      switch (fieldNum) {
        case 1: // width - 支持 VARINT (wireType=0) 和 FLOAT (wireType=5)
          if (wireType === 0) {
            params.width = reader.int32()
            LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: width (VARINT)=${params.width}`)
          } else if (wireType === 5) {
            params.width = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: width (FLOAT)=${params.width}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseMovieParamsFromReader: width has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 2: // height - 支持 VARINT (wireType=0) 和 FLOAT (wireType=5)
          if (wireType === 0) {
            params.height = reader.int32()
            LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: height (VARINT)=${params.height}`)
          } else if (wireType === 5) {
            params.height = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: height (FLOAT)=${params.height}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseMovieParamsFromReader: height has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 3: // fps
          if (wireType === 0) {
            params.fps = reader.int32()
            LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: fps=${params.fps}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseMovieParamsFromReader: fps has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 4: // frames
          if (wireType === 0) {
            params.frames = reader.int32()
            LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: frames=${params.frames}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseMovieParamsFromReader: frames has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        default:
          LogUtils.debug(SVGAProtoParser.TAG, `parseMovieParamsFromReader: skipping unknown field ${fieldNum}`)
          reader.skipType(wireType)
          break
      }
    }

    LogUtils.info(SVGAProtoParser.TAG, `parseMovieParamsFromReader: completed, params=${JSON.stringify(params)}`)
    return params
  }

  /**
   * 解析 Images Map Entry
   */
  private static parseImagesEntry(reader: protobuf.Reader, images: Map<string, Uint8Array>): void {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)

    let key: string = ''
    let value: Uint8Array = new Uint8Array()

    while (nestedReader.pos < nestedReader.len) {
      const tag = nestedReader.uint32()
      const fieldNum = tag >>> 3

      switch (fieldNum) {
        case 1: // key
          key = nestedReader.string()
          break
        case 2: // value
          value = nestedReader.bytes()
          break
        default:
          nestedReader.skipType(tag & 7)
          break
      }
    }
    images.set(key, value)
  }

  /**
   * 解析 SpriteEntity
   */
  private static parseSpriteEntity(reader: protobuf.Reader): SpriteEntityParams {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)

    const sprite: SpriteEntityParams = { imageKey: '', matteKey: '', frames: [] }

    while (nestedReader.pos < nestedReader.len) {
      const tag = nestedReader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      switch (fieldNum) {
        case 1: // imageKey
          sprite.imageKey = nestedReader.string()
          break
        case 2: // frames (nested message or group)
          if (wireType === 2) { // LENGTH_DELIMITED
            const frame = SVGAProtoParser.parseFrameEntity(nestedReader)
            sprite.frames?.push(frame)
          } else if (wireType === 3) { // START_GROUP
            const frame = SVGAProtoParser.parseFrameEntityGroup(nestedReader)
            sprite.frames?.push(frame)
          }
          break
        case 3: // matteKey
          sprite.matteKey = nestedReader.string()
          break
        default:
          nestedReader.skipType(wireType)
          break
      }
    }
    return sprite
  }

  /**
   * 解析 FrameEntity (LENGTH_DELIMITED 格式)
   */
  private static parseFrameEntity(reader: protobuf.Reader): FrameEntityParams {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseFrameEntityFromReader(nestedReader)
  }

  /**
   * 解析 FrameEntity (GROUP 格式 - proto2)
   */
  private static parseFrameEntityGroup(reader: protobuf.Reader): FrameEntityParams {
    const frame = SVGAProtoParser.parseFrameEntityFromReader(reader)
    // 读取 END_GROUP 标记 (field 2, wire type 4)
    reader.uint32()
    return frame
  }

  /**
   * 从 Reader 解析 FrameEntity
   */
  private static parseFrameEntityFromReader(reader: protobuf.Reader): FrameEntityParams {
    const frame: FrameEntityParams = {
      alpha: 1.0,
      layout: { x: 0, y: 0, width: 0, height: 0 },
      transform: { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 },
      clipPath: '',
      shapes: [],
    }

    LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: starting, reader.pos=${reader.pos}, reader.len=${reader.len}`)

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: fieldNum=${fieldNum}, wireType=${wireType}, pos=${reader.pos}`)

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: END_GROUP detected, stopping`)
        reader.pos-- // 回退 tag 位置
        break
      }

      // 如果遇到无效的 wire type，跳过
      if (wireType > 5 && wireType !== 3) {
        LogUtils.warn(SVGAProtoParser.TAG, `parseFrameEntityFromReader: invalid wire type ${wireType}, skipping`)
        reader.skipType(wireType)
        continue
      }

      switch (fieldNum) {
        case 1: // alpha - 支持 VARINT (wireType=0) 和 FLOAT (wireType=5)
          if (wireType === 0) { // VARINT
            frame.alpha = reader.int32() / 255.0
            LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: alpha (VARINT)=${frame.alpha}`)
          } else if (wireType === 5) { // FLOAT
            frame.alpha = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: alpha (FLOAT)=${frame.alpha}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseFrameEntityFromReader: alpha has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 2: // layout
          if (wireType === 2) {
            frame.layout = SVGAProtoParser.parseLayout(reader)
          } else if (wireType === 3) {
            frame.layout = SVGAProtoParser.parseLayoutGroup(reader)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseFrameEntityFromReader: layout has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 3: // transform
          if (wireType === 2) {
            frame.transform = SVGAProtoParser.parseTransform(reader)
          } else if (wireType === 3) {
            frame.transform = SVGAProtoParser.parseTransformGroup(reader)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseFrameEntityFromReader: transform has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 4: // clipPath
          if (wireType === 2) {
            frame.clipPath = reader.string()
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseFrameEntityFromReader: clipPath has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 5: // shapes
          if (wireType === 2) {
            const shape = SVGAProtoParser.parseShapeEntity(reader)
            frame.shapes?.push(shape)
          } else if (wireType === 3) {
            const shape = SVGAProtoParser.parseShapeEntityGroup(reader)
            frame.shapes?.push(shape)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseFrameEntityFromReader: shapes has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        default:
          LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: skipping unknown field ${fieldNum}`)
          reader.skipType(wireType)
          break
      }
    }

    LogUtils.debug(SVGAProtoParser.TAG, `parseFrameEntityFromReader: completed`)
    return frame
  }

  /**
   * 解析 Layout (LENGTH_DELIMITED 格式)
   */
  private static parseLayout(reader: protobuf.Reader): LayoutParams {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseLayoutFromReader(nestedReader)
  }

  /**
   * 解析 Layout (GROUP 格式 - proto2)
   */
  private static parseLayoutGroup(reader: protobuf.Reader): LayoutParams {
    const layout = SVGAProtoParser.parseLayoutFromReader(reader)
    // 读取 END_GROUP 标记
    reader.uint32()
    return layout
  }

  /**
   * 从 Reader 解析 Layout
   */
  private static parseLayoutFromReader(reader: protobuf.Reader): LayoutParams {
    const layout: LayoutParams = { x: 0, y: 0, width: 0, height: 0 }

    LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: starting, reader.pos=${reader.pos}, reader.len=${reader.len}`)

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: fieldNum=${fieldNum}, wireType=${wireType}, pos=${reader.pos}`)

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: END_GROUP detected, stopping`)
        reader.pos-- // 回退 tag 位置
        break
      }

      switch (fieldNum) {
        case 1: // x
          if (wireType === 5) {
            layout.x = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: x=${layout.x}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseLayoutFromReader: x has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 2: // y
          if (wireType === 5) {
            layout.y = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: y=${layout.y}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseLayoutFromReader: y has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 3: // width
          if (wireType === 5) {
            layout.width = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: width=${layout.width}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseLayoutFromReader: width has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 4: // height
          if (wireType === 5) {
            layout.height = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: height=${layout.height}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseLayoutFromReader: height has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        default:
          LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: skipping unknown field ${fieldNum}`)
          reader.skipType(wireType)
          break
      }
    }

    LogUtils.debug(SVGAProtoParser.TAG, `parseLayoutFromReader: completed, layout=${JSON.stringify(layout)}`)
    return layout
  }

  /**
   * 解析 Transform (LENGTH_DELIMITED 格式)
   */
  private static parseTransform(reader: protobuf.Reader): TransformParams {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseTransformFromReader(nestedReader)
  }

  /**
   * 解析 Transform (GROUP 格式 - proto2)
   */
  private static parseTransformGroup(reader: protobuf.Reader): TransformParams {
    const transform = SVGAProtoParser.parseTransformFromReader(reader)
    // 读取 END_GROUP 标记
    reader.uint32()
    return transform
  }

  /**
   * 从 Reader 解析 Transform
   */
  private static parseTransformFromReader(reader: protobuf.Reader): TransformParams {
    const transform: TransformParams = { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 }

    LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: starting, reader.pos=${reader.pos}, reader.len=${reader.len}`)

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: fieldNum=${fieldNum}, wireType=${wireType}, pos=${reader.pos}`)

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: END_GROUP detected, stopping`)
        reader.pos-- // 回退 tag 位置
        break
      }

      switch (fieldNum) {
        case 1: // a
          if (wireType === 5) {
            transform.a = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: a=${transform.a}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseTransformFromReader: a has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 2: // b
          if (wireType === 5) {
            transform.b = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: b=${transform.b}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseTransformFromReader: b has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 3: // c
          if (wireType === 5) {
            transform.c = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: c=${transform.c}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseTransformFromReader: c has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 4: // d
          if (wireType === 5) {
            transform.d = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: d=${transform.d}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseTransformFromReader: d has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 5: // tx
          if (wireType === 5) {
            transform.tx = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: tx=${transform.tx}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseTransformFromReader: tx has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        case 6: // ty
          if (wireType === 5) {
            transform.ty = reader.float()
            LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: ty=${transform.ty}`)
          } else {
            LogUtils.warn(SVGAProtoParser.TAG, `parseTransformFromReader: ty has unexpected wire type ${wireType}`)
            reader.skipType(wireType)
          }
          break
        default:
          LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: skipping unknown field ${fieldNum}`)
          reader.skipType(wireType)
          break
      }
    }

    LogUtils.debug(SVGAProtoParser.TAG, `parseTransformFromReader: completed, transform=${JSON.stringify(transform)}`)
    return transform
  }

  /**
   * 解析 ShapeEntity (LENGTH_DELIMITED 格式)
   */
  private static parseShapeEntity(reader: protobuf.Reader): ShapeEntityParams {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseShapeEntityFromReader(nestedReader)
  }

  /**
   * 解析 ShapeEntity (GROUP 格式 - proto2)
   */
  private static parseShapeEntityGroup(reader: protobuf.Reader): ShapeEntityParams {
    const shape = SVGAProtoParser.parseShapeEntityFromReader(reader)
    // 读取 END_GROUP 标记
    reader.uint32()
    return shape
  }

  /**
   * 从 Reader 解析 ShapeEntity
   */
  private static parseShapeEntityFromReader(reader: protobuf.Reader): ShapeEntityParams {
    const shape: ShapeEntityParams = {
      shapePath: '',
      isKeep: false,
    }

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        reader.pos-- // 回退 tag 位置
        break
      }

      switch (fieldNum) {
        case 1: // type
          const typeValue = reader.int32()
          shape.isKeep = (typeValue === 3) // ShapeType.KEEP = 3
          break
        case 2: // shape
          if (wireType === 2) {
            shape.shapePath = SVGAProtoParser.parseShapeArgs(reader)
          } else if (wireType === 3) {
            shape.shapePath = SVGAProtoParser.parseShapeArgsGroup(reader)
          }
          break
        case 10: // styles
          if (wireType === 2) {
            shape.styles = SVGAProtoParser.parseShapeStyle(reader)
          } else if (wireType === 3) {
            shape.styles = SVGAProtoParser.parseShapeStyleGroup(reader)
          }
          break
        case 11: // transform
          if (wireType === 2) {
            shape.transform = SVGAProtoParser.parseTransform(reader)
          } else if (wireType === 3) {
            shape.transform = SVGAProtoParser.parseTransformGroup(reader)
          }
          break
        default:
          reader.skipType(wireType)
          break
      }
    }
    return shape
  }

  /**
   * 解析 ShapeArgs (LENGTH_DELIMITED 格式)
   */
  private static parseShapeArgs(reader: protobuf.Reader): string {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseShapeArgsFromReader(nestedReader)
  }

  /**
   * 解析 ShapeArgs (GROUP 格式 - proto2)
   */
  private static parseShapeArgsGroup(reader: protobuf.Reader): string {
    const d = SVGAProtoParser.parseShapeArgsFromReader(reader)
    // 读取 END_GROUP 标记
    reader.uint32()
    return d
  }

  /**
   * 从 Reader 解析 ShapeArgs
   */
  private static parseShapeArgsFromReader(reader: protobuf.Reader): string {
    let d: string = ''

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        reader.pos-- // 回退 tag 位置
        break
      }

      switch (fieldNum) {
        case 1: // d
          d = reader.string()
          break
        default:
          reader.skipType(wireType)
          break
      }
    }
    return d
  }

  /**
   * 解析 ShapeStyle (LENGTH_DELIMITED 格式)
   */
  private static parseShapeStyle(reader: protobuf.Reader): ShapeStyleParams {
    const nestedData = reader.bytes()
    const nestedReader = protobuf.Reader.create(nestedData)
    return SVGAProtoParser.parseShapeStyleFromReader(nestedReader)
  }

  /**
   * 解析 ShapeStyle (GROUP 格式 - proto2)
   */
  private static parseShapeStyleGroup(reader: protobuf.Reader): ShapeStyleParams {
    const style = SVGAProtoParser.parseShapeStyleFromReader(reader)
    // 读取 END_GROUP 标记
    reader.uint32()
    return style
  }

  /**
   * 从 Reader 解析 ShapeStyle
   */
  private static parseShapeStyleFromReader(reader: protobuf.Reader): ShapeStyleParams {
    const style: ShapeStyleParams = {}

    while (reader.pos < reader.len) {
      const tag = reader.uint32()
      const fieldNum = tag >>> 3
      const wireType = tag & 7

      // 如果遇到 END_GROUP (wire type 4)，停止解析
      if (wireType === 4) {
        reader.pos-- // 回退 tag 位置
        break
      }

      switch (fieldNum) {
        case 1: // fill
          style.fill = reader.string()
          break
        case 2: // stroke
          style.stroke = reader.string()
          break
        case 3: // strokeWidth
          style.strokeWidth = reader.float()
          break
        default:
          reader.skipType(wireType)
          break
      }
    }
    return style
  }

  /**
   * 跳过字段
   */
  private static skipField(reader: protobuf.Reader, wireType: number): void {
    reader.skipType(wireType)
  }
}
