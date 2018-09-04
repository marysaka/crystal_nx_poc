require "./svc/svc"

lib Crt0
  $rela_test : UInt8
  $rela_test_size : UInt32
end


svcOutputDebugString(pointerof(Crt0.rela_test), Crt0.rela_test_size.to_u64);
SVC.output_debug_string "Hello World"