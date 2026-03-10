/**
 * SVGA Player Unit Tests
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium'
import { 
  Svgarect, 
  Svgamatrix, 
  Svgapathentity,
  Svgavideoshapeentity,
  Svgavideospriteframeentity,
  Svgavideospriteentity,
  Svgavideoentity,
  Svgadynamicentity,
  LogUtils,
  LogLevel
} from 'svga-player'

export default function svgaplayerTest() {
  describe('SVGA Player Test Suite', () => {

    beforeAll(() => {
      console.info('SVGA Player Test - beforeAll called')
      LogUtils.setLogLevel(LogLevel.ERROR)  // 测试时减少日志输出
    })

    beforeEach(() => {
      console.info('SVGA Player Test - beforeEach called')
    })

    afterEach(() => {
      console.info('SVGA Player Test - afterEach called')
    })

    afterAll(() => {
      console.info('SVGA Player Test - afterAll called')
    })

    // ========== Svgarect Tests ==========
    describe('Svgarect Tests', () => {
      it('should create rect with correct values', 0, () => {
        const rect = new Svgarect(10, 20, 100, 200)
        expect(rect.x).assertEqual(10)
        expect(rect.y).assertEqual(20)
        expect(rect.width).assertEqual(100)
        expect(rect.height).assertEqual(200)
      })

      it('should detect empty rect', 0, () => {
        const emptyRect = new Svgarect(0, 0, 0, 0)
        expect(emptyRect.isEmpty()).assertTrue()

        const validRect = new Svgarect(0, 0, 100, 100)
        expect(validRect.isEmpty()).assertFalse()
      })

      it('should detect point containment', 0, () => {
        const rect = new Svgarect(10, 10, 100, 100)
        expect(rect.contains(50, 50)).assertTrue()
        expect(rect.contains(5, 5)).assertFalse()
        expect(rect.contains(200, 200)).assertFalse()
      })

      it('should create correct copy', 0, () => {
        const rect = new Svgarect(10, 20, 100, 200)
        const copy = rect.copy()
        expect(copy.x).assertEqual(rect.x)
        expect(copy.y).assertEqual(rect.y)
        expect(copy.width).assertEqual(rect.width)
        expect(copy.height).assertEqual(rect.height)
      })
    })

    // ========== Svgamatrix Tests ==========
    describe('Svgamatrix Tests', () => {
      it('should create identity matrix', 0, () => {
        const matrix = new Svgamatrix()
        const values = matrix.getValues()
        expect(values[0]).assertEqual(1)  // a
        expect(values[4]).assertEqual(1)  // d
        expect(values[8]).assertEqual(1)  // 1
      })

      it('should translate correctly', 0, () => {
        const matrix = new Svgamatrix()
        matrix.translate(100, 200)
        const values = matrix.getValues()
        expect(values[2]).assertEqual(100)  // tx
        expect(values[5]).assertEqual(200)  // ty
      })

      it('should scale correctly', 0, () => {
        const matrix = new Svgamatrix()
        matrix.scale(2, 3)
        const values = matrix.getValues()
        expect(values[0]).assertEqual(2)  // a
        expect(values[4]).assertEqual(3)  // d
      })

      it('should reset to identity', 0, () => {
        const matrix = new Svgamatrix()
        matrix.translate(100, 200)
        matrix.reset()
        const values = matrix.getValues()
        expect(values[0]).assertEqual(1)
        expect(values[2]).assertEqual(0)
        expect(values[5]).assertEqual(0)
      })
    })

    // ========== Svgapathentity Tests ==========
    describe('Svgapathentity Tests', () => {
      it('should build simple path', 0, () => {
        const path = new Svgapathentity('M 0 0 L 100 100')
        const path2d = path.buildPath()
        expect(path2d).assertNotNull()
      })

      it('should build rectangular path', 0, () => {
        const path = new Svgapathentity('M 0 0 L 100 0 L 100 100 L 0 100 Z')
        const path2d = path.buildPath()
        expect(path2d).assertNotNull()
      })

      it('should cache built path', 0, () => {
        const path = new Svgapathentity('M 0 0 L 100 100')
        const path2d1 = path.buildPath()
        const path2d2 = path.buildPath()
        // 应该返回相同的缓存对象
        expect(path2d1).assertEqual(path2d2)
      })
    })

    // ========== Svgavideoshapeentity Tests ==========
    describe('Svgavideoshapeentity Tests', () => {
      it('should create shape with styles', 0, () => {
        const shape = new Svgavideoshapeentity({
          styles: {
            fill: '#FF0000',
            stroke: '#000000',
            strokeWidth: 2
          },
          shapePath: 'M 0 0 L 100 100'
        })
        expect(shape.styles).assertNotNull()
        expect(shape.styles?.fill).assertEqual('#FF0000')
      })

      it('should build path correctly', 0, () => {
        const shape = new Svgavideoshapeentity({
          shapePath: 'M 0 0 L 100 100'
        })
        const path = shape.buildPath()
        expect(path).assertNotNull()
      })
    })

    // ========== Svgavideospriteframeentity Tests ==========
    describe('Svgavideospriteframeentity Tests', () => {
      it('should create frame with correct values', 0, () => {
        const frame = new Svgavideospriteframeentity({
          alpha: 0.8,
          layout: { x: 10, y: 20, width: 100, height: 200 },
          transform: { a: 1, b: 0, c: 0, d: 1, tx: 50, ty: 50 }
        })
        expect(frame.alpha).assertEqual(0.8)
        expect(frame.layout.width).assertEqual(100)
        expect(frame.layout.height).assertEqual(200)
      })

      it('should detect mask correctly', 0, () => {
        const frameWithoutMask = new Svgavideospriteframeentity({
          clipPath: ''
        })
        expect(frameWithoutMask.hasMask()).assertFalse()

        const frameWithMask = new Svgavideospriteframeentity({
          clipPath: 'M 0 0 L 100 100'
        })
        expect(frameWithMask.hasMask()).assertTrue()
      })
    })

    // ========== Svgavideospriteentity Tests ==========
    describe('Svgavideospriteentity Tests', () => {
      it('should create sprite with frames', 0, () => {
        const sprite = new Svgavideospriteentity({
          imageKey: 'test.png',
          frames: [
            { alpha: 1.0 },
            { alpha: 0.5 },
            { alpha: 0.0 }
          ]
        })
        expect(sprite.imageKey).assertEqual('test.png')
        expect(sprite.frames.length).assertEqual(3)
      })

      it('should get frame at index', 0, () => {
        const sprite = new Svgavideospriteentity({
          frames: [{ alpha: 1.0 }, { alpha: 0.5 }]
        })
        const frame0 = sprite.getFrameAt(0)
        const frame1 = sprite.getFrameAt(1)
        const frame2 = sprite.getFrameAt(2)  // 越界

        expect(frame0).assertNotNull()
        expect(frame1).assertNotNull()
        expect(frame2).assertNull()
      })

      it('should detect matte correctly', 0, () => {
        const normalSprite = new Svgavideospriteentity({
          imageKey: 'normal.png'
        })
        expect(normalSprite.isMatte()).assertFalse()

        const matteSprite = new Svgavideospriteentity({
          imageKey: 'mask.matte'
        })
        expect(matteSprite.isMatte()).assertTrue()
      })
    })

    // ========== Svgavideoentity Tests ==========
    describe('Svgavideoentity Tests', () => {
      it('should create video entity with correct params', 0, () => {
        const entity = new Svgavideoentity({
          version: '2.0',
          fps: 30,
          frames: 60,
          videoSize: { x: 0, y: 0, width: 500, height: 500 }
        })
        expect(entity.version).assertEqual('2.0')
        expect(entity.fps).assertEqual(30)
        expect(entity.frames).assertEqual(60)
        expect(entity.videoSize.width).assertEqual(500)
        expect(entity.videoSize.height).assertEqual(500)
      })

      it('should calculate duration correctly', 0, () => {
        const entity = new Svgavideoentity({
          fps: 30,
          frames: 60
        })
        // 60 frames at 30 FPS = 2000ms
        expect(entity.getDuration()).assertEqual(2000)
      })

      it('should manage sprites correctly', 0, () => {
        const entity = new Svgavideoentity()
        const sprite1 = new Svgavideospriteentity({ imageKey: 'sprite1.png' })
        const sprite2 = new Svgavideospriteentity({ imageKey: 'sprite2.png' })

        entity.setSprites([sprite1, sprite2])

        expect(entity.getSpriteCount()).assertEqual(2)
        expect(entity.getSpriteAt(0)?.imageKey).assertEqual('sprite1.png')
        expect(entity.getSpriteAt(1)?.imageKey).assertEqual('sprite2.png')
      })
    })

    // ========== Svgadynamicentity Tests ==========
    describe('Svgadynamicentity Tests', () => {
      it('should set and get dynamic text', 0, () => {
        const entity = new Svgadynamicentity()
        entity.setDynamicText('Hello World', { fontSize: 16, color: '#000000' }, 'label1')

        expect(entity.getDynamicText('label1')).assertEqual('Hello World')
        expect(entity.getDynamicTextStyle('label1')?.fontSize).assertEqual(16)
      })

      it('should set and check hidden state', 0, () => {
        const entity = new Svgadynamicentity()
        entity.setDynamicHidden(true, 'element1')

        expect(entity.isHidden('element1')).assertTrue()
        expect(entity.isHidden('element2')).assertFalse()  // 未设置，默认 false
      })

      it('should clear all dynamic elements', 0, () => {
        const entity = new Svgadynamicentity()
        entity.setDynamicText('Test', {}, 'label1')
        entity.setDynamicHidden(true, 'element1')

        entity.clear()

        expect(entity.getDynamicText('label1')).assertUndefined()
        expect(entity.isHidden('element1')).assertFalse()
      })
    })

    // ========== Integration Tests ==========
    describe('Integration Tests', () => {
      it('should create complete video entity', 0, () => {
        // 创建完整的视频实体结构
        const videoEntity = new Svgavideoentity({
          version: '1.0',
          fps: 30,
          frames: 60,
          videoSize: { x: 0, y: 0, width: 300, height: 300 }
        })

        const sprite = new Svgavideospriteentity({
          imageKey: 'test.png',
          frames: Array.from({ length: 60 }, (_, i) => ({
            alpha: 1.0,
            layout: { x: i * 5, y: i * 5, width: 50, height: 50 },
            transform: { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 },
            shapes: [{
              shapePath: 'M 0 0 L 50 0 L 50 50 L 0 50 Z',
              styles: { fill: '#FF0000' }
            }]
          }))
        })

        videoEntity.setSprites([sprite])

        expect(videoEntity.frames).assertEqual(60)
        expect(videoEntity.getSpriteCount()).assertEqual(1)
        expect(videoEntity.getDuration()).assertEqual(2000)
      })
    })

  })
}
