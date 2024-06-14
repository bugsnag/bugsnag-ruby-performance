require "os"

module BugsnagPerformanceMazeRunner
  class Environment
    def host
      return "host.docker.internal" if OS.mac?

      ip_addr = `ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\\.){3}[0-9]*' | grep -v '127.0.0.1'`
      ip_list = /((?:[0-9]*\.){3}[0-9]*)/.match(ip_addr)
      ip_list.captures.first
    end
  end
end
