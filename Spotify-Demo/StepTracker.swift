//
//  StepTracker.swift
//  Spotify-Demo
//
//  Created by Peter Cardenas on 10/28/19.
//  Copyright © 2019 Riverswave Technologies, India. All rights reserved.
//

import Foundation
import CoreMotion

class StepTracker {
    
    var pedometer : CMPedometer
    var pedometerData : [Double:Double]
    
    init() {
        self.pedometer = CMPedometer()
        self.pedometerData = [:]
    }
    
    func getStepsPerMinute(changeInCadence: Double, callback : @escaping (Double) -> Void) {
        var prevStepsPerMinute = 0.0
        var prevTotalSteps = 0
        var prevTime = Date()
        var stabilized = false
        
        pedometer.startUpdates(from: prevTime) { (data, error) in
            guard let pedometerDatum = data else { return }
            let currTime = pedometerDatum.endDate
            let stepsPerMinute = Double(pedometerDatum.numberOfSteps.intValue - prevTotalSteps) * 60 / (currTime.timeIntervalSince(prevTime))
            print("Steps per minute: \(stepsPerMinute) at \(currTime)")
            if !stabilized {
                if abs(prevStepsPerMinute - stepsPerMinute) < changeInCadence && stepsPerMinute > 0 {
                    stabilized = true
                    callback(stepsPerMinute)
                }
                prevStepsPerMinute = stepsPerMinute
            } else {
                if abs(stepsPerMinute - prevStepsPerMinute) > changeInCadence {
                    callback(stepsPerMinute)
                    prevStepsPerMinute = stepsPerMinute
                }
            }
            prevTotalSteps = pedometerDatum.numberOfSteps.intValue
            prevTime = currTime
        }
    }
    
    func stopPedometerUpdates() {
        pedometer.stopUpdates()
    }
}
