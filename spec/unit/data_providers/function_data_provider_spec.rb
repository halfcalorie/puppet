#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano_spec/compiler'

describe "when using function data provider" do
  include OreganoSpec::Compiler

  # There is a fully configured environment in fixtures in this location
  let(:environmentpath) { parent_fixture('environments') }

  around(:each) do |example|
    # Initialize settings to get a full compile as close as possible to a real
    # environment load
    Oregano.settings.initialize_global_settings
    # Initialize loaders based on the environmentpath. It does not work to
    # just set the setting environmentpath for some reason - this achieves the same:
    # - first a loader is created, loading directory environments from the fixture (there is
    # one such environment, 'production', which will be loaded since the node references this
    # environment by name).
    # - secondly, the created env loader is set as 'environments' in the oregano context.
    #
    loader = Oregano::Environments::Directories.new(environmentpath, [])
    Oregano.override(:environments => loader) do
      example.run
    end
  end

  # The environment configured in the fixture has one module called 'abc'. Its class abc, includes
  # a class called 'def'. This class has three parameters test1, test2, and test3 and it creates
  # three notify with name set to the value of the three parameters.
  #
  # Since the abc class does not provide any parameter values to its def class, it attempts to
  # get them from data lookup. The fixture has an environment that is configured to load data from
  # a function called environment::data, this data sets test1, and test2.
  # The module 'abc' is configured to get data by calling the function abc::data(), this function
  # returns data for all three parameters test1-test3, now with the prefix 'module'.
  #
  # The result should be that the data set in the environment wins over those set in the
  # module.
  #
  it 'gets data from module and environment functions and combines them with env having higher precedence' do
    Oregano[:code] = 'include abc'
    node = Oregano::Node.new("testnode", :facts => Oregano::Node::Facts.new("facts", {}), :environment => 'production')
    compiler = Oregano::Parser::Compiler.new(node)
    catalog = compiler.compile()
    resources_created_in_fixture = ["Notify[env_test1]", "Notify[env_test2]", "Notify[module_test3]", "Notify[env_test2-ipl]"]
    expect(resources_in(catalog)).to include(*resources_created_in_fixture)
  end

  it 'gets data from module having a oregano function delivering module data' do
    Oregano[:code] = 'include xyz'
    node = Oregano::Node.new("testnode", :facts => Oregano::Node::Facts.new("facts", {}), :environment => 'production')
    compiler = Oregano::Parser::Compiler.new(node)
    catalog = compiler.compile()
    resources_created_in_fixture = ["Notify[env_test1]", "Notify[env_test2]", "Notify[module_test3]"]
    expect(resources_in(catalog)).to include(*resources_created_in_fixture)
  end

  it 'gets data from oregano function delivering environment data' do
    Oregano[:code] = <<-CODE
      function environment::data() {
        { 'cls::test1' => 'env_oregano1',
          'cls::test2' => 'env_oregano2'
        }
      }
      class cls ($test1, $test2) {
        notify { $test1: }
        notify { $test2: }
      }
      include cls
    CODE
    node = Oregano::Node.new('testnode', :facts => Oregano::Node::Facts.new('facts', {}), :environment => 'production')
    catalog = Oregano::Parser::Compiler.new(node).compile
    expect(resources_in(catalog)).to include('Notify[env_oregano1]', 'Notify[env_oregano2]')
  end

  it 'raises an error if the environment data function does not return a hash' do
    Oregano[:code] = 'include abc'
    # find the loaders to patch with faulty function
    node = Oregano::Node.new("testnode", :facts => Oregano::Node::Facts.new("facts", {}), :environment => 'production')

    compiler = Oregano::Parser::Compiler.new(node)
    loaders = compiler.loaders()
    env_loader = loaders.private_environment_loader()
    f = Oregano::Functions.create_function('environment::data') do
      def data()
        'this is not a hash'
      end
    end
    env_loader.add_entry(:function, 'environment::data', f.new(compiler.topscope, env_loader), nil)
    expect do
      compiler.compile()
    end.to raise_error(/Value returned from deprecated API function 'environment::data' has wrong type/)
  end

  it 'raises an error if the module data function does not return a hash' do
    Oregano[:code] = 'include abc'
    # find the loaders to patch with faulty function
    node = Oregano::Node.new("testnode", :facts => Oregano::Node::Facts.new("facts", {}), :environment => 'production')

    compiler = Oregano::Parser::Compiler.new(node)
    loaders = compiler.loaders()
    module_loader = loaders.public_loader_for_module('abc')
    f = Oregano::Functions.create_function('abc::data') do
      def data()
        'this is not a hash'
      end
    end
    module_loader.add_entry(:function, 'abc::data', f.new(compiler.topscope, module_loader), nil)
    expect do
      compiler.compile()
    end.to raise_error(/Value returned from deprecated API function 'abc::data' has wrong type/)
  end

  def parent_fixture(dir_name)
    File.absolute_path(File.join(my_fixture_dir(), "../#{dir_name}"))
  end

  def resources_in(catalog)
    catalog.resources.map(&:ref)
  end

end
