# frozen_string_literal: true

class FakeTaskScheduler
  attr_reader :done
  attr_reader :tasks

  def initialize(done)
    @done = done
    @tasks = Set.new
  end

  def now(&block)
    @tasks << FakeTask.new(@done, &block)
  end

  def run!
    @tasks.each { |task| task.run! }
  end
end

class FakeTask < BugsnagPerformance::Task
  def initialize(done, &block)
    @done = done
    @block = block
  end

  def run!
    @block.call(@done)
  end
end

RSpec.describe BugsnagPerformance::ProbabilityFetcher do
  subject do
    BugsnagPerformance::ProbabilityFetcher.new(delivery, task_scheduler)
  end

  let(:delivery) { BugsnagPerformance::Delivery.new(configuration) }

  let(:configuration) do
    BugsnagPerformance::Configuration.new(BugsnagPerformance::NilErrorsConfiguration.new).tap do |config|
      config.api_key = "abcdef1234567890abcdef1234567890"
    end
  end

  let(:task_scheduler) { FakeTaskScheduler.new(double(Proc)) }

  around do |spec|
    # apply a 1 second timeout to all tests to save us against ending up in an
    # infinite loop inside the ProbabilityFetcher
    Timeout::timeout(1, &spec)
  end

  it "can successfully fetch a probability value from the server" do
    expect(task_scheduler.done).to receive(:call).once
    expect(subject).not_to receive(:sleep)

    fetched_probability = nil

    subject.on_new_probability do |probability|
      fetched_probability = probability
    end

    stub_probability_request(0.1234)

    task_scheduler.run!
    expect(fetched_probability).to be(0.1234)
  end

  it "continues making requests if the probability is not returned" do
    expect(task_scheduler.done).to receive(:call).once
    expect(subject).to receive(:sleep).at_least(:once) { sleep(0.01) }

    fetched_probability = nil

    subject.on_new_probability do |probability|
      fetched_probability = probability
    end

    # run the scheduler in another thread as otherwise it will block
    thread = Thread.new { task_scheduler.run! }
    thread.join(0.1)
    expect(fetched_probability).to be_nil

    stub_probability_request(0.6)
    thread.join

    expect(fetched_probability).to be(0.6)
  end

  it "continues making requests if an invalid probability is returned" do
    expect(task_scheduler.done).to receive(:call).once
    expect(subject).to receive(:sleep).at_least(:once) { sleep(0.01) }

    invalid_stub = stub_probability_request("very probable")

    fetched_probability = nil

    subject.on_new_probability do |probability|
      fetched_probability = probability
    end

    thread = Thread.new { task_scheduler.run! }

    # wait a bit and check no probability has been set
    thread.join(0.1)
    expect(fetched_probability).to be_nil
    expect(invalid_stub).to have_been_requested.at_least_once

    stub_probability_request(0.99)
    thread.join

    expect(fetched_probability).to be(0.99)
  end
end
