require_relative 'helpers/m3u8'
require_relative '../tsstream.rb'
require_relative 'helpers/tsproperties'
include TS_segemter_helper

describe TSStream do
    before :all do
        @exp_playlist = m3u8_playlist
        @exp_chunk_sizes = m3u8_chunk_sizes(@exp_playlist)
    end
    before :each do
        stub_ts_parameters
    end
    let (:ts_stream) do
        File.open 'spec/fixtures/BigBuckBunny_320x180.ts', 'rb'
    end

    before :each do
        allow(Process).to receive(:wait)
        expect(IO).to receive(:popen)
        .with(/.*ffmpeg -y -i browse.ts -c copy -f mpegts pipe:1 <\/dev\/null 2>>.*/) {
            ts_stream
        }
    end

    shared_examples 'segmented mpegts stream' do
        before :each do
            @sizes = []
            @stream = []
            while subject.nextchunk do
                @stream << subject.data
                @sizes << subject.data.length
            end
        end

        it 'concatenation of the chunks matches the originbal stream' do
            expect(@stream.join).to eq IO.binread 'spec/fixtures/BigBuckBunny_320x180.ts'
        end

        it 'chunk sizes match the sum of byteranges in the playlist' do
            expect(@sizes).to eq @exp_chunk_sizes
        end

        it 'every chunk starts with a keyframe' do
            rac = @stream.drop(1).map {|x| TSPacket.new(x).rac?}
            expect(rac.select { |x| x != true } ).to be_empty
        end
    end

    context 'with a defined playlist' do
        subject { TSStream.new('browse.ts',@exp_playlist) }
        it_behaves_like 'segmented mpegts stream' 
    end

    context 'without a playlist' do
        before :all do
            @ts = TsProperties.new
        end
        subject { TSStream.new('browse.ts') }

        it_behaves_like 'segmented mpegts stream' 

        it 'creates an m3u8 playlist' do
            nil while subject.nextchunk 
            expect(subject.playlist).to eq @exp_playlist
        end
        it 'sets the initial and the final timestamp' do
            expect(TsProperties.f2pts(subject.time)).to eq @ts.initial_timestamp
            nil while subject.nextchunk 
            expect(TsProperties.f2pts(subject.time)).to eq @ts.final_timestamp
        end
    end

end
