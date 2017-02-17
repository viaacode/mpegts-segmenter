module TS_segemter_helper
    def m3u8_chunk_sizes(m3u8)
        segment_sizes = []
        byterange = 0
        StringIO.new(m3u8).each("\n") do |line|
            case line 
            when /^#EXT-X-BYTERANGE:(\d+)/
                byterange = $1.to_i
            when /^[^#].*\.ts\.(\d+)/
                i = $1.to_i
                segment_sizes[i] ||= 0
                segment_sizes[i] += byterange 
            end
        end
        segment_sizes
    end

    def m3u8_playlist
<<eos
#EXTM3U
#EXT-X-VERSION:4
#EXT-X-TARGETDURATION:5.0
#EXT-X-MEDIA-SEQUENCE:0
#DURATION:29.99

#EXTINF:5.0,
#EXT-X-BYTERANGE:428828@0
browse.ts.0

#EXTINF:3.5,
#EXT-X-BYTERANGE:416608
browse.ts.0

#EXTINF:3.0,
#EXT-X-BYTERANGE:381452@0
browse.ts.1

#EXTINF:3.0,
#EXT-X-BYTERANGE:429016
browse.ts.1

#EXTINF:3.5,
#EXT-X-BYTERANGE:436160
browse.ts.1

#EXTINF:4.0,
#EXT-X-BYTERANGE:416796@0
browse.ts.2

#EXTINF:3.5,
#EXT-X-BYTERANGE:429204
browse.ts.2

#EXTINF:3.0,
#EXT-X-BYTERANGE:432212
browse.ts.2

#EXTINF:1.49,
#EXT-X-BYTERANGE:224472@0
browse.ts.3

#EXT-X-ENDLIST
eos
    end
    def stub_ts_parameters
        stub_const 'TSStream::FRAG_SIZE_TARGET', 2000 * 188
        stub_const 'TSStream::FIRSTCHUNK_SIZE_TARGET', 2000 * 188 * 2
        stub_const 'TSStream::CHUNK_SIZE_TARGET', 2000 * 188 * 3
    end
end
