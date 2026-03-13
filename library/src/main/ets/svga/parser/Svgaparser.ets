/**
 * SVGA Player for HarmonyOS NEXT
 * SVGA 解析器 - 支持 zlib 解压和图片提取
 */

import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import zlib from '@ohos.zlib'
import { image } from '@kit.ImageKit'
import { SVGAProtoParser } from './SVGAProtoParser'
import { Svgavideoentity } from '../entity/Svgavideoentity'
import { Svgavideospriteentity } from '../entity/Svgavideospriteentity'
import { LogUtils } from '../utils/LogUtils'
import {
  SpriteEntityParams,
  FrameEntityParams,
  LayoutParams,
  TransformParams,
  ShapeEntityParams,
  ShapeStyleParams
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



// 图片类型检测函数
function isPngData(data: Uint8Array): boolean {
  // PNG 魔数: 89 50 4E 47 0D 0A 1A 0A
  return data.length >= 8 && 
    data[0] === 0x89 && data[1] === 0x50 && 
    data[2] === 0x4E && data[3] === 0x47 &&
    data[4] === 0x0D && data[5] === 0x0A &&
    data[6] === 0x1A && data[7] === 0x0A
}

function isJpgData(data: Uint8Array): boolean {
  // JPEG 魔数: FF D8 FF
  return data.length >= 3 && 
    data[0] === 0xFF && data[1] === 0xD8 && data[2] === 0xFF
}

function isImageData(data: Uint8Array): boolean {
  // 检测是否为图片二进制数据（PNG 或 JPEG）
  return isPngData(data) || isJpgData(data)
}

function isAudioData(data: Uint8Array): boolean {
  // 检测是否为音频数据（ID3 标签）
  // ID3 标签魔数: 73 68 51 ('I' 'D' '3')
  return data.length >= 3 && 
    data[0] === 73 && data[1] === 68 && data[2] === 51
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
          LogUtils.info(Svgaparser.TAG, 'JSON parseResult successfully')
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
    let parseResult: FullParseResult | null = null

    try {
      // 检查是否是 zlib 压缩数据 (0x78 0x9c 是 zlib 的默认压缩头)
      if (data[0] === 0x78 && (data[1] === 0x9c || data[1] === 0x01 || data[1] === 0xda)) {
        LogUtils.info(Svgaparser.TAG, 'Detected zlib compressed data, decompressing...')
        decompressedData = await this.decompressZlib(data)
        LogUtils.info(Svgaparser.TAG, `Decompressed: ${data.length} -> ${decompressedData.length} bytes`)
      }

      const headerStr = this.readString(decompressedData, 0, Math.min(200, decompressedData.length))
      // Debug: LogUtils.debug(Svgaparser.TAG, 'Header: ' + headerStr.substring(0, 50))

      const versionMatch = headerStr.match(/(\d+\.\d+\.\d+)/)
      if (versionMatch) {
        version = versionMatch[1]
        LogUtils.info(Svgaparser.TAG, `Version: ${version}`)
      }

      // Protobuf 解析 - 使用 @ohos/protobufjs 解析
      parseResult = SVGAProtoParser.parseFullData(decompressedData) as FullParseResult

      if (parseResult !== null) {
        if (parseResult.fps > 0) fps = parseResult.fps
        if (parseResult.frames > 0) frames = parseResult.frames
        if (parseResult.width > 0) width = parseResult.width
        if (parseResult.height > 0) height = parseResult.height
      }
    } catch (decompressError) {
      LogUtils.error(Svgaparser.TAG, 'Error during decompression/parsing: ' + String(decompressError))
    }

    const videoEntity = new Svgavideoentity({
      version: version,
      fps: fps,
      frames: frames,
      videoSize: { x: 0, y: 0, width: width, height: height }
    })

    // 解析图片和精灵数据
    try {
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

            // 跳过音频数据
            if (isAudioData(imageData)) {
              LogUtils.info(Svgaparser.TAG, `Skipping audio data for key: ${key}`)
              continue
            }

            // 检查是否是有效的图片数据
            if (isImageData(imageData)) {
              LogUtils.info(Svgaparser.TAG, `Processing image ${key}: ${imageData.length} bytes, first bytes: ${imageData[0].toString(16)} ${imageData[1].toString(16)} ${imageData[2].toString(16)}`)
              const pixelMap = await this.createPixelMapFromBytes(imageData)
              if (pixelMap) {
                videoEntity.addImage(key, pixelMap)
                LogUtils.info(Svgaparser.TAG, `Added image: ${key}`)
              } else {
                LogUtils.warn(Svgaparser.TAG, `Failed to create PixelMap for: ${key}`)
              }
            } else {
              LogUtils.warn(Svgaparser.TAG, `Data for key ${key} is not a valid image (${imageData.length} bytes), first bytes: ${imageData.slice(0, 10).join(',')}`)
            }
          }
        }

        // 添加精灵到 videoEntity
        if (parseResult.sprites.length > 0) {
          LogUtils.info(Svgaparser.TAG, `Creating ${parseResult.sprites.length} sprites...`)
          const spriteEntities: Svgavideospriteentity[] = []
          for (const spriteParams of parseResult.sprites) {
            const sprite = new Svgavideospriteentity(spriteParams)
            spriteEntities.push(sprite)
          }
          videoEntity.setSprites(spriteEntities)
        } else {
          // 创建默认精灵
          LogUtils.warn(Svgaparser.TAG, 'No sprites found, creating default sprite')
          const defaultSprite = new Svgavideospriteentity({
            imageKey: parseResult.images.keys().next().value || 'main',
            matteKey: '',
            frames: this.createDefaultFrames(frames)
          })
          videoEntity.setSprites([defaultSprite])
        }
      }
    } catch (parseError) {
      LogUtils.error(Svgaparser.TAG, 'Error processing parseResult data: ' + String(parseError))
    }

    LogUtils.info(Svgaparser.TAG, `=== Parse Complete ===`)
    LogUtils.info(Svgaparser.TAG, `Images: ${videoEntity.getImageCount()}`)
    LogUtils.info(Svgaparser.TAG, `Sprites: ${videoEntity.getSprites().length}`)
    // Fallback: inject a minimal 1x1 PixelMap if no images parsed
    if (videoEntity.getImageCount() === 0) {
      try {
        LogUtils.info(Svgaparser.TAG, 'No images parseResult, injecting fallback image...')
        // 1x1 transparent PNG base64
        const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII='
        const base64Helper = new util.Base64Helper()
        const imgBuf = base64Helper.decodeSync(pngBase64)
        const imageData = new Uint8Array(imgBuf)
        const pixelMap = await this.createPixelMapFromBytes(imageData)
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
      // Debug: LogUtils.debug(Svgaparser.TAG, `Decompressing ${data.length} bytes...`)

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
        // Debug: LogUtils.debug(Svgaparser.TAG, `Decompress success: ${result.destLen} bytes`)
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

  private async createPixelMapFromBytes(imageData: Uint8Array): Promise<image.PixelMap | null> {
    try {
      LogUtils.info(Svgaparser.TAG, `Creating PixelMap from ${imageData.length} bytes, first bytes: ${imageData[0].toString(16)} ${imageData[1].toString(16)} ${imageData[2].toString(16)}`)

      // 创建图片数据的独立拷贝，避免 ArrayBuffer 共享问题
      const buffer = new ArrayBuffer(imageData.byteLength)
      new Uint8Array(buffer).set(imageData)
      
      LogUtils.info(Svgaparser.TAG, `Buffer created: ${buffer.byteLength} bytes`)

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
      LogUtils.info(Svgaparser.TAG, `PixelMap created: ${imageInfo.size.width}x${imageInfo.size.height}`)

      return pixelMap
    } catch (e) {
      LogUtils.error(Svgaparser.TAG, `Failed to create PixelMap: ${(e as Error).message}`, e as Error)
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
        const pixelMap = await this.createPixelMapFromBytes(imageData)
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
    // Debug: LogUtils.debug(Svgaparser.TAG, `Creating ${frameCount} default frames`)
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
      // Debug: LogUtils.debug(Svgaparser.TAG, `Sprite ${index}: imageKey=${imageKey}`)

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
