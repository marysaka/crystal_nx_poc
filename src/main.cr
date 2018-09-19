require "./kernel/svc"
require "./kernel/ipc"
require "./services/sm"

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
