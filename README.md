# AVCacheSupport
AVPlayer 支持缓存播放

支持 iOS 8 以上，使用NSURLSession 对AVPlayer数据进行加载；

只需要导入头文件 AVPlayerItem+WGCacheSupport.h 即可使用

通过接口实现对视频资源的加载播放
+ (AVPlayerItem *)wg_playerItemWithURL:(NSURL *)URL;

实现了对播放数据的缓存，并且支持本地URL。

有问题欢迎提问。

