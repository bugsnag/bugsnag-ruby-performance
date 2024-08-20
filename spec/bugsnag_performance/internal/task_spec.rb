# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::Task do
  subject { BugsnagPerformance::Internal::Task.new(callback) }
  let(:callback) { spy(Proc) }

  context "#schedule" do
    it "runs a task immediately with a delay of 0" do
      subject.schedule(0)

      elapsed = measure { subject.wait }

      expect(elapsed).to be_within(0.1).of(0)
      expect(callback).to have_received(:call).once
    end

    it "runs a task after the given delay" do
      subject.schedule(0.25)

      elapsed = measure { subject.wait }

      expect(elapsed).to be_within(0.1).of(0.25)
      expect(callback).to have_received(:call).once
    end

    it "can be rescheduled before being triggered" do
      subject.schedule(0.1)

      sleep(0.005)

      expect(callback).not_to have_received(:call)

      subject.schedule(0.025)

      sleep(0.01)

      expect(callback).not_to have_received(:call)

      elapsed = measure { subject.wait }

      # the elapsed time should be ~0.015s as we've already slept for 0.01s since
      # rescheduling the task to take 0.025s
      expect(elapsed).to be_within(0.05).of(0.015)
      expect(callback).to have_received(:call).once
    end

    it "can be rescheduled while running" do
      call_count = 0
      callback = proc do
        call_count += 1
        sleep(0.05)
      end

      task = BugsnagPerformance::Internal::Task.new(callback)
      task.schedule(0.01)

      elapsed2 = 0
      thread = Thread.new do
        sleep(0.02)

        expect(task.state).to be(:processing)
        task.schedule(0.03)
        expect(task.state).to be(:processing)

        elapsed2 = measure { task.wait }
      end

      elapsed1 = measure { task.wait }
      thread.join

      expect(elapsed1).to be_within(0.04).of(0.06)
      expect(elapsed2).not_to be_zero
      expect(elapsed2).to be_within(0.04).of(0.05)

      expect(call_count).to be(1)
    end

    it "can be rescheduled multiple times while running" do
      call_count = 0
      callback = proc do
        call_count += 1
        sleep(0.05)
      end

      task = BugsnagPerformance::Internal::Task.new(callback)
      task.schedule(0.01)

      threads = 10.times.map do
        Thread.new do
          sleep(0.02)

          expect(task.state).to be(:processing)
          task.schedule(0.03)
          expect(task.state).to be(:processing)
        end
      end

      task.wait
      threads.each(&:join)

      expect(call_count).to be(1)
    end
  end

  context "#wait" do
    it "waits for the task to finish" do
      subject.schedule(0.1)
      expect(callback).not_to have_received(:call)

      subject.wait
      expect(callback).to have_received(:call).once
    end

    it "raises if the task has not been scheduled" do
      expect { subject.wait }.to raise_error(
        BugsnagPerformance::Internal::Task::UnscheduledTaskError,
        "Task has not been scheduled"
      )
    end

    it "does nothing if called after the task has finished" do
      subject.schedule(0.1)
      expect(callback).not_to have_received(:call)

      subject.wait
      expect(callback).to have_received(:call).once

      subject.wait
      subject.wait
      subject.wait

      expect(callback).to have_received(:call).once
    end
  end

  context "#state" do
    it "is :unscheduled if the task has not been scheduled" do
      expect(subject.state).to be(:unscheduled)
    end

    it "is :pending if the task is pending" do
      subject.schedule(0.1)
      expect(subject.state).to be(:pending)
    end

    it "is :processing if the task is processing" do
      task = BugsnagPerformance::Internal::Task.new(proc { sleep(0.05) })
      task.schedule(0.01)

      thread = Thread.new do
        sleep(0.02)
        expect(task.state).to be(:processing)
      end

      expect(task.state).to be(:pending)
      task.wait
      thread.join
    end

    it "is :finished if the task has finished" do
      subject.schedule(0)
      subject.wait

      expect(subject.state).to be(:finished)
    end

    it "is :finished if the task fails" do
      task = BugsnagPerformance::Internal::Task.new(proc { raise "oh no" })
      task.schedule(0)
      task.wait

      expect(task.state).to be(:finished)
    end
  end
end
