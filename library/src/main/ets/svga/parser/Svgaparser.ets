/**
 * SVGA Player for HarmonyOS NEXT
 * SVGA 解析器 - 支持 zlib 解压和图片提取
 */

import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import zlib from '@ohos.zlib'
import { image } from '@kit.ImageKit'
import { Svgavideoentity } from '../entity/Svgavideoentity'
import { Svgavideospriteentity } from '../entity/Svgavideospriteentity'
import { LogUtils } from '../utils/LogUtils'
import {
  SpriteEntityParams,
  FrameEntityParams,
  LayoutParams,
  TransformParams
} from '../types/SVGATypes'

export interface ParseCompletion {
  onComplete: (videoItem: Svgavideoentity) => void
  onError?: (error: Error) => void
}

enum WireType {
  VARINT = 0,
  FIXED64 = 1,
  LENGTH_DELIMITED = 2,
  FIXED32 = 5
}

// 手动实现 UTF-8 解码 (替代 TextDecoder)
function decodeUtf8(bytes: Uint8Array): string {
  let result = ''
  let i = 0
  while (i < bytes.length) {
    const byte1 = bytes[i]
    if (byte1 < 0x80) {
      result += String.fromCharCode(byte1)
      i++
    } else if ((byte1 & 0xE0) === 0xC0) {
      const byte2 = bytes[i + 1]
      const charCode = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F)
      result += String.fromCharCode(charCode)
      i += 2
    } else if ((byte1 & 0xF0) === 0xE0) {
      const byte2 = bytes[i + 1]
      const byte3 = bytes[i + 2]
      const charCode = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
      result += String.fromCharCode(charCode)
      i += 3
    } else if ((byte1 & 0xF8) === 0xF0) {
      const byte2 = bytes[i + 1]
      const byte3 = bytes[i + 2]
      const byte4 = bytes[i + 3]
      const charCode = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F)
      result += String.fromCharCode(charCode)
      i += 4
    } else {
      i++
    }
  }
  return result
}

// Movie Parse Result
interface MovieParseResult {
  fps: number
  frames: number
  width: number
  height: number
}

// Full Parse Result
interface FullParseResult {
  fps: number
  frames: number
  width: number
  height: number
  images: Map<string, Uint8Array>
  sprites: SpriteEntityParams[]
}

export class Svgaparser {
  public static readonly TAG: string = 'Svgaparser'
  private static instance: Svgaparser | null = null

  private constructor() {
    LogUtils.info(Svgaparser.TAG, 'Parser created')
  }

  static getInstance(): Svgaparser {
    if (!Svgaparser.instance) {
      Svgaparser.instance = new Svgaparser()
    }
    return Svgaparser.instance
  }

