//
//  StatsView.swift
//  PHP Monitor
//
//  Created by Nico Verbruggen on 04/02/2021.
//  Copyright © 2021 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa

/**
 The ServicesView is an example of a view that I consider to be "poorly" set up.
 Why ship it like this, then? Well, it works — that's reason number one, really.
 
 However, I do believe this should be refactored at some point. Here's why:
 this view is responsible for retaining the information about the services status.
 
 The status of the services should live somewhere else, and the fetching of said
 service information should also not happen in a view. Yet here we are.
 */
class ServicesView: NSView, XibLoadable {
    
    @IBOutlet weak var imageViewPhp: NSImageView!
    @IBOutlet weak var imageViewNginx: NSImageView!
    @IBOutlet weak var imageViewDnsmasq: NSImageView!
    
    @IBOutlet weak var textFieldPhp: NSTextField!
    
    static var services: [String: HomebrewService] = [:]
    
    static func asMenuItem() -> NSMenuItem {
        let view = Self.createFromXib()!
        [view.imageViewPhp, view.imageViewNginx, view.imageViewDnsmasq].forEach { imageView in
            imageView?.contentTintColor = NSColor(named: "IconColorNormal")
        }
        let item = NSMenuItem()
        item.view = view
        item.target = self
        NotificationCenter.default.addObserver(
            view, selector: #selector(self.updateInformation),
            name: Events.ServicesUpdated,
            object: nil
        )
        return item
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        self.loadData()
    }

    @objc func updateInformation() {
        self.loadData()
    }
    
    // TODO: (5.1) Move data fetching, caching & retrieval somewhere else
    func loadData() {
        // Use stale data
        self.applyAllInfoFieldsFromCachedValue()
        
        // Re-fetch services
        runAsync {
            let servicesList = try! JSONDecoder().decode(
                [HomebrewService].self,
                from: Shell.pipe(
                    "sudo \(Paths.brew) services info --all --json",
                    requiresPath: true
                ).data(using: .utf8)!
            ).filter({ service in
                return [PhpEnv.phpInstall.formula, "nginx", "dnsmasq"].contains(service.name)
            })
            
            ServicesView.services = Dictionary(uniqueKeysWithValues: servicesList.map{ ($0.name, $0) })
        } completion: {
            // Use fresh data
            self.applyAllInfoFieldsFromCachedValue()
        }
    }
    
    func applyAllInfoFieldsFromCachedValue() {
        if ServicesView.services.keys.isEmpty {
            return
        }
        
        DispatchQueue.main.async {
            self.textFieldPhp.stringValue = PhpEnv.phpInstall.formula.uppercased()
            self.applyServiceStyling(PhpEnv.phpInstall.formula, self.imageViewPhp)
            self.applyServiceStyling("nginx", self.imageViewNginx)
            self.applyServiceStyling("dnsmasq", self.imageViewDnsmasq)
        }
    }
    
    func applyServiceStyling(_ serviceName: String, _ imageView: NSImageView) {
        if ServicesView.services[serviceName] == nil {
            imageView.image = NSImage(named: "ServiceLoading")
            imageView.contentTintColor = NSColor(named: "IconColorNormal")
            return
        }
        
        if ServicesView.services[serviceName]!.running {
            imageView.image = NSImage(named: "ServiceOn")
            imageView.contentTintColor = NSColor(named: "IconColorNormal")
            return
        }
        
        imageView.image = NSImage(named: "ServiceOff")
        imageView.contentTintColor = NSColor(named: "IconColorRed")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Events.ServicesUpdated, object: nil)
    }
}
