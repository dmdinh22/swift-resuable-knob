/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
// import subclass to override gesture recognizer methods
import UIKit.UIGestureRecognizerSubclass

class Knob: UIControl {
  var minimumValue: Float = 0
  var maximumValue: Float = 1
  private (set) var value: Float = 0
  private let renderer = KnobRenderer()
  
  // lets you set value of control programmatically
  func setValue(_ newValue: Float, animated: Bool = false) {
    value = min(maximumValue, max(minimumValue, newValue))
    
    let angleRange = endAngle - startAngle
    let valueRange = maximumValue - minimumValue
    let angleValue = CGFloat(value - minimumValue) / CGFloat(valueRange) * angleRange + startAngle
    
    renderer.setPointerAngle(angleValue, animated: animated)
  }
  
  var isContinuous = true
  
  // exposing appearance props in the api
  // allows others to change control's appearance
  var lineWidth: CGFloat {
    get { return renderer.lineWidth }
    set { renderer.lineWidth = newValue }
  }
  
  var startAngle: CGFloat {
    get { return renderer.startAngle}
    set { renderer.startAngle = newValue }
  }
  
  var endAngle: CGFloat {
    get { return renderer.endAngle }
    set { renderer.endAngle = newValue }
  }
  
  var pointerLength: CGFloat {
    get { return renderer.pointerLength }
    set { renderer.pointerLength = newValue }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }
  
  private func commonInit() {
    // set knob renderer's size
    renderer.updateBounds(bounds)
    renderer.color = tintColor
    renderer.setPointerAngle(renderer.startAngle, animated: false)
    
    // add two layers as sublayers of control's layer
    layer.addSublayer(renderer.trackLayer)
    layer.addSublayer(renderer.pointerLayer)
    
    // wire up interaction to knob control
    let gestureRecognizer = RotationGestureRecognizer(target: self, action: #selector(Knob.handleGesture(_:)))
    addGestureRecognizer(gestureRecognizer)
  }
    
    @objc private func handleGesture(_ gesture: RotationGestureRecognizer) {
        // 1 - calc angle of midpoint bt start and end angles
        // not part of knob path, but represents angle the pointer should flip bt min and max vals
        let midPointAngle = (2 * CGFloat(Double.pi) + startAngle - endAngle) / 2 + endAngle

        // 2 - boundedAngle var to adjust angle calculated to ensure
        // it stays in the allowed bounded ranges
        var boundedAngle = gesture.touchAngle
        if boundedAngle > midPointAngle {
            boundedAngle -= 2 * CGFloat(Double.pi)
        } else if boundedAngle < (midPointAngle - 2 * CGFloat(Double.pi)) {
            boundedAngle -= 2 * CGFloat(Double.pi)
        }

        // 3 - update angle to be bt defined bounds
        boundedAngle = min(endAngle, max(startAngle, boundedAngle))

        // 4 - convert angle to a value
        let angleRange = endAngle - startAngle
        let valueRange = maximumValue - minimumValue
        let angleValue = Float(boundedAngle - startAngle) / Float(angleRange) * valueRange + minimumValue

        // 5 - set knob's control value to calculated val
        setValue(angleValue)
      
      // fire event every time gesture sends an update if continuously moving
      if isContinuous {
        sendActions(for: .valueChanged)
      } else {
        if gesture.state == .ended || gesture.state == .cancelled {
          sendActions(for: .valueChanged)
        }
      }
    }
}

private class KnobRenderer {
  var color: UIColor = .blue {
    didSet {
      trackLayer.strokeColor = color.cgColor
      pointerLayer.strokeColor = color.cgColor
    }
  }
  
  var lineWidth: CGFloat = 2 {
    didSet {
      trackLayer.lineWidth = lineWidth
      pointerLayer.lineWidth = lineWidth
      updateTrackLayerPath()
      updatePointerLayerPath()
    }
  }
  
  var startAngle: CGFloat = CGFloat(-Double.pi) * 11/8 {
    didSet {
      updateTrackLayerPath()
    }
  }
  