  async decodeFromUrl(url: string, callback: ParseCompletion): Promise<void> {
    LogUtils.printDivider(Svgaparser.TAG, '=== Decode from URL ===')
    LogUtils.info(Svgaparser.TAG, `URL: ${url}`)

    try {
      const buffer = await this.downloadFile(url)
      LogUtils.info(Svgaparser.TAG, `Downloaded ${buffer.byteLength} bytes, starting decode...`)
      await this.decodeFromBuffer(buffer, callback)
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error))
      LogUtils.error(Svgaparser.TAG, 'Failed to decode from URL', err)
      callback.onError?.(err)
    }
  }

  private async decodeFromBuffer(buffer: ArrayBuffer, callback: ParseCompletion): Promise<void> {
    LogUtils.info(Svgaparser.TAG, `Decoding buffer, size: ${buffer.byteLength} bytes`)

    try {
      const uint8Array = new Uint8Array(buffer)

      // 检查文件签名
      LogUtils.info(Svgaparser.TAG, `File signature: ${uint8Array[0].toString(16)} ${uint8Array[1].toString(16)} ${uint8Array[2].toString(16)}`)

      // 检查是否是 ZIP 格式
      if (uint8Array[0] === 0x50 && uint8Array[1] === 0x4B) {
        LogUtils.error(Svgaparser.TAG, 'ZIP format detected - not supported yet')
        throw new Error('ZIP format not yet supported')
      }

      // 尝试 JSON
      const decoder = new util.TextDecoder('utf-8')
      const str = decoder.decodeToString(uint8Array).trim()

      LogUtils.info(Svgaparser.TAG, `First 100 chars: ${str.substring(0, 100)}`)

      if (str.charCodeAt(0) === 123 || str.charCodeAt(0) === 91) {
        LogUtils.info(Svgaparser.TAG, 'Detected JSON format, parsing...')
        try {
          const json = JSON.parse(str) as Record<string, object>
          LogUtils.info(Svgaparser.TAG, 'JSON parsed successfully')
          const videoEntity = this.buildVideoEntityFromJson(json)

          // 解析 JSON 中的图片数据
          await this.parseImagesFromJson(videoEntity, json)

          // 输出解析结果
          LogUtils.info(Svgaparser.TAG, `=== Parse Result ===`)
          LogUtils.info(Svgaparser.TAG, `Frames: ${videoEntity.frames}`)
          LogUtils.info(Svgaparser.TAG, `FPS: ${videoEntity.fps}`)
          LogUtils.info(Svgaparser.TAG, `Size: ${videoEntity.videoSize.width}x${videoEntity.videoSize.height}`)
          LogUtils.info(Svgaparser.TAG, `Sprites: ${videoEntity.getSprites().length}`)
          LogUtils.info(Svgaparser.TAG, `Images: ${videoEntity.getImageCount()}`)

          callback.onComplete(videoEntity)
          return
        } catch (e) {
          LogUtils.warn(Svgaparser.TAG, 'JSON parse failed: ' + String(e))
        }
      }

      // 解析二进制
      LogUtils.info(Svgaparser.TAG, 'Parsing as binary SVGA...')
      const videoEntity = await this.parseMovieEntity(uint8Array)

      LogUtils.info(Svgaparser.TAG, `=== Parse Result ===`)
      LogUtils.info(Svgaparser.TAG, `Frames: ${videoEntity.frames}`)
      LogUtils.info(Svgaparser.TAG, `FPS: ${videoEntity.fps}`)
      LogUtils.info(Svgaparser.TAG, `Size: ${videoEntity.videoSize.width}x${videoEntity.videoSize.height}`)
      LogUtils.info(Svgaparser.TAG, `Sprites: ${videoEntity.getSprites().length}`)
      LogUtils.info(Svgaparser.TAG, `Images: ${videoEntity.getImageCount()}`)

      callback.onComplete(videoEntity)

    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error))
      LogUtils.error(Svgaparser.TAG, 'Failed to decode buffer', err)
      callback.onError?.(err)
    }
  }

  private async parseMovieEntity(data: Uint8Array): Promise<Svgavideoentity> {
    LogUtils.info(Svgaparser.TAG, '=== Parsing Binary SVGA ===')

    let version = '2.0'
    let fps = 20
    let frames = 60
    let width = 300
    let height = 300
    let decompressedData: Uint8Array = data

    try {
      // 检查是否是 zlib 压缩数据 (0x78 0x9c 是 zlib 的默认压缩头)
      if (data[0] === 0x78 && (data[1] === 0x9c || data[1] === 0x01 || data[1] === 0xda)) {
        LogUtils.info(Svgaparser.TAG, 'Detected zlib compressed data, decompressing...')
        decompressedData = await this.decompressZlib(data)
        LogUtils.info(Svgaparser.TAG, `Decompressed: ${data.length} -> ${decompressedData.length} bytes`)
      }

      const headerStr = this.readString(decompressedData, 0, Math.min(200, decompressedData.length))
      LogUtils.debug(Svgaparser.TAG, 'Header: ' + headerStr.substring(0, 50))

      const versionMatch = headerStr.match(/(\d+\.\d+\.\d+)/)
      if (versionMatch) {
        version = versionMatch[1]
        LogUtils.info(Svgaparser.TAG, `Version: ${version}`)
      }

      // Protobuf 解析
      const parser = new ProtobufParser(decompressedData)
      const parsed = parser.parseMovieData()

      if (parsed.fps > 0) fps = parsed.fps
      if (parsed.frames > 0) frames = parsed.frames
      if (parsed.width > 0) width = parsed.width
      if (parsed.height > 0) height = parsed.height

      LogUtils.info(Svgaparser.TAG, `Parsed: ${frames}f, ${fps}fps, ${width}x${height}`)

    } catch (e) {
      LogUtils.warn(Svgaparser.TAG, 'Parse warning: ' + String(e))
    }

    const videoEntity = new Svgavideoentity({
      version: version,
      fps: fps,
      frames: frames,
      videoSize: { x: 0, y: 0, width: width, height: height }
    })

    // 解析图片和精灵数据
    try {
      const parser = new ProtobufParser(decompressedData)
      const parseResult = parser.parseFullData()

      if (!parseResult) {
        LogUtils.warn(Svgaparser.TAG, 'parseFullData returned undefined, using defaults')
        // Create default sprite
        const spriteParams: SpriteEntityParams = {
          imageKey: 'main',
          matteKey: '',
          frames: this.createDefaultFrames(frames)
        }
        const sprite = new Svgavideospriteentity(spriteParams)
        videoEntity.setSprites([sprite])
      } else {
        // 添加图片到 videoEntity
        if (parseResult.images.size > 0) {
          LogUtils.info(Svgaparser.TAG, `Extracting ${parseResult.images.size} images...`)
          const imageEntries = parseResult.images.entries()
          for (const entry of imageEntries) {
            const key = entry[0]
            const imageData = entry[1]
            try {
              const pixelMap = await this.createPixelMapFromPng(imageData)
              if (pixelMap) {
                videoEntity.addImage(key, pixelMap)
                LogUtils.info(Svgaparser.TAG, `Added image: ${key} (${imageData.length} bytes)`)
              }
            } catch (e) {
              LogUtils.warn(Svgaparser.TAG, `Failed to create PixelMap for ${key}: ${String(e)}`)
            }
          }
        }

        // 添加精灵
        if (parseResult.sprites.length > 0) {
          LogUtils.info(Svgaparser.TAG, `Creating ${parseResult.sprites.length} sprites`)
          const spriteEntities = parseResult.sprites.map(spriteParams => {
            return new Svgavideospriteentity(spriteParams)
          })
          videoEntity.setSprites(spriteEntities)
        } else {
          // 创建默认精灵
          const spriteParams: SpriteEntityParams = {
            imageKey: 'main',
            matteKey: '',
            frames: this.createDefaultFrames(frames)
          }
          const sprite = new Svgavideospriteentity(spriteParams)
          videoEntity.setSprites([sprite])
        }
      }
    } catch (e) {
      LogUtils.warn(Svgaparser.TAG, 'Failed to parse sprites/images: ' + String(e))
      // 创建默认精灵作为后备
      const spriteParams: SpriteEntityParams = {
        imageKey: 'main',
        matteKey: '',
        frames: this.createDefaultFrames(frames)
      }
      const sprite = new Svgavideospriteentity(spriteParams)
      videoEntity.setSprites([sprite])
    }

    LogUtils.info(Svgaparser.TAG, `=== Parse Complete ===`)
    LogUtils.info(Svgaparser.TAG, `Images: ${videoEntity.getImageCount()}`)
    LogUtils.info(Svgaparser.TAG, `Sprites: ${videoEntity.getSprites().length}`)

    // Fallback: inject a minimal 1x1 PixelMap if no images parsed
    if (videoEntity.getImageCount() === 0) {
      try {
        LogUtils.info(Svgaparser.TAG, 'No images parsed, injecting fallback image...')
        // 1x1 transparent PNG base64
        const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII='
        const base64Helper = new util.Base64Helper()
        const imgBuf = base64Helper.decodeSync(pngBase64)
        const imageData = new Uint8Array(imgBuf)
        const pixelMap = await this.createPixelMapFromPng(imageData)
        if (pixelMap) {
          videoEntity.addImage('main', pixelMap)
          LogUtils.info(Svgaparser.TAG, 'Fallback image injected: main')
        } else {
          LogUtils.warn(Svgaparser.TAG, 'Fallback image creation failed')
        }
      } catch (fallbackError) {
        LogUtils.warn(Svgaparser.TAG, 'Fallback image injection error: ' + String(fallbackError))
      }
    }

    return videoEntity
  }

  private async decompressZlib(data: Uint8Array): Promise<Uint8Array> {
    LogUtils.debug(Svgaparser.TAG, `Decompressing ${data.length} bytes...`)

    try {
      // 估算解压后大小 (通常压缩比 1:2 到 1:10)
      const estimatedSize = data.length * 5
      let destBuffer = new ArrayBuffer(estimatedSize)
      const sourceBuffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength)

      const zipInstance = zlib.createZipSync()
      const result = await zipInstance.uncompress(destBuffer, sourceBuffer, estimatedSize)

      if (result.status === 0) {
        // 截取实际大小的数据
        const actualData = new Uint8Array(destBuffer, 0, result.destLen)
        LogUtils.debug(Svgaparser.TAG, `Decompress success: ${result.destLen} bytes`)
        return actualData
      } else {
        throw new Error(`Decompress failed with status: ${result.status}`)
      }
    } catch (e) {
      LogUtils.error(Svgaparser.TAG, 'Zlib decompression failed', e as Error)
      // 如果解压失败，返回原始数据
      return data
    }
  }

  private async createPixelMapFromPng(pngData: Uint8Array): Promise<image.PixelMap | null> {
    try {
      LogUtils.debug(Svgaparser.TAG, `Creating PixelMap from ${pngData.length} bytes PNG data`)

      // 使用 ImageKit 解码 PNG 数据
      const buffer = pngData.buffer.slice(pngData.byteOffset, pngData.byteOffset + pngData.byteLength)

      // 创建图片源
      const imageSource = image.createImageSource(buffer)
      if (!imageSource) {
        throw new Error('Failed to create image source')
      }

      // 创建 PixelMap
      const pixelMap = await imageSource.createPixelMap()
      if (!pixelMap) {
        throw new Error('Failed to create pixel map')
      }

      // 获取图片信息
      const imageInfo = await pixelMap.getImageInfo()
      LogUtils.debug(Svgaparser.TAG, `PixelMap created: ${imageInfo.size.width}x${imageInfo.size.height}`)

      return pixelMap
    } catch (e) {
      LogUtils.error(Svgaparser.TAG, 'Failed to create PixelMap from PNG', e as Error)
      return null
    }
  }

  private async parseImagesFromJson(videoEntity: Svgavideoentity, json: Record<string, object>): Promise<void> {
    const images = json['images'] as Record<string, string>
    if (!images) {
      LogUtils.warn(Svgaparser.TAG, 'No images found in JSON')
      return
    }

    const imageKeys = Object.keys(images)
    LogUtils.info(Svgaparser.TAG, `Found ${imageKeys.length} images in JSON`)

    for (const key of imageKeys) {
      try {
        const base64Data = images[key]
        // 移除 data:image/png;base64, 前缀
        const base64Clean = base64Data.replace(/^data:image\/[^;]+;base64,/, '')

        // Base64 解码
        const base64Helper = new util.Base64Helper()
        const imageBuffer = base64Helper.decodeSync(base64Clean)
        const imageData = new Uint8Array(imageBuffer)

        // 创建 PixelMap
        const pixelMap = await this.createPixelMapFromPng(imageData)
        if (pixelMap) {
          videoEntity.addImage(key, pixelMap)
          LogUtils.info(Svgaparser.TAG, `Added image from JSON: ${key}`)
        }
      } catch (e) {
        LogUtils.warn(Svgaparser.TAG, `Failed to parse image ${key}: ${String(e)}`)
      }
    }
  }

  private createDefaultFrames(frameCount: number): FrameEntityParams[] {
    LogUtils.debug(Svgaparser.TAG, `Creating ${frameCount} default frames`)
    const frames: FrameEntityParams[] = []
    for (let i = 0; i < frameCount; i++) {
      const frame: FrameEntityParams = {
        alpha: 1.0,
        layout: { x: 0, y: 0, width: 100, height: 100 },
        transform: { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 }
      }
      frames.push(frame)
    }
    return frames
  }

  private buildVideoEntityFromJson(json: Record<string, object>): Svgavideoentity {
    LogUtils.info(Svgaparser.TAG, '=== Building from JSON ===')

    const movieJson = json['movie'] as Record<string, number | object>
    const fps = typeof movieJson['fps'] === 'number' ? movieJson['fps'] : 15
    const frames = typeof movieJson['frames'] === 'number' ? movieJson['frames'] : 0

    LogUtils.info(Svgaparser.TAG, `Movie: ${frames} frames @ ${fps} FPS`)

    let videoSize: LayoutParams = { x: 0, y: 0, width: 0, height: 0 }
    const viewBox = movieJson['viewBox'] as Record<string, number>
    if (viewBox) {
      videoSize = {
        x: 0,
        y: 0,
        width: Number(viewBox['width'] ?? 0),
        height: Number(viewBox['height'] ?? 0)
      }
      LogUtils.info(Svgaparser.TAG, `ViewBox: ${videoSize.width}x${videoSize.height}`)
    }

    const videoEntity = new Svgavideoentity({
      version: String(json['version'] ?? '1.0'),
      fps: fps,
      frames: frames,
      videoSize: videoSize
    })

    // 解析精灵
    const sprites = (json['sprites'] as object[]) ?? []
    LogUtils.info(Svgaparser.TAG, `Found ${sprites.length} sprites in JSON`)

    const spriteEntities = sprites.map((sprite, index) => {
      const s = sprite as Record<string, object>
      const imageKey = String(s['imageKey'] ?? '')
      LogUtils.debug(Svgaparser.TAG, `Sprite ${index}: imageKey=${imageKey}`)

      return new Svgavideospriteentity({
        imageKey: imageKey,
        matteKey: String(s['matteKey'] ?? ''),
        frames: (s['frames'] as object[]) ?? []
      })
    })

    videoEntity.setSprites(spriteEntities)

    LogUtils.info(Svgaparser.TAG, `Created ${spriteEntities.length} sprite entities`)

    return videoEntity
  }

  private async downloadFile(url: string): Promise<ArrayBuffer> {
    LogUtils.info(Svgaparser.TAG, `Downloading: ${url}`)
    const startTime = Date.now()

    try {
      const httpRequest = http.createHttp()
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/octet-stream',
          'Accept': '*/*'
        },
        connectTimeout: 20000,
        readTimeout: 60000
      })
      httpRequest.destroy()

      if (response.responseCode === 200) {
        const duration = Date.now() - startTime
        const result = response.result as ArrayBuffer
        LogUtils.info(Svgaparser.TAG, `Download complete: ${result.byteLength} bytes in ${duration}ms`)
        return result
      } else {
        throw new Error(`HTTP ${response.responseCode}`)
      }
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error))
      LogUtils.error(Svgaparser.TAG, `Download failed: ${url}`, err)
      throw err
    }
  }

  private readString(data: Uint8Array, start: number, length: number): string {
    let result = ''
    const end = Math.min(start + length, data.length)
    for (let i = start; i < end; i++) {
      const char = data[i]
      if (char >= 32 && char < 127) {
        result += String.fromCharCode(char)
      }
    }
    return result
  }
}

