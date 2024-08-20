# frozen_string_literal: true

module BugsnagPerformance
  class TaskScheduler
    def now(&on_finish)
      Task.new(on_finish).tap do |task|
        task.schedule(0)
      end
    end
  end
end