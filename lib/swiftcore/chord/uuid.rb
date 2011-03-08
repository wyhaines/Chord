module Swiftcore
  class Chord
    class UUID
      Epoch = 0x01B21DD213814000
      TimeFormat = "%08x-%04x-%04x"
      RandHigh = 1 << 128

      @seq = (Time.now.to_i * rand(2 << 128)).to_s(16)

      def self.generate
        now = Time.now
        # Turn the time into a very large integer.
        time = (now.to_i * 10_000_000) + (now.tv_usec * 10) + Epoch

        # Now break that integer into three chunks.
        t1 = time & 0xFFFF_FFFF
        t2 = time >> 32
        t2 = t2 & 0xFFFF
        t3 = time >> 48
        t3 = t3 & 0b0000_1111_1111_1111
        t3 = t3 | 0b0001_0000_0000_0000

        time_string = TimeFormat % [t1, t2, t3]
        arg_string  = Digest::SHA1.hexdigest(@seq.succ!)
        "#{time_string}-#{arg_string}-#{rand(RandHigh).to_s(16)}"
      end
    end
  end
end