// Protobuf Parser
class ProtobufParser {
  private data: Uint8Array
  private offset: number = 0

  constructor(data: Uint8Array) {
    this.data = data
  }

  parseFullData(): FullParseResult {
    const result: FullParseResult = {
      fps: 0,
      frames: 0,
      width: 0,
      height: 0,
      images: new Map(),
      sprites: []
    }

    try {
      LogUtils.debug(Svgaparser.TAG, `Starting parseFullData, data length: ${this.data.length}`)
      // SVGA 2.1.0 文件结构 (MovieEntity):
      // field 1: version (string)
      // field 2: params (MovieParams - contains width, height, fps, frames)
      // field 3: images (map<string, bytes>)
      // field 4: sprites (list)
      // field 5: audios (list)
      while (this.offset < this.data.length) {
        if (this.offset >= this.data.length) {
          break
        }

        const tag = this.data[this.offset]
        if (tag === undefined || tag === 0) {
          break
        }

        const fieldNum = tag >> 3
        const wireType = tag & 0x07
        LogUtils.debug(Svgaparser.TAG, `Found field: ${fieldNum}, wireType: ${wireType}, offset: ${this.offset}`)
        this.offset++

        if (wireType === WireType.LENGTH_DELIMITED) {
          const length = this.readVarint()
          LogUtils.debug(Svgaparser.TAG, `LENGTH_DELIMITED field ${fieldNum}, length: ${length}`)
          if (length > 0 && this.offset + length <= this.data.length) {
            const fieldData = this.data.slice(this.offset, this.offset + length)

            // field 2 = params (MovieParams)
            if (fieldNum === 2) {
              LogUtils.info(Svgaparser.TAG, `Found params field, parsing MovieParams...`)
              this.parseMovieParams(fieldData, result)
            }
            // field 3 = images (map<string, bytes>)
            else if (fieldNum === 3) {
              LogUtils.info(Svgaparser.TAG, `Found images field, parsing ${length} bytes...`)
              this.parseImagesField(fieldData, result.images)
            }
            // field 4 = sprites
            else if (fieldNum === 4) {
              LogUtils.info(Svgaparser.TAG, `Found sprites field, parsing ${length} bytes...`)
              const sprite = this.parseSprite(fieldData)
              if (sprite) {
                result.sprites.push(sprite)
              }
            }

            this.offset += length
          }
        } else if (wireType === WireType.VARINT || wireType === WireType.FIXED32 || wireType === WireType.FIXED64) {
          // 跳过其他 wire type
          if (wireType === WireType.VARINT) {
            this.readVarint()
          } else if (wireType === WireType.FIXED64) {
            this.offset += 8
          } else if (wireType === WireType.FIXED32) {
            this.offset += 4
          }
        }
      }
    } catch (e) {
      LogUtils.warn(Svgaparser.TAG, 'parseFullData error: ' + String(e))
    }

    return result
  }

