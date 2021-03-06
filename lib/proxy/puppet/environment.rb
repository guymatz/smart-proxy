module Proxy::Puppet

  require 'proxy/puppet/initializer'
  require 'proxy/puppet/puppet_class'
  require 'puppet'

  class Environment
    extend Proxy::Log

    class << self
      # return a list of all puppet environments
      def all
        puppet_environments.map { |env, path| new(:name => env, :paths => path.split(":")) }
      end

      def find name
        all.each { |e| return e if e.name == name }
        nil
      end

      private

      def puppet_environments
        Initializer.load
        conf = Puppet.settings.instance_variable_get(:@values)

        env = { }
        # query for the environments variable
        if conf[:main][:environments].nil?
          # 0.25 and newer doesn't require the environments variable anymore, scanning for modulepath
          conf.keys.each { |p| env[p] = conf[p][:modulepath] unless conf[p][:modulepath].nil? }
          # puppetmaster section "might" also returns the modulepath
          env.delete :main
          env.delete :puppetmasterd if env.size > 1
        else
          conf[:main][:environments].split(",").each { |e| env[e.to_sym] = conf[e.to_sym][:modulepath] unless conf[e.to_sym][:modulepath].nil? }
        end
        if env.values.compact.size == 0
          # fall back to defaults - we probably don't use environments
          env[:production] = conf[:main][:modulepath] || conf[:master][:modulepath] || '/etc/puppet/modules'
          logger.warn "No environments found - falling back to defaults (production - #{env[:production]})"
        end

        new_env = env.clone
        # are we using dynamic puppet environments?
        env.each do|environment, modulepath|
          next unless modulepath

          # expand $confdir if defined and used in modulepath
          if modulepath.include?("$confdir")
            if conf[:main][:confdir]
              modulepath.gsub!("$confdir", conf[:main][:confdir])
            else
              # /etc/puppet is the default if $confdir is not defined
              modulepath.gsub!("$confdir", "/etc/puppet")
            end
          end

          modulepath.split(":").each do |base_dir|
            if base_dir.include?("$environment")
              # remove this entry from the current env so that static paths are unaltered
              temp_path = modulepath.split(':')
              temp_path.delete base_dir
              if temp_path.empty?
                new_env.delete environment
              else
                new_env[environment] = temp_path.join(':')
              end
              # Dynamic environments - get every directory under the modulepath
              base_dir.gsub!(/\$environment.*/,"/")
              Dir.glob("#{base_dir}/*").grep(/\/[A-Za-z0-9_]+$/) do |dir|
                e = dir.split("/").last
                new_env[e] = base_dir.gsub("$environment", e)
              end
            end
          end
        end

        new_env.reject { |k, v| k.nil? or v.nil? }
      end
    end

    attr_reader :name, :paths

    def initialize args
      @name = args[:name].to_s || raise("Must provide a name")
      @paths= args[:paths]     || raise("Must provide a path")
    end

    def to_s
      name
    end

    def classes
      paths.map {|path| PuppetClass.scan_directory path}.flatten
    end

  end
end
