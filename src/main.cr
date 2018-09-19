require "./kernel/svc"
require "./kernel/ipc"
require "./services/sm"

sm_res = ServiceManager.open
case sm_res
when ServiceManager
  SVC.output_debug_string "Got SM"
  sm_close_res = sm_res.release
  if sm_close_res != 0
    SVC.output_debug_string "Error code while closing SM"
    ReturnValue.return_value = sm_close_res.to_u64
  end
when Result
  SVC.output_debug_string "Error code while opening SM"
  SVC.output_debug_string sm_res, 16
  ReturnValue.return_value = sm_res.to_u64
end

alloc_test = Cryloc.allocate(0x2000)
test = alloc_test.as(UInt8*)
memset(test, 0, 0x2000u64)
test[0] = 0x48
test[1] = 0x65
test[2] = 0x6C
test[3] = 0x6C
test[4] = 0x20
test[5] = 0x79
test[6] = 0x65
test[7] = 0x61
test[8] = 0x68

SVC.output_debug_string test, 0x2000

Cryloc.release(alloc_test)
