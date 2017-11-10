require "vagrant/ssh/config/version"
require "net/ssh"
require "English"
require "open3"
require "tempfile"

module Vagrant
  module SSH
    # Helper methods for `vagrant ssh-config`
    module Config
      @ssh_config = nil

      # @param [Hash] opts
      # @option opts [Hash] :env optional environment variable names and
      # values
      # @return [String] raw content of `vagrant ssh-config`
      def self.ssh_config(env: {})
        return @ssh_config if @ssh_config
        @ssh_config = get_vagrant_ssh_config(env: env) unless @ssh_config
      end

      # @param [String] hostname, opts
      # @option hostname [Strng] hostname
      # @option opts [Hash] :env optional environment variable names and
      # values
      # @return [Net::SSH::Config] for the host
      def self.for(host, env: {})
        f = tempfile
        begin
          f.write(ssh_config(env: env))
          f.close
          Net::SSH::Config.load(f.path, host)
        ensure
          f.unlink
        end
      end

      def self.tempfile
        Tempfile.new("ssh_config")
      end

      # the ugly implementation of self.ssh_config
      #
      # @param [Hash] opts
      # @option opts [Hash] :env optional environment variable names and
      # values
      # @return [String] raw content of `vagrant ssh-config`
      def self.get_vagrant_ssh_config(env: {})
        Bundler.with_clean_env do
          configure_env(env: env)
          Open3.popen3("vagrant ssh-config") do |_i, o, e, thr|
            # rubocop:disable Metrics/LineLength:
            raise StandardError, format("failed to run `vagrant ssh-config`\n%s\n%s", out.read.chomp, e.read.chomp) unless thr.value.success?
            # rubocop:enable Metrics/LineLength:
            o.read.chomp
          end
        end
      end

      def self.configure_env(env: {})
        env.each do |k, v|
          ENV[k] = v
        end
      end
    end
  end
end
