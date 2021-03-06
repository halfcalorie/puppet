#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/indirector/facts/facter'

module NodeFactsFacterSpec
describe Oregano::Node::Facts::Facter do
  FS = Oregano::FileSystem

  it "should be a subclass of the Code terminus" do
    expect(Oregano::Node::Facts::Facter.superclass).to equal(Oregano::Indirector::Code)
  end

  it "should have documentation" do
    expect(Oregano::Node::Facts::Facter.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:facts)
    expect(Oregano::Node::Facts::Facter.indirection).to equal(indirection)
  end

  it "should have its name set to :facter" do
    expect(Oregano::Node::Facts::Facter.name).to eq(:facter)
  end

  before :each do
    Oregano::Node::Facts::Facter.stubs(:reload_facter)
    @facter = Oregano::Node::Facts::Facter.new
    Facter.stubs(:to_hash).returns({})
    @name = "me"
    @request = stub 'request', :key => @name
    @environment = stub 'environment'
    @request.stubs(:environment).returns(@environment)
    @request.environment.stubs(:modules).returns([])
    @request.environment.stubs(:modulepath).returns([])
  end

  describe 'when finding facts' do
    it 'should reset facts' do
      reset = sequence 'reset'
      Facter.expects(:reset).in_sequence(reset)
      Oregano::Node::Facts::Facter.expects(:setup_search_paths).in_sequence(reset)
      @facter.find(@request)
    end

    it 'should add the oreganoversion and agent_specified_environment facts' do
      reset = sequence 'reset'
      Facter.expects(:reset).in_sequence(reset)
      Facter.expects(:add).with(:oreganoversion)
      Facter.expects(:add).with(:agent_specified_environment)
      @facter.find(@request)
    end

    it 'should include external facts' do
      reset = sequence 'reset'
      Facter.expects(:reset).in_sequence(reset)
      Oregano::Node::Facts::Facter.expects(:setup_external_search_paths).in_sequence(reset)
      Oregano::Node::Facts::Facter.expects(:setup_search_paths).in_sequence(reset)
      @facter.find(@request)
    end

    it "should return a Facts instance" do
      expect(@facter.find(@request)).to be_instance_of(Oregano::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      expect(@facter.find(@request).name).to eq(@name)
    end

    it "should return the Facter facts as the values in the Facts instance" do
      Facter.expects(:to_hash).returns("one" => "two")
      facts = @facter.find(@request)
      expect(facts.values["one"]).to eq("two")
    end

    it "should add local facts" do
      facts = Oregano::Node::Facts.new("foo")
      Oregano::Node::Facts.expects(:new).returns facts
      facts.expects(:add_local_facts)

      @facter.find(@request)
    end

    it "should sanitize facts" do
      facts = Oregano::Node::Facts.new("foo")
      Oregano::Node::Facts.expects(:new).returns facts
      facts.expects(:sanitize)

      @facter.find(@request)
    end
  end

  it 'should fail when saving facts' do
    expect { @facter.save(@facts) }.to raise_error(Oregano::DevError)
  end

  it 'should fail when destroying facts' do
    expect { @facter.destroy(@facts) }.to raise_error(Oregano::DevError)
  end

  describe 'when setting up search paths' do
    let(:factpath1) { File.expand_path 'one' }
    let(:factpath2) { File.expand_path 'two' }
    let(:factpath) { [factpath1, factpath2].join(File::PATH_SEPARATOR) }
    let(:modulepath) { File.expand_path 'module/foo' }
    let(:modulelibfacter) { File.expand_path 'module/foo/lib/facter' }
    let(:modulepluginsfacter) { File.expand_path 'module/foo/plugins/facter' }

    before :each do
      FileTest.expects(:directory?).with(factpath1).returns true
      FileTest.expects(:directory?).with(factpath2).returns true
      @request.environment.stubs(:modulepath).returns [modulepath]
      Dir.expects(:glob).with("#{modulepath}/*/lib/facter").returns [modulelibfacter]
      Dir.expects(:glob).with("#{modulepath}/*/plugins/facter").returns [modulepluginsfacter]

      Oregano[:factpath] = factpath
    end

    it 'should skip files' do
      FileTest.expects(:directory?).with(modulelibfacter).returns false
      FileTest.expects(:directory?).with(modulepluginsfacter).returns false
      Facter.expects(:search).with(factpath1, factpath2)
      Oregano::Node::Facts::Facter.setup_search_paths @request
    end

    it 'should add directories' do
      FileTest.expects(:directory?).with(modulelibfacter).returns true
      FileTest.expects(:directory?).with(modulepluginsfacter).returns true
      Facter.expects(:search).with(modulelibfacter, modulepluginsfacter, factpath1, factpath2)
      Oregano::Node::Facts::Facter.setup_search_paths @request
    end
  end

  describe 'when setting up external search paths' do
    let(:pluginfactdest) { File.expand_path 'plugin/dest' }
    let(:modulepath) { File.expand_path 'module/foo' }
    let(:modulefactsd) { File.expand_path 'module/foo/facts.d'  }

    before :each do
      FileTest.expects(:directory?).with(pluginfactdest).returns true
      mod = Oregano::Module.new('foo', modulepath, @request.environment)
      @request.environment.stubs(:modules).returns [mod]
      Oregano[:pluginfactdest] = pluginfactdest
    end

    it 'should skip files' do
      File.expects(:directory?).with(modulefactsd).returns false
      Facter.expects(:search_external).with [pluginfactdest]
      Oregano::Node::Facts::Facter.setup_external_search_paths @request
    end

    it 'should add directories' do
      File.expects(:directory?).with(modulefactsd).returns true
      Facter.expects(:search_external).with [modulefactsd, pluginfactdest]
      Oregano::Node::Facts::Facter.setup_external_search_paths @request
    end
  end
end
end
