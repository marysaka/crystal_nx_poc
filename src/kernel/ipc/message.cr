module IPC
  struct Message
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

    @message_type = Message::Type::Request
    @send_pid = false
    @pid = 0u64
    @buffers : BufferArray(MAX_BUFFERS)
    @statics_in : SizedStaticArray(PointerBuffer, MAX_BUFFERS)      # X
    @statics_out : SizedStaticArray(ReceiveListBuffer, MAX_BUFFERS) # Y
    @handles : HandleArray(MAX_OBJECTS)
    @object_ids_count = 0u64
    @object_ids : SizedStaticArray(::Handle, MAX_OBJECTS)

    def set_message_type(message_type : Message::Type) : Void
      @message_type = message_type
    end

    def send_pid : Void
      @send_pid = true
    end

    def send_handle(handle : ::Handle, handle_type : IPC::Handle::Type) : Void
      @handles.push(IPC::Handle.new(handle, handle_type))
    end

    def add_buffer(ipc_buffer : Buffer) : Void
      @buffers.push(ipc_buffer)
    end

    def add_send_buffer(buffer : Void*, buffer_size : UInt64, buffer_type : Buffer::Type = Buffer::Type::Normal) : Void
      add_buffer(Buffer.new(Buffer::Direction::Send, buffer_type, buffer, buffer_size))
    end

    def add_receive_buffer(buffer : Void*, buffer_size : UInt64, buffer_type : Buffer::Type = Buffer::Type::Normal) : Void
      add_buffer(Buffer.new(Buffer::Direction::Receive, buffer_type, buffer, buffer_size))
    end

    def add_exchange_buffer(buffer : Void*, buffer_size : UInt64, buffer_type : Buffer::Type = Buffer::Type::Normal) : Void
      add_buffer(Buffer.new(Buffer::Direction::Exchange, buffer_type, buffer, buffer_size))
    end

    def handles : HandleArray
      @handles
    end

    def pid : UInt64
      @pid
    end

    def pack(raw_struct) : Void
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
        @handles.filter_by_type IPC::Handle::Type::Copy do |handle|
          buffer[i] = handle.value
          i += 1
        end

        # moved handles
        @handles.filter_by_type IPC::Handle::Type::Move do |handle|
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
      @buffers.filter_by_direction Buffer::Direction::Send do |ipc_buffer|
        i += ipc_buffer.pack(buffer + i)
      end

      # B descriptors
      @buffers.filter_by_direction Buffer::Direction::Receive do |ipc_buffer|
        i += ipc_buffer.pack(buffer + i)
      end

      # W descriptors
      @buffers.filter_by_direction Buffer::Direction::Exchange do |ipc_buffer|
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

      @message_type = Message::Type.new(ctrl0 & 0xffff)
      @has_pid = false
      raw_size = (ctrl1 & 0x1ff) * 4

      # Force clean up before starting messing with those array
      @buffers = BufferArray(MAX_BUFFERS).new
      @statics_in = SizedStaticArray(PointerBuffer, MAX_BUFFERS).new
      @statics_out = SizedStaticArray(ReceiveListBuffer, MAX_BUFFERS).new
      @handles = HandleArray(MAX_OBJECTS).new
      @object_ids = SizedStaticArray(::Handle, MAX_OBJECTS).new

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
          @handles.push(IPC::Handle.new(buffer[i + handle_index], IPC::Handle::Type::Copy))
        end
        i += handles_copied_count

        # moved handles
        handles_moved_count = ((handle_descriptor >> 5) & 15)
        handles_moved_count.times do |handle_index|
          @handles.push(IPC::Handle.new(buffer[i + handle_index], IPC::Handle::Type::Move))
        end
        i += handles_moved_count
      end

      if parse_buffer
        statics_in_count.times do |static_in_index|
          static_in = PointerBuffer.unpack(buffer + i + (static_in_index * 2))
          @statics_in.push(static_in)
        end
      end
      i += statics_in_count * 2

      buffers_count = (send_count + recv_count + exch_count)

      raw_ptr = (buffer + i + (buffers_count * 3)).address
      raw_padded_ptr = (raw_ptr + 15) & ~15

      if parse_buffer
        send_count.times do |send_index|
          send_buffer = Buffer.unpack(buffer + i + (send_index * 3), Buffer::Direction::Send)
          @buffers.push(send_buffer)
        end
        i += send_count * 3
        recv_count.times do |recv_index|
          receive_buffer = Buffer.unpack(buffer + i + (recv_index * 3), Buffer::Direction::Receive)
          @buffers.push(receive_buffer)
        end
        i += recv_count * 3
        exch_count.times do |exch_index|
          exchange_buffer = Buffer.unpack(buffer + i + (exch_index * 3), Buffer::Direction::Exchange)
          @buffers.push(exchange_buffer)
        end
        i += exch_count * 3
      else
        i += buffers_count * 3
      end

      res = Pointer(Void).new(ignore_raw_padding ? raw_ptr : raw_padded_ptr)
      # TODO: C descriptors parsing
      res
    end

    def initialize
      @buffers = uninitialized BufferArray(MAX_BUFFERS)
      @statics_in = uninitialized SizedStaticArray(PointerBuffer, MAX_BUFFERS)
      @statics_out = uninitialized SizedStaticArray(ReceiveListBuffer, MAX_BUFFERS)
      @handles = uninitialized SizedStaticArray(Handle, MAX_OBJECTS)
      @object_ids = uninitialized SizedStaticArray(::Handle, MAX_OBJECTS)
    end
  end
end
