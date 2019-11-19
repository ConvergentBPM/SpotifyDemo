//  Pedometer.swift
//  Spotify-Demo
//
//  Created by Peter Cardenas on 10/28/19.
//  Copyright ¬© 2019 Riverswave Technologies, India. All rights reserved.
//

import Foundation
import CoreMotion

class StepTracker {
    
    var pedometer : CMPedometer?
    var timer : Timer?
    var pedometerData : [Double:Double]?
    
    init() {
        self.pedometer = CMPedometer()
        self.timer = nil
        self.pedometerData = nil
    }
    
    func getStepsPerMinute(numSeconds : Double, callback : (Double) -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(numSeconds), repeats: false, block: {
            _ in
            self.timer!.invalidate()
            self.pedometer!.stopUpdates()
        })
        pedometerData = [:]
        let start = Date()
        self.pedometer!.startUpdates(from: start) { (data, error) in
            guard let pedometerDatum = data else { return }
            let stepsPerMinute = pedometerDatum.currentPace!.doubleValue * 60.0
            let elapsed = start.distance(to: Date())
            self.pedometerData![elapsed] = stepsPerMinute
        }
    }
    
    func getStepsPerMinute(callback : @escaping (Double, Double) -> Void) {
        var prevStepsPerMinute = 0.0
        var prevTotalSteps = 0
        var prevTime = Date()
        pedometer!.startUpdates(from: prevTime) { (data, error) in
            guard let pedometerDatum = data else { return }
            let currTime = Date()
            let stepsPerMinute = Double(pedometerDatum.numberOfSteps.intValue - prevTotalSteps) * 60 / (currTime.timeIntervalSince(prevTime))
            callback(stepsPerMinute, stepsPerMinute - prevStepsPerMinute)
            prevTotalSteps = pedometerDatum.numberOfSteps.intValue
            prevTime = currTime
            prevStepsPerMinute = stepsPerMinute
        }
    }
    
    func stopPedometerUpdates() {
        pedometer!.stopUpdates()
    }
}
