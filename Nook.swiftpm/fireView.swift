//
//  fire.swift
//  Nook
//
//  Created by Yedil on 26.02.2026.
//

import SwiftUI

struct fireView: View {
    var decibelLevel: Float = -160

    private var intensity: Double {
        let norm = Double((decibelLevel + 60) / 60)
        return 0.4 + 0.6 * min(1, max(0, norm))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                let breathScale = 1.0 + 0.02 * sin(time * 2.0)
                context.translateBy(x: size.width / 2, y: size.height)
                context.scaleBy(x: breathScale, y: breathScale)
                context.translateBy(x: -size.width / 2, y: -size.height)
                
                drawLogs(in: &context, size: size)
                
                drawFlames(in: &context, size: size, time: time, intensity: intensity)
                
                drawSparks(in: &context, size: size, time: time, intensity: intensity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
    
    private func drawLogs(in context: inout GraphicsContext, size: CGSize) {
        let logColor = Color(red: 0.4, green: 0.22, blue: 0.12)
        let darkLogColor = Color(red: 0.3, green: 0.15, blue: 0.08)
        let logSize = CGSize(width: 80, height: 14)
        
        var ctx1 = context
        ctx1.translateBy(x: size.width / 2, y: size.height - 18)
        ctx1.rotate(by: .degrees(20))
        let path1 = Path(roundedRect: CGRect(x: -logSize.width / 2, y: -logSize.height / 2, width: logSize.width, height: logSize.height), cornerRadius: logSize.height / 2)
        ctx1.fill(path1, with: .color(logColor))
        
        var ctx2 = context
        ctx2.translateBy(x: size.width / 2, y: size.height - 18)
        ctx2.rotate(by: .degrees(-20))
        let path2 = Path(roundedRect: CGRect(x: -logSize.width / 2, y: -logSize.height / 2, width: logSize.width, height: logSize.height), cornerRadius: logSize.height / 2)
        ctx2.fill(path2, with: .color(darkLogColor))
    }
    
    private func drawFlames(in context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        var fireCtx = context
        fireCtx.blendMode = .screen
        
        let colors: [Color] = [.yellow, .orange.opacity(0.9), .red.opacity(0.7), .red.opacity(0.0)]
        let fireGradient = Gradient(colors: colors)
        
        func drawFlame(xOffset: Double, width: Double, height: Double, phase: Double) {
            let rect = CGRect(x: size.width / 2 - width / 2 + xOffset, y: size.height - height - 25, width: width, height: height)
            var path = Path()
            
            let bottomCenter = CGPoint(x: rect.midX, y: rect.maxY)
            
            let topXWobble = sin(time * 5 + phase) * (width * 0.25)
            let topCenter = CGPoint(x: rect.midX + topXWobble, y: rect.minY)
            
            let ctrlWobble = cos(time * 3 + phase) * (width * 0.15)
            let leftCtrl = CGPoint(x: rect.minX - ctrlWobble, y: rect.maxY - height * 0.4)
            let rightCtrl = CGPoint(x: rect.maxX + ctrlWobble, y: rect.maxY - height * 0.4)
            
            path.move(to: bottomCenter)
            path.addQuadCurve(to: topCenter, control: leftCtrl)
            path.addQuadCurve(to: bottomCenter, control: rightCtrl)
            
            let shading = GraphicsContext.Shading.linearGradient(
                fireGradient,
                startPoint: bottomCenter,
                endPoint: CGPoint(x: rect.midX, y: rect.minY)
            )
            
            fireCtx.fill(path, with: shading)
        }
        
        drawFlame(xOffset: -20, width: 45 * intensity, height: 80  * intensity, phase: 0.0)
        drawFlame(xOffset: 20,  width: 50 * intensity, height: 95  * intensity, phase: 2.0)
        drawFlame(xOffset: 0,   width: 65 * intensity, height: 130 * intensity, phase: 1.0)
    }
    
    private func drawSparks(in context: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        var sparkCtx = context
        sparkCtx.blendMode = .plusLighter
        
        let sparkCount = 30
        
        for i in 0..<sparkCount {
            let seed = Double(i) * 73.1
            
            let duration = 1.0 + seed.truncatingRemainder(dividingBy: 2.0)
            let localTime = (time + seed).truncatingRemainder(dividingBy: duration)
            let progress = localTime / duration
            
            let startX = size.width / 2 + (seed.truncatingRemainder(dividingBy: 60) - 30)
            let startY = size.height - 25
            let travelY = (100 + seed.truncatingRemainder(dividingBy: 150)) * intensity
            let currY = startY - travelY * progress
            
            let amplitude = 10 + seed.truncatingRemainder(dividingBy: 20)
            let currX = startX + sin(progress * .pi * 4 + seed) * amplitude
            
            let radius = 1.0 + seed.truncatingRemainder(dividingBy: 2.5)
            let opacity = 1.0 - pow(progress, 1.5)
            
            let rect = CGRect(x: currX - radius, y: currY - radius, width: radius * 2, height: radius * 2)
            let path = Path(ellipseIn: rect)
            
            let colorIndex = Int(seed) % 3
            let sparkColor: Color = colorIndex == 0 ? .yellow : (colorIndex == 1 ? .orange : .red)
            
            sparkCtx.opacity = opacity
            sparkCtx.fill(path, with: .color(sparkColor))
        }
    }
}
