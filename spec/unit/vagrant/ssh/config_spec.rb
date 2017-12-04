# frozen_string_literal: true

require_relative "../../../spec_helper"

vagrant_dir = "#{Dir.pwd}/spec/vagrant"
vagrant_path = `which vagrant`.chomp
ssh_config_regexp = <<~'__SSH_CONFIG_REGEXP__'
  Host default
    HostName 127\.0\.0\.1
    User vagrant
    Port \d+
    UserKnownHostsFile \/dev\/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile .*\/private_key
    IdentitiesOnly yes
    LogLevel FATAL
__SSH_CONFIG_REGEXP__

ssh_config = <<~'__SSH_CONFIG__'
  Host default
    HostName 192.168.123.123
    User foo
    Port 22
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile /your/private_key
    IdentitiesOnly yes
    LogLevel FATAL
  Host foo
    HostName 192.168.1.1
    User foo
    Port 22
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    PasswordAuthentication no
    IdentityFile /my/private_key
    IdentitiesOnly yes
    LogLevel FATAL
__SSH_CONFIG__

RSpec.describe Vagrant::SSH::Config do
  it "has a version number" do
    expect(Vagrant::SSH::Config::VERSION).not_to be nil
  end

  describe "#configure_env" do
    let(:key) { "vagrant_ssh_config#{rand(100)}" }
    it "sets an environment variable" do
      Vagrant::SSH::Config.configure_env(env: { key => "foobar" })
      expect(ENV[key]).to eq "foobar"
    end
  end

  describe "#get_vagrant_ssh_config" do
    context "Without Vagrantfile" do
      it "raises an exception" do
        expect { Vagrant::SSH::Config.get_vagrant_ssh_config }.to raise_exception StandardError
      end
    end

    context "With Vagrantfile" do
      before(:all) do
        Dir.chdir(vagrant_dir) do
          Bundler.with_clean_env do
            `#{vagrant_path} up` unless vagrant_path.empty?
          end
        end
      end

      after(:all) do
        Dir.chdir(vagrant_dir) do
          Bundler.with_clean_env do
            `#{vagrant_path} destroy -f` unless vagrant_path.empty?
          end
        end
      end

      it "does not raise an exception" do
        skip if vagrant_path.empty?
        expect do
          Vagrant::SSH::Config.get_vagrant_ssh_config(
            env: { "VAGRANT_CWD" => vagrant_dir }
          )
        end.not_to raise_exception
      end

      it "returns same config" do
        skip if vagrant_path.empty?
        expect(Vagrant::SSH::Config.get_vagrant_ssh_config(
                 env: { "VAGRANT_CWD" => vagrant_dir }
        )).to match(/^#{ssh_config_regexp}$/)
      end
    end
  end

  describe "#ssh_config" do
    it "returns ssh_config" do
      allow(Vagrant::SSH::Config).to receive(:get_vagrant_ssh_config).and_return ssh_config
      expect(Vagrant::SSH::Config.ssh_config).to eq ssh_config
    end
  end

  describe "#for" do
    it "raises no exception" do
      allow(Vagrant::SSH::Config).to receive(:get_vagrant_ssh_config).and_return ssh_config
      expect { Vagrant::SSH::Config.for("foo") }.not_to raise_exception
    end

    it "returns Net::SSH option" do
      allow(Vagrant::SSH::Config).to receive(:get_vagrant_ssh_config).and_return ssh_config
      foo = Vagrant::SSH::Config.for("foo")
      expect(foo).to include(
        "host" => "foo",
        "hostname" => "192.168.1.1",
        "identitiesonly" => true,
        "identityfile" => ["/my/private_key"],
        "loglevel" => "FATAL",
        "passwordauthentication" => false,
        "port" => 22,
        "stricthostkeychecking" => false,
        "user" => "foo",
        "userknownhostsfile" => "/dev/null"
      )
    end
  end
end
