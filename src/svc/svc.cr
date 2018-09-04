# For crt0
fun svcExitProcess
    SVC.exit_process();
end

fun svcOutputDebugString(string : UInt8*, string_size : UInt64) : UInt32
    res = uninitialized UInt32
    asm("svc 0x27" : "=w0"(res) : "x0"(string), "x1"(string_size))
    res
end

class String
    def bytesize
        @bytesize
    end
    def to_unsafe : UInt8*
        pointerof(@c)
    end
end

module SVC
    def self.exit_process
        asm("svc 0x7" :::: "volatile");
    end

    def self.output_debug_string(string : String)
        svcOutputDebugString(string.to_unsafe, string.bytesize.to_u64)
    end
end
