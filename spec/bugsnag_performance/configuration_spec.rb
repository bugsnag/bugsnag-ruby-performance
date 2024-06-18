# frozen_string_literal: true

RSpec.describe BugsnagPerformance::Configuration do
  context "API key" do
    it "is nil by default" do
      expect(subject.api_key).to be_nil
    end

    it "can be set to a valid value" do
      api_key = "abcdef1234567890abcdef1234567890"

      subject.api_key = api_key

      expect(subject.api_key).to eq(api_key)
    end
  end

  context "app version" do
    it "is nil by default" do
      expect(subject.app_version).to be_nil
    end

    it "can be set to a valid value" do
      app_version = "1.2.3"

      subject.app_version = app_version

      expect(subject.app_version).to eq(app_version)
    end
  end

  context "release stage" do
    it "is 'production' by default" do
      expect(subject.release_stage).to eq("production")
    end

    it "can be set to a valid value" do
      release_stage = "staging"

      subject.release_stage = release_stage

      expect(subject.release_stage).to eq(release_stage)
    end
  end

  context "enabled release stages" do
    it "is nil by default" do
      expect(subject.enabled_release_stages).to be_nil
    end

    it "can be set to a valid value" do
      enabled_release_stages = ["staging", "development"]

      subject.enabled_release_stages = enabled_release_stages

      expect(subject.enabled_release_stages).to eq(enabled_release_stages)
    end
  end

  context "endpoint" do
    it "is nil if API key is not set" do
      expect(subject.endpoint).to be_nil
    end

    it "is the default URL if API key is set" do
      subject.api_key = "1234567890abcdef1234567890abcdef"

      expect(subject.endpoint).to eq("https://#{subject.api_key}.otlp.bugsnag.com/v1/traces")
    end

    it "can be set to a valid value" do
      endpoint = "https://example.com/traces"

      subject.endpoint = endpoint

      expect(subject.endpoint).to eq(endpoint)
    end
  end

  context "use managed quota" do
    it "is 'true' by default" do
      expect(subject.use_managed_quota).to eq(true)
    end

    it "can be set to a valid value" do
      use_managed_quota = false

      subject.use_managed_quota = use_managed_quota

      expect(subject.use_managed_quota).to eq(use_managed_quota)
    end
  end
end
