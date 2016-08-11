require_relative '../spec_helper'

describe Dapp::Application do
  include SpecHelper::Common
  include SpecHelper::Application
  include SpecHelper::Git

  before :all do
    @wd = Dir.pwd
    init
  end

  before :each do
    application_build!
  end

  after :all do
    Dir.chdir @wd
  end

  def init
    FileUtils.rm_rf project_path
    FileUtils.mkpath project_path
    Dir.chdir project_path
    git_init!
  end

  def project_path
    Pathname('/tmp/dapp/test')
  end

  def project_dapp_path
    project_path.join('.dapps/dapp')
  end

  def config
    @config ||= default_config.merge(
      _builder: :shell,
      _home_path: project_path,
      _docker: default_config[:_docker].merge(_from: :'ubuntu:16.04'),
      _git_artifact: default_config[:_git_artifact].merge(_local: { _artifact_options: { where_to_add: '/app' } })
    )
  end

  def stages_names
    @stages ||= stages.keys.reverse
  end

  def stage_index(stage_name)
    stages_names.index(stage_name)
  end

  def stages_signatures
    stages.values.map { |s| [:"#{s.send(:name)}", s.send(:signature)] }.to_h
  end

  def check_image_command(stage_name, command)
    expect(stages[stage_name].send(:image).send(:bash_commands).join =~ Regexp.new(command)).to be
  end

  def expect_from_image
    check_image_command(:source_1_archive, 'tar -x')
  end

  def expect_infra_install_image
    check_image_command(:infra_install, config[:_shell][:_infra_install].last)
    check_image_command(:source_1_archive, 'tar -x')
  end

  [:install, :infra_setup, :setup].each do |stage_name|
    define_method "expect_#{stage_name}_image" do
      check_image_command(stage_name, config[:_shell][:"_#{stage_name}"].last)
      check_image_command(prev_stage(stage_name), 'apply')
    end
  end

  [:source_4, :source_5].each do |stage_name|
    define_method "expect_#{stage_name}_image" do
      check_image_command(stage_name, 'apply')
    end
  end

  def change_from
    config[:_docker][:_from] = :'ubuntu:14.04'
  end

  [:infra_install, :install, :infra_setup, :setup].each do |stage_name|
    define_method :"change_#{stage_name}" do
      config[:_shell][:"_#{stage_name}"] << generate_command
    end
  end

  def change_source_4
    file_path = project_path.join('large_file')
    if File.exist? file_path
      FileUtils.rm file_path
      git_commit!
    else
      git_change_and_commit!('large_file', 'x' * 1024 * 1024)
    end
  end

  def change_source_5
    git_change_and_commit!
  end

  def from_modified_signatures
    stages_names
  end

  def infra_install_modified_signatures
    stages_names[stage_index(:infra_install)..-1]
  end

  [:install, :infra_setup, :setup].each do |stage_name|
    define_method "#{stage_name}_modified_signatures" do
      stages_names[stage_index(stage_name) - 2..-1]
    end
  end

  [:source_4, :source_5].each do |stage_name|
    define_method "#{stage_name}_modified_signatures" do
      stages_names[stage_index(stage_name)..-1]
    end
  end

  def from_saved_signatures
    []
  end

  def infra_install_saved_signatures
    [stages_names.first]
  end

  [:install, :infra_setup, :setup].each do |stage_name|
    define_method "#{stage_name}_saved_signatures" do
      stages_names[0..stage_index(stage_name) - 3]
    end
  end

  def source_4_saved_signatures
    stages_names[0..stage_index(:source_4) - 2]
  end

  def source_5_saved_signatures
    stages_names[0..stage_index(:source_5) - 1]
  end

  def build_and_check(stage_name)
    check_signatures_and_build(stage_name)
    send("expect_#{stage_name}_image")
  end

  def check_signatures_and_build(stage_name)
    saved_signatures = stages_signatures
    send(:"change_#{stage_name}")
    application_renew
    expect_stages_signatures(stage_name, saved_signatures, stages_signatures)
    application_build!
  end

  def expect_stages_signatures(stage_name, saved_keys, new_keys)
    send("#{stage_name}_saved_signatures").each { |s| expect(saved_keys).to include s => new_keys[s] }
    send("#{stage_name}_modified_signatures").each { |s| expect(saved_keys).to_not include s => new_keys[s] }
  end

  def source_5
    build_and_check(:source_5)
  end

  def source_4
    build_and_check(:source_4)
    source_5
  end

  def setup
    build_and_check(:setup)
    source_5
    source_4
  end

  def infra_setup
    build_and_check(:infra_setup)
    source_5
    source_4
    setup
  end

  def install
    build_and_check(:install)
    source_5
    source_4
    setup
    infra_setup
  end

  def infra_install
    build_and_check(:infra_install)
    source_5
    source_4
    setup
    infra_setup
    install
  end

  def from
    build_and_check(:from)
    source_5
    source_4
    setup
    infra_setup
    install
    infra_install
  end

  [:source_5, :source_4, :setup, :infra_setup, :install, :infra_install, :from].each do |stage|
    it "test #{stage}" do
      send(stage)
    end
  end
end
