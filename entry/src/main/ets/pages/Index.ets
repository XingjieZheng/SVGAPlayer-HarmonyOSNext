/**
 * 主页面 - SVGA播放器演示
 */

import { 
  LogUtils, 
  LogLevel, 
  Svgaplayer, 
  Svgaparser,
  Svgavideoentity
} from 'svga-player'

@Entry
@Component
struct Index {
  @State private status: string = 'Ready'
  @State private message: string = 'SVGA Player Library Demo'
  @State private videoItem: Svgavideoentity | null = null
  @State private isPlaying: boolean = false
  
  aboutToAppear(): void {
    LogUtils.setLogLevel(LogLevel.DEBUG)
    console.info('SVGA Player Demo - Page appeared')
    this.loadSvgaFile()
  }

  private loadSvgaFile(): void {
    const svgaUrl = 'https://photo.zastatic.com/images/cms/gift/20191106/420351339427704.svga'
    
    this.status = 'Loading SVGA...'
    this.videoItem = null
    console.info('Loading SVGA from: ' + svgaUrl)
    
    const parser = Svgaparser.getInstance()
    parser.decodeFromUrl(svgaUrl, {
      onComplete: (videoItem) => {
        console.info('SVGA loaded: ' + videoItem.frames + ' frames')
        this.videoItem = videoItem
        this.isPlaying = true
        this.status = 'Playing'
        this.message = videoItem.frames + ' frames loaded. Auto playing.'
      },
      onError: (error) => {
        console.error('Failed to load SVGA: ' + error.message)
        this.status = 'Load Failed'
        this.message = 'Error: ' + error.message
        this.videoItem = null
      }
    })
  }

  private playAnimation(): void {
    if (this.videoItem) {
      console.info('Play clicked - reloading to play')
      this.loadSvgaFile()
    } else {
      console.warn('Cannot play: no video loaded')
      this.status = 'No Video'
      this.message = 'Please wait for video to load'
    }
  }

  private pauseAnimation(): void {
    console.info('Pause clicked - Note: autoPlay=true, player controls itself')
    this.isPlaying = false
    this.status = 'Paused (Demo)'  
  }

  private stopAnimation(): void {
    console.info('Stop clicked - Note: autoPlay=true, player controls itself')
    this.isPlaying = false
    this.status = 'Stopped (Demo)'
  }

  build() {
    Column({ space: 20 }) {
      Text('HarmonyOS SVGA Player')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890ff')
        .margin({ top: 40, bottom: 20 })

      // SVGA Player Component
      Stack() {
        if (this.videoItem) {
          Svgaplayer({
            loops: 0,
            autoPlay: true,
            antiAlias: true,
            sourceVideoItem: this.videoItem
          })
            .width(300)
            .height(300)
        } else {
          // Show loading or placeholder
          Column() {
            if (this.status === 'Loading SVGA...') {
              LoadingProgress()
                .width(50)
                .height(50)
                .color(Color.Grey)
              Text('Loading...')
                .fontSize(14)
                .fontColor('#999999')
                .margin({ top: 10 })
            } else if (this.status === 'Load Failed') {
              Text('Failed to load')
                .fontSize(14)
                .fontColor('#ff0000')
            } else {
              Text('No video loaded')
                .fontSize(14)
                .fontColor('#999999')
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width(300)
      .height(300)
      .backgroundColor('#f0f0f0')

      Text(this.status)
        .fontSize(16)
        .fontColor('#666666')

      Text(this.message)
        .fontSize(14)
        .fontColor('#999999')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 10 }) {
        Button('Reload & Play')
          .onClick(() => {
            this.playAnimation()
          })

        Button('Pause (Demo)')
          .onClick(() => {
            this.pauseAnimation()
          })

        Button('Stop (Demo)')
          .onClick(() => {
            this.stopAnimation()
          })
      }

      Column({ space: 10 }) {
        Text('Library Components:')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text('✓ Svgaplayer - Main component')
          .fontSize(12)
          .fontColor('#666666')

        Text('✓ Svgaparser - Load SVGA files')
          .fontSize(12)
          .fontColor('#666666')

        Text('✓ Canvas rendering')
          .fontSize(12)
          .fontColor('#666666')

        Text('✓ Animation controls')
          .fontSize(12)
          .fontColor('#666666')
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 20, left: 20, right: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}