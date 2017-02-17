require_relative 'tspacket'
# packet: mpeg transport stream packet (188 bytes)
# segment: HLS segment:
#   - unit of HTTP download
#   - starts with a keyframe
#   - corresponds to one item in the m3u8 playlist
# chunk: part of the mpegts stream, contains multiple segments and is aligned 
#        with the segment boundary

class TSStream

    TS_PKT_SZ = 188  # size of mpeg ts packets
    FFMPEGCMD = '/usr/local/bin/ffmpeg'
    
    # desired number of TS packets in a segment.
    # actual number will vary depending on the postion of the key frames
    FRAG_PKTS_TARGET = 6000

    # Number if segments in the first chunk
    FIRSTCHUNK_SEGMENTS = 6
    # Number of segments in the other chunks
    CHUNK_SEGMENTS = 48

    # desired segment size
    # actual size will vary depending on the postion of the key frames
    FRAG_SIZE_TARGET = FRAG_PKTS_TARGET * TS_PKT_SZ

    # desired size of the first chunk
    FIRSTCHUNK_SIZE_TARGET = FIRSTCHUNK_SEGMENTS * FRAG_SIZE_TARGET
    # desired size of the remaining chunks
    CHUNK_SIZE_TARGET = CHUNK_SEGMENTS * FRAG_SIZE_TARGET

    attr_reader :time, :pos, :data, :playlist, :chunk

    def initialize(name,playlist=nil)
        @name = name.sub(/.*\/(\w*\.)\w*$/, '\1ts')
        @pipe = IO.popen("#{FFMPEGCMD} -y -i #{name} -c copy -f mpegts pipe:1 </dev/null 2>>log/ffmpeg.log")
        @chunkbuffer = ''
        @chunk = -1
        case playlist
        when nil
            initm3u8
        else
            initmpegts playlist
        end
    end

    def initm3u8
        @pos = 0
        @cursor = ''
        @playlistbody = ''
        @targetduration = 0
        # Find the first rac packet and initialize the timestamps
        read_til_next_rac_packet
        @segmenttime = @time
        @starttime = @time
        @segmentpos = 0
    end

    def initmpegts(playlist)
        @playlist = StringIO.new playlist
        @carry = 0
        nextchunksize  # goto the start of first chunk
    end

    def nextchunksize
        bytes = @carry
        @carry = 0 
        while line = @playlist.gets
            next unless /^#EXT-X-BYTERANGE:(\d+)(@0+)?/ =~ line 
            break if $2 # start of new chunk, carry to next chunk on exit
            bytes += $1.to_i
        end
        @carry = $1.to_i if line
        #@chunk += 1
        bytes
    end

    def nextchunk
        @chunk += 1
        case @pos   # are we generating a playlist
        when nil
            @data = @pipe.read(nextchunksize)
        else
            @chunkpos = 0
            @chunkoffset = @pos
            maxchunksize = @chunk == 0 ? FIRSTCHUNK_SIZE_TARGET : CHUNK_SIZE_TARGET
            while @chunkpos < maxchunksize && read_next_segment do
                add_segment_to_playlist
                @chunkpos = @pos - @chunkoffset
            end
            @playlist = header + @playlistbody + footer if @chunkpos < maxchunksize
            @data = @chunkbuffer
            @chunkbuffer = ''
        end
        if @data.length == 0
            Process.wait(@pipe.pid)
            return nil
        end
        @data
    end

    private
    def set_time_to_last_pes_packet
        timestamps = []
        ptr = @chunkbuffer.length - TS_PKT_SZ
        packet = nil
        until packet&.video_pes? || ptr < 0
            packet = TSPacket.new(@chunkbuffer[ptr, TS_PKT_SZ])
            timestamps << packet.pts_time if packet.pes_start?
            ptr -= TS_PKT_SZ
        end
        @time = timestamps.max
    end

    def read_next_packet
        rawpacket = @pipe.read(TS_PKT_SZ)
        return nil unless rawpacket
        @chunkbuffer << @cursor
        @cursor = rawpacket
        TSPacket.new(rawpacket)
    end

    def read_til_next_rac_packet
        packet = read_next_packet or return nil
        while !(packet.video_pes? && packet.rac?) do
            @pos += TS_PKT_SZ
            packet = read_next_packet
            break unless packet
        end
        @time = packet.pts_time
    end

    def add_segment_to_playlist
        pos_delta = @pos - @segmentpos
        time_delta = @time - @segmenttime
        # update the max fragment time if fragment longer than current maximum
        @targetduration = time_delta if time_delta > @targetduration
        @playlistbody+= "\n#EXTINF:#{time_delta.round(2)},\n"
        suffix = @chunkpos == 0 ? '@0' : ''
        @playlistbody += "#EXT-X-BYTERANGE:#{pos_delta}#{suffix}\n" 
        @playlistbody += "#{@name}.#{@chunk}\n"
        @segmentpos = @pos
        @segmenttime = @time
    end

    def read_next_segment
        chunk = @pipe.read(FRAG_SIZE_TARGET)
        return nil unless chunk 
        @chunkbuffer << @cursor << chunk
        @pos += @cursor.length + chunk.length
        @cursor = ''
        read_til_next_rac_packet || set_time_to_last_pes_packet
    end

    def header
        <<-eos
#EXTM3U
#EXT-X-VERSION:4
#EXT-X-TARGETDURATION:#{@targetduration.round(3)}
#EXT-X-MEDIA-SEQUENCE:0
#DURATION:#{(@time - @starttime).round(2)}
        eos
    end

    def footer
        "\n#EXT-X-ENDLIST\n"
    end
end
