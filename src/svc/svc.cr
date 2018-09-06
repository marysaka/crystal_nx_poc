# For crt0
fun svcExitProcess : NoReturn
  SVC.exit_process
end

fun svcReturnFromException(error_code : UInt64) : NoReturn
  SVC.return_from_exception(error_code)
end

module SVC
  def self.break(reason : UInt64, unknown : UInt64, info : UInt64)
    res = uninitialized UInt32
    asm("svc 0x28" : "=w0"(res) : "x0"(reason), "x1"(unknown), "x2"(info))
    res
  end

  def self.exit_process : NoReturn
    asm("svc 0x7" :::: "volatile")
    while true
    end
  end

  def self.output_debug_string(string : UInt8*, string_size : UInt64) : UInt32
    res = uninitialized UInt32
    asm("svc 0x27" : "=w0"(res) : "x0"(string), "x1"(string_size))
    res
  end

  def self.return_from_exception(error_code : UInt64) : NoReturn
    asm("svc 0x28" :: "x0"(error_code))
    while true
    end
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
