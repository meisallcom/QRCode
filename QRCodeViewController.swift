//
//  QRCodeViewController.swift
//  QRCode
//
//  Created by mjt on 15/11/22.
//  Copyright © 2015年 mjt. All rights reserved.
//
//  AVCaptureMetadataOutputObjectsDelegate: 返回视频捕捉到的数据源
// 

import UIKit
import AVFoundation

class QRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var reScanBtn: UIButton!
    @IBOutlet weak var detailTitle: UILabel!
    // 视频捕捉会话
    var session: AVCaptureSession?
    // 视频显示预览层
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    // 锁定捕捉目标的View
    var autolockView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initSession()
        reScanBtn.hidden = true
    }
    
    func initSession() {
        // 初始化视频捕捉会话
        session = AVCaptureSession()
        // 制定设备为摄像头
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        // 输入
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session?.addInput(input)
        } catch {
            return
        }
        // 输出
        let output = AVCaptureMetadataOutput()
        session?.addOutput(output)
        //添加元数据对象输出代理
        output.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
        // 输出的类型
        output.metadataObjectTypes = [AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeFace]
        
        // 初始化视频预览层，并与session关联
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        // 使预览层充满整个界面
        videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        // 设置预览层frame
        videoPreviewLayer?.frame = view.layer.bounds
        // 添加预览层到主view
        view.layer.addSublayer(videoPreviewLayer!)
        
        // 启动session
        session?.startRunning()
        
        // 把显示结果的label放到视图最前面
        view.bringSubviewToFront(detailTitle)
        
        // 初始化自动锁定框
        autolockView = UIView()
        autolockView?.layer.borderColor = UIColor.greenColor().CGColor
        autolockView?.layer.borderWidth = 2
        view.addSubview(autolockView!)
        view.bringSubviewToFront(autolockView!)
    }
    
    // MARK: - AVCaptureMetadataOutputObjects Delegate
    
    // 视频捕捉成功
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        // 如果捕捉到目标
        if metadataObjects.count > 0 {
            // 判断是否为人脸
            if let obj = metadataObjects.first as? AVMetadataFaceObject {
                let faceObj = videoPreviewLayer?.transformedMetadataObjectForMetadataObject(obj)
                autolockView?.frame = (faceObj?.bounds)!
                detailTitle.text = "发现人脸"
            }
            // 判断是否为机器码
            if let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
                let barCodeObj = videoPreviewLayer?.transformedMetadataObjectForMetadataObject(obj)
                autolockView?.frame = (barCodeObj?.bounds)!
                
                switch obj.type {
                    // 如果使二维码
                case AVMetadataObjectTypeQRCode:
                    if let decodeStr = obj.stringValue {
                        detailTitle.text = "二维码：" + decodeStr
                        launchQRCodeWithURL(decodeStr)
                        stopScan()
                    }
                    break
                    // 如果使条形码
                case AVMetadataObjectTypeEAN13Code:
                    if let decodeStr = obj.stringValue {
                        detailTitle.text = "条形码：" + decodeStr
                        launchBarcodeWithString(decodeStr)
                        stopScan()
                    }
                    break
                default:break
                }
            }
            // 判断是否为条形码
            
        } else {
            autolockView?.frame = CGRectZero
            detailTitle.text = "扫描中..."
            return
        }
    }
    
    @IBAction func reScan(sender: UIButton) {
        session?.startRunning()
        sender.hidden = false
        view.bringSubviewToFront(sender)
    }
    
    func stopScan() {
        session?.stopRunning()
        reScanBtn.hidden = true
    }
    
    // 解析二维码
    func launchQRCodeWithURL(url: String) {
        let alert = UIAlertController(title: "扫描成功", message: "确定要打开吗", preferredStyle: UIAlertControllerStyle.ActionSheet)
        let okAction = UIAlertAction(title: "打开", style: UIAlertActionStyle.Destructive) { (__) -> Void in
            if let url = NSURL(string: url) {
                if UIApplication.sharedApplication().canOpenURL(url) {
                    UIApplication.sharedApplication().canOpenURL(url)
                }
            }
        }
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.Cancel, handler: nil)
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = reScanBtn.frame
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    // 解析条形码
    func launchBarcodeWithString(urlStr: String) {
        // 配置网络会话
         let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        // 聚合数据 条形码 API
        let baseURL = "http://api.juheapi.com/jubar/bar?appkey=6dbeb78efa84f3b745623d2c99297ba0&pkg=me.hcxy&cityid=1&barcode="
        
        let request = NSURLRequest(URL: NSURL(string: baseURL + urlStr)!)
        
        let task = session.dataTaskWithRequest(request) { (data, _, e) -> Void in
            if e == nil {
                do {
                    if let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary {
                        if let summary = json["result"]?["summary"] as? NSDictionary {
                            let name = summary.valueForKey("name") as? String
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.detailTitle.text = self.detailTitle.text! + name!
                            })
                        }
                    }
                } catch {
                    
                }
            }
        }
        
        task.resume()
    }
}