  var endAngle: CGFloat = CGFloat(Double.pi) * 3/8 {
    didSet {
      updateTrackLayerPath()
    }
  }
  
  var pointerLength: CGFloat = 6 {
    didSet {
      updateTrackLayerPath()
      updatePointerLayerPath()
    }
  }
  
  private (set) var pointerAngle: CGFloat = CGFloat(-Double.pi) * 11/8
  
  func setPointerAngle(_ newPointerAngle: CGFloat, animated: Bool = false) {
    // wrap in CATranscation to predictably animate
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    // creates rotation transform to rotate the layer around the z-axis by specified angle
    // transform prop expects to be passed a CATransform3D
    pointerLayer.transform = CATransform3DMakeRotation(newPointerAngle, 0, 0, 1)
    
    // when animated is true, create explicity animation that rotates pointer in right direction
    if animated {
      let midAngleValue = (max(newPointerAngle, pointerAngle) - min(newPointerAngle, pointerAngle)) / 2
                        + min(newPointerAngle, pointerAngle)
      // create frame animation and specify property to animate
      let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
      
      // specify three angles which the layer would rotate 
      animation.values = [pointerAngle, midAngleValue, newPointerAngle]
      // normalized times as percentages to reach animation values
      animation.keyTimes = [0.0, 0.5, 1.0]
      animation.timingFunctions = [CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)]
      
      pointerLayer.add(animation, forKey: nil)
    }
    
    CATransaction.commit()
    
    pointerAngle = newPointerAngle
  }
  
  // creating the two layers for knob track and pointer
  let trackLayer = CAShapeLayer()
  let pointerLayer = CAShapeLayer()
  
  init() {
    trackLayer.fillColor = UIColor.clear.cgColor
    pointerLayer.fillColor = UIColor.clear.cgColor
  }
  
  // creates arc btwn startAngle & endAngle values, positioned on center of trackLayer
  private func updateTrackLayerPath() {
    let bounds = trackLayer.bounds
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let offset = max(pointerLength, lineWidth / 2)
    let radius = min(bounds.width, bounds.height) / 2 - offset
  
    // use UIBezierPath to create path, then convert to CGPathRef
    let ring = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle,
                            endAngle: endAngle, clockwise: true)
    trackLayer.path = ring.cgPath
  }
  
  // creates path for pointer at position where angle == 0
  private func updatePointerLayerPath() {
    let bounds = trackLayer.bounds
    let pointer = UIBezierPath()
    
    pointer.move(to: CGPoint(x: bounds.width - CGFloat(pointerLength)
      - CGFloat(lineWidth) / 2, y: bounds.midY))
    pointer.addLine(to: CGPoint(x: bounds.width, y: bounds.midY))
    pointerLayer.path = pointer.cgPath
  }
  
  // take a bounds rect and resizes layers to match and positions layers
  // to center of bounding rect
  func updateBounds(_ bounds: CGRect) {
    trackLayer.bounds = bounds
    trackLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    updateTrackLayerPath()
    
    pointerLayer.bounds = trackLayer.bounds
    pointerLayer.position = trackLayer.position
    updatePointerLayerPath()
  }
}

// responsing to touch interaction to track single finger drag across screen
private class RotationGestureRecognizer: UIPanGestureRecognizer {
  private(set) var touchAngle: CGFloat = 0
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    updateAngle(with: touches)
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesMoved(touches, with: event)
    updateAngle(with: touches)
  }
  
  // utility function
  // takes set of touches and extracts first touch
  // translates touch point into coord system of view associated with gesture recognizer
  private func updateAngle(with touches: Set<UITouch>) {
    guard
      let touch = touches.first,
      let view = view
      else {
        return
    }
    
    let touchPoint = touch.location(in: view)
    touchAngle = angle(for: touchPoint, in: view)
  }
  
  private func angle(for point: CGPoint, in view: UIView) -> CGFloat {
    let centerOffset = CGPoint(x: point.x - view.bounds.midX, y: point.y - view.bounds.midY)
    return atan2(centerOffset.y, centerOffset.x)
  }
  
  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    
    maximumNumberOfTouches = 1
    minimumNumberOfTouches = 1
  }
}


