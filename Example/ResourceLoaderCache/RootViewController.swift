//
//  RootViewController.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/7/16.
//

import UIKit

class RootViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "视频类型"
    }
    
    var urls = [ "http://vfx.mtime.cn/Video/2019/02/04/mp4/190204084208765161.mp4",
                 "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4",
                 "http://220.249.115.46:18080/wav/Lovey_Dovey.mp4",
                 // 不支持随机访问，只能顺序播放，seek 时需要等待前面的下载完成才行
                 "http://220.249.115.46:18080/wav/day_by_day.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/21/mp4/190321153853126488.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/19/mp4/190319222227698228.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/19/mp4/190319212559089721.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/18/mp4/190318231014076505.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/18/mp4/190318214226685784.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/19/mp4/190319104618910544.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/19/mp4/190319125415785691.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/17/mp4/190317150237409904.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/14/mp4/190314223540373995.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/14/mp4/190314102306987969.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/13/mp4/190313094901111138.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/12/mp4/190312143927981075.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/12/mp4/190312083533415853.mp4",
                 "http://vfx.mtime.cn/Video/2019/03/09/mp4/190309153658147087.mp4"]
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urls.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.textLabel?.text = "\(indexPath.row)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = URL(string: urls[indexPath.row])
        
        let vc = ViewController()
        vc.url = url
        navigationController?.pushViewController(vc, animated: true)
    }
}
