#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

describe Oregano::Face[:help, '0.0.1'] do
  it "has a help action" do
    expect(subject).to be_action :help
  end

  it "has a default action of help" do
    expect(subject.get_action('help')).to be_default
  end

  it "accepts a call with no arguments" do
    expect {
      subject.help()
    }.to_not raise_error
  end

  it "accepts a face name" do
    expect { subject.help(:help) }.to_not raise_error
  end

  it "accepts a face and action name" do
    expect { subject.help(:help, :help) }.to_not raise_error
  end

  it "fails if more than a face and action are given" do
    expect { subject.help(:help, :help, :for_the_love_of_god) }.
      to raise_error ArgumentError
  end

  it "treats :current and 'current' identically" do
    expect(subject.help(:help, :version => :current)).to eq(
      subject.help(:help, :version => 'current')
    )
  end

  it "raises an error when the face is unavailable" do
    expect {
      subject.help(:huzzah, :bar, :version => '17.0.0')
    }.to raise_error(ArgumentError, /Could not find version 17\.0\.0/)
  end

  it "finds a face by version" do
    face = Oregano::Face[:huzzah, :current]
    expect(subject.help(:huzzah, :version => face.version)).
      to eq(subject.help(:huzzah, :version => :current))
  end

  it "raises an ArgumentError if the face raises a StandardError" do
    face = Oregano::Face[:module, :current]
    face.stubs(:short_description).raises(StandardError, "whoops")

    expect {
      subject.help(:module)
    }.to raise_error(ArgumentError, /Detail: "whoops"/)
  end

  it "raises an ArgumentError if the face raises a LoadError" do
    face = Oregano::Face[:module, :current]
    face.stubs(:short_description).raises(LoadError, "cannot load such file -- yard")

    expect {
      subject.help(:module)
    }.to raise_error(ArgumentError, /Detail: "cannot load such file -- yard"/)
  end

  context "when listing subcommands" do
    subject { Oregano::Face[:help, :current].help }

    RSpec::Matchers.define :have_a_summary do
      match do |instance|
        instance.summary.is_a?(String)
      end
    end

    # Check a precondition for the next block; if this fails you have
    # something odd in your set of face, and we skip testing things that
    # matter. --daniel 2011-04-10
    it "has at least one face with a summary" do
      expect(Oregano::Face.faces).to be_any do |name|
        Oregano::Face[name, :current].summary
      end
    end

    it "lists all faces which are runnable from the command line" do
      help_face = Oregano::Face[:help, :current]
      # The main purpose of the help face is to provide documentation for
      #  command line users.  It shouldn't show documentation for faces
      #  that can't be run from the command line, so, rather than iterating
      #  over all available faces, we need to iterate over the subcommands
      #  that are available from the command line.
      Oregano::Application.available_application_names.each do |name|
        next unless help_face.is_face_app?(name)
        next if help_face.exclude_from_docs?(name)
        face = Oregano::Face[name, :current]
        summary = face.summary

        expect(subject).to match(%r{ #{name} })
        summary and expect(subject).to match(%r{ #{name} +#{summary}})
      end
    end

    it "returns an 'unavailable' summary if the 'agent' application fails to generate help" do
      Oregano::Application['agent'].class.any_instance.stubs(:summary).raises(ArgumentError, "whoops")

      expect(subject).to match(/agent\s+! Subcommand unavailable due to error\. Check error logs\./)
    end

    it "returns an 'unavailable' summary if the legacy application raises a LoadError" do
      Oregano::Application['agent'].class.any_instance.stubs(:summary).raises(LoadError, "cannot load such file -- yard")

      expect(subject).to match(/agent\s+! Subcommand unavailable due to error\. Check error logs\./)
    end

    context "face summaries" do
      it "can generate face summaries" do
        faces = Oregano::Face.faces
        expect(faces.length).to be > 0
        faces.each do |name|
          expect(Oregano::Face[name, :current]).to have_a_summary
        end
      end

      it "returns an 'unavailable' summary if the face application raises a LoadError" do
        face = Oregano::Face[:module, :current]
        face.stubs(:summary).raises(LoadError, "cannot load such file -- yard")

        expect(Oregano::Face[:help, :current].help).to match(/module\s+! Subcommand unavailable due to error\. Check error logs\./)
      end
    end

    it "lists all legacy applications" do
      Oregano::Face[:help, :current].legacy_applications.each do |appname|
        expect(subject).to match(%r{ #{appname} })

        summary = Oregano::Face[:help, :current].horribly_extract_summary_from(appname)
        summary and expect(subject).to match(%r{ #{summary}\b})
      end
    end
  end

  context "deprecated faces" do
    it "prints a deprecation warning for deprecated faces" do
      Oregano::Face[:module, :current].stubs(:deprecated?).returns(true)
      expect(Oregano::Face[:help, :current].help(:module)).to match(/Warning: 'oregano module' is deprecated/)
    end
  end

  context "#all_application_summaries" do
    it "appends a deprecation warning for deprecated faces" do
      # Stub the module face as deprecated
      Oregano::Face[:module, :current].expects(:deprecated?).returns(true)
      result = Oregano::Face[:help, :current].all_application_summaries.each do |appname,summary|
        expect(summary).to match(/Deprecated/) if appname == 'module'
      end
    end
  end

  context "#legacy_applications" do
    subject { Oregano::Face[:help, :current].legacy_applications }

    # If we don't, these tests are ... less than useful, because they assume
    # it.  When this breaks you should consider ditching the entire feature
    # and tests, but if not work out how to fake one. --daniel 2011-04-11
    it { is_expected.to have_at_least(1).item }

    # Meh.  This is nasty, but we can't control the other list; the specific
    # bug that caused these to be listed is annoyingly subtle and has a nasty
    # fix, so better to have a "fail if you do something daft" trigger in
    # place here, I think. --daniel 2011-04-11
    %w{face_base indirection_base}.each do |name|
      it { is_expected.not_to include name }
    end
  end

  context "help for legacy applications" do
    subject { Oregano::Face[:help, :current] }
    let :appname do subject.legacy_applications.first end

    # This test is purposely generic, so that as we eliminate legacy commands
    # we don't get into a loop where we either test a face-based replacement
    # and fail to notice breakage, or where we have to constantly rewrite this
    # test and all. --daniel 2011-04-11
    it "returns the legacy help when given the subcommand" do
      help = subject.help(appname)
      expect(help).to match(/oregano-#{appname}/)
      %w{SYNOPSIS USAGE DESCRIPTION OPTIONS COPYRIGHT}.each do |heading|
        expect(help).to match(/^#{heading}$/)
      end
    end

    it "fails when asked for an action on a legacy command" do
      expect { subject.help(appname, :whatever) }.
        to raise_error ArgumentError, /Legacy subcommands don't take actions/
    end

    it "raises an ArgumentError if a legacy application raises a StandardError" do
      Oregano::Application[appname].class.any_instance.stubs(:help).raises(StandardError, "whoops")

      expect {
        subject.help(appname)
      }.to raise_error ArgumentError, /Detail: "whoops"/
    end

    it "raises an ArgumentError if a legacy application raises a LoadError" do
      Oregano::Application[appname].class.any_instance.stubs(:help).raises(LoadError, "cannot load such file -- yard")

      expect {
        subject.help(appname)
      }.to raise_error ArgumentError, /Detail: "cannot load such file -- yard"/
    end
  end
end
