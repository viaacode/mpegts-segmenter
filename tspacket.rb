class TSPacket

    attr_reader :packet, :adaptation_field_control

    def initialize(packet)
        raise unless packet[0].ord == 0x47 #mpeg ts sync byte
        @packet = packet
        @adaptation_field_control = (@packet[3].ord & 0b00110000) >> 4
        @pes_offset = @adaptation_field_control < 2 ? 4 : 4 + @packet[4].ord + 1
    end

    def pusi?
        (@packet[1].ord & 0x40) == 0x40 
    end

    def pes_start?
        return false unless pusi?
        # PES start sequence
        @packet[@pes_offset].ord == 0 && @packet[@pes_offset+1].ord == 0 &&
           @packet[@pes_offset+2].ord == 1    # PES start sequence
    end

    def video_pes?
        pes_start? && (0xe0..0xef) === @packet[@pes_offset+3].ord
    end

    def rac?
        # check afc first, if no afc, then certainly no rac
        @adaptation_field_control > 1 && (@packet[5].ord & 0x40) == 0x40
    end

    def pts_time
        # The MPEG2 transport stream clocks have units of 1/90000 second.
        # The PTS is a 33 bit value with three marker bits expanded into 5 bytes
        # The pattern is (from most to least significant bit):
        # 3 bits, marker, 15 bits, marker, 15 bits, marker.
        # The markers must be equal to 1.
        # | byte 1 | byte 2 | byte 3 | byte 4 | byte 5 |
        #  ....xxx1 xxxxxxxx xxxxxxx1 xxxxxxxx xxxxxxx1
        
        # packet without a pes start sequence does not contain a pts_time
        return nil unless pes_start?
        # check the marker bits
        markerbit = @packet[@pes_offset + 9].ord &
            @packet[@pes_offset + 11].ord &
            @packet[@pes_offset + 13].ord & 0b00000001 
        return nil unless markerbit == 1
        
        # byte 1 (3 bits)
        pts = (@packet[@pes_offset + 9].ord & 0b00001110) << 29
        # byte 2 (8 bits)
        pts = pts | (@packet[@pes_offset + 10].ord << 22)
        # byte 3 (7 bits)
        pts = pts | ((@packet[@pes_offset + 11].ord & 0b11111110) << 14)
        # byte 4 (8 bits)
        pts = pts | (@packet[@pes_offset + 12].ord << 7)
        # byte 5 (7 bits)
        pts = pts | (@packet[@pes_offset + 13].ord >> 1)
        pts/90000.0
    end

end