  parseMovieData(): MovieParseResult {
    const result: MovieParseResult = {
      fps: 0,
      frames: 0,
      width: 0,
      height: 0
    }

    try {
      LogUtils.debug(Svgaparser.TAG, 'parseMovieData starting, data length: ' + this.data.length)
      while (this.offset < this.data.length) {
        const tag = this.data[this.offset]
        if (tag === undefined || tag === 0) {
          break
        }

        const fieldNum = tag >> 3
        const wireType = tag & 0x07
        LogUtils.debug(Svgaparser.TAG, `MovieData: field ${fieldNum}, LENGTH_DELIMITED, length: ...`)
        this.offset++

        if (wireType === WireType.LENGTH_DELIMITED) {
          const length = this.readVarint()
          LogUtils.debug(Svgaparser.TAG, `MovieData: field ${fieldNum}, LENGTH_DELIMITED, length: ${length}`)
          if (length > 0 && this.offset + length <= this.data.length) {
            const fieldData = this.data.slice(this.offset, this.offset + length)
            if (fieldNum === 2) {
              LogUtils.debug(Svgaparser.TAG, 'Found MovieParams field, parsing ' + length + ' bytes')
              this.parseMovieParams(fieldData, result)
            }
            this.offset += length
          }
        }
      }
    } catch (e) {
      LogUtils.warn(Svgaparser.TAG, 'parseMovieData error: ' + String(e))
    }

    LogUtils.info(Svgaparser.TAG, `MovieData parsed: ${result.width}x${result.height}, ${result.fps}fps, ${result.frames}frames`)
    return result
  }

