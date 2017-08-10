//
//  ViewController.swift
//  CustomCamera
//
//  Created by Adarsh V C on 06/10/16.
//  Copyright © 2016 FAYA Corporation. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation
import CoreImage

class ViewController: UIViewController {
    
    var qrCodeFrameView: UIView?
    var timer: DispatchSourceTimer?
    
    @IBOutlet weak var capturedImage: UIImageView!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var navigationBar: UINavigationBar!
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var captureSession = AVCaptureSession()
    let stillImageOutput = AVCaptureStillImageOutput()
    var previewLayer : AVCaptureVideoPreviewLayer?
    var capturePhotoOutput: AVCapturePhotoOutput?
    
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.perform(#selector(self.capturDevice), with: nil, afterDelay: 1.0)
//
//        self.capturDevice()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    //MARK: -- Custom Methods
    func capturDevice(){
     captureDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front)
        if captureDevice != nil {
            print("Capture device found")
            beginSession()
        }
        
        
    }
    
    func takePhoto(){
        // Make sure capturePhotoOutput is valid
        guard let capturePhotoOutput = self.capturePhotoOutput else { return }
        
        // Get an instance of AVCapturePhotoSettings class
        let photoSettings = AVCapturePhotoSettings()
        
        // Set photo settings for our need
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.isHighResolutionPhotoEnabled = true
        // Call capturePhoto method by passing our photo settings and a delegate implementing AVCapturePhotoCaptureDelegate
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func beginSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                
                // Get an instance of the AVCaptureDeviceInput class using the previous deivce object
                let input = try AVCaptureDeviceInput(device: self.captureDevice)
                
                // Initialize the captureSession object
                self.captureSession = AVCaptureSession()
                
                // Set the input devcie on the capture session
                self.captureSession.addInput(input)
                
                
                // Get an instance of ACCapturePhotoOutput class
                self.capturePhotoOutput = AVCapturePhotoOutput()
                self.capturePhotoOutput?.isHighResolutionCaptureEnabled = true
                
                // Set the output on the capture session
                self.captureSession.addOutput(self.capturePhotoOutput)
                
                // Initialize a AVCaptureMetadataOutput object and set it as the input device
                let captureMetadataOutput = AVCaptureMetadataOutput()
                self.captureSession.addOutput(captureMetadataOutput)
                
                // Set delegate and use the default dispatch queue to execute the call back
                captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode,AVMetadataObjectTypeFace]
          
            }
            catch {
                print("error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                if self.captureSession.canAddOutput(self.stillImageOutput) {
                    self.captureSession.addOutput(self.stillImageOutput)
                }
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.videoPreviewLayer?.frame.size = self.cameraView.frame.size
                self.videoPreviewLayer?.frame = self.cameraView.layer.frame
                self.videoPreviewLayer?.frame = self.cameraView.bounds
                self.videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                self.cameraView.layer.addSublayer(self.videoPreviewLayer!)
                self.view.addSubview(self.navigationBar)
                self.captureSession.startRunning()
                
                //Initialize QR Code Frame to highlight the QR code
                self.qrCodeFrameView = UIView()
                
                if let qrCodeFrameView = self.qrCodeFrameView {
                    qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                    qrCodeFrameView.layer.borderWidth = 2
                    self.cameraView.addSubview(qrCodeFrameView)
                    self.cameraView.bringSubview(toFront: qrCodeFrameView)
                }
                self.startTimer()
            }
        }
     

    }
    func endSession() {
        self.cameraView.removeFromSuperview()
    }
 
    func startTimer() {
        let queue = DispatchQueue(label: "com.domain.app.timer")  // you can also use `DispatchQueue.main`, if you want
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.scheduleRepeating(deadline: .now(), interval: .seconds(2))
        timer!.setEventHandler { 
            self.takePhoto()
        }
        timer!.resume()
    }
    
    func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    deinit {
        self.stopTimer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
//        self.captureSession.stopRunning()
        
    }
}

extension ViewController : AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        // Make sure we get some photo sample buffer
        guard error == nil,
            let photoSampleBuffer = photoSampleBuffer else {
                print("Error capturing photo: \(String(describing: error))")
                return
        }
        
        // Convert photo same buffer to a jpeg image data by using AVCapturePhotoOutput
        if #available(iOS 10.0, *) {
            guard let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else {
                return
            }
            let capturedImage = UIImage.init(data: imageData , scale: 1.0)
            self.captureSession.stopRunning()
            if let outputImage = capturedImage {
                self.perform(#selector(detect), with: outputImage, afterDelay: 0.5)
            }
        } else {
            // Fallback on earlier versions
        }
        // Initialise an UIImage with our image data
    }
    
    func detect(image:UIImage) {
        let imageOptions =  NSDictionary(object: NSNumber(value: 5) as NSNumber, forKey: CIDetectorImageOrientation as NSString)
        let personciImage = CIImage(cgImage: image.cgImage!)
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: personciImage, options: imageOptions as? [String : AnyObject])
        
        if let face = faces?.first as? CIFaceFeature {
            print("found bounds are \(face.bounds)")
            capturedImage.image = image
            if face.hasSmile {
                print("face is smiling");
            }
            
            if face.hasLeftEyePosition {
                print("Left eye bounds are \(face.leftEyePosition)")
            }
            
            if face.hasRightEyePosition {
                print("Right eye bounds are \(face.rightEyePosition)")
            }
            self.captureSession.stopRunning()
            stopTimer()
            self.perform(#selector(self.endSession), with: nil, afterDelay: 0.5)
        } else {
            
            self.captureSession.startRunning()
        }
    }
}

extension ViewController : AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputMetadataObjects metadataObjects: [Any]!,
                       from connection: AVCaptureConnection!) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects == nil || metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
        
        if let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            if metadataObj.stringValue != nil {
                debugPrint(metadataObj.stringValue)
            }
        }
        else if let faceObj = metadataObjects[0] as? AVMetadataFaceObject {
            if let faceObject = self.videoPreviewLayer?.transformedMetadataObject(for: faceObj){
                qrCodeFrameView?.frame = (faceObject.bounds)
               
            }
        }
    }
}
