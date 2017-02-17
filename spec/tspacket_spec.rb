require_relative '../tspacket'
require_relative 'helpers/tsproperties'

describe TSPacket do

    before :all do
        @ts = TsProperties.new
    end

    context 'packet with video data in the middle of a frame' do
        subject { TSPacket.new @ts.videodataframe }
        it { is_expected.not_to be_rac }
        it { is_expected.not_to be_video_pes }
        it 'pts_time returns nil' do 
            expect(subject.pts_time).to be_nil
        end
    end

    context 'unaligned packets' do
        before :all do
            @packets = []
            file = File.open('spec/fixtures/BigBuckBunny_320x180.ts','rb')
            file.read 1
            while packet = file.read(188)
                @packets <<
                begin
                    TSPacket.new packet
                rescue RuntimeError => e
                    e
                end
            end
           file.close
        end

        it 'fails on unaligned packets' do
            expect(@packets.select { |x| RuntimeError === x }).to eq @packets
        end
    end

    context "with the test ts file" do
       before :all do
           file = File.open('spec/fixtures/BigBuckBunny_320x180.ts','rb')
           pos = -188
           @videopesframes = []
           @videokeyframes = []
           while packet=file.read(188) do
               pos += 188
               pack = TSPacket.new(packet)
               frameinfo = [ pos, sprintf('%.6f',pack.pts_time||0)]
               @videopesframes << frameinfo if pack.video_pes?
               @videokeyframes << frameinfo if pack.rac? && pack.video_pes?
           end
           file.close
       end

       it 'identifies all pes video packets with a correct pos and pts_time' do
           expect(@videopesframes).to eq @ts.videopesframes
       end
       it 'identifes the packets containing a key frame' do
           expect(@videokeyframes).to eq @ts.videokeyframes
       end
   end
end