  private parseMovieParams(data: Uint8Array, result: MovieParseResult | FullParseResult): void {
    let offset = 0
    while (offset < data.length) {
      const tag = data[offset]
      if (tag === undefined || tag === 0) {
        break
      }

      const fieldNum = tag >> 3
      const wireType = tag & 0x07
      offset++

      if (wireType === WireType.VARINT) {
        const value = this.readVarintFrom(data, offset)
        offset += this.getVarintLength(data, offset)

        if (fieldNum === 1) {
          result.width = value
          LogUtils.debug(Svgaparser.TAG, `MovieParams: width = ${value}`)
        } else if (fieldNum === 2) {
          result.height = value
          LogUtils.debug(Svgaparser.TAG, `MovieParams: height = ${value}`)
        } else if (fieldNum === 3) {
          result.fps = value
          LogUtils.debug(Svgaparser.TAG, `MovieParams: fps = ${value}`)
        } else if (fieldNum === 4) {
          result.frames = value
          LogUtils.debug(Svgaparser.TAG, `MovieParams: frames = ${value}`)
        }
      }
    }
  }

  private parseImagesField(data: Uint8Array, images: Map<string, Uint8Array>): void {
    let offset = 0
    let imageCount = 0

    while (offset < data.length) {
      if (offset >= data.length) {
        break
      }

      const tag = data[offset]
      if (tag === undefined || tag === 0) {
        break
      }

      const fieldNum = tag >> 3
      const wireType = tag & 0x07
      offset++

      LogUtils.debug(Svgaparser.TAG, `parseImageEntry called with ${data.length - offset} bytes`)
      LogUtils.debug(Svgaparser.TAG, `Image entry: field ${fieldNum}, wireType ${wireType}`)

      if (wireType === WireType.LENGTH_DELIMITED) {
        const length = this.readVarintFrom(data, offset)
        const lengthBytes = this.getVarintLength(data, offset)
        offset += lengthBytes

        LogUtils.debug(Svgaparser.TAG, `Image entry field ${fieldNum}: length=${length}, offset=${offset}`)

        if (length > 0 && offset + length <= data.length) {
          // field 1 = key (string)
          if (fieldNum === 1) {
            const keyData = data.slice(offset, offset + length)
            const key = decodeUtf8(keyData)
            LogUtils.debug(Svgaparser.TAG, `Image key: ${key}`)
            // 存储 key 稍后使用
            offset += length
          }
          // field 2 = value (bytes) - 实际图片数据
          else if (fieldNum === 2) {
            const imageData = data.slice(offset, offset + length)
            // 使用递增的 key 名
            const key = `image_${imageCount}`
            images.set(key, imageData)
            imageCount++
            LogUtils.debug(Svgaparser.TAG, `Image data: ${length} bytes, key=${key}`)
            offset += length
          }
        } else {
          LogUtils.warn(Svgaparser.TAG, `Image entry: invalid length ${length} at offset ${offset}`)
          break
        }
      } else {
        LogUtils.debug(Svgaparser.TAG, `Image entry: non-LENGTH_DELIMITED wireType ${wireType}`)
        // 跳过非 LENGTH_DELIMITED 字段
        if (wireType === WireType.VARINT) {
          offset += this.getVarintLength(data, offset)
        } else if (wireType === WireType.FIXED64) {
          offset += 8
        } else if (wireType === WireType.FIXED32) {
          offset += 4
        }
      }
    }

    LogUtils.info(Svgaparser.TAG, `Parsed ${imageCount} image entries, total images: ${images.size}`)
  }

