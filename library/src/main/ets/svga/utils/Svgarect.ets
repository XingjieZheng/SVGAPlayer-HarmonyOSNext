/**
 * SVGA Player for HarmonyOS NEXT
 * 矩形工具类
 */

export class Svgarect {
  x: number
  y: number
  width: number
  height: number

  constructor(x: number = 0, y: number = 0, width: number = 0, height: number = 0) {
    this.x = x
    this.y = y
    this.width = width
    this.height = height
  }

  /**
   * 判断是否为空矩形
   */
  isEmpty(): boolean {
    return this.width <= 0 || this.height <= 0
  }

  /**
   * 判断是否包含点
   */
  contains(x: number, y: number): boolean {
    return x >= this.x && x <= this.x + this.width &&
           y >= this.y && y <= this.y + this.height
  }

  /**
   * 复制矩形
   */
  copy(): Svgarect {
    return new Svgarect(this.x, this.y, this.width, this.height)
  }

  /**
   * 转换为字符串
   */
  toString(): string {
    return `Rect(${this.x.toFixed(2)}, ${this.y.toFixed(2)}, ${this.width.toFixed(2)}, ${this.height.toFixed(2)})`
  }
}
