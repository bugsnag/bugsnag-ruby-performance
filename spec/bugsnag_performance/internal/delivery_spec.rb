# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Internal::Delivery do
  subject { BugsnagPerformance::Internal::Delivery.new(configuration) }

  let(:configuration) do
    BugsnagPerformance::Configuration.new(BugsnagPerformance::Internal::NilErrorsConfiguration.new).tap do |config|
      config.api_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    end
  end

  context "#deliver" do
    it "can deliver a payload" do
      response = subject.deliver({ "header" => "yes" }, "hello")

      expect(response).to be_successful
      expect(WebMock).to have_requested(:post, TRACES_URI)
        .with(
          body: "hello",
          headers: {
            "header" => "yes",
            "Content-Type" => "application/json",
            "Bugsnag-Api-Key" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "User-Agent" => "Ruby Bugsnag Performance SDK v#{BugsnagPerformance::VERSION}",
          }
        ).once
    end
  end

  describe BugsnagPerformance::Internal::Delivery::Response do
    subject do
      BugsnagPerformance::Internal::Delivery.new(configuration).deliver({}, "")
    end

    context "#state" do
      context ":success" do
        (200...300).to_a.sample(20).each do |status_code|
          it "is :success when the status code is #{status_code}" do
            expect(subject.state).to be(:success)
            expect(subject).to be_successful
            expect(subject).not_to be_retryable
          end
        end
      end

      context ":failure_retryable" do
        [402, 407, 408, 429, 600, 10000, 0].each do |status_code|
          it "is :failure_retryable when the status code is #{status_code}" do
            stub_response_status_code(status_code)

            expect(subject.state).to be(:failure_retryable)
            expect(subject).not_to be_successful
            expect(subject).to be_retryable
          end
        end

        it "is :failure_retryable when there is no response" do
          response = BugsnagPerformance::Internal::Delivery::Response.new(nil)

          expect(response.state).to be(:failure_retryable)
          expect(response).not_to be_successful
          expect(response).to be_retryable
        end
      end

      context ":failure_discard" do
        ((400...500).to_a - [402, 407, 408, 429]).sample(20).each do |status_code|
          it "is :failure_discard when the status code is #{status_code}" do
            stub_response_status_code(status_code)

            expect(subject.state).to be(:failure_discard)
            expect(subject).not_to be_successful
            expect(subject).not_to be_retryable
          end
        end
      end
    end

    context "#sampling_probability" do
      [0.0, 0.1, 0.25, 0.33, 0.4, 0.5, 0.66, 0.75, 0.8, 0.99, 1.0].each do |probability|
        it "returns #{probability} if the server response is #{probability}" do
          stub_probability_request(probability)

          expect(subject.sampling_probability).to be(probability)
        end
      end

      it "returns nil if the server response is < 0" do
        stub_probability_request(-0.1)

        expect(subject.sampling_probability).to be_nil
      end

      it "returns nil if the server response is > 1" do
        stub_probability_request(1.001)

        expect(subject.sampling_probability).to be_nil
      end

      it "returns nil if the server response is not parsable as a float" do
        stub_probability_request(":)")

        expect(subject.sampling_probability).to be_nil
      end

      it "returns nil when there is no response" do
        response = BugsnagPerformance::Internal::Delivery::Response.new(nil)

        expect(response.sampling_probability).to be_nil
      end
    end
  end
end
