# For crt0
fun svcExitProcess
    SVC.exit_process();
end

fun svcReturnFromException(error_code : UInt64)
    SVC.return_from_exception(error_code)
end

fun svcOutputDebugString(string : UInt8*, string_size : UInt64) : UInt32
    res = uninitialized UInt32
    asm("svc 0x27" : "=w0"(res) : "x0"(string), "x1"(string_size))
    res
end

module SVC
    def self.exit_process
        asm("svc 0x7" :::: "volatile");
    end

    def self.return_from_exception(error_code : UInt64)
        asm("svc 0x28" : : "x0"(error_code));
    end

    def self.output_debug_string(string : String)
        svcOutputDebugString(string.to_unsafe, string.bytesize.to_u64)
    end
end
