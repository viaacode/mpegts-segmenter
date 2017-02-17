class TsProperties
    
# ffprobe -show_frames -of csv -i BigBuckBunny_320x180.ts
# relevant fields:
#  1: media_type
#  3: key_frame
#  5: pkt_pts_time
# 12:pkt_pos: 12
#
    attr_reader :videokeyframes, :videopesframes, :videodataframe, :initial_timestamp, :final_timestamp

    def self.f2pts(timestamp)
        sprintf('%.6f',timestamp)
    end

    def initialize
        file = File.open 'spec/fixtures/BigBuckBunny_320x180.ts.csv','r'
        @pesframes = []
        @videokeyframes = []
        @videopesframes = []
        while frame = file.gets&.split(',') do
            next unless /\d+/ =~ frame[12]     # skip frames without pkt_pos information
            frameinfo = [ frame[12].to_i, frame[5] ]
            @pesframes << frameinfo
            next unless frame[1] == 'video'
            @videopesframes << frameinfo
            @videokeyframes << frameinfo if frame[3] == '1'
        end
        @videodataframe = File.binread('spec/fixtures/BigBuckBunny_320x180.ts',188,videokeyframes[5][0]+188) 
        @initial_timestamp = @pesframes.min { |x,y| x[1].to_f <=> y[1].to_f}[1]
        @final_timestamp = @pesframes.max { |x,y| x[1].to_f <=> y[1].to_f }[1]
    end
end
