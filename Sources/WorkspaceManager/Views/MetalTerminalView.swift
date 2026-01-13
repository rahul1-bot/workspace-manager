import SwiftUI
import MetalKit
import CoreText
import AppKit
import SwiftTerm
import Darwin

struct MetalTerminalView: NSViewRepresentable {
    typealias NSViewType = MTKView

    let workingDirectory: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MetalTerminalMTKView(frame: .zero)
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.preferredFramesPerSecond = 120
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = true
        mtkView.presentsWithTransaction = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)

        if let device = mtkView.device {
            let renderer = MetalTerminalRenderer(device: device, view: mtkView)
            let session = MetalTerminalSession(
                workingDirectory: workingDirectory,
                renderer: renderer
            )
            context.coordinator.renderer = renderer
            context.coordinator.session = session
            mtkView.terminalSession = session
            renderer.session = session
            mtkView.delegate = renderer
            session.start()
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        if nsView.preferredFramesPerSecond != 120 {
            nsView.preferredFramesPerSecond = 120
        }
    }

    class Coordinator {
        var renderer: MetalTerminalRenderer?
        var session: MetalTerminalSession?
    }
}

final class MetalTerminalMTKView: MTKView {
    weak var terminalSession: MetalTerminalSession?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        terminalSession?.handleKeyDown(event)
    }
}

final class MetalTerminalSession: SwiftTerm.TerminalDelegate, SwiftTerm.LocalProcessDelegate {
    private var terminal: SwiftTerm.Terminal!
    private var process: SwiftTerm.LocalProcess!
    private let workingDirectory: String
    private weak var renderer: MetalTerminalRenderer?

    private var textGrid: [String] = []
    private var cols: Int
    private var rows: Int

    init(workingDirectory: String, renderer: MetalTerminalRenderer) {
        let options = SwiftTerm.TerminalOptions(
            cols: 80,
            rows: 24,
            cursorStyle: .steadyBlock,
            screenReaderMode: false,
            scrollback: 2000,
            enableSixelReported: false
        )
        self.workingDirectory = workingDirectory
        self.renderer = renderer
        self.cols = options.cols
        self.rows = options.rows
        self.terminal = SwiftTerm.Terminal(delegate: self, options: options)
        self.process = SwiftTerm.LocalProcess(delegate: self)
    }

