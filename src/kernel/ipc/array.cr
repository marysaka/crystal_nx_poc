module IPC
  struct HandleArray(N)
    @buffer : StaticArray(IPC::Handle, N)
    @size = 0u64

    def initialize
      @buffer = uninitialized StaticArray(IPC::Handle, N)
    end

    @[AlwaysInline]
    def [](index : Int)
      @buffer[index]
    end

    def filter_by_type(handle_type : IPC::Handle::Type)
      @size.times do |i|
        handle = @buffer[i]
        if handle.type == handle_type
          yield handle
        end
      end
    end

    def copy_count
      res = 0u64
      filter_by_type IPC::Handle::Type::Copy do |handle|
        res += 1
      end
      res
    end

    def move_count
      res = 0u64
      filter_by_type IPC::Handle::Type::Move do |handle|
        res += 1
      end
      res
    end

    def push(value : IPC::Handle)
      # FIXME: SIZE CHECK
      @buffer[@size] = value
      @size += 1
      self
    end
  end

  struct BufferArray(N)
    @buffer : StaticArray(Buffer, N)
    @size = 0u64

    def initialize
      @buffer = uninitialized StaticArray(Buffer, N)
    end

    def size
      @size
    end

    def send_count
      res = 0u64
      filter_by_direction Buffer::Direction::Send do |buffer|
        res += 1
      end
      res
    end

    def recv_count
      res = 0u64
      filter_by_direction Buffer::Direction::Receive do |buffer|
        res += 1
      end
      res
    end

    def exch_count
      res = 0u64
      filter_by_direction Buffer::Direction::Exchange do |buffer|
        res += 1
      end
      res
    end

    def filter_by_direction(direction : Buffer::Direction)
      @size.times do |i|
        buffer = @buffer[i]
        if buffer.direction == direction
          yield buffer
        end
      end
    end

    def push(value : Buffer)
      # FIXME: SIZE CHECK
      @buffer[@size] = value
      @size += 1
      self
    end
  end
end
