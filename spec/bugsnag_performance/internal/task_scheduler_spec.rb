# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::TaskScheduler do
  context "#now" do
    it "returns a task scheduled to run immediately" do
      callback = spy(Proc)

      task = subject.now { callback.call }

      expect(task).to be_a(BugsnagPerformance::Internal::Task)

      # wait for the scheduled task to fire
      elapsed = measure { task.wait }

      expect(callback).to have_received(:call).once
      expect(elapsed).to be_within(0.1).of(0)
    end
  end
end
