struct IpcBuffer
  enum Type : UInt32
    Normal,
    Type1,
    Invalid,
    Type2
  end

  enum Direction : UInt32
    # A
    Send,
    # B
    Receive,
    # W
    Exchange
  end

  def initialize(@direction : IpcBuffer::Direction, @type : IpcBuffer::Type, @address : Void*, @size : UInt64)
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

abstract struct IpcStaticBuffer
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

struct IpcPointerBuffer < IpcStaticBuffer
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

struct IpcReceiveListBuffer < IpcStaticBuffer
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

struct IpcHandle
  enum Type
    Move,
    Copy
  end

  def initialize(@handle : Handle, @type : IpcHandle::Type)
  end

  def value
    @handle
  end

  def type
    @type
  end
end

struct IpcBufferArray(N)
  @buffer : StaticArray(IpcBuffer, N)
  @size = 0u64

  def initialize
    @buffer = uninitialized StaticArray(IpcBuffer, N)
  end

  def size
    @size
  end

  def send_count
    res = 0u64
    filter_by_direction IpcBuffer::Direction::Send do |buffer|
      res += 1
    end
    res
  end

  def recv_count
    res = 0u64
    filter_by_direction IpcBuffer::Direction::Receive do |buffer|
      res += 1
    end
    res
  end

  def exch_count
    res = 0u64
    filter_by_direction IpcBuffer::Direction::Exchange do |buffer|
      res += 1
    end
    res
  end

  def filter_by_direction(direction : IpcBuffer::Direction)
    @size.times do |i|
      buffer = @buffer[i]
      if buffer.direction == direction
        yield buffer
      end
    end
  end

  def push(value : IpcBuffer)
    # FIXME: SIZE CHECK
    @buffer[@size] = value
    @size += 1
    self
  end
end

struct IpcHandleArray(N)
  @buffer : StaticArray(IpcHandle, N)
  @size = 0u64

  def initialize
    @buffer = uninitialized StaticArray(IpcHandle, N)
  end

  @[AlwaysInline]
  def [](index : Int)
    @buffer[index]
  end

  def filter_by_type(handle_type : IpcHandle::Type)
    @size.times do |i|
      handle = @buffer[i]
      if handle.type == handle_type
        yield handle
      end
    end
  end

  def copy_count
    res = 0u64
    filter_by_type IpcHandle::Type::Copy do |handle|
      res += 1
    end
    res
  end

  def move_count
    res = 0u64
    filter_by_type IpcHandle::Type::Move do |handle|
      res += 1
    end
    res
  end

  def push(value : IpcHandle)
    # FIXME: SIZE CHECK
    @buffer[@size] = value
    @size += 1
    self
  end
end

abstract struct IpcCommand
  SFCI_MAGIC = 0x49434653_u64
  SFCO_MAGIC = 0x4f434653_u64
  @magic : UInt64 = SFCI_MAGIC

  def magic
    @magic
  end

  def is_request
    @magic == SFCI_MAGIC
  end

  def is_response
    @magic == SFCO_MAGIC
  end

  def initialize(@id : UInt64)
  end
end

struct IpcRawResponse < IpcCommand
  def response_code
    @id
  end

  def initialize(@id : UInt64)
  end
end