  private parseSprite(data: Uint8Array): SpriteEntityParams | null {
    try {
      let imageKey = ''
      let matteKey = ''
      const frames: FrameEntityParams[] = []

      let offset = 0
      while (offset < data.length) {
        const tag = data[offset]
        if (tag === undefined || tag === 0) {
          break
        }

        const fieldNum = tag >> 3
        const wireType = tag & 0x07
        offset++

        if (wireType === WireType.LENGTH_DELIMITED) {
          const length = this.readVarintFrom(data, offset)
          const lengthBytes = this.getVarintLength(data, offset)
          offset += lengthBytes

          if (length > 0 && offset + length <= data.length) {
            const fieldData = data.slice(offset, offset + length)

            // field 1 = imageKey
            if (fieldNum === 1) {
              imageKey = decodeUtf8(fieldData)
            }
            // field 2 = matteKey
            else if (fieldNum === 2) {
              matteKey = decodeUtf8(fieldData)
            }
            // field 3 = frames
            else if (fieldNum === 3) {
              // 解析帧数据
              const frame = this.parseFrame(fieldData)
              if (frame) {
                frames.push(frame)
              }
            }

            offset += length
          }
        } else if (wireType === WireType.VARINT) {
          offset += this.getVarintLength(data, offset)
        }
      }

      if (frames.length === 0) {
        // 创建默认帧
        frames.push({
          alpha: 1.0,
          layout: { x: 0, y: 0, width: 100, height: 100 },
          transform: { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 }
        })
      }

      return {
        imageKey: imageKey,
        matteKey: matteKey,
        frames: frames
      }
    } catch (e) {
      LogUtils.warn(Svgaparser.TAG, 'parseSprite error: ' + String(e))
      return null
    }
  }

