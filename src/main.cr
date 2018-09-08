require "./kernel/svc"
require "./kernel/ipc"
require "./services/sm"

lib Crt0
  $rela_test : UInt8
  $rela_test_size : UInt32
end

sm_res = ServiceManager.open
case sm_res
when ServiceManager
  SVC.output_debug_string "Got SM"
when Result
  SVC.output_debug_string "Error code while opening SM"
  SVC.output_debug_string sm_res, 16
end
# IPC.dispatch(0)
# IPC.close 0_u32
SVC.output_debug_string pointerof(Crt0.rela_test), Crt0.rela_test_size.to_u64
SVC.output_debug_string "Hello World"
