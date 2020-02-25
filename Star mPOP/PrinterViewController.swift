//
//  PrinterViewController.swift
//  Star mPOP
//
//  Created by Pranit  Harekar on 2/25/20.
//  Copyright © 2020 Pranit  Harekar. All rights reserved.
//

import UIKit

typealias SuccessCallback = (() -> Void)
typealias ErrorCallback = ((NSError?) -> Void)

let serialQueue = DispatchQueue(label: "com.star.queue")

class PrinterViewController: UIViewController, StarIoExtManagerDelegate {
    let emulation = StarIoExtEmulation.starLine
    let portSettings = ""
    let ioTimeoutInMillis: UInt = 10000
    
    var name = ""
    var starIoExtManager: StarIoExtManager!
    var printers = [PortInfo]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let ports = self.searchPrinters()
        print("ports \(ports)")

        // Create an instance of StarIoExtManager
        self.starIoExtManager = StarIoExtManager(type: .withBarcodeReader,
                                                 portName: ports[0].portName,
                                                 portSettings: portSettings,
                                                 ioTimeoutMillis: ioTimeoutInMillis)
        self.starIoExtManager.delegate = self
        self.name = "\(ports[0].portName!) \(ports[0].modelName!)"
        
        // Connect to port via StarIoExtManager
        serialQueue.async {
            self.starIoExtManager.connect()
        }
    }
 
    // handlers for various buttons
    @IBAction func didTapSearchPrinters(_ sender: Any) {
        self.printers = self.searchPrinters()
        print("found printers : \(self.printers)")
    }
    
    @IBAction func didTapPrintTestReceipt(_ sender: Any) {
        printTestReceipt(success:{
            print("successfully to printed receipt")
        }) { (err) in
            print("failed to print receipt. \(err.debugDescription)")
        }
    }
    
    @IBAction func didTapKickCashDrawer(_ sender: Any) {
        self.kickCashDrawer(success:{
            print("successfully kicked cash drawer")
        }) { (err) in
            print("failed to kick cash drawer. \(err.debugDescription)")
        }
    }
    
    // helpers
    func searchPrinters() -> [PortInfo] {
        do {
            guard let ports = try SMPort.searchPrinter(target: "ALL:") as? [PortInfo] else {
                return []
            }
            return ports
            
        } catch {
            print("Failed to search printers")
            return []
        }
    }
    
    func printTestReceipt(success: @escaping SuccessCallback, error: @escaping ErrorCallback) {
        guard let receipt = UIImage(named: "receipt.jpg") else {
            print("failed to get receipt")
            return
        }
        
        // build commands
        let builder = StarIoExt.createCommandBuilder(self.emulation)
        builder?.beginDocument()
        builder?.appendBitmap(receipt, diffusion: false)
        builder?.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)
        builder?.endDocument()
        
        // send commands
        let commands = builder?.commands.copy() as! Data
        sendCommands(commands, success, error)
    }
    
    func sendCommands(_ commands: Data,_ success: @escaping SuccessCallback,_ error: @escaping ErrorCallback) {
        self.starIoExtManager.lock.lock()
        
        serialQueue.async {
            if self.starIoExtManager.port == nil {
                print("port is nil")
            }
            
            print("port is \(String(describing: self.starIoExtManager.port))")

            _ = StarCommunicationUtils.sendCommands(commands, port: self.starIoExtManager.port) { result in
                if result.result == Result.success {
                    success()
                } else {
                    let e = self.extractError(result)
                    error(e)
                }
                self.starIoExtManager.lock.unlock()
            }
        }
    }
    
    func kickCashDrawer(success: @escaping SuccessCallback, error: @escaping ErrorCallback) {
        // build commands
        let builder = StarIoExt.createCommandBuilder(emulation)
        builder?.appendPeripheral(SCBPeripheralChannel.no1)
        
        // send commands
        let commands = (builder!.commands.copy() as! NSData) as Data
        sendCommands(commands, success, error)
    }
    
    func extractError(_ result: CommunicationResult) -> NSError {
        return NSError(domain: "StarPrinterError", code: result.code, userInfo: [
            NSLocalizedDescriptionKey :  NSLocalizedString(
                "StarPrinterError",
                value: "\(result.code)",
                comment: ""
            ),
            NSLocalizedFailureReasonErrorKey : NSLocalizedString(
                "StarPrinterError",
                value: "\(result.code)",
                comment: ""
            )
            ])
    }
}

extension PrinterViewController {
    func didBarcodeReaderConnect(_ manager: StarIoExtManager!) {
        print("Star BT Barcode Reader: \(String(describing: self.name)) is connected")
        NotificationCenter.default.post(name: NSNotification.Name("scannerConnected"),
                                        object: self.name,
                                        userInfo: nil)
    }
    
    func didBarcodeReaderDisconnect(_ manager: StarIoExtManager!) {
        print("Star BT Barcode Reader: \(String(describing: self.name)) is disconnected")
        NotificationCenter.default.post(name: NSNotification.Name("scannerDisconnected"),
                                        object: self.name,
                                        userInfo: nil)
    }
    
    func didBarcodeDataReceive(_ manager: StarIoExtManager!, data: Data!) {
        guard let scanData = String(data: data, encoding: .ascii)?
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "") else {
                print("Star BT Barcode Reader: Failed to decode scanned data")
                return
        }
        
        print("Star BT Barcode Reader: Scanned Item \(scanData)")
        NotificationCenter.default.post(name: NSNotification.Name("scannedItem"),
                                        object: nil,
                                        userInfo: ["item": scanData])
    }
    
    func didBarcodeReaderImpossible(_ manager: StarIoExtManager!) {
        print("Star BT Barcode Reader: Unable to read the barcode")
    }
}
