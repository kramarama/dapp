module Dapp
  module Dimg
    module Dapp
      module Command
        module Push
          def push
            #require 'ruby-prof'
            #RubyProf.start
            repo = option_repo
            validate_repo_name!(repo)
            log_step_with_indent(:stages) { stages_push } if with_stages?
            build_configs.each do |config|
              log_dimg_name_with_indent(config) do
                Dimg.new(config: config, dapp: self, ignore_git_fetch: true, should_be_built: true).tap do |dimg|
                  dimg.export!(repo, format: push_format(config._name))
                end
              end
            end
            # FIXME: rework images cache, then profile
            #result = RubyProf.stop
            #printer = RubyProf::MultiPrinter.new(result)
            #printer.print(path: '/tmp/testdapp.push.profile', profile: 'profile')
          end


          protected

          def with_stages?
            !!options[:with_stages]
          end
        end
      end
    end
  end # Dimg
end # Dapp
