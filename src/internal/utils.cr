# compiler-rt needs some bare minimal to be linkable (memcmp, memcpy, abort, and assert)
fun memcmp(s1 : UInt8*, s2 : UInt8*, n : UInt64) : Int32
  until n == 0
    if s1.value != s2.value
      return (s1.value.to_i32 - s2.value.to_i32)
    end
    n -= 1
  end
  0_i32
end

fun memcpy(dest : UInt8*, src : UInt8*, n : UInt64)
  n.times do |i|
    dest[i] = src[i]
  end
end

fun memset(s : UInt8*, c : Int32, n : UInt64) : UInt8*
  n.times do |i|
    s[i] = c.to_u8
  end
  s
end

def __strlen(str) : UInt64
  res = 0_u64
  until str[res] == 0
    res += 1
  end
  res
end

fun abort
  SVC.break(0x80000000, 0, 0)
  SVC.exit_process(0x42)
end

# see include/assert.h
fun __assert(msg : UInt8*, file : UInt8*, line : UInt32)
  SVC.output_debug_string(msg, __strlen(msg))
  SVC.output_debug_string(file, __strlen(file))
  SVC.output_debug_string("Line: ")
  SVC.output_debug_string(line, 10)
  abort
end
