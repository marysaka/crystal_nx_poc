module SVC
  def self.set_heap_size(out_addr : Void**, size : UInt64) : Result
    res = uninitialized Result
    out = uninitialized Void*
    asm("svc 0x1" : "={w0}"(res), "={x1}"(out) : "{x0}"(size) :: "volatile")
    out_addr.value = out
    res
  end

  def self.close_handle(handle : Handle) : Result
    res = uninitialized Result
    asm("svc 0x16" : "={w0}"(res) : "w0"(handle) :: "volatile")
    res
  end

  def self.connect_to_named_port(session : Handle*, name : String) : Result
    res = uninitialized Result
    handle = uninitialized Handle
    asm("svc 0x1F" : "={w0}"(res), "={w1}"(handle) : "{x1}"(name.to_unsafe) :: "volatile")
    session.value = handle
    res
  end

  def self.send_sync_request(session : Handle) : Result
    res = uninitialized Result
    asm("svc 0x21" : "={w0}"(res) : "{x0}"(session))
    res
  end

  def self.break(reason : UInt64, unknown : UInt64, info : UInt64) : Result
    res = uninitialized Result
    asm("svc 0x26" : "=w0"(res) : "x0"(reason), "x1"(unknown), "x2"(info))
    res
  end

  def self.exit_process(return_code : Int32) : NoReturn
    asm("svc 0x7" :: "x0"(return_code) :: "volatile")
    while true
    end
  end

  def self.output_debug_string(string : UInt8*, string_size : UInt64) : Result
    res = uninitialized Result
    asm("svc 0x27" : "=w0"(res) : "x0"(string), "x1"(string_size))
    res
  end

  def self.return_from_exception(error_code : UInt64) : NoReturn
    asm("svc 0x28" :: "x0"(error_code))
    while true
    end
  end

  def self.get_info(out_value : UInt64*, info_id : UInt64, handle : Handle, info_sub_id : UInt64) : Result
    res = uninitialized Result
    out = uninitialized UInt64
    asm("svc 0x29" : "={w0}"(res), "={x1}"(out) : "x1"(info_id), "w2"(handle), "x3"(info_sub_id))
    out_value.value = out
    res
  end

  def self.output_debug_string(string : String)
    output_debug_string(string.to_unsafe, string.bytesize.to_u64)
  end

  def self.output_debug_string(value : Int, base)
    value.internal_to_s(base, false) do |ptr, count|
      output_debug_string(ptr, count.to_u64)
    end
  end
end
