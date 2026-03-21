//
//  GameViewController.swift
//  YJS97
//
//  Created by FrancisGray on 2026/3/16.
//

import Cocoa
import MetalKit

// Our macOS specific view controller
class GameViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            unlockMouse()
            return
        }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            return
        }
        renderer?.pressedKeys.insert(key)
    }

    override func keyUp(with event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            return
        }
        renderer?.pressedKeys.remove(key)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        // Check for Metal 4 support
        if !defaultDevice.supportsFamily(.metal4) {
            print("Metal 4 is not supported")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            event in
            self.keyDown(with: event)
            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) {
            event in
            self.keyUp(with: event)
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
        ]) { event in
            self.renderer?.camera.processMouseMovement(
                deltaX: Float(event.deltaX),
                deltaY: Float(event.deltaY)
            )
            return event
        }
    }
    //Mouse
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.acceptsMouseMovedEvents = true
    }
    override func mouseMoved(with event: NSEvent) {
        renderer?.camera.processMouseMovement(
            deltaX: Float(event.deltaX),
            deltaY: Float(event.deltaY)
        )
    }
    override func mouseDragged(with event: NSEvent) {
        renderer?.camera.processMouseMovement(
            deltaX: Float(event.deltaX),
            deltaY: Float(event.deltaY)
        )
    }
    var isMouseLocked = false

    // 玩家用鼠标点击游戏画面时，立刻锁定并隐藏鼠标！
    override func mouseDown(with event: NSEvent) {
        lockMouse()
    }

    func lockMouse() {
        if !isMouseLocked {
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
            isMouseLocked = true
        }
    }

    func unlockMouse() {
        if isMouseLocked {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            isMouseLocked = false
        }
    }
    
}