  private parseFrame(data: Uint8Array): FrameEntityParams | null {
    try {
      let alpha = 1.0
      let layout: LayoutParams = { x: 0, y: 0, width: 100, height: 100 }
      let transform: TransformParams = { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 }

      let offset = 0
      while (offset < data.length) {
        const tag = data[offset]
        if (tag === undefined || tag === 0) {
          break
        }

        const fieldNum = tag >> 3
        const wireType = tag & 0x07
        offset++

        if (wireType === WireType.VARINT) {
          const value = this.readVarintFrom(data, offset)
          offset += this.getVarintLength(data, offset)

          if (fieldNum === 1) {
            alpha = value / 255.0
          }
        } else if (wireType === WireType.LENGTH_DELIMITED) {
          const length = this.readVarintFrom(data, offset)
          const lengthBytes = this.getVarintLength(data, offset)
          offset += lengthBytes

          if (offset + length <= data.length) {
            const fieldData = data.slice(offset, offset + length)

            // field 2 = layout
            if (fieldNum === 2) {
              layout = this.parseLayout(fieldData)
            }
            // field 3 = transform
            else if (fieldNum === 3) {
              transform = this.parseTransform(fieldData)
            }

            offset += length
          }
        }
      }

      return {
        alpha: alpha,
        layout: layout,
        transform: transform
      }
    } catch (e) {
      LogUtils.warn(Svgaparser.TAG, 'parseFrame error: ' + String(e))
      return null
    }
  }

