/**
 * SVGA Player for HarmonyOS NEXT
 * 日志工具类 - 用于排查播放动画是否正常
 */

import { hilog } from '@kit.PerformanceAnalysisKit'

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

export class LogUtils {
  private static readonly DOMAIN: number = 0x0001
  private static readonly TAG: string = 'SVGAPlayer'
  private static currentLevel: LogLevel = LogLevel.DEBUG
  private static isDebugMode: boolean = true

  /**
   * 设置日志级别
   */
  static setLogLevel(level: LogLevel): void {
    LogUtils.currentLevel = level
  }

  /**
   * 设置调试模式
   */
  static setDebugMode(debug: boolean): void {
    LogUtils.isDebugMode = debug
  }

  /**
   * 调试日志
   */
  static debug(tag: string, message: string): void {
    if (LogUtils.isDebugMode && LogUtils.currentLevel <= LogLevel.DEBUG) {
      hilog.debug(LogUtils.DOMAIN, LogUtils.TAG, `[${tag}] ${message}`)
    }
  }

  /**
   * 信息日志
   */
  static info(tag: string, message: string): void {
    if (LogUtils.currentLevel <= LogLevel.INFO) {
      hilog.info(LogUtils.DOMAIN, LogUtils.TAG, `[${tag}] ${message}`)
    }
  }

  /**
   * 警告日志
   */
  static warn(tag: string, message: string): void {
    if (LogUtils.currentLevel <= LogLevel.WARN) {
      hilog.warn(LogUtils.DOMAIN, LogUtils.TAG, `[${tag}] ${message}`)
    }
  }

  /**
   * 错误日志
   */
  static error(tag: string, message: string, error?: Error): void {
    if (LogUtils.currentLevel <= LogLevel.ERROR) {
      const errorMsg = error ? ` - ${error.message}` : ''
      hilog.error(LogUtils.DOMAIN, LogUtils.TAG, `[${tag}] ${message}${errorMsg}`)
    }
  }

  /**
   * 打印分隔线 - 用于标记重要流程节点
   */
  static printDivider(tag: string, title: string): void {
    LogUtils.info(tag, `================ ${title} ================`)
  }

  /**
   * 打印对象信息
   */
  static debugObject(tag: string, obj: object): void {
    if (LogUtils.isDebugMode && LogUtils.currentLevel <= LogLevel.DEBUG) {
      try {
        const json = JSON.stringify(obj, null, 2)
        hilog.debug(LogUtils.DOMAIN, LogUtils.TAG, `[${tag}] ${json}`)
      } catch (e) {
        hilog.debug(LogUtils.DOMAIN, LogUtils.TAG, `[${tag}] [Object unable to stringify]`)
      }
    }
  }

  /**
   * 打印动画播放状态
   */
  static logAnimationState(tag: string, state: string, details?: object): void {
    LogUtils.info(tag, `Animation State: ${state}`)
    if (details) {
      LogUtils.debugObject(tag, details)
    }
  }

  /**
   * 打印渲染信息
   */
  static logRenderInfo(tag: string, frameIndex: number, spriteCount: number): void {
    LogUtils.debug(tag, `Rendering frame ${frameIndex}, sprites: ${spriteCount}`)
  }

  /**
   * 打印性能信息
   */
  static logPerformance(tag: string, operation: string, durationMs: number): void {
    LogUtils.debug(tag, `${operation} took ${durationMs.toFixed(2)}ms`)
  }
}
