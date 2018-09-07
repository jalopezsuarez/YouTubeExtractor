# YouTubeExtractor
YoutubeExtractor is a Swift4 library to extract the download link from YouTube videos, download them and/or play.


## Usage Example

Usage Example:

```
https://www.youtube.com/watch?v=bJjQs9NJ0Ho
```

```swift
YouTubeExtractor.instance.info(id: "bJjQs9NJ0Ho", quality: .HD720, completion: { url in                    
  print(url?.absoluteString)
})
```

```
https://r7---sn-w511uxa-n89l.googlevideo.com/videoplayback?ei=Y72SW4fpFYKQVZ75o7AG&requiressl=yes&itag=22&mt=1536343305&ip=37.132.187.47&ratebypass=yes&lmt=1509506162723984&sparams=dur%2Cei%2Cid%2Cinitcwndbps%2Cip%2Cipbits%2Citag%2Clmt%2Cmime%2Cmm%2Cmn%2Cms%2Cmv%2Cpl%2Cratebypass%2Crequiressl%2Csource%2Cexpire&expire=1536364995&ms=au%2Crdu&initcwndbps=895000&ipbits=0&pl=24&mv=m&mm=31%2C29&fvip=3&source=youtube&c=WEB&id=o-AMF5LjPfE_X4qBiWc_al8CFnGIO6IKUz4nt3cZltvxxW&dur=1822.627&mn=sn-w511uxa-n89l%2Csn-h5q7dnez&mime=video%2Fmp4&key=yt6&signature=3A560F018E494A5E3071F8E9D185382A47929B7E.1BCFD20911A0B06C73CD6DEFF75C492A8C07BD5D
```
