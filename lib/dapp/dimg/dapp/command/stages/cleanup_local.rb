module Dapp
  module Dimg
    module Dapp
      module Command
        module Stages
          module CleanupLocal
            def stages_cleanup_local
              lock_repo(option_repo, readonly: true) do
                raise Error::Command, code: :stages_cleanup_required_option unless stages_cleanup_option?

                dapp_containers_flush

                proper_cache           if proper_cache_version?
                stages_cleanup_by_repo if proper_repo_cache?
                proper_git_commit      if proper_git_commit?
              end
            end

            protected

            def proper_cache
              log_proper_cache do
                lock("#{name}.images") do
                  log_step_with_indent(name) do
                    remove_images(dapp_images_names.select { |image_name| !actual_cache_images.include?(image_name) })
                  end
                end
              end
            end

            def stages_cleanup_by_repo
              registry = registry(option_repo)
              repo_dimgs = repo_dimgs_images(registry)

              lock("#{name}.images") do
                log_step_with_indent(name) do
                  dapp_dangling_images_flush
                  dimgs, stages = dapp_images_hash.partition { |_, image_spec| repo_dimgs.values.include?(image_spec[:id]) }.map(&:to_h)
                  dimgs.each { |_, dimg_spec| except_image_with_parents(dimg_spec[:id], stages) }

                  # Удаление только образов старше 2ч
                  stages.delete_if do |_, stage_spec|
                    Time.now - stage_spec[:created_at] < 2*60*60
                  end

                  remove_images(stages.keys)
                end
              end
            end

            def repo_dimgs_images(registry)
              repo_dimgs_and_cache(registry).first
            end

            def actual_cache_images
              @actual_cache_images ||= begin
                shellout!([
                  "#{host_docker} images",
                  '--format="{{.Repository}}:{{.Tag}}"',
                  %(-f "label=dapp-cache-version=#{::Dapp::BUILD_CACHE_VERSION}"),
                  stage_cache
                ].join(' ')).stdout.lines.map(&:strip)
              end
            end

            def dapp_images_hash
              shellout!(%(#{host_docker} images --format "{{.Repository}}:{{.Tag}};{{.ID}};{{.CreatedAt}}" --no-trunc #{stage_cache}))
                .stdout.lines.map do |line|
                  name, id, created_at = line.strip.split(';', 3)
                  [name, {name: name, id: id, created_at: Time.parse(created_at)}]
                end.to_h
            end

            def except_image_with_parents(image_id, stages)
              if image_exist?(image_id)
                image_dapp_artifacts_label(image_id).each { |aiid| except_image_with_parents(aiid, stages) }
                iid = image_id
                loop do
                  stages.delete_if { |_, stage_spec| stage_spec[:id] == iid }
                  break if (iid = image_parent(iid)).empty?
                end
              else
                stages.delete_if { |_, stage_spec| stage_spec[:id] == image_id }
              end
            end

            def image_exist?(image_id)
              shellout!(%(#{host_docker} inspect #{image_id}))
              true
            rescue ::Dapp::Error::Shellout
              false
            end

            def image_dapp_artifacts_label(image_id)
              select_dapp_artifacts_ids(::Dapp::Dimg::Image::Docker.image_config_option(image_id: image_id, option: 'Labels') || {})
            end

            def image_parent(image_id)
              shellout!(%(#{host_docker} inspect -f {{.Parent}} #{image_id})).stdout.strip
            end

            def proper_git_commit
              log_proper_git_commit do
                unproper_images_names = []
                dapp_images_detailed.each do |_, attrs|
                  attrs['Config']['Labels'].each do |repo_name, commit|
                    next if (repo = dapp_git_repositories[repo_name]).nil?
                    unproper_images_names.concat(image_hierarchy_by_id(attrs['Id'])) unless repo.commit_exists?(commit)
                  end
                end
                remove_images(unproper_images_names.uniq)
              end
            end

            def dapp_images_detailed
              @dapp_images_detailed ||= {}.tap do |images|
                dapp_images_names.each do |image_name|
                  shellout!(%(#{host_docker} inspect --format='{{json .}}' #{image_name})).stdout.strip.tap do |output|
                    images[image_name] = output == 'null' ? {} : JSON.parse(output)
                  end
                end
              end
            end

            def image_hierarchy_by_id(image_id)
              hierarchy = []
              iids = [image_id]

              loop do
                hierarchy.concat(dapp_images_detailed.map { |name, attrs| name if iids.include?(attrs['Id']) }.compact)
                break if begin
                  iids.map! do |iid|
                    dapp_images_detailed.map { |_, attrs| attrs['Id'] if attrs['Parent'] == iid }.compact
                  end.flatten!.empty?
                end
              end

              hierarchy
            end
          end
        end
      end
    end
  end # Dimg
end # Dapp
