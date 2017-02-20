# MPEGTS Segmenter
* Generates a ts stream from a media file (using [ffmpeg](https://ffmpeg.org/)).
* The ts stream is split into chunks in order to achieve parallelism. Each chunk contains several HLS segments
* Generates an m3u8 file, or uses a pre-existing one.
* The HLS segments are defined in the m3u8 file by byteranges and are aligned on key-frames in the ts stream.
* Created for fast 'on demand' conversion: ts stream generation and key-frame detection without decoding the media streams.

### Use case
The mpegts segmenter has been developed and tested for the following use case:
* mp4 files containing `h264` video and `aac` audio.
* ts chunks and m3u8 file are posted to an object store and served via http.
* the byteranges in the m3u8 file translate to http range requests, which are supported natively by the object store. Hence the hls fragments are served directly to the player by a simple web server.
* the m3u8 file and the first chunk (approx. the first 30 seconds of the media file) are retained for a long time. The remaing chunks have a shorter retention and are regenerated when needed.

### Example

Convert a file on the local filestsem (./video.mp4) to a set of mpegts chunks and generate an m3u8 file: 

```ruby
require_relative 'lib/tsstream'

def save(name)
    puts name
    basename = File.dirname name
    ts = TSStream.new name
    threads = []
    while ts.nextchunk do
        chunkname = ts.chunk_name
        chunkdata = ts.chunk_payload
        threads << Thread.new do 
            puts "writing #{chunkname}"
            File.write "#{basename}/#{chunkname}", chunkdata
        end
    end
    threads.each { |t| t.join  }

    File.write "#{name}.m3u8", ts.playlist

end

save "./video.mp4"
```
This creates the files: video.mp4.m3u8, video.ts.0, video.ts.1, ....

video.mp4.m3u8 contains the m3u8 playlist:
```
#EXTM3U
#EXT-X-VERSION:4
#EXT-X-TARGETDURATION:7.68
#EXT-X-MEDIA-SEQUENCE:0
#DURATION:254.96

#EXTINF:5.68,
#EXT-X-BYTERANGE:1147928@0
video.ts.0

#EXTINF:4.36,
#EXT-X-BYTERANGE:1428236
video.ts.0

#EXTINF:7.24,
#EXT-X-BYTERANGE:1336868
video.ts.0

#EXTINF:4.0,
#EXT-X-BYTERANGE:1176692
video.ts.0

#EXTINF:6.0,
#EXT-X-BYTERANGE:1338372
video.ts.0

#EXTINF:5.2,
#EXT-X-BYTERANGE:1168044
video.ts.0

#EXTINF:5.64,
#EXT-X-BYTERANGE:1181392@0
video.ts.1

#EXTINF:5.0,
#EXT-X-BYTERANGE:1240236
video.ts.1
...
```
Play the playlist, for example using [mpv](https://mpv.io/):

```
$ mpv --msg-level=ffmpeg/demuxer=v ./video.mp4.m3u8
Playing: video.mp4.m3u8
[ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.0', offset 0, playlist 0
 (+) Video --vid=1 (h264)
  (+) Audio --aid=1 (aac)
  AO: [pulse] 44100Hz stereo 2ch float
  VO: [opengl] 640x480 yuv420p
  AV: 00:00:04 / 00:04:14 (1%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.0', offset 1147928, playlist 0
  AV: 00:00:08 / 00:04:14 (3%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.0', offset 2576164, playlist 0
  AV: 00:00:15 / 00:04:14 (6%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.0', offset 3913032, playlist 0
  AV: 00:00:19 / 00:04:14 (7%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.0', offset 5089724, playlist 0
  AV: 00:00:25 / 00:04:14 (10%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.0', offset 6428096, playlist 0
  AV: 00:00:31 / 00:04:14 (12%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.1', offset 0, playlist 0
  AV: 00:00:36 / 00:04:14 (14%) A-V:  0.000
  [ffmpeg/demuxer] hls,applehttp: HLS request for url 'video.ts.1', offset 1181392, playlist 0
  AV: 00:00:41 / 00:04:14 (16%) A-V:  0.000
  ...
```
