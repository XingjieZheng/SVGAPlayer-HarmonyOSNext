/**
 * SVGA Player for HarmonyOS NEXT
 * 矩阵工具类 - 用于处理2D变换
 */

export class Svgamatrix {
  // 3x3 矩阵 [a, c, tx, b, d, ty, 0, 0, 1]
  private values: Float32Array = new Float32Array([
    1, 0, 0,  // a, c, tx
    0, 1, 0,  // b, d, ty
    0, 0, 1   // 0, 0, 1
  ])

  constructor()
  constructor(values: Float32Array)
  constructor(values?: Float32Array) {
    if (values && values.length === 9) {
      this.values.set(values)
    }
  }

  /**
   * 从数组创建矩阵
   * 数组顺序: [a, c, tx, b, d, ty, 0, 0, 1]
   */
  static fromValues(values: number[]): Svgamatrix {
    const matrix = new Svgamatrix()
    if (values.length >= 6) {
      matrix.values[0] = values[0]  // a
      matrix.values[1] = values[1]  // c
      matrix.values[2] = values[2]  // tx
      matrix.values[3] = values[3]  // b
      matrix.values[4] = values[4]  // d
      matrix.values[5] = values[5]  // ty
    }
    return matrix
  }

  /**
   * 重置为单位矩阵
   */
  reset(): void {
    this.values[0] = 1
    this.values[1] = 0
    this.values[2] = 0
    this.values[3] = 0
    this.values[4] = 1
    this.values[5] = 0
    this.values[6] = 0
    this.values[7] = 0
    this.values[8] = 1
  }

  /**
   * 设置值
   */
  setValues(values: Float32Array): void {
    if (values.length === 9) {
      this.values.set(values)
    }
  }

  /**
   * 获取值
   */
  getValues(): Float32Array {
    return this.values
  }

  /**
   * 平移
   */
  translate(tx: number, ty: number): Svgamatrix {
    this.values[2] += tx
    this.values[5] += ty
    return this
  }

  /**
   * 缩放
   */
  scale(sx: number, sy: number): Svgamatrix {
    this.values[0] *= sx
    this.values[1] *= sx
    this.values[3] *= sy
    this.values[4] *= sy
    return this
  }

  /**
   * 旋转 (角度)
   */
  rotate(degrees: number): Svgamatrix {
    const rad = degrees * Math.PI / 180
    const cos = Math.cos(rad)
    const sin = Math.sin(rad)

    const a = this.values[0]
    const c = this.values[1]
    const tx = this.values[2]
    const b = this.values[3]
    const d = this.values[4]
    const ty = this.values[5]

    this.values[0] = a * cos + c * sin
    this.values[1] = -a * sin + c * cos
    this.values[3] = b * cos + d * sin
    this.values[4] = -b * sin + d * cos

    return this
  }

  /**
   * 矩阵乘法 (前乘)
   */
  preConcat(other: Svgamatrix): Svgamatrix {
    const a1 = this.values[0]
    const c1 = this.values[1]
    const tx1 = this.values[2]
    const b1 = this.values[3]
    const d1 = this.values[4]
    const ty1 = this.values[5]

    const a2 = other.values[0]
    const c2 = other.values[1]
    const tx2 = other.values[2]
    const b2 = other.values[3]
    const d2 = other.values[4]
    const ty2 = other.values[5]

    this.values[0] = a1 * a2 + c1 * b2
    this.values[1] = a1 * c2 + c1 * d2
    this.values[2] = a1 * tx2 + c1 * ty2 + tx1
    this.values[3] = b1 * a2 + d1 * b2
    this.values[4] = b1 * c2 + d1 * d2
    this.values[5] = b1 * tx2 + d1 * ty2 + ty1

    return this
  }

  /**
   * 矩阵乘法 (后乘)
   */
  postConcat(other: Svgamatrix): Svgamatrix {
    const a1 = other.values[0]
    const c1 = other.values[1]
    const tx1 = other.values[2]
    const b1 = other.values[3]
    const d1 = other.values[4]
    const ty1 = other.values[5]

    const a2 = this.values[0]
    const c2 = this.values[1]
    const tx2 = this.values[2]
    const b2 = this.values[3]
    const d2 = this.values[4]
    const ty2 = this.values[5]

    this.values[0] = a1 * a2 + c1 * b2
    this.values[1] = a1 * c2 + c1 * d2
    this.values[2] = a1 * tx2 + c1 * ty2 + tx1
    this.values[3] = b1 * a2 + d1 * b2
    this.values[4] = b1 * c2 + d1 * d2
    this.values[5] = b1 * tx2 + d1 * ty2 + ty1

    return this
  }

  /**
   * 获取缩放比例
   */
  getScale(): number {
    const a = this.values[0]
    const b = this.values[3]
    return Math.sqrt(a * a + b * b)
  }

  /**
   * 转换为数组 [a, b, c, d, tx, ty]
   * 用于 Canvas transform
   */
  toTransformArray(): number[] {
    return [
      this.values[0], // a
      this.values[3], // b
      this.values[1], // c
      this.values[4], // d
      this.values[2], // tx
      this.values[5]  // ty
    ]
  }

  /**
   * 复制矩阵
   */
  copy(): Svgamatrix {
    return new Svgamatrix(new Float32Array(this.values))
  }

  /**
   * 转换为字符串
   */
  toString(): string {
    return `Matrix([${this.values[0].toFixed(2)}, ${this.values[1].toFixed(2)}, ${this.values[2].toFixed(2)}, ` +
           `${this.values[3].toFixed(2)}, ${this.values[4].toFixed(2)}, ${this.values[5].toFixed(2)}])`
  }
}