    func start() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let cwd = FileManager.default.fileExists(atPath: workingDirectory)
            ? workingDirectory
            : FileManager.default.homeDirectoryForCurrentUser.path
        var env = ProcessInfo.processInfo.environment
        env["PWD"] = cwd
        let environment = env.map { "\($0.key)=\($0.value)" }
        process.startProcess(
            executable: shell,
            args: ["-l"],
            environment: environment,
            execName: nil,
            currentDirectory: cwd
        )
        if let renderer = renderer {
            let grid = renderer.currentGridSize()
            resize(cols: grid.cols, rows: grid.rows)
        }
    }

    func resize(cols: Int, rows: Int) {
        self.cols = max(cols, 20)
        self.rows = max(rows, 10)
        terminal.resize(cols: self.cols, rows: self.rows)
        textGrid = Array(repeating: String(repeating: " ", count: self.cols), count: self.rows)
        renderer?.updateText(lines: textGrid, changedRows: nil)
    }

    func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 36: // return
            sendBytes(SwiftTerm.EscapeSequences.cmdRet)
            return
        case 48: // tab
            sendBytes(SwiftTerm.EscapeSequences.cmdTab)
            return
        case 51: // delete/backspace
            sendBytes(SwiftTerm.EscapeSequences.cmdDel)
            return
        case 53: // escape
            sendBytes(SwiftTerm.EscapeSequences.cmdEsc)
            return
        case 117: // forward delete
            sendBytes(SwiftTerm.EscapeSequences.cmdDelKey)
            return
        case 123: // left
            sendBytes(SwiftTerm.EscapeSequences.moveLeftNormal)
            return
        case 124: // right
            sendBytes(SwiftTerm.EscapeSequences.moveRightNormal)
            return
        case 125: // down
            sendBytes(SwiftTerm.EscapeSequences.moveDownNormal)
            return
        case 126: // up
            sendBytes(SwiftTerm.EscapeSequences.moveUpNormal)
            return
        case 115: // home
            sendBytes(SwiftTerm.EscapeSequences.moveHomeNormal)
            return
        case 119: // end
            sendBytes(SwiftTerm.EscapeSequences.moveEndNormal)
            return
        case 116: // page up
            sendBytes(SwiftTerm.EscapeSequences.cmdPageUp)
            return
        case 121: // page down
            sendBytes(SwiftTerm.EscapeSequences.cmdPageDown)
            return
        default:
            break
        }

        if let chars = event.characters {
            sendBytes([UInt8](chars.utf8))
        }
    }

    private func sendBytes(_ bytes: [UInt8]) {
        process.send(data: bytes[...])
    }

    func processTerminated(_ source: SwiftTerm.LocalProcess, exitCode: Int32?) {
        // TODO: surface exit in UI
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        terminal.feed(buffer: slice)
        flushUpdates()
    }

    func getWindowSize() -> winsize {
        return winsize(
            ws_row: UInt16(terminal.rows),
            ws_col: UInt16(terminal.cols),
            ws_xpixel: UInt16(16),
            ws_ypixel: UInt16(16)
        )
    }

    func send(source: SwiftTerm.Terminal, data: ArraySlice<UInt8>) {
        process.send(data: data)
    }

    private func flushUpdates() {
        guard let range = terminal.getUpdateRange() else { return }
        let start = max(0, range.startY)
        let end = min(rows - 1, range.endY)
        if textGrid.count != rows {
            textGrid = Array(repeating: String(repeating: " ", count: cols), count: rows)
        }
        if start <= end {
            for row in start...end {
                if let line = terminal.getLine(row: row) {
                    var text = line.translateToString(trimRight: false, startCol: 0, endCol: cols)
                    if text.count < cols {
                        text += String(repeating: " ", count: cols - text.count)
                    } else if text.count > cols {
                        text = String(text.prefix(cols))
                    }
                    textGrid[row] = text.replacingOccurrences(of: "\u{0}", with: " ")
                } else {
                    textGrid[row] = String(repeating: " ", count: cols)
                }
            }
        }
        terminal.clearUpdateRange()
        renderer?.updateText(lines: textGrid, changedRows: start <= end ? start...end : nil)
    }
}

final class MetalTerminalRenderer: NSObject, MTKViewDelegate {
    private struct Vertex {
        var position: SIMD2<Float>
        var texCoord: SIMD2<Float>
    }

    private struct Uniforms {
        var viewportSize: SIMD2<UInt32>
        var flipVertical: Float
        var padding: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let atlas: GlyphAtlas

    weak var session: MetalTerminalSession?

    private var vertexBuffer: MTLBuffer
    private var vertexCount: Int
    private var viewportSize = SIMD2<UInt32>(0, 0)
    private var lastDrawableSize = CGSize.zero
    private var gridColumns = 0
    private var gridRows = 0
    private let gridMargin: CGFloat = 12
    private var textGrid: [String] = []

    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.atlas = GlyphAtlas(device: device, fontName: "Menlo", fontSize: 16)
        self.pipelineState = MetalTerminalRenderer.buildPipeline(device: device)
        self.samplerState = MetalTerminalRenderer.buildSampler(device: device)

