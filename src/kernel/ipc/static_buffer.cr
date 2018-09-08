module IPC
  # This is the abstract representation a static buffer descriptor ([X](http://switchbrew.org/index.php?title=IPC_Marshalling#Buffer_descriptor_X_.22Pointer.22) / [C](http://switchbrew.org/index.php?title=IPC_Marshalling#Buffer_descriptor_C_.22ReceiveList.22)).
  abstract struct StaticBuffer
    def initialize(@address : Void*, @size : UInt64, @counter : UInt8)
    end

    def address
      @address
    end

    def size
      @size
    end

    def counter
      @counter
    end
  end

  # Represent a ["Pointer" buffer descriptor](http://switchbrew.org/index.php?title=IPC_Marshalling#Buffer_descriptor_X_.22Pointer.22).
  # NOTE: Also known as buffer **X** or buffer type **0x9**.
  struct PointerBuffer < StaticBuffer
    def self.unpack(buffer : UInt32*) : PointerBuffer
      packed = buffer[0]

      address = (buffer[1].to_u64 | (((packed >> 12) & 15) << 32) | (((packed >> 6) & 15) << 36))
      size = packed >> 16
      counter = packed & 63
      PointerBuffer.new(Pointer(Void).new(address), size.to_u64, counter.to_u8)
    end

    def pack(buffer : UInt32*) : UInt32
      ptr = @address.address
      # packed:
      #        5-0 + 11-9 = counter
      #        8-6 + 15-12  = highter bits of the address (38-36, 35-32)
      buffer[0] = @counter.to_u32 | (@size << 16) | (((ptr >> 32) & 15) << 12) | (((ptr >> 36) & 15) << 6)

      # lower 32 bits of the address
      buffer[1] = ptr.to_u32
      2u32
    end
  end

  # Represent a ["ReceiveList" buffer descriptor](http://switchbrew.org/index.php?title=IPC_Marshalling#Buffer_descriptor_C_.22ReceiveList.22).
  # NOTE: Also known as buffer **C** or buffer type **0x1A**.
  struct ReceiveListBuffer < StaticBuffer
    def pack(buffer : UInt32*) : UInt32
      c_address = @address.address

      # lower 32 bits of address
      buffer[0] = c_address.to_u32
      # packed
      #         15-0 = rest of the address
      #         31-16 = size
      buffer[1] = (c_address >> 32).to_u32 | (@size << 16)
      2u32
    end

    def pack_size(buffer : UInt16*)
      buffer[0] = (@size > 0xFFFF) ? 0u16 : @size.to_u16
    end
  end
end