struct IpcMessage
  enum Type : UInt32
    Invalid,
    LegacyRequest,
    Close,
    LegacyControl,
    Request,
    Control,
    RequestWithContext,
    ControlWithContext
  end
  MAX_BUFFERS = 8
  MAX_OBJECTS = 8

  @message_type = IpcMessage::Type::Request
  @send_pid = false
  @pid = 0u64
  @buffers : IpcBufferArray(MAX_BUFFERS)
  @statics_in : SizedStaticArray(IpcPointerBuffer, MAX_BUFFERS)      # X
  @statics_out : SizedStaticArray(IpcReceiveListBuffer, MAX_BUFFERS) # Y
  @handles : IpcHandleArray(MAX_OBJECTS)
  @object_ids_count = 0u64
  @object_ids : SizedStaticArray(Handle, MAX_OBJECTS)

  def set_message_type(message_type : IpcMessage::Type)
    @message_type = message_type
  end

  def send_pid : Void
    @send_pid = true
  end

  def send_handle(handle : Handle, handle_type : IpcHandle::Type) : Void
    @handles.push(IpcHandle.new(handle, handle_type))
  end

  def add_buffer(ipc_buffer : IpcBuffer) : Void
    @buffers.push(ipc_buffer)
  end

  def add_send_buffer(buffer : Void*, buffer_size : UInt64, buffer_type : IpcBuffer::Type = IpcBuffer::Type::Normal) : Void
    add_buffer(IpcBuffer.new(IpcBuffer::Direction::Send, buffer_type, buffer, buffer_size))
  end

  def add_receive_buffer(buffer : Void*, buffer_size : UInt64, buffer_type : IpcBuffer::Type = IpcBuffer::Type::Normal) : Void
    add_buffer(IpcBuffer.new(IpcBuffer::Direction::Receive, buffer_type, buffer, buffer_size))
  end

  def add_exchange_buffer(buffer : Void*, buffer_size : UInt64, buffer_type : IpcBuffer::Type = IpcBuffer::Type::Normal) : Void
    add_buffer(IpcBuffer.new(IpcBuffer::Direction::Exchange, buffer_type, buffer, buffer_size))
  end

  def handles : IpcHandleArray
    @handles
  end

  def pack(raw_struct)
    i = 0
    buffer = get_tls().as(UInt32*)

    # Get all buffers count
    send_count = @buffers.send_count
    recv_count = @buffers.recv_count
    exch_count = @buffers.exch_count
    static_in_count = @statics_in.size
    static_out_count = @statics_out.size
    handles_move_count = @handles.move_count
    handles_copy_count = @handles.copy_count

    buffer[i] = @message_type.value | (static_in_count << 16) | (send_count << 20) | (recv_count << 24) | (exch_count << 28)
    i += 1
    if static_out_count > 0
      # 13-10 (type C count)
      buffer[i] = (static_out_count + 2).to_u32 << 10
    else
      buffer[i] = 0
    end

    # handle descriptor
    if @send_pid || handles_copy_count > 0 || handles_move_count > 0
      # handle descriptor flag
      buffer[i] = buffer[i] | 0x80000000
      i += 1

      pid_enabled = @send_pid ? 1u32 : 0u32
      buffer[i] = pid_enabled | (handles_copy_count << 1) | (handles_move_count << 5)
      i += 1

      if @send_pid
        i += 2
      end

      # copied handles
      @handles.filter_by_type IpcHandle::Type::Copy do |handle|
        buffer[i] = handle.value
        i += 1
      end

      # moved handles
      @handles.filter_by_type IpcHandle::Type::Move do |handle|
        buffer[i] = handle.value
        i += 1
      end
    else
      i += 1
    end

    # X descriptors (packing nighmare)
    static_in_count.times do |index|
      i += @statics_in[index].pack(buffer + i)
    end

    # A descriptors
    @buffers.filter_by_direction IpcBuffer::Direction::Send do |ipc_buffer|
      i += ipc_buffer.pack(buffer + i)
    end

    # B descriptors
    @buffers.filter_by_direction IpcBuffer::Direction::Receive do |ipc_buffer|
      i += ipc_buffer.pack(buffer + i)
    end

    # W descriptors
    @buffers.filter_by_direction IpcBuffer::Direction::Exchange do |ipc_buffer|
      i += ipc_buffer.pack(buffer + i)
    end

    raw_data_start = i
    padding = ((16u64 - ((buffer + i).address & 15u64)) & 15u64) / 4u64

    # copy structure content to raw section
    raw_struct_size = sizeof(typeof(raw_struct))
    raw_size = (raw_struct_size + 3) & ~3

    memcpy((buffer + i + padding).as(UInt8*), pointerof(raw_struct).as(UInt8*), raw_struct_size.to_u64)
    i += raw_size

    buffer_u16 = buffer.as(UInt16*)
    # C descriptor u16 size list
    static_out_count.times do |index|
      @statics_out[index].pack_size(buffer_u16 + i + index)
    end

    c_u16_list_size = ((2 * static_out_count) + 3) / 4

    i += c_u16_list_size
    raw_size += c_u16_list_size

    # update raw size
    buffer[1] = buffer[1] | raw_size

    # C descriptors
    static_out_count.times do |index|
      i += @statics_out[index].pack(buffer + i)
    end
  end

  def unpack(ignore_raw_padding = false, parse_buffer = false) : Void*
    i = 0
    buffer = get_tls().as(UInt32*)

    ctrl0 = buffer[0]
    ctrl1 = buffer[1]
    i += 2

    @message_type = IpcMessage::Type.new(ctrl0 & 0xffff)
    @has_pid = false
    raw_size = (ctrl1 & 0x1ff) * 4

    # Force clean up before starting messing with those array
    @buffers = IpcBufferArray(MAX_BUFFERS).new
    @statics_in = SizedStaticArray(IpcPointerBuffer, MAX_BUFFERS).new
    @statics_out = SizedStaticArray(IpcReceiveListBuffer, MAX_BUFFERS).new
    @handles = IpcHandleArray(MAX_OBJECTS).new
    @object_ids = SizedStaticArray(Handle, MAX_OBJECTS).new

    statics_out_count = (ctrl1 >> 10) & 15
    statics_in_count = (ctrl0 >> 16) & 15
    send_count = (ctrl0 >> 20) & 15
    recv_count = (ctrl0 >> 24) & 15
    exch_count = (ctrl0 >> 28) & 15

    # Single descriptor
    if (statics_out_count >> 1) != 0
      statics_out_count += 1
    end
    # value - 2 descriptors
    if (statics_out_count >> 1) != 0
      statics_out_count += 1
    end

    # handle descriptor enabled?
    if ((ctrl1 & 0x80000000) != 0)
      handle_descriptor = buffer[i]
      i += 1
      # has Pid?
      if ((handle_descriptor & 1) != 0)
        @has_pid = true
        @pid = buffer[i].to_u64 | (buffer[i + 1].to_u64 << 32)
        i += 2
      end

      # copied handles
      handles_copied_count = ((handle_descriptor >> 1) & 15)
      handles_copied_count.times do |handle_index|
        @handles.push(IpcHandle.new(buffer[i + handle_index], IpcHandle::Type::Copy))
      end
      i += handles_copied_count

      # moved handles
      handles_moved_count = ((handle_descriptor >> 5) & 15)
      handles_moved_count.times do |handle_index|
        @handles.push(IpcHandle.new(buffer[i + handle_index], IpcHandle::Type::Move))
      end
      i += handles_moved_count
    end

    if parse_buffer
      # TODO: X descriptors parsing
    end
    i += statics_in_count * 2

    buffers_count = (send_count + recv_count + exch_count)

    raw_ptr = (buffer + i + (buffers_count * 3)).address
    raw_padded_ptr = (raw_ptr + 15) & ~15

    if parse_buffer
      # TODO: A/B/W descriptors parsing
    end
    i += buffers_count * 3

    Pointer(Void).new(ignore_raw_padding ? raw_ptr : raw_padded_ptr)
  end

  def initialize
    @buffers = uninitialized IpcBufferArray(MAX_BUFFERS)
    @statics_in = uninitialized SizedStaticArray(IpcPointerBuffer, MAX_BUFFERS)
    @statics_out = uninitialized SizedStaticArray(IpcReceiveListBuffer, MAX_BUFFERS)
    @handles = uninitialized SizedStaticArray(Handle, MAX_OBJECTS)
    @object_ids = uninitialized SizedStaticArray(Handle, MAX_OBJECTS)
  end
end

class IPC
  def self.close(session : Handle) : Result
    buffer = get_tls().as(UInt32*)
    buffer[0] = IpcMessage::Type::Close.value
    dispatch(session)
  end

  def self.dispatch(session : Handle) : Result
    SVC.send_sync_request(session)
  end
end
