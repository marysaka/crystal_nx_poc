module IPC
  # Represent a [A/B/W ("Send"/"Receive"/"Exchange") buffer descriptor](http://switchbrew.org/index.php?title=IPC_Marshalling#Buffer_descriptor_A.2FB.2FW_.22Send.22.2F.22Receive.22.2F.22Exchange.22).
  # NOTE: A reply must not use A/B/W. svcReplyAndReceive will return 0xE801 in this case.
  struct Buffer
    # Represent the flags applied to a buffer descriptor.
    enum Type : UInt32
      # Device mapping *not* allowed for source or destination.
      Normal,
      # Device mapping allowed for source or destination.
      Type1,
      # Device mapping allowed only for source.
      Type2 = 3_u32
    end

    enum Direction : UInt32
      # Buffer is sent from source process into service process.
      # NOTE: Also known as buffer **A** or buffer type **0x5**.
      Send,
      # Data is copied from service process into user process.
      # NOTE: Also known as buffer **B** or buffer type **0x6**.
      Receive,
      # Same as `Send` and `Receive`.
      # NOTE: Also known as buffer **W**.
      # NOTE: This buffer hasn't been observed before.
      Exchange
    end

    def initialize(@direction : Buffer::Direction, @type : Buffer::Type, @address : Void*, @size : UInt64)
    end

    def address
      @address
    end

    def type
      @type
    end

    def size
      @size
    end

    def direction
      @direction
    end

    def self.unpack(buffer : UInt32*, buffer_direction : Buffer::Direction) : Buffer
      size = buffer[0]
      packed = buffer[2]
      address = (buffer[1].to_u64 | ((packed >> 28) << 32) | (((packed >> 2) & 15) << 36))
      buffer_type = Buffer::Type.new(packed & 3)

      Buffer.new(buffer_direction, buffer_type, Pointer(Void).new(address), size.to_u64)
    end

    def pack(buffer : UInt32*) : UInt32
      buffer_address = @address.address
      # lower 32 bits of the size
      buffer[0] = @size.to_u32
      # lower 32 bits of the address
      buffer[1] = buffer_address.to_u32

      # packed
      #         0-1 = flags (0, 1, 3)
      #         4-2 + 31-28 = highter bits of the address (38-36, 35-32)
      #         31-16 = highter bits of size
      # FIXME: is 31-16 required?
      buffer[2] = @type.value | (((buffer_address >> 32) & 15) << 28) | ((buffer_address >> 36) << 2)
      3u32
    end
  end
end
