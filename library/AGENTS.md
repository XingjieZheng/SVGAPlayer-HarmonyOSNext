# SVGA Player Library - Agent Guide

**Scope:** `library/` - HarmonyOS SVGA animation player implementation  
**Stack:** ArkTS, HarmonyOS SDK API 12+, Canvas 2D  
**Lines:** ~3,500 (18 .ets files)

---

## Structure

```
library/
├── Index.ets                    # Public API exports
├── src/main/ets/svga/
│   ├── component/
│   │   └── Svgaplayer.ets       # Main @Component player (225 lines)
│   ├── drawer/
│   │   ├── Sgvadrawer.ets       # Base drawer interface
│   │   └── Svgacanvasdrawer.ets # Canvas 2D renderer (297 lines)
│   ├── entity/                  # Data models (6 files)
│   │   ├── Svgavideoentity.ets       # Root video container
│   │   ├── Svgavideospriteentity.ets # Sprite (layer) entity
│   │   ├── Svgavideospriteframeentity.ets # Frame entity
│   │   ├── Svgavideoshapeentity.ets     # Shape entity
│   │   ├── Svgapathentity.ets           # SVG path parser
│   │   └── Svgadynamicentity.ets        # Dynamic element overrides
│   ├── parser/
│   │   └── Svgaparser.ets       # Binary SVGA protobuf parser (321 lines)
│   ├── types/
│   │   └── SVGATypes.ets        # Shared TypeScript interfaces
│   └── utils/
│       ├── LogUtils.ets         # Hilog wrapper (116 lines)
│       ├── Svgarect.ets         # Rectangle utility
│       └── Svgamatrix.ets       # Matrix transform utility
└── oh-package.json5             # Library manifest
```

---

## Key Entry Points

| Task | File | Symbol |
|------|------|--------|
| Use player component | `component/Svgaplayer.ets` | `Svgaplayer` struct |
| Parse SVGA file | `parser/Svgaparser.ets` | `Svgaparser.getInstance()` |
| Render frame | `drawer/Svgacanvasdrawer.ets` | `Svgacanvasdrawer.draw()` |
| Logging | `utils/LogUtils.ets` | `LogUtils.info/debug/error()` |

---

## Architecture Patterns

### Component State Flow
```typescript
// Svgaplayer.ets - Standard state pattern
@State private videoItem: Svgavideoentity | null = null
@State private currentFrame: number = 0
@State private isPlaying: boolean = false
@Prop loops: number = 0  // From parent

// Controller pattern for external control
private controller: SvgaplayerController = {
  startAnimation: () => { ... },
  setVideoItem: (item) => { ... }
}
```

### Animation Loop
```typescript
// requestAnimationFrame-based loop
private animator: number | null = null
private startAnimation(): void {
  const frame = () => {
    this.drawCurrentFrame()
    this.animator = requestAnimationFrame(frame)
  }
  this.animator = requestAnimationFrame(frame)
}
```

### Protobuf Binary Parsing
```typescript
// Svgaparser.ets - Custom protobuf decoder
async decodeFromBuffer(buffer: ArrayBuffer, callback: ParseCompletion): void {
  const view = new DataView(buffer)
  let offset = 0
  // Wire type parsing (VARINT, FIXED64, LENGTH_DELIMITED, FIXED32)
}
```

---

## Conventions (Library-Specific)

### Naming
- **Classes:** PascalCase with `Svg` prefix (e.g., `Svgaplayer`, `Svgavideoentity`)
- **Interfaces:** PascalCase (e.g., `PlayerCallbacks`, `ParseCompletion`)
- **Enums:** PascalCase (e.g., `FillMode`, `LogLevel`)
- **Private static TAG:** Used for logging context: `private static readonly TAG: string = 'Svgaplayer'`
- **File names:** PascalCase matching primary export (e.g., `Svgaplayer.ets`)

### Component Structure
```typescript
@Component
export struct Svgaplayer {
  // 1. Static readonly TAG
  private static readonly TAG: string = 'Svgaplayer'
  
  // 2. @State variables (nullable with | null)
  @State private videoItem: Svgavideoentity | null = null
  
  // 3. Private instance variables
  private dynamicEntity: Svgadynamicentity = new Svgadynamicentity()
  private animator: number | null = null
  
  // 4. @Prop from parent
  @Prop loops: number = 0
  
  // 5. Lifecycle callbacks
  aboutToAppear() { ... }
  aboutToDisappear() { ... }
  
  // 6. Private methods
  private startAnimation(): void { ... }
  
  // 7. build()
  build() { ... }
}
```

### Import Organization
```typescript
// 1. HarmonyOS SDK kits
import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'

// 2. Project types/interfaces
import { Svgavideoentity } from '../entity/Svgavideoentity'
import { PlayerCallbacks } from '../types/SVGATypes'

// 3. Project utilities
import { LogUtils } from '../utils/LogUtils'
```

### Logging Pattern
```typescript
// ALWAYS use LogUtils wrapper, not direct hilog
LogUtils.info(TAG, 'message')
LogUtils.error(TAG, 'message', error)
LogUtils.printDivider(TAG, 'section marker')  // Visual separator
```

---

## Type Patterns

### Entity Pattern (Protobuf-generated)
```typescript
// All entities use optional parameters interface
export class Svgavideoentity {
  videoSize: Svgarect
  FPS: number = 30
  frames: number = 0
  sprites: Svgavideospriteentity[] = []
  
  constructor(params: VideoEntityParams) {
    if (params.FPS !== undefined) this.FPS = params.FPS
    // All fields optional, defaults provided
  }
}
```

### Callback Interfaces
```typescript
export interface PlayerCallbacks {
  onComplete?: () => void
  onError?: (error: Error) => void
  onFrame?: (frame: number, percentage: number) => void
}
```

---

## Anti-Patterns (Avoid)

### ❌ Direct hilog usage
```typescript
// WRONG - bypasses log level control
import { hilog } from '@kit.PerformanceAnalysisKit'
hilog.info(0x0000, 'tag', 'message')

// CORRECT - use LogUtils
LogUtils.info('tag', 'message')
```

### ❌ Missing TAG constant
```typescript
// WRONG - inconsistent logging context
LogUtils.info('RandomTag', 'message')

// CORRECT
private static readonly TAG: string = 'ClassName'
LogUtils.info(ClassName.TAG, 'message')
```

### ❌ Public state mutation
```typescript
// WRONG - direct @State modification from outside
@State isPlaying: boolean

// CORRECT - use controller pattern
private controller: SvgaplayerController
controller.startAnimation()  // Controlled internal mutation
```

---

## SDK Dependencies

| Kit | Usage |
|-----|-------|
| `@kit.ArkUI` | UI components, Canvas, rendering |
| `@kit.AbilityKit` | UIAbility lifecycle |
| `@kit.NetworkKit` | HTTP download (parser) |
| `@kit.ImageKit` | PixelMap, image.PixelMap |
| `@kit.ArkTS` | util.Base64Helper, ArrayBuffer |
| `@kit.PerformanceAnalysisKit` | hilog (via LogUtils) |

---

## Testing

- Tests located in `library/src/test/ets/`
- Run: `cd entry && ohpm test`
- Coverage: Entities, utils, integration

---

## Notes

- **Binary format:** Custom protobuf-lite implementation (no external proto lib)
- **Canvas reuse:** Single Canvas instance, frame-by-frame clearing
- **Path caching:** Path2D objects cached in Svgapathentity
- **Matrix pooling:** Reuse matrix objects for transform calculations
- **No third-party deps:** Zero oh-package.json5 dependencies (pure HarmonyOS SDK)