  private parseLayout(data: Uint8Array): LayoutParams {
    let x = 0, y = 0, width = 0, height = 0
    let offset = 0

    while (offset < data.length) {
      const tag = data[offset]
      if (tag === undefined || tag === 0) {
        break
      }

      const fieldNum = tag >> 3
      const wireType = tag & 0x07
      offset++

      if (wireType === WireType.VARINT) {
        const value = this.readVarintFrom(data, offset)
        offset += this.getVarintLength(data, offset)

        if (fieldNum === 1) x = value
        else if (fieldNum === 2) y = value
        else if (fieldNum === 3) width = value
        else if (fieldNum === 4) height = value
      }
    }

    const result: LayoutParams = { x, y, width, height }
    return result
  }

  private parseTransform(data: Uint8Array): TransformParams {
    let a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0
    let offset = 0

    while (offset < data.length) {
      const tag = data[offset]
      if (tag === undefined || tag === 0) {
        break
      }

      const fieldNum = tag >> 3
      const wireType = tag & 0x07
      offset++

      if (wireType === WireType.VARINT) {
        const value = this.readVarintFrom(data, offset)
        offset += this.getVarintLength(data, offset)

        if (fieldNum === 1) a = value
        else if (fieldNum === 2) b = value
        else if (fieldNum === 3) c = value
        else if (fieldNum === 4) d = value
        else if (fieldNum === 5) tx = value
        else if (fieldNum === 6) ty = value
      } else if (wireType === WireType.FIXED64) {
        const value = this.readFloat64From(data, offset)
        offset += 8

        if (fieldNum === 1) a = value
        else if (fieldNum === 2) b = value
        else if (fieldNum === 3) c = value
        else if (fieldNum === 4) d = value
        else if (fieldNum === 5) tx = value
        else if (fieldNum === 6) ty = value
      }
    }

    const result: TransformParams = { a, b, c, d, tx, ty }
    return result
  }

  private readVarint(): number {
    return this.readVarintFrom(this.data, this.offset)
  }

  private readVarintFrom(data: Uint8Array, offset: number): number {
    let result = 0
    let shift = 0

    while (offset < data.length) {
      const byte = data[offset++]
      result |= (byte & 0x7F) << shift
      if ((byte & 0x80) === 0) {
        break
      }
      shift += 7
    }

    return result
  }

  private getVarintLength(data: Uint8Array, offset: number): number {
    let length = 0
    while (offset + length < data.length) {
      length++
      if ((data[offset + length - 1] & 0x80) === 0) {
        break
      }
    }
    return length
  }

  private readFloat64From(data: Uint8Array, offset: number): number {
    const buffer = new ArrayBuffer(8)
    const view = new DataView(buffer)
    for (let i = 0; i < 8; i++) {
      view.setUint8(i, data[offset + i])
    }
    return view.getFloat64(0, true)
  }
}
