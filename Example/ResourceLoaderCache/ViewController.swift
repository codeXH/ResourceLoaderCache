//
//  ViewController.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/12.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let playerView = PlayerView(frame: view.bounds)
        playerView.backgroundColor = .black
        view.addSubview(playerView)
        view.backgroundColor = .white
        
        if let url = url {
            playerView.setPlayerSourceUrl(url: url)
        }
    }
}
