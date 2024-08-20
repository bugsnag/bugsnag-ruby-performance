# frozen_string_literal: true

module BugsnagPerformance
  module Internal
    # A wrapper around Concurrent::ScheduledTask that is easier to work with when
    # a task needs to be run repeatedly (a ScheduledTask can only run once)
    class Task
      class UnscheduledTaskError < ::BugsnagPerformance::Error
        def initialize
          super("Task has not been scheduled")
        end
      end

      def initialize(on_finish)
        @on_finish = on_finish
        @lock = Mutex.new
        @scheduled_task = nil
      end

      def schedule(delay)
        @lock.synchronize do
          if @scheduled_task && @scheduled_task.pending?
            # if we have a pending task we can reschedule it
            @scheduled_task.reschedule(delay)
          elsif @scheduled_task && @scheduled_task.processing?
            # task is currently running so re-schedule when it finishes and remove
            # any existing reschedules
            @scheduled_task.delete_observers

            @scheduled_task.add_observer(OnTaskFinish.new(proc do
              self.schedule(delay)
            end))
          else
            # otherwise make a new task; if there's an existing task and it isn't
            # pending or processing then it must have already finished so we don't
            # need to worry about cancelling it
            @scheduled_task = Concurrent::ScheduledTask.execute(delay) { @on_finish.call }
          end
        end

        nil
      end

      def wait
        raise UnscheduledTaskError.new if @scheduled_task.nil?

        @scheduled_task.wait
      end

      def state
        case @scheduled_task&.state
        when nil then :unscheduled
        when :pending then :pending
        when :processing then :processing
        else :finished
        end
      end

      private

      class OnTaskFinish
        def initialize(on_finish)
          @on_finish = on_finish
        end

        def update(...)
          @on_finish.call
        end
      end
    end
  end
end
