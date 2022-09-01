//
//  PlayerView.swift
//  CJPlayer
//
//  Created by Itanotomomi on 4.3.21.
//

import UIKit
import SnapKit
import Foundation
import AVFoundation
import MobileCoreServices
import ResourceLoaderCache

//: 有播放器 ✓
//: 有 loading ✓
//: 有播放时间和总时间 - 需要监听时间变化 ✓
//: 有进度条 - 可滑动 ✓
//: 有播放按钮 / 暂停按钮 - 需要监听播放状态 ✓
open class PlayerView: UIView {
    
    // 播放器
    private var player = AVPlayer(playerItem: nil)
    private var playerItem: AVPlayerItem?
    private var playerLayer = AVPlayerLayer()
    
    // 播放设置
    private var timeObserver: Any? // 视频播放时间监听
    private var sliding = false // 是否正在滑动
    private var isPlayEnd = false  // 是否播放完成
    private var videoReadyToPlay: Bool = false // 视频是否已准备播放
    private var autoPlay = false
    
    // UI
    private var loadingIndicator = PlayerLoading()
    private lazy var timeSlider: PlayerSlider = {
        let slider = PlayerSlider(frame: .zero)
        slider.addTarget(self, action: #selector(sliderTouchDown(slider:)), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderTouchEnd(slider:)), for: .touchCancel)
        slider.addTarget(self, action: #selector(sliderTouchEnd(slider:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(sliderTouchEnd(slider:)), for: .touchUpOutside)
        slider.addTarget(self, action: #selector(sliderValueChanged(slider:)), for: .valueChanged)
        return slider
    }()
    
    private lazy var currentTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = .white
        label.text = formatPlayTime(seconds: 0)
        return label
    }()
    
    private lazy var totalTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = .white
        label.text = formatPlayTime(seconds: 0)
        return label
    }()
    
    public lazy var playerBtn: UIButton = {
        let play = UIButton(type: .custom)
        play.setImage(UIImage(named: "play"), for: .normal)
        play.addTarget(self, action: #selector(didClickOnPlayBtn(sender:)), for: .touchUpInside)
        return play
    }()
    
    /// 边下边播的代理
    private var videoLoader: ResourceLoaderManager?
    
    // MARK: - init and deinit
    public init(frame: CGRect, videoGravity: AVLayerVideoGravity = .resizeAspect) {
    
        super.init(frame: frame)
        self.playerLayer.frame = layer.bounds
        self.playerLayer.videoGravity = videoGravity
        self.layer.addSublayer(self.playerLayer)
        layer.insertSublayer(self.playerLayer, at: 0)
        self.playerLayer.player = self.player
        
        setup()
        notify()
    }
    
    /// 视频播放方法
    /// - Parameter url: url
    public func setPlayerSourceUrl(url: URL) {
        
        videoLoader = ResourceLoaderManager()
        // videoLoader?.cleanCache()
        
        if playerItem != nil {
            playerItem?.removeObserver(self, forKeyPath: "status")
        }
        
        playerItem = videoLoader?.playerItem(with: url)
        playerItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        player.addObserver(self, forKeyPath: "timeControlStatus", options: .new, context: nil)
        
        player.replaceCurrentItem(with: playerItem)
        playerLayer.player = player
        
        addProgressObserver()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        addSubview(playerBtn)
        playerBtn.snp.makeConstraints { make in
            make.center.equalTo(self)
            make.width.height.equalTo(104)
        }
        
        addSubview(currentTimeLabel)
        currentTimeLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-40)
            make.left.equalTo(10)
            make.width.equalTo(40)
        }
        
        addSubview(totalTimeLabel)
        totalTimeLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-40)
            make.right.equalToSuperview().offset(-10)
            make.width.equalTo(40)
        }
        
        addSubview(timeSlider)
        timeSlider.snp.remakeConstraints { make in
            make.left.equalTo(currentTimeLabel.snp.right).offset(10)
            make.height.equalTo(25)
            make.centerY.equalTo(currentTimeLabel.snp.centerY)
            make.right.equalTo(totalTimeLabel.snp.left).offset(-10)
        }
        
        addSubview(loadingIndicator)
        loadingIndicator.snp.makeConstraints { make in
            make.width.height.equalTo(50)
            make.center.equalToSuperview()
        }
        loadingIndicator.startAnimating()
    }
    
    func notify() {
        NotificationCenter.default.addObserver(self, selector: #selector(enterBack), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForground), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForground), name: .CacheManagerDidUpdateCache, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForground), name: .CacheManagerDidFinishCache, object: nil)
    }
    
    deinit {
        pause()
        videoLoader?.cancleLoaders()
        playerItem?.removeObserver(self, forKeyPath: "status")
        
        NotificationCenter.default.removeObserver(self)
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        log("CJPlayer deinit")
    }
    
    // MARK: - 点击事件
    @objc func didClickOnPlayBtn(sender: UIButton) {
        
        DispatchQueue.main.async {
            if !self.playerBtn.isSelected {
                self.isPlayEnd ? self.replay() : self.play()
                self.playerBtn.isSelected = true
            } else {
                self.pause()
                self.playerBtn.isSelected = false
            }
            
            if self.playerBtn.isSelected {
                UIView.animate(withDuration: 0.35) {
                    self.playerBtn.alpha = 0
                }
            } else {
                self.playerBtn.alpha = 1
            }
        }
    }
    
    /// UISlider结束事件
    @objc private func sliderTouchDown(slider: UISlider) {
        sliding = true
    }
    
    @objc private func sliderTouchEnd(slider: UISlider) {
        sliding = false
        seek(to: slider.value)
    }
    
    /// 进度条改变
    @objc private func sliderValueChanged(slider: UISlider) {
        sliding = true
    }
    
    // MARK: - 视频播放、暂停、重播、速率、静音、指定时间
    /// 播放
    public func play() {
        player.play()
    }
    
    /// 暂停
    public func pause() {
        player.pause()
    }
    
    /// 重播
    public func replay() {
        seek(to: 0)
        play()
    }
    
    /// 静音
    public func muted(_ isMuted: Bool) {
        player.isMuted = isMuted
    }
    
    /// seek 到指定进度
    public func seek(to progress: Float) {
        
        guard progress >= 0, progress <= 1 else { return }
        
        if let totalTime = playerItem?.duration {
            let totalSec = CMTimeGetSeconds(totalTime)
            let playTimeSec = totalSec * Float64(progress)
            let currentTime = CMTime(value: Int64(playTimeSec), timescale: 1)
            player.seek(to: currentTime)
        }
    }
    
    /// 更新时间
    public func update(current: Float, total: Float) {
        
        let currentTimeString = "\(formatPlayTime(seconds: TimeInterval(current)))"
        let totalTimeString = "\(formatPlayTime(seconds: TimeInterval(total)))"
        currentTimeLabel.text = currentTimeString
        totalTimeLabel.text = totalTimeString
        
        if !sliding {
            timeSlider.value = Float(current / total)
        }
        
        if current == total {
            isPlayEnd = true
            DispatchQueue.main.async {
                self.playerBtn.isSelected = false
                self.playerBtn.alpha = 1
            }
        } else {
            isPlayEnd = false
        }
    }
    
    /// 时间
    private func formatPlayTime(seconds: TimeInterval) -> String {
        if seconds.isNaN {
            return "00:00"
        }
        let minit = Int(seconds / 60)
        let sec = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minit, sec)
    }
    
    // MARK: - KVO 监听
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            switch playerItem?.status {
            case .readyToPlay:
                log("readyToPlay")
                videoReadyToPlay = true
                totalTimeLabel.text = formatPlayTime(seconds: TimeInterval(CMTimeGetSeconds(playerItem?.duration ?? CMTime())))
                if autoPlay, !playerBtn.isSelected, !isPlayEnd {
                    didClickOnPlayBtn(sender: playerBtn)
                }
            case .failed:
                log("failed")
                log(playerItem?.error)
            case .unknown:
                log("unknown")
            default: break
            }
        }
        
        if keyPath == "timeControlStatus" {
            if player.timeControlStatus == .playing {
                loadingIndicator.stopAnimating()
            } else {
                loadingIndicator.startAnimating()
            }
        }
    }
    
    /// 添加播放器时间监听
    private func addProgressObserver() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime.init(value: 1, timescale: 1), queue: DispatchQueue.main, using: { [weak self] time in
            let current = CMTimeGetSeconds(time)
            let total = CMTimeGetSeconds(self?.playerItem?.duration ?? CMTime.init())
            self?.update(current: Float(current), total: Float(total))
        })
    }
    
    // MARK: 通知
    @objc private func enterBack() {
        if playerBtn.isSelected {
            didClickOnPlayBtn(sender: playerBtn)
        }
    }
    
    @objc private func enterForground() {
        DispatchQueue.main.async {
            if !self.playerBtn.isSelected {
                self.didClickOnPlayBtn(sender: self.playerBtn)
            }
        }
    }
    
    @objc private func updateCache(notify: Notification) {
        if let dic = notify.userInfo, let configue = dic[CacheConfigurationKey] as? CacheConfiguration {
            log("cached progress = \(configue.progress)")
            log("cached downloadSpeed = \(configue.downloadSpeed ?? 0)")
        }
    }
    
    @objc private func finishedCache(notify: Notification) {
        if let dic = notify.userInfo, let error = dic[CacheFinishedErrorKey] as? MediaCacheError {
            log(error.errorDescription)
        }
    }
}
