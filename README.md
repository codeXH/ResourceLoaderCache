# ResourceLoaderCache

ResourceLoading and cache written in Swift.

Cache media file while play media using AVPlayerr.

Use AVAssetResourceLoader to control AVPlayer download media data.

## CocoaPods
```
pod 'ResourceLoaderCache'
```

## Usage - Swift

```
let videoLoader = ResourceLoaderManager()
playerItem = videoLoader?.playerItem(with: url)
player.replaceCurrentItem(with: playerItem)
```

## Contact
wo18919029008@163.com

## License
MIT
