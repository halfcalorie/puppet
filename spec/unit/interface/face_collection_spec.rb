#! /usr/bin/env ruby
require 'spec_helper'

require 'tmpdir'
require 'oregano/interface'

describe Oregano::Interface::FaceCollection do

  # To prevent conflicts with other specs that use faces, we must save and restore global state.
  # Because there are specs that do 'describe Oregano::Face[...]', we must restore the same objects otherwise
  # the 'subject' of the specs will differ.
  before :all do
    # Save FaceCollection's global state
    faces = described_class.instance_variable_get(:@faces)
    @faces = faces.dup
    faces.each do |k, v|
      @faces[k] = v.dup
    end
    @faces_loaded = described_class.instance_variable_get(:@loaded)

    # Save the already required face files
    @required = []
    $".each do |path|
      @required << path if path =~ /face\/.*\.rb$/
    end

    # Save Autoload's global state
    @loaded = Oregano::Util::Autoload.instance_variable_get(:@loaded).dup
  end

  after :all do
    # Restore global state
    described_class.instance_variable_set :@faces, @faces
    described_class.instance_variable_set :@loaded, @faces_loaded
    $".delete_if { |path| path =~ /face\/.*\.rb$/ }
    @required.each { |path| $".push path unless $".include? path }
    Oregano::Util::Autoload.instance_variable_set(:@loaded, @loaded)
  end

  before :each do
    # Before each test, clear the faces
    subject.instance_variable_get(:@faces).clear
    subject.instance_variable_set(:@loaded, false)
    Oregano::Util::Autoload.instance_variable_get(:@loaded).clear
    $".delete_if { |path| path =~ /face\/.*\.rb$/ }
  end

  describe "::[]" do
    before :each do
      subject.instance_variable_get("@faces")[:foo][SemanticOregano::Version.parse('0.0.1')] = 10
    end

    it "should return the face with the given name" do
      expect(subject["foo", '0.0.1']).to eq(10)
    end

    it "should attempt to load the face if it isn't found" do
      subject.expects(:require).once.with('oregano/face/bar')
      subject.expects(:require).once.with('oregano/face/0.0.1/bar')
      subject["bar", '0.0.1']
    end

    it "should attempt to load the default face for the specified version :current" do
      subject.expects(:require).with('oregano/face/fozzie')
      subject['fozzie', :current]
    end

    it "should return true if the face specified is registered" do
      subject.instance_variable_get("@faces")[:foo][SemanticOregano::Version.parse('0.0.1')] = 10
      expect(subject["foo", '0.0.1']).to eq(10)
    end

    it "should attempt to require the face if it is not registered" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:bar][SemanticOregano::Version.parse('0.0.1')] = true
        file == 'oregano/face/bar'
      end
      expect(subject["bar", '0.0.1']).to be_truthy
    end

    it "should return false if the face is not registered" do
      subject.stubs(:require).returns(true)
      expect(subject["bar", '0.0.1']).to be_falsey
    end

    it "should return false if the face file itself is missing" do
      subject.stubs(:require).
        raises(LoadError, 'no such file to load -- oregano/face/bar').then.
        raises(LoadError, 'no such file to load -- oregano/face/0.0.1/bar')
      expect(subject["bar", '0.0.1']).to be_falsey
    end

    it "should register the version loaded by `:current` as `:current`" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:huzzah]['2.0.1'] = :huzzah_face
        file == 'oregano/face/huzzah'
      end
      subject["huzzah", :current]
      expect(subject.instance_variable_get("@faces")[:huzzah][:current]).to eq(:huzzah_face)
    end

    context "with something on disk" do
      it "should register the version loaded from `oregano/face/{name}` as `:current`" do
        expect(subject["huzzah", '2.0.1']).to be
        expect(subject["huzzah", :current]).to be
        expect(Oregano::Face[:huzzah, '2.0.1']).to eq(Oregano::Face[:huzzah, :current])
      end

      it "should index :current when the code was pre-required" do
        expect(subject.instance_variable_get("@faces")[:huzzah]).not_to be_key :current
        require 'oregano/face/huzzah'
        expect(subject[:huzzah, :current]).to be_truthy
      end
    end

    it "should not cause an invalid face to be enumerated later" do
      expect(subject[:there_is_no_face, :current]).to be_falsey
      expect(subject.faces).not_to include :there_is_no_face
    end
  end

  describe "::get_action_for_face" do
    it "should return an action on the current face" do
      expect(Oregano::Face::FaceCollection.get_action_for_face(:huzzah, :bar, :current)).
        to be_an_instance_of Oregano::Interface::Action
    end

    it "should return an action on an older version of a face" do
      action = Oregano::Face::FaceCollection.
        get_action_for_face(:huzzah, :obsolete, :current)

      expect(action).to be_an_instance_of Oregano::Interface::Action
      expect(action.face.version).to eq(SemanticOregano::Version.parse('1.0.0'))
    end

    it "should load the full older version of a face" do
      action = Oregano::Face::FaceCollection.
        get_action_for_face(:huzzah, :obsolete, :current)

      expect(action.face.version).to eq(SemanticOregano::Version.parse('1.0.0'))
      expect(action.face).to be_action :obsolete_in_core
    end

    it "should not add obsolete actions to the current version" do
      action = Oregano::Face::FaceCollection.
        get_action_for_face(:huzzah, :obsolete, :current)

      expect(action.face.version).to eq(SemanticOregano::Version.parse('1.0.0'))
      expect(action.face).to be_action :obsolete_in_core

      current = Oregano::Face[:huzzah, :current]
      expect(current.version).to eq(SemanticOregano::Version.parse('2.0.1'))
      expect(current).not_to be_action :obsolete_in_core
      expect(current).not_to be_action :obsolete
    end
  end

  describe "::register" do
    it "should store the face by name" do
      face = Oregano::Face.new(:my_face, '0.0.1')
      subject.register(face)
      expect(subject.instance_variable_get("@faces")).to eq({
        :my_face => { face.version => face }
      })
    end
  end

  describe "::underscorize" do
    faulty = [1, "23foo", "#foo", "$bar", "sturm und drang", :"sturm und drang"]
    valid  = {
      "Foo"       => :foo,
      :Foo        => :foo,
      "foo_bar"   => :foo_bar,
      :foo_bar    => :foo_bar,
      "foo-bar"   => :foo_bar,
      :"foo-bar"  => :foo_bar,
      "foo_bar23" => :foo_bar23,
      :foo_bar23  => :foo_bar23,
    }

    valid.each do |input, expect|
      it "should map #{input.inspect} to #{expect.inspect}" do
        result = subject.underscorize(input)
        expect(result).to eq(expect)
      end
    end

    faulty.each do |input|
      it "should fail when presented with #{input.inspect} (#{input.class})" do
        expect { subject.underscorize(input) }.
          to raise_error ArgumentError, /not a valid face name/
      end
    end
  end

  context "faulty faces" do
    before :each do
      $:.unshift "#{OreganoSpec::FIXTURE_DIR}/faulty_face"
    end

    after :each do
      $:.delete_if {|x| x == "#{OreganoSpec::FIXTURE_DIR}/faulty_face"}
    end

    it "should not die if a face has a syntax error" do
      expect(subject.faces).to be_include :help
      expect(subject.faces).not_to be_include :syntax
      expect(@logs).not_to be_empty
      expect(@logs.first.message).to match(/syntax error/)
    end
  end
end
