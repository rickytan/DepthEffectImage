//
//  ViewController.swift
//  DepthEffectImage
//
//  Created by rickytan on 2022/11/22.
//

import UIKit
import Photos
import PhotosUI
import CoreML
import Vision

extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        self.draw(in: .init(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? self
    }
}

extension UIImageView : NSSecureCoding {
    public static var supportsSecureCoding: Bool {
        false
    }
}

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    lazy var request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model.model)) { [unowned self] request, error in
        if let results = request.results as? [VNCoreMLFeatureValueObservation] {
            if let feature = results.first?.featureValue, let arrayValue = feature.multiArrayValue {
                let width = arrayValue.shape[0].intValue
                let height = arrayValue.shape[1].intValue
                let stride = arrayValue.strides[0].intValue
                let components = 4
                var bitmapData = Data(count: arrayValue.count * components)
                for var i in 0..<width {
                    for var j in 0..<height {
                        let label = arrayValue[j * stride + i].intValue
                        switch label {
                        case 0:
                            bitmapData[j * stride * components + i * components + 0] = 0x0
                            bitmapData[j * stride * components + i * components + 1] = 0x0
                            bitmapData[j * stride * components + i * components + 2] = 0x0
                            bitmapData[j * stride * components + i * components + 3] = 0x0
                        default:
                            bitmapData[j * stride * components + i * components + 0] = 0x0
                            bitmapData[j * stride * components + i * components + 1] = 0x0
                            bitmapData[j * stride * components + i * components + 2] = 0x0
                            bitmapData[j * stride * components + i * components + 3] = 0xff
                        }
                    }
                }
                let bitmapImage = CGImage(width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bitsPerPixel: 8 * components,
                                          bytesPerRow: width * components,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: .init(rawValue: CGImageAlphaInfo.last.rawValue),
                                          provider: .init(data: bitmapData as CFData)!,
                                          decode: nil,
                                          shouldInterpolate: false,
                                          intent: .defaultIntent)
                let image = UIImage(cgImage: bitmapImage!).resize(to: self.imageSize)
                DispatchQueue.main.async {
                    self.maskImage = image
                }
            }
            
        }
    }
    lazy var model = try! DeepLabV3(configuration: {
        let config = MLModelConfiguration()
        config.allowLowPrecisionAccumulationOnGPU = true
        config.computeUnits = .cpuAndNeuralEngine
        return config
    }())
    
    var imageSize: CGSize = .zero
    var maskImage: UIImage? {
        didSet {
            replicateView = UIImageView(image: self.imageView.image)
            let mask = UIImageView(image: maskImage)
            mask.contentMode = .scaleAspectFill
            mask.frame = self.imageView.bounds
            replicateView?.mask = mask
        }
    }
    var replicateView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let view = replicateView {
                view.frame = self.imageView.bounds
                view.contentMode = self.imageView.contentMode
                self.view.addSubview(view)
            }
        }
    }
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        segment()
    }
    
    private func segment() {
        if let image = self.imageView.image {
            imageSize = image.size
            DispatchQueue.global().async { [unowned self] in
                self.request.imageCropAndScaleOption = .scaleFill
                let handler = VNImageRequestHandler(cgImage: image.cgImage!)
                try? handler.perform([self.request])
            }
        }
    }
    
    private func replicateView(view: UIView) -> UIView? {
        view.snapshotView(afterScreenUpdates: false)
    }
    
    @IBAction func onPhoto(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
}

extension ViewController : UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else {
            return
        }
        picker.dismiss(animated: true) {
            self.imageView.image = image
            self.segment()
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
