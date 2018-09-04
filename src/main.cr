require "./crt0/dummy"

module SVC
    def self.exit_process
        asm("svc 0x7" :::: "volatile");
    end
end

fun svcExitProcess
    SVC.exit_process();
end