        let initialSize = view.drawableSize
        lastDrawableSize = initialSize
        let grid = MetalTerminalRenderer.gridGeometry(atlas: atlas, drawableSize: initialSize, margin: gridMargin)
        self.gridColumns = grid.columns
        self.gridRows = grid.rows
        self.textGrid = Array(repeating: String(repeating: " ", count: gridColumns), count: gridRows)
        let vertices = MetalTerminalRenderer.buildGridVertices(
            atlas: atlas,
            drawableSize: initialSize,
            margin: gridMargin,
            columns: gridColumns,
            rows: gridRows,
            lines: textGrid
        )
        self.vertexCount = vertices.count
        self.vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )!

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lastDrawableSize = size
        let grid = MetalTerminalRenderer.gridGeometry(atlas: atlas, drawableSize: size, margin: gridMargin)
        gridColumns = grid.columns
        gridRows = grid.rows
        textGrid = Array(repeating: String(repeating: " ", count: gridColumns), count: gridRows)
        session?.resize(cols: gridColumns, rows: gridRows)
        let vertices = MetalTerminalRenderer.buildGridVertices(
            atlas: atlas,
            drawableSize: size,
            margin: gridMargin,
            columns: gridColumns,
            rows: gridRows,
            lines: textGrid
        )
        vertexCount = vertices.count
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )!
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }

        viewportSize = SIMD2<UInt32>(UInt32(view.drawableSize.width), UInt32(view.drawableSize.height))
        var uniforms = Uniforms(viewportSize: viewportSize, flipVertical: 1.0)

        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipelineState)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder?.setFragmentTexture(atlas.texture, index: 0)
        encoder?.setFragmentSamplerState(samplerState, index: 0)
        encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        encoder?.endEncoding()

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }

    func currentGridSize() -> (cols: Int, rows: Int) {
        return (gridColumns, gridRows)
    }

    func updateText(lines: [String], changedRows: ClosedRange<Int>?) {
        guard gridColumns > 0, gridRows > 0 else { return }
        if lines.count != gridRows {
            textGrid = Array(repeating: String(repeating: " ", count: gridColumns), count: gridRows)
        } else {
            textGrid = lines
        }

        if vertexBuffer.length == 0 {
            return
        }

        if let changedRows {
            updateVertexBufferRows(rows: changedRows)
        } else {
            rebuildFullVertexBuffer()
        }
    }

    private func rebuildFullVertexBuffer() {
        let vertices = MetalTerminalRenderer.buildGridVertices(
            atlas: atlas,
            drawableSize: lastDrawableSize,
            margin: gridMargin,
            columns: gridColumns,
            rows: gridRows,
            lines: textGrid
        )
        vertexCount = vertices.count
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )!
    }

    private func updateVertexBufferRows(rows: ClosedRange<Int>) {
        guard gridColumns > 0 else { return }
        let rowVertexCount = gridColumns * 6
        for row in rows {
            if row < 0 || row >= gridRows { continue }
            let line = textGrid[row]
            let rowVertices = MetalTerminalRenderer.buildRowVertices(
                atlas: atlas,
                margin: gridMargin,
                row: row,
                columns: gridColumns,
                line: line
            )
            let offsetVertices = row * rowVertexCount
            let byteOffset = offsetVertices * MemoryLayout<Vertex>.stride
            let copySize = rowVertices.count * MemoryLayout<Vertex>.stride
            memcpy(vertexBuffer.contents().advanced(by: byteOffset), rowVertices, copySize)
        }
    }

    private static func buildPipeline(device: MTLDevice) -> MTLRenderPipelineState {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position;
            float2 texCoord;
        };

        struct Uniforms {
            uint2 viewportSize;
            float flipVertical;
            float padding;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertex_main(
            uint vertexId [[vertex_id]],
            const device VertexIn *vertices [[buffer(0)]],
            constant Uniforms &uniforms [[buffer(1)]]
        ) {
            VertexOut out;
            float2 pos = vertices[vertexId].position;
            float2 viewport = float2(uniforms.viewportSize);
            float2 ndc = float2(
                (pos.x / viewport.x) * 2.0 - 1.0,
                1.0 - (pos.y / viewport.y) * 2.0
            );
            out.position = float4(ndc, 0.0, 1.0);
            float2 uv = vertices[vertexId].texCoord;
            if (uniforms.flipVertical > 0.5) {
                uv.y = 1.0 - uv.y;
            }
            out.texCoord = uv;
            return out;
        }

        fragment float4 fragment_main(
            VertexOut in [[stage_in]],
            texture2d<float> atlas [[texture(0)]],
            sampler samplerState [[sampler(0)]]
        ) {
            float4 color = atlas.sample(samplerState, in.texCoord);
            return color;
        }
        """

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: nil)
        } catch {
            fatalError("Metal shader compile failed: \\(error)")
        }

        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        if let attachment = descriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Metal pipeline creation failed: \\(error)")
        }
    }

    private static func buildSampler(device: MTLDevice) -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .nearest
        descriptor.magFilter = .nearest
        descriptor.mipFilter = .notMipmapped
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        return device.makeSamplerState(descriptor: descriptor)!
    }

    private static func gridGeometry(atlas: GlyphAtlas, drawableSize: CGSize, margin: CGFloat) -> (columns: Int, rows: Int) {
        let availableWidth = max(drawableSize.width - margin * 2, atlas.cellSize.width)
        let availableHeight = max(drawableSize.height - margin * 2, atlas.cellSize.height)
        let columns = max(Int(availableWidth / atlas.cellSize.width), 20)
        let rows = max(Int(availableHeight / atlas.cellSize.height), 10)
        return (columns, rows)
    }

    private static func buildGridVertices(
        atlas: GlyphAtlas,
        drawableSize: CGSize,
        margin: CGFloat,
        columns: Int,
        rows: Int,
        lines: [String]
    ) -> [Vertex] {

        var vertices: [Vertex] = []
        vertices.reserveCapacity(columns * rows * 6)

        for row in 0..<rows {
            for col in 0..<columns {
                let line = row < lines.count ? lines[row] : ""
                let char = ascii(from: line, column: col)

                let uv = atlas.uv(for: char)
                let x0 = Float(margin + CGFloat(col) * atlas.cellSize.width)
                let y0 = Float(margin + CGFloat(row) * atlas.cellSize.height)
                let x1 = x0 + Float(atlas.cellSize.width)
                let y1 = y0 + Float(atlas.cellSize.height)

                let u0 = uv.min.x
                let v0 = uv.min.y
                let u1 = uv.max.x
                let v1 = uv.max.y

                vertices.append(Vertex(position: SIMD2<Float>(x0, y0), texCoord: SIMD2<Float>(u0, v0)))
                vertices.append(Vertex(position: SIMD2<Float>(x1, y0), texCoord: SIMD2<Float>(u1, v0)))
                vertices.append(Vertex(position: SIMD2<Float>(x0, y1), texCoord: SIMD2<Float>(u0, v1)))

                vertices.append(Vertex(position: SIMD2<Float>(x1, y0), texCoord: SIMD2<Float>(u1, v0)))
                vertices.append(Vertex(position: SIMD2<Float>(x1, y1), texCoord: SIMD2<Float>(u1, v1)))
                vertices.append(Vertex(position: SIMD2<Float>(x0, y1), texCoord: SIMD2<Float>(u0, v1)))
            }
        }

        return vertices
    }

    private static func buildRowVertices(
        atlas: GlyphAtlas,
        margin: CGFloat,
        row: Int,
        columns: Int,
        line: String
    ) -> [Vertex] {
        var vertices: [Vertex] = []
        vertices.reserveCapacity(columns * 6)
        for col in 0..<columns {
            let char = ascii(from: line, column: col)
            let uv = atlas.uv(for: char)
            let x0 = Float(margin + CGFloat(col) * atlas.cellSize.width)
            let y0 = Float(margin + CGFloat(row) * atlas.cellSize.height)
            let x1 = x0 + Float(atlas.cellSize.width)
            let y1 = y0 + Float(atlas.cellSize.height)

            let u0 = uv.min.x
            let v0 = uv.min.y
            let u1 = uv.max.x
            let v1 = uv.max.y

            vertices.append(Vertex(position: SIMD2<Float>(x0, y0), texCoord: SIMD2<Float>(u0, v0)))
            vertices.append(Vertex(position: SIMD2<Float>(x1, y0), texCoord: SIMD2<Float>(u1, v0)))
            vertices.append(Vertex(position: SIMD2<Float>(x0, y1), texCoord: SIMD2<Float>(u0, v1)))

            vertices.append(Vertex(position: SIMD2<Float>(x1, y0), texCoord: SIMD2<Float>(u1, v0)))
            vertices.append(Vertex(position: SIMD2<Float>(x1, y1), texCoord: SIMD2<Float>(u1, v1)))
            vertices.append(Vertex(position: SIMD2<Float>(x0, y1), texCoord: SIMD2<Float>(u0, v1)))
        }
        return vertices
    }

    private static func ascii(from line: String, column: Int) -> UInt8 {
        guard column < line.count else { return 32 }
        let index = line.index(line.startIndex, offsetBy: column)
        let scalar = line[index].unicodeScalars.first?.value ?? 32
        if scalar < 32 || scalar > 126 {
            return 32
        }
        return UInt8(scalar)
    }
}

final class GlyphAtlas {
    let texture: MTLTexture
    let cellSize: CGSize
    let atlasSize: CGSize
    private let columns: Int
    private let firstASCII: UInt8 = 32
    private let glyphCount: Int = 95

    init(device: MTLDevice, fontName: String, fontSize: CGFloat) {
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)

        let sampleChar = "W" as CFString
        let sampleGlyph = CTFontGetGlyphWithName(font, sampleChar)
        var advance = CGSize.zero
        var glyph = sampleGlyph
        CTFontGetAdvancesForGlyphs(font, .default, &glyph, &advance, 1)

        let width = max(advance.width, fontSize * 0.6)
        let height = max(ascent + descent + leading, fontSize * 1.2)

        let cellWidth = Int(ceil(width))
        let cellHeight = Int(ceil(height))

        self.cellSize = CGSize(width: cellWidth, height: cellHeight)
        self.columns = 16
        let rows = Int(ceil(Double(glyphCount) / Double(columns)))
        self.atlasSize = CGSize(width: cellWidth * columns, height: cellHeight * rows)

        let texture = GlyphAtlas.buildTexture(
            device: device,
            font: font,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            columns: columns,
            rows: rows,
            firstASCII: firstASCII,
            glyphCount: glyphCount
        )
        self.texture = texture
    }

    func uv(for ascii: UInt8) -> (min: SIMD2<Float>, max: SIMD2<Float>) {
        let idx = max(0, min(Int(ascii) - Int(firstASCII), glyphCount - 1))
        let col = idx % columns
        let row = idx / columns

        let u0 = Float(col) * Float(cellSize.width) / Float(atlasSize.width)
        let v0 = Float(row) * Float(cellSize.height) / Float(atlasSize.height)
        let u1 = Float(col + 1) * Float(cellSize.width) / Float(atlasSize.width)
        let v1 = Float(row + 1) * Float(cellSize.height) / Float(atlasSize.height)

        return (SIMD2<Float>(u0, v0), SIMD2<Float>(u1, v1))
    }

    private static func buildTexture(
        device: MTLDevice,
        font: CTFont,
        cellWidth: Int,
        cellHeight: Int,
        columns: Int,
        rows: Int,
        firstASCII: UInt8,
        glyphCount: Int
    ) -> MTLTexture {
        let width = cellWidth * columns
        let height = cellHeight * rows
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create glyph atlas context")
        }

        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor.white.cgColor)
        context.setTextDrawingMode(.fill)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setFont(CTFontCopyGraphicsFont(font, nil))
        context.setFontSize(CTFontGetSize(font))

        let descent = CTFontGetDescent(font)

        for i in 0..<glyphCount {
            let ascii = firstASCII + UInt8(i)
            var char = UniChar(ascii)
            var glyph = CGGlyph()
            if !CTFontGetGlyphsForCharacters(font, &char, &glyph, 1) {
                continue
            }

            let col = i % columns
            let row = i / columns

            let x = CGFloat(col * cellWidth)
            let yBottom = CGFloat(height - (row + 1) * cellHeight)
            let baseline = yBottom + descent
            var position = CGPoint(x: x, y: baseline)

            CTFontDrawGlyphs(font, &glyph, &position, 1, context)
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            fatalError("Failed to create glyph atlas texture")
        }

        if let data = context.data {
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: data,
                bytesPerRow: bytesPerRow
            )
        }

        return texture
    }
